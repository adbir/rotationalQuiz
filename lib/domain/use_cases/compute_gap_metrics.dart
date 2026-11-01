import '../models/buff_windows.dart';
import '../models/fight_log.dart';
import '../models/gap_detail.dart';
import '../models/player_metrics.dart';
import '../specs/rotation_spec.dart';
import 'compute_cooldown_metrics.dart';

/// Finds the stretches with no cast, and notes what the log shows during each.
class ComputeGapMetrics {
  const ComputeGapMetrics(this.spec, this.log, this.cooldowns);

  final RotationSpec spec;
  final FightLog log;
  final ComputeCooldownMetrics cooldowns;

  /// Longer than one GCD, so an instant cast followed by the next is no gap.
  static const threshold = Duration(milliseconds: 1800);

  /// [events] are the fight's cast events without duplicates, in log order.
  GapMetrics call(List<LogCast> events) {
    final rules = spec.logRules;
    final form = rules.movementFormId;
    final graceId = rules.graceId;
    final formWindows = form == null ? null : BuffWindows.of(log, form);
    final graceWindows = graceId == null ? null : BuffWindows.of(log, graceId);
    final graceCasts = graceId == null
        ? const <Duration>[]
        : cooldowns.normalPressTimes(graceId);
    final graceLength = _graceCooldown(graceId);

    bool during(BuffWindows? windows, Duration start, Duration end) =>
        windows != null &&
        windows.windows.any(
          (w) => w.start <= end + logMoment && w.end >= start - logMoment,
        );

    var longest = Duration.zero;
    final details = <GapDetail>[];
    for (var i = 1; i < events.length; i++) {
      final (before, after) = (events[i - 1], events[i]);
      final finishedCast =
          before.isBegin &&
          !after.isBegin &&
          before.abilityId == after.abilityId;
      if (finishedCast) continue;
      final length = after.time - before.time;
      if (length > longest) longest = length;
      if (length <= threshold) continue;

      final graceUp = during(graceWindows, before.time, after.time);
      final lastGrace = graceCasts.where((t) => t <= before.time).lastOrNull;
      details.add(
        GapDetail(
          start: before.time,
          length: length,
          inMovementForm:
              during(formWindows, before.time, after.time) ||
              events.any(
                (c) =>
                    c.abilityId == form &&
                    c.time >= before.time - logMoment &&
                    c.time <= after.time + logMoment,
              ),
          graceUp: graceUp,
          graceReady:
              !graceUp &&
              graceLength != null &&
              (lastGrace == null || lastGrace + graceLength <= before.time),
        ),
      );
    }
    return GapMetrics(
      threshold: threshold,
      count: details.length,
      longest: longest,
      details: details,
    );
  }

  /// How long the grace spell's cooldown is, or `null` when the spec has none.
  Duration? _graceCooldown(int? graceId) {
    final spell = spec.spells.values
        .where((s) => graceId != null && s.spellId == graceId)
        .firstOrNull;
    final cooldown = spec.cooldowns
        .where((c) => spell != null && c.id == spell.cooldownId)
        .firstOrNull;
    if (cooldown == null) return null;
    return Duration(
      milliseconds: (spec.cooldownDuration(cooldown, log.talents) * 1000)
          .round(),
    );
  }
}
