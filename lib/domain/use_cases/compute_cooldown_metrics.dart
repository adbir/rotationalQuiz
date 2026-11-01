import 'dart:math';

import '../models/buff_windows.dart';
import '../models/fight_log.dart';
import '../models/log_rules.dart';
import '../models/player_metrics.dart';
import '../models/spec_definition.dart';
import '../specs/rotation_spec.dart';
import 'compute_chance_proc_metrics.dart';

/// Works out how one fight's cooldowns were used, keeping casts another player
/// paid for apart from the player's own.
class ComputeCooldownMetrics {
  /// [events] are the fight's cast events without duplicates, in log order.
  ComputeCooldownMetrics(this.spec, this.log, this._events);

  final RotationSpec spec;
  final FightLog log;
  final List<LogCast> _events;

  late final List<LogCast> _presses = [
    for (final cast in _events)
      if (!cast.isBegin) cast,
  ];

  /// The casts each raid buff paid for: those landing as a window of it ended.
  late final Map<RaidFreeCast, Set<LogCast>> _paidFor = {
    for (final rule in spec.logRules.raidFreeCasts)
      rule: {
        for (final window in BuffWindows.of(log, rule.buffId).windows)
          ?_presses
              .where(
                (c) =>
                    rule.castIds.contains(c.abilityId) &&
                    isSameMoment(c.time, window.end),
              )
              .firstOrNull,
      },
  };

  List<RaidFreeCastMetrics> raidFreeCasts() => [
    for (final MapEntry(key: rule, value: paid) in _paidFor.entries)
      RaidFreeCastMetrics(
        name: rule.name,
        available: BuffWindows.of(log, rule.buffId).windows.length,
        spent: paid.length,
        refreshedByNormalCast: _refreshes(rule, paid),
      ),
  ];

  /// When the player pressed [spellId] on their own cooldown, in log order.
  List<Duration> normalPressTimes(int spellId) {
    final paid = _paidFor.values.expand((casts) => casts).toSet();
    return [
      for (final cast in _presses)
        if (cast.abilityId == spellId && !paid.contains(cast)) cast.time,
    ];
  }

  List<CooldownMetrics> cooldowns() => [
    for (final cooldown in spec.cooldowns)
      if (_tracked(cooldown) case final SpellDefinition spell)
        _cooldown(cooldown, spell),
  ];

  /// The spell behind [cooldown], if the player has it and it isn't charged,
  /// or a rule counts its possible casts.
  SpellDefinition? _tracked(CooldownDefinition cooldown) {
    final spell = spec.spells[cooldown.id];
    final talents = log.talents;
    final isKnown =
        (cooldown.requiredTalent == null ||
            talents.contains(cooldown.requiredTalent)) &&
        !talents.contains(spell?.replacedByTalent);
    final isSimple = spec.maxCharges(cooldown, talents) == null;
    return isKnown && (isSimple || _possibleRule(cooldown) != null)
        ? spell
        : null;
  }

  PossibleCastsRule? _possibleRule(CooldownDefinition cooldown) => spec
      .logRules
      .possibleCasts
      .where((r) => r.cooldownId == cooldown.id)
      .firstOrNull;

  /// Charges, one more per full cooldown in the fight, and one per cast that
  /// restores a charge.
  int? _possible(CooldownDefinition cooldown, double seconds) {
    final rule = _possibleRule(cooldown);
    if (rule == null) return null;
    final charges = spec.maxCharges(cooldown, log.talents) ?? 1;
    final cycles = log.fight.duration.inMilliseconds ~/ (seconds * 1000);
    final restored = _presses
        .where((c) => rule.restoredByCastIds.contains(c.abilityId))
        .length;
    return charges + cycles + restored;
  }

  CooldownMetrics _cooldown(
    CooldownDefinition cooldown,
    SpellDefinition spell,
  ) {
    final casts = _presses.where((c) => c.abilityId == spell.spellId).toList();
    final paid = _paidFor.values.expand((casts) => casts).toSet();
    final normal = casts.where((c) => !paid.contains(c)).toList();
    final base = spec.cooldownDuration(cooldown, log.talents);
    final rule = _shorteningRule(cooldown);
    final proc = rule == null ? null : ComputeChanceProcMetrics(rule);
    final procTimes = proc?.times(log) ?? const <Duration>[];
    // Drift assumes one charge: a second can be pressed at once.
    final hasCharges = spec.maxCharges(cooldown, log.talents) != null;

    final drifts = <double>[];
    final procCounts = <int>[];
    var early = 0;
    for (var i = 1; i < normal.length && !hasCharges; i++) {
      final used = normal[i - 1].time;
      var ready = used + _duration(base);
      var procs = 0;
      for (final time in procTimes) {
        if (time < used - logMoment) continue;
        if (time >= ready) break;
        ready -= _duration(rule!.cooldownSecondsPerProc);
        procs++;
      }
      procCounts.add(procs);
      final drift = _pressStart(normal[i], spell) - ready;
      if (drift < -logMoment) early++;
      drifts.add(max(drift.inMilliseconds, 0) / 1000);
    }

    return CooldownMetrics(
      id: cooldown.id,
      name: cooldown.name,
      cooldown: base,
      uses: casts.length,
      freeUses: casts.length - normal.length,
      earlyPresses: early,
      averageDrift: _average(drifts),
      medianDrift: _median(drifts),
      shortening: rule == null || procCounts.isEmpty
          ? null
          : _shortening(rule, procCounts),
      raidDependsOn: spec.logRules.raidCooldownSupport[cooldown.id] ?? const [],
      possible: _possible(cooldown, base),
    );
  }

  ChanceProcRule? _shorteningRule(CooldownDefinition cooldown) {
    for (final rule in spec.logRules.chanceProcs) {
      if (rule.cooldownId == cooldown.id &&
          log.talents.contains(rule.requiredTalent) &&
          log.talents.contains(rule.cooldownTalent)) {
        return rule;
      }
    }
    return null;
  }

  CooldownShortening _shortening(ChanceProcRule rule, List<int> procCounts) {
    final total = procCounts.reduce((a, b) => a + b);
    return CooldownShortening(
      procName: rule.name,
      secondsPerCycle: total * rule.cooldownSecondsPerProc / procCounts.length,
      fewestProcs: procCounts.reduce(min),
      mostProcs: procCounts.reduce(max),
    );
  }

  /// When [cast] was pressed. A press is its `begincast`, because a cast time
  /// isn't delay. An instant, or a cast the log didn't see start, is its finish.
  Duration _pressStart(LogCast cast, SpellDefinition spell) {
    final longest = _duration(spell.castTime);
    final begin = _events.where(
      (c) =>
          c.isBegin &&
          c.abilityId == cast.abilityId &&
          c.time <= cast.time &&
          cast.time - c.time <= longest,
    );
    return begin.lastOrNull?.time ?? cast.time;
  }

  /// Normal casts straight after a free one, which only refreshed its buff.
  /// Abilities with a buff share its id, so a refresh of that id shows this.
  List<Duration> _refreshes(RaidFreeCast rule, Set<LogCast> paid) {
    final refreshed = <Duration>[];
    for (final id in rule.castIds) {
      final casts = _presses.where((c) => c.abilityId == id).toList();
      for (var i = 1; i < casts.length; i++) {
        final cast = casts[i];
        if (paid.contains(casts[i - 1]) &&
            !paid.contains(cast) &&
            _wasRefreshed(id, cast.time)) {
          refreshed.add(cast.time);
        }
      }
    }
    return refreshed;
  }

  bool _wasRefreshed(int buffId, Duration time) => log.buffEvents.any(
    (e) =>
        e.abilityId == buffId &&
        e.targetId == log.playerId &&
        e.change == LogBuffChange.refresh &&
        isSameMoment(e.time, time),
  );

  static Duration _duration(double seconds) =>
      Duration(milliseconds: (seconds * 1000).round());

  static double? _average(List<double> values) =>
      values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;

  static double? _median(List<double> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
