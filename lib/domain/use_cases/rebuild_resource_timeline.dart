import '../models/buff_windows.dart';
import '../models/fight_log.dart';
import '../models/resource_timeline.dart';
import '../specs/rotation_spec.dart';

enum _Kind { gain, checkpoint, spend }

class _Step {
  const _Step(this.time, this.kind, this.amount, [this.max]);

  final Duration time;
  final _Kind kind;

  /// Net gain, logged reading or cost, by [kind].
  final int amount;

  /// The cap a gain was logged against.
  final int? max;
}

/// Rebuilds the spec's primary resource over a fight.
///
/// Gains are `resourcechange` events, held at the cap they were logged with.
/// Taking each event's `waste` off as well drifts further (8 points lower on
/// the fixture), since the cap already removes it. Spends are spender casts
/// at the cost the log shows, else the spec's table cost. A cast logged with a
/// reading but no cost was free. Readings on casts are checkpoints, taken after
/// that moment's gains and before its spend (as the logs show).
class RebuildResourceTimeline {
  const RebuildResourceTimeline(this.spec);

  final RotationSpec spec;

  /// [startAmount] is the amount at the pull. Without it, the first checkpoint
  /// sets it, so that checkpoint has no drift. Use it for a fight window that
  /// begins mid-pull.
  ResourceTimeline call(FightLog log, {double? startAmount}) {
    final steps = _steps(log)
      ..sort((a, b) {
        final byTime = a.time.compareTo(b.time);
        return byTime != 0 ? byTime : a.kind.index.compareTo(b.kind.index);
      });
    var start = startAmount ?? 0;
    if (startAmount == null) {
      final first = _run(log, steps, 0).checkpoints.firstOrNull;
      if (first != null) start = first.logged - first.rebuilt;
    }
    return _run(log, steps, start < 0 ? 0 : start);
  }

  ResourceTimeline _run(FightLog log, List<_Step> steps, double start) {
    var amount = start;
    final points = <ResourcePoint>[];
    final checkpoints = <ResourceCheckpoint>[];
    for (final step in steps) {
      switch (step.kind) {
        case _Kind.checkpoint:
          checkpoints.add(
            ResourceCheckpoint(
              time: step.time,
              logged: step.amount,
              rebuilt: amount,
            ),
          );
          continue;
        case _Kind.gain:
          amount += step.amount;
          final max = step.max;
          if (max != null && amount > max) amount = max.toDouble();
        case _Kind.spend:
          amount -= step.amount;
          if (amount < 0) amount = 0;
      }
      points.add(ResourcePoint(step.time, amount));
    }
    return ResourceTimeline(
      start: start,
      points: points,
      checkpoints: checkpoints,
      end: log.fight.duration,
    );
  }

  List<_Step> _steps(FightLog log) {
    final rules = spec.logRules;
    final costs = {
      for (final spell in spec.spells.values)
        if (spell.cost > 0 && spell.spellId != null) spell.spellId!: spell.cost,
    };
    final freeWindows = [
      for (final id in rules.freeSpenderBuffIds) BuffWindows.of(log, id),
    ];
    final steps = <_Step>[
      for (final gain in log.resourceGains)
        if (gain.type == rules.resourceType)
          _Step(gain.time, _Kind.gain, gain.amount, gain.max),
    ];
    for (final cast in log.casts) {
      if (cast.isBegin || rules.duplicateCastIds.contains(cast.abilityId)) {
        continue;
      }
      final reading = cast.resources
          .where((r) => r.type == rules.resourceType)
          .firstOrNull;
      if (reading != null) {
        steps.add(_Step(cast.time, _Kind.checkpoint, reading.amount));
      }
      final tableCost = costs[cast.abilityId];
      if (tableCost == null) continue;
      // ponytail: the table cost ignores cost modifiers; the ceiling is a
      // cast with no reading and a discount the log doesn't show.
      final cost =
          reading?.cost ??
          (reading != null || freeWindows.any((w) => w.isUpFor(cast.time))
              ? 0
              : tableCost.round());
      steps.add(_Step(cast.time, _Kind.spend, cost));
    }
    return steps;
  }
}
