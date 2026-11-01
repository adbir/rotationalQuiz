import '../models/fight_log.dart';
import '../models/pooling_report.dart';
import '../models/resource_timeline.dart';
import '../specs/rotation_spec.dart';

/// Checks whether a player held back their resource before known events.
///
/// For each event time (the caller finds add waves or phases) it reports the
/// resource around it and the gap since the player's last spender, and judges
/// two ways. [PoolingReport.isHeld] is the better test: the gap is longer than
/// [heldGapFactor] times the player's own median gap, or [heldGapFloor], and a
/// spender comes within [heldFollow]. [PoolingReport.isPooled] compares the
/// mean resource in the [lead] before with the fight's mean. It says what
/// happened, not why.
class DetectPooling {
  const DetectPooling(
    this.spec, {
    this.lead = const Duration(seconds: 10),
    this.follow = const Duration(seconds: 8),
    this.margin = 15,
    this.heldGapFactor = 2,
    this.heldGapFloor = const Duration(seconds: 10),
    this.heldFollow = const Duration(seconds: 5),
  });

  final RotationSpec spec;

  /// How far before an event to look.
  final Duration lead;

  /// How far after an event to look for spenders.
  final Duration follow;

  /// How far above the player's normal level counts as held back, in points.
  final double margin;

  /// A gap this many times the player's median gap counts as a hold...
  final double heldGapFactor;

  /// ...and so does any gap longer than this.
  final Duration heldGapFloor;

  /// A held spender must be cast within this long after the event.
  final Duration heldFollow;

  // Held-spender rule checked on Mythic Twin Fangs (docs/warcraft-logs.md):
  // rank 1 (CGjdNa8RBfcQtAWg fight 33, median gap 5.2 s) held at 98, 192, 253
  // and 347 s (gaps 17.8, 17.0, 15.3, 11.6 s) and not at 37 or 408 s (4.6 and
  // 0.6 s). The mean-based isPooled read those as 52 to 80 against a fight
  // mean of 65, so it stays only as the Maelstrom numbers.
  // ponytail: the median gap is over the whole fight, so a player who holds
  // often has a longer median. The ceiling is a median per phase.
  List<PoolingReport> call(
    FightLog log,
    ResourceTimeline timeline,
    List<Duration> eventTimes,
  ) {
    final spenders = {
      for (final spell in spec.spells.values)
        if (spell.cost > 0 && spell.spellId != null) spell.spellId!: spell.name,
    };
    final spends = [
      for (final cast in log.casts)
        if (!cast.isBegin && spenders.containsKey(cast.abilityId))
          (time: cast.time, name: spenders[cast.abilityId]!),
    ];
    int between(Duration from, Duration to) =>
        spends.where((s) => s.time > from && s.time <= to).length;
    final median = _medianGap([for (final s in spends) s.time]);

    final normal = timeline.mean(Duration.zero, timeline.end);
    return [
      for (final time in eventTimes)
        () {
          final from = time - lead < Duration.zero
              ? Duration.zero
              : time - lead;
          final mean = timeline.mean(from, time);
          final after = between(time, time + follow);
          final last = spends.where((s) => s.time <= time).lastOrNull;
          final next = spends.where((s) => s.time > time).firstOrNull;
          final gap = time - (last?.time ?? Duration.zero);
          final offset = next == null ? null : next.time - time;
          final long =
              gap > heldGapFloor ||
              (median != null && gap > median * heldGapFactor);
          final levels = [
            timeline.at(from),
            for (final p in timeline.points)
              if (p.time > from && p.time <= time) p.amount,
          ];
          return PoolingReport(
            eventTime: time,
            meanBefore: mean,
            normalLevel: normal,
            spendersBefore: between(from, time),
            spendersAfter: after,
            isPooled: mean >= normal + margin && after > 0,
            levelAtEvent: timeline.at(time),
            lowestBefore: levels.reduce((a, b) => a < b ? a : b),
            highestBefore: levels.reduce((a, b) => a > b ? a : b),
            gapSinceLastSpender: gap,
            medianSpenderGap: median,
            firstSpenderAfter: offset,
            firstSpenderAfterName: next?.name,
            isHeld: long && offset != null && offset <= heldFollow,
          );
        }(),
    ];
  }

  static Duration? _medianGap(List<Duration> times) {
    if (times.length < 2) return null;
    final gaps = [
      for (var i = 1; i < times.length; i++) times[i] - times[i - 1],
    ]..sort();
    return gaps[gaps.length ~/ 2];
  }
}
