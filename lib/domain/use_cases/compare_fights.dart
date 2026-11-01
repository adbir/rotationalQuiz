import '../models/boss_comparison.dart';
import '../models/enemy_group.dart';
import '../models/fight_log.dart';
import '../models/pooling_report.dart';
import '../specs/rotation_spec.dart';
import 'compute_player_metrics.dart';
import 'detect_pooling.dart';
import 'pick_stretch_starts.dart';
import 'rebuild_resource_timeline.dart';

/// One fight to compare, with its ranking row when it has one.
class FightToCompare {
  const FightToCompare({required this.label, required this.log, this.ranked});

  final String label;
  final FightLog log;
  final RankedLog? ranked;
}

/// Lines logs of one encounter up: their metrics, casts per minute by stretch
/// and the resource before each stretch. Only the portion every log fought is
/// compared. The stretches are cut at the first log's add waves (or phases) and
/// reused for the rest, since waves come on a timer. When several kinds of add
/// come in waves, the kind the top log holds spenders for wins: that is the
/// wave the rotation reacts to.
class CompareFights {
  const CompareFights(this.spec);

  final RotationSpec spec;

  /// The first of [fights] is the player's; [playerEnemyGroups] are its adds.
  BossComparison call(
    List<FightToCompare> fights,
    List<EnemyGroup> playerEnemyGroups,
  ) {
    final fought = fights
        .map((f) => f.log.fight.duration)
        .reduce((a, b) => a < b ? a : b);
    // The last of [fights] is the top log (rank 1).
    final top = fights.last.log;
    final topTimeline = RebuildResourceTimeline(spec)(top);
    final (source, starts) = const PickStretchStarts()(
      end: fought,
      phaseStarts: fights.first.log.fight.phaseStarts,
      groups: playerEnemyGroups,
      preference: (waves) => DetectPooling(spec)(
        top,
        topTimeline,
        waves,
      ).where((r) => r.isHeld).length,
    );
    final edges = [Duration.zero, ...starts, fought];
    final stretches = [
      for (var i = 0; i + 1 < edges.length; i++)
        Stretch(edges[i], edges[i + 1]),
    ];

    final metrics = ComputePlayerMetrics(spec);
    return BossComparison(
      logs: [
        for (final f in fights)
          ComparedLog(
            label: f.label,
            metrics: metrics(f.log),
            kill: f.log.fight.kill,
            dps: f.ranked?.amount,
            itemLevel: (f.ranked?.itemLevel ?? 0) > 0
                ? f.ranked!.itemLevel
                : null,
          ),
      ],
      fought: fought,
      stretchSource: source,
      stretches: stretches,
      castsPerMinute: [
        for (final f in fights) _castsPerMinute(f.log, stretches),
      ],
      pooling: starts.isEmpty
          ? const []
          : [for (final f in fights) _pooling(f.log, starts)],
    );
  }

  List<double> _castsPerMinute(FightLog log, List<Stretch> stretches) {
    final duplicates = spec.logRules.duplicateCastIds;
    final presses = [
      for (final cast in log.casts)
        if (!cast.isBegin && !duplicates.contains(cast.abilityId)) cast.time,
    ];
    return [
      for (final s in stretches)
        presses.where((t) => t >= s.start && t < s.end).length /
            ((s.end - s.start).inMilliseconds / 60000),
    ];
  }

  List<PoolingReport> _pooling(FightLog log, List<Duration> starts) {
    final timeline = RebuildResourceTimeline(spec)(log);
    return DetectPooling(spec)(log, timeline, starts);
  }
}
