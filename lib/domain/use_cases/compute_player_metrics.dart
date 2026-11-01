import '../models/buff_windows.dart';
import '../models/fight_log.dart';
import '../models/gap_detail.dart';
import '../models/log_rules.dart';
import '../models/player_metrics.dart';
import '../specs/rotation_spec.dart';
import 'compute_chance_proc_metrics.dart';
import 'compute_cooldown_metrics.dart';
import 'compute_gap_metrics.dart';
import 'compute_window_cast_metrics.dart';

/// Turns one player's fight into [PlayerMetrics], from the spec's tables.
class ComputePlayerMetrics {
  const ComputePlayerMetrics(this.spec);

  final RotationSpec spec;

  /// A phase change this close to the end is the boss dying, not a phase.
  static const _shortestLastPhase = Duration(seconds: 1);

  /// [FightLog.casts] must be in log order.
  PlayerMetrics call(FightLog log) {
    final rules = spec.logRules;
    final events = [
      for (final cast in log.casts)
        if (!rules.duplicateCastIds.contains(cast.abilityId)) cast,
    ];
    final presses = [
      for (final cast in events)
        if (!cast.isBegin) cast,
    ];
    final minutes = log.fight.duration.inMilliseconds / 60000;
    double perMinute(num count) => minutes == 0 ? 0 : count / minutes;
    final cooldowns = ComputeCooldownMetrics(spec, log, events);

    return PlayerMetrics(
      fightLength: log.fight.duration,
      casts: CastMetrics(
        total: presses.length,
        perMinute: perMinute(presses.length),
        byAbility: _byAbility(log, presses, perMinute),
        byPhase: _byPhase(log.fight, presses),
      ),
      gaps: ComputeGapMetrics(spec, log, cooldowns)(events),
      resource: _resource(log, rules, perMinute),
      spenders: _spenders(log, rules, presses),
      cooldowns: cooldowns.cooldowns(),
      raidFreeCasts: cooldowns.raidFreeCasts(),
      windowCasts: ComputeWindowCastMetrics(spec, log)(events),
      chanceProcs: [
        for (final rule in rules.chanceProcs)
          if (log.talents.contains(rule.requiredTalent))
            ComputeChanceProcMetrics(rule)(log, presses),
      ],
    );
  }

  List<AbilityCasts> _byAbility(
    FightLog log,
    List<LogCast> presses,
    double Function(num) perMinute,
  ) {
    final counts = <int, int>{};
    for (final cast in presses) {
      counts.update(cast.abilityId, (n) => n + 1, ifAbsent: () => 1);
    }
    return [
      for (final MapEntry(key: id, value: count) in counts.entries)
        AbilityCasts(
          abilityId: id,
          name: log.abilityNames[id] ?? 'Ability $id',
          casts: count,
          perMinute: perMinute(count),
        ),
    ]..sort((a, b) => b.casts.compareTo(a.casts));
  }

  List<PhaseCasts> _byPhase(LogFight fight, List<LogCast> presses) {
    final starts = [
      for (final start in fight.phaseStarts)
        if (fight.duration - start >= _shortestLastPhase) start,
    ];
    return [
      for (var i = 0; i < starts.length; i++)
        _phase(
          starts[i],
          i + 1 < starts.length ? starts[i + 1] : fight.duration,
          presses,
        ),
    ];
  }

  PhaseCasts _phase(Duration start, Duration end, List<LogCast> presses) {
    final casts = presses.where((c) => c.time >= start && c.time < end).length;
    final length = end - start;
    return PhaseCasts(
      start: start,
      length: length,
      casts: casts,
      perMinute: casts / (length.inMilliseconds / 60000),
    );
  }

  ResourceMetrics _resource(
    FightLog log,
    SpecLogRules rules,
    double Function(num) perMinute,
  ) {
    var gained = 0;
    var wasted = 0;
    for (final gain in log.resourceGains) {
      if (gain.type != rules.resourceType) continue;
      gained += gain.amount;
      wasted += gain.waste;
    }
    return ResourceMetrics(
      gained: gained,
      wasted: wasted,
      gainedPerMinute: perMinute(gained),
      wastedPerMinute: perMinute(wasted),
    );
  }

  SpenderMetrics _spenders(
    FightLog log,
    SpecLogRules rules,
    List<LogCast> presses,
  ) {
    final spenderIds = {
      for (final spell in spec.spells.values)
        if (spell.cost > 0) ?spell.spellId,
    };
    final spenders = [
      for (final cast in presses)
        if (spenderIds.contains(cast.abilityId)) cast,
    ];
    final freeBuffs = [
      for (final id in rules.freeSpenderBuffIds) BuffWindows.of(log, id),
    ];
    bool isFree(LogCast cast) =>
        freeBuffs.any((buff) => buff.isUpFor(cast.time)) ||
        cast.resources.any(
          (r) => r.type == rules.resourceType && r.cost == null,
        );
    final fades = [
      for (final e in log.buffEvents)
        if (e.change == LogBuffChange.remove &&
            e.targetId == log.playerId &&
            rules.freeSpenderSourceIds.contains(e.abilityId))
          e,
    ];
    final lostFree = [
      for (final e in log.buffEvents)
        if (e.change == LogBuffChange.refresh &&
            e.targetId == log.playerId &&
            rules.freeSpenderBuffIds.contains(e.abilityId))
          LostFreeSpender(
            time: e.time,
            sourceName: _name(
              log,
              fades.where((f) => f.time <= e.time).lastOrNull?.abilityId,
            ),
          ),
    ];

    final buffId = rules.spenderBuffId;
    final hasBuff =
        buffId != null && log.talents.contains(rules.spenderBuffTalent);
    final buff = hasBuff ? BuffWindows.of(log, buffId) : null;
    final skipBuffs = [
      for (final id in rules.spenderBuffSkipIds) BuffWindows.of(log, id),
    ];
    bool skipped(LogCast cast) =>
        skipBuffs.isNotEmpty &&
        !buff!.isUpFor(cast.time) &&
        skipBuffs.every((b) => b.isUpFor(cast.time));

    return SpenderMetrics(
      casts: spenders.length,
      free: spenders.where(isFree).length,
      lostFree: lostFree.length,
      lostFreeDetails: lostFree,
      withBuff: buff == null
          ? null
          : spenders.where((c) => buff.isUpFor(c.time)).length,
      skippedBuff: buff == null ? null : spenders.where(skipped).length,
      buffName: hasBuff ? log.abilityNames[buffId] : null,
    );
  }

  static String? _name(FightLog log, int? id) =>
      id == null ? null : log.abilityNames[id] ?? 'Ability $id';
}
