import 'dart:math';

import '../models/fight_log.dart';
import '../models/log_rules.dart';
import '../models/player_metrics.dart';

/// Compares a chance-based proc with what its rules predict, using the
/// player's own casts. Only applies terms for talents they took.
class ComputeChanceProcMetrics {
  const ComputeChanceProcMetrics(this.rule);

  final ChanceProcRule rule;

  /// When each proc happened, in log order. An added stack is a proc; a
  /// refresh isn't.
  List<Duration> times(FightLog log) => [
    for (final event in log.buffEvents)
      if (rule.buffIds.contains(event.abilityId) &&
          event.targetId == log.playerId &&
          (event.change == LogBuffChange.apply ||
              event.change == LogBuffChange.applyStack))
        event.time,
  ];

  ChanceProcMetrics call(FightLog log, List<LogCast> presses) {
    final actual = times(log).length;
    final guaranteed = presses
        .where((c) => rule.guaranteedCastIds.contains(c.abilityId))
        .length;
    final rolls = log.talents.contains(rule.rollTalent)
        ? presses.where((c) => rule.rollCastIds.contains(c.abilityId)).length
        : 0;
    final chance = rule.rollChance;
    final repeat = log.talents.contains(rule.repeatTalent)
        ? rule.repeatChance
        : 0.0;

    // Each starting proc opens a chain that goes on with chance `repeat`, so a
    // chain's length is geometric, and the total is a compound of the two.
    final starts = guaranteed + chance * rolls;
    final startsVariance = rolls * chance * (1 - chance);
    final chainLength = 1 / (1 - repeat);
    final chainVariance = repeat / pow(1 - repeat, 2);

    return ChanceProcMetrics(
      name: rule.name,
      actual: actual,
      expected: starts * chainLength,
      spread: sqrt(
        starts * chainVariance + startsVariance * pow(chainLength, 2),
      ),
      perCast: presses.isEmpty ? 0 : actual / presses.length,
      note: rule.note,
    );
  }
}
