import '../models/fight_log.dart';
import '../models/pooling_report.dart';
import '../models/resource_timeline.dart';
import '../specs/rotation_spec.dart';

/// Checks whether a player held back their resource before known events.
///
/// For each event time (the caller finds add waves or phases) it compares the
/// mean resource in the [lead] before it with the fight's mean, and counts
/// spender casts before and in the [follow] after. It says what happened, not
/// why: a high level with no spenders after is reported as not pooled.
class DetectPooling {
  const DetectPooling(
    this.spec, {
    this.lead = const Duration(seconds: 8),
    this.follow = const Duration(seconds: 8),
    this.margin = 15,
  });

  final RotationSpec spec;

  /// How far before an event to look.
  final Duration lead;

  /// How far after an event to look for spenders.
  final Duration follow;

  /// How far above the player's normal level counts as held back, in points.
  final double margin;

  // Checked on Mythic Twin Fangs (docs/warcraft-logs.md): rank 1
  // (CGjdNa8RBfcQtAWg fight 33, 420 s), rank 53 (pDkwjXv3Z2Q8mBVc fight 2,
  // 415 s) and a 1% wipe (dvpkyx8D4YnAHGJK fight 18, 394 s). At the default 8 s,
  // 8 s and 15 points, 2 of 16 add waves read as pooled, against 4 of 31 and
  // 8 of 33 ordinary moments in the top two logs. No lead, follow or margin
  // separated waves from other moments, so the defaults stay as guesses.
  // ponytail: "normal" is the whole-fight mean, so a log of mostly pooling
  // reads as normal. The ceiling is a median per phase.
  List<PoolingReport> call(
    FightLog log,
    ResourceTimeline timeline,
    List<Duration> eventTimes,
  ) {
    final spenderIds = {
      for (final spell in spec.spells.values)
        if (spell.cost > 0) ?spell.spellId,
    };
    final spends = [
      for (final cast in log.casts)
        if (!cast.isBegin && spenderIds.contains(cast.abilityId)) cast.time,
    ];
    int between(Duration from, Duration to) =>
        spends.where((t) => t > from && t <= to).length;

    final normal = timeline.mean(Duration.zero, timeline.end);
    return [
      for (final time in eventTimes)
        () {
          final from = time - lead < Duration.zero
              ? Duration.zero
              : time - lead;
          final mean = timeline.mean(from, time);
          final after = between(time, time + follow);
          return PoolingReport(
            eventTime: time,
            meanBefore: mean,
            normalLevel: normal,
            spendersBefore: between(from, time),
            spendersAfter: after,
            isPooled: mean >= normal + margin && after > 0,
          );
        }(),
    ];
  }
}
