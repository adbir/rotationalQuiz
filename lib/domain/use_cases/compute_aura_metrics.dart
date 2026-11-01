import 'dart:collection';

import '../models/aura_metrics.dart';
import '../models/fight_log.dart';
import '../models/log_rules.dart';

/// Upkeep, held procs and the resource's level of one fight, per the spec's
/// log rules.
class ComputeAuraMetrics {
  const ComputeAuraMetrics(this.rules, this.log);

  final SpecLogRules rules;
  final FightLog log;

  List<AuraUptime> upkeep() => [
    for (final aura in rules.upkeepAuras) _uptime(aura),
  ];

  AuraUptime _uptime(UpkeepAura aura) {
    final table = aura.onOthers ? log.appliedBuffs : log.receivedBuffs;
    final uptime = table
        .where((b) => b.abilityId == aura.buffId)
        .fold(Duration.zero, (sum, b) => sum + b.uptime);
    final length = log.fight.duration.inMilliseconds;
    return AuraUptime(
      buffId: aura.buffId,
      name: aura.name,
      onOthers: aura.onOthers,
      uptime: uptime,
      percent: length == 0 ? 0 : 100 * uptime.inMilliseconds / length,
    );
  }

  List<HeldProcMetrics> heldProcs() => [
    for (final rule in rules.heldProcs) _held(rule),
  ];

  /// Each proc waits from its application or added stack until a stack goes,
  /// oldest first. A removal with nothing waiting was up from the start.
  HeldProcMetrics _held(HeldProcRule rule) {
    final waiting = Queue<Duration>();
    var gained = 0;
    var spent = 0;
    var held = Duration.zero;
    void spend(Duration time) {
      held += time - (waiting.isEmpty ? Duration.zero : waiting.removeFirst());
      spent++;
    }

    for (final e in log.buffEvents) {
      if (e.abilityId != rule.buffId || e.targetId != log.playerId) continue;
      switch (e.change) {
        case LogBuffChange.apply || LogBuffChange.applyStack:
          waiting.add(e.time);
          gained++;
        case LogBuffChange.removeStack:
          spend(e.time);
        case LogBuffChange.remove:
          do {
            spend(e.time);
          } while (waiting.isNotEmpty);
        case LogBuffChange.refresh:
          break;
      }
    }
    return HeldProcMetrics(
      buffId: rule.buffId,
      name: rule.name,
      gained: gained,
      spent: spent,
      unspentAtEnd: waiting.length,
      averageHold: spent == 0 ? null : held ~/ spent,
    );
  }

  /// `null` unless the spec reads its resource's level.
  ResourceLevelMetrics? resourceLevels(List<Duration> phaseChanges) {
    if (!rules.readsResourceLevel) return null;
    final readings = [
      for (final cast in log.casts)
        for (final r in cast.resources)
          if (r.type == rules.resourceType && r.max > 0)
            ResourceLevel(cast.time, 100 * r.amount / r.max),
    ];
    return ResourceLevelMetrics(
      readings: readings.length,
      atPhaseChanges: [
        for (final change in phaseChanges)
          if (readings.where((r) => r.time < change).lastOrNull
              case final before?)
            ResourceLevel(change, before.percent),
      ],
      atEnd: readings.lastOrNull,
      lowest: readings.isEmpty
          ? null
          : readings.reduce((a, b) => b.percent < a.percent ? b : a),
    );
  }
}
