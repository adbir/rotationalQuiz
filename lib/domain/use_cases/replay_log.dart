import '../apl/apl_document.dart';
import '../apl/apl_evaluator.dart';
import '../models/buff_windows.dart';
import '../models/enemy_presence.dart';
import '../models/fight_log.dart';
import '../models/replay_report.dart';
import '../models/spec_definition.dart';
import '../specs/rotation_spec.dart';
import 'log_state_builder.dart';
import 'rebuild_resource_timeline.dart';

/// Replays a fight through the APL: at each GCD press it rebuilds the state
/// from the log, asks the APL what it wanted, and reports where the player
/// pressed something else. It says what happened, never why. The APL has no
/// fight timeline, so holding a spender for an add wave shows as a deviation.
class ReplayLog {
  const ReplayLog(this.spec);

  final RotationSpec spec;

  /// A cast is a press of its `begincast` when one came this soon before.
  static const _stateLag = Duration(milliseconds: 10);

  /// How far around a GCD press an off-GCD press still belongs to it.
  static const _offGcdBefore = Duration(milliseconds: 2500);
  static const _offGcdAfter = Duration(milliseconds: 1000);

  /// [talents] stands in when the log has none. [fightRemainsAfter] is how
  /// long the fight went on after a log that is only a window of it. Targets
  /// come from [presence], or are [targets] throughout.
  ReplayReport call(
    FightLog log,
    AplDocument document, {
    Set<String>? talents,
    Duration? fightRemainsAfter,
    int targets = 1,
    EnemyPresence? presence,
    double? startAmount,
  }) {
    final rules = spec.logRules;
    final events = [
      for (final cast in log.casts)
        if (!rules.duplicateCastIds.contains(cast.abilityId)) cast,
    ];
    final finished = [
      for (final cast in events)
        if (!cast.isBegin) cast,
    ];
    final builder = LogStateBuilder(
      spec,
      log,
      finished,
      RebuildResourceTimeline(spec)(log, startAmount: startAmount),
      talents: log.talents.isNotEmpty
          ? log.talents
          : talents ?? spec.loadouts.first.talents,
      fightRemainsAfter: fightRemainsAfter,
      targets: targets,
      presence: presence,
    );
    final spellsById = {
      for (final spell in spec.spells.values)
        if (spell.spellId != null) spell.spellId!: spell,
    };

    final begins = _pairBegins(events, finished, spellsById);
    var compared = 0;
    var agreements = 0;
    var skippedPresses = 0;
    var skippedOffGcd = 0;
    final deviations = <ReplayDeviation>[];
    final notes = <ReplayNote>[];

    for (var i = 0; i < finished.length; i++) {
      final cast = finished[i];
      final spell = spellsById[cast.abilityId];
      if (spell == null) {
        skippedPresses++;
        continue;
      }
      if (spell.offGcd) continue;

      final (pressTime, q) = _stateMoment(begins[i], finished, i);
      final state = builder.at(
        q,
        pressAt: i > 0 && begins[i] == null && finished[i - 1].time == cast.time
            ? cast.time
            : null,
      );
      final result = AplEvaluator(spec).recommend(document, state);
      compared++;

      skippedOffGcd += _unpressedOffGcd(result, finished, spellsById, q).length;
      final wanted = result.selected?.name;
      if (wanted == spell.id) {
        agreements++;
        continue;
      }

      // A line for the pressed ability whose condition passed but the state
      // said it couldn't be pressed: the player did press it, so the state is
      // what's wrong, not the play.
      final tie = result.trace
          .where(
            (e) =>
                e.action.name == spell.id &&
                e.outcome == TraceOutcome.unavailable &&
                e.conditionPassed != false,
          )
          .firstOrNull;
      if (tie != null) {
        agreements++;
        notes.add(
          ReplayNote(
            cast.time,
            '${spell.name}: the APL line passed but the rebuilt state said '
            '"${tie.reason}"',
          ),
        );
        continue;
      }

      final winner = result.trace
          .where((e) => e.outcome == TraceOutcome.selected)
          .firstOrNull;
      // The state that decided it is what the winning line read and what the
      // pressed ability's own lines read, which turned it down.
      final estimated = builder.estimated([
        ...?winner?.identifierValues.keys,
        for (final e in result.trace)
          if (e.action.name == spell.id) ...e.identifierValues.keys,
      ], q);
      deviations.add(
        ReplayDeviation(
          time: pressTime,
          pressed: spell.id,
          wanted: wanted,
          winningLine: winner?.action.rawLine,
          confidence: winner != null && estimated.isEmpty
              ? ReplayConfidence.exact
              : ReplayConfidence.uncertain,
          estimated: estimated,
        ),
      );
    }

    return ReplayReport(
      compared: compared,
      agreements: agreements,
      deviations: deviations,
      notes: notes,
      skippedPresses: skippedPresses,
      skippedOffGcd: skippedOffGcd,
    );
  }

  /// The `begincast` each finished cast belongs to, by index into [finished]
  /// (null for an instant). A finish takes the earliest unused `begincast` of
  /// its spell within the spell's cast time, so a chained cast's finish does
  /// not take the next cast's start. A `begincast` in the finish's own
  /// millisecond is an instant (a Lava Surge Lava Burst) and is used up
  /// without being a press time.
  static List<LogCast?> _pairBegins(
    List<LogCast> events,
    List<LogCast> finished,
    Map<int, SpellDefinition> spellsById,
  ) {
    final used = <LogCast>{};
    return [
      for (final cast in finished)
        () {
          final spell = spellsById[cast.abilityId];
          if (spell == null || spell.offGcd) return null;
          final window = Duration(
            milliseconds: (spell.castTime * 1000).round(),
          );
          final begin = events
              .where(
                (c) =>
                    c.isBegin &&
                    c.abilityId == cast.abilityId &&
                    !used.contains(c) &&
                    c.time <= cast.time &&
                    cast.time - c.time <= window,
              )
              .firstOrNull;
          if (begin == null) return null;
          used.add(begin);
          return begin.time == cast.time ? null : begin;
        }(),
    ];
  }

  /// When press [i] happened, and the moment to rebuild its state at. A cast
  /// with a [begin] is pressed there, and what its predecessor did is logged
  /// within a few milliseconds of it. An instant is read just before itself,
  /// so that a buff it spends is still up, but not before its predecessor. One
  /// pressed in the millisecond its predecessor finished is read at that
  /// millisecond, with the buffs removed in it (its own spend) still up.
  (Duration, Duration) _stateMoment(
    LogCast? begin,
    List<LogCast> finished,
    int i,
  ) {
    final cast = finished[i];
    if (begin != null) return (begin.time, begin.time + _stateLag);
    final earliest = i == 0 ? Duration.zero : finished[i - 1].time + _stateLag;
    final q = cast.time - logMoment;
    if (i > 0 && finished[i - 1].time == cast.time) {
      return (cast.time, cast.time);
    }
    final latest = cast.time - const Duration(milliseconds: 1);
    final at = q > earliest ? q : earliest;
    return (cast.time, at > latest ? latest : at);
  }

  /// Off-GCD abilities the APL wanted with this press that the player didn't
  /// press around it.
  List<String> _unpressedOffGcd(
    AplRecommendation result,
    List<LogCast> finished,
    Map<int, SpellDefinition> spellsById,
    Duration q,
  ) => [
    for (final action in result.offGcd)
      if (!finished.any(
        (c) =>
            spellsById[c.abilityId]?.id == action.name &&
            c.time >= q - _offGcdBefore &&
            c.time <= q + _offGcdAfter,
      ))
        action.name,
  ];
}
