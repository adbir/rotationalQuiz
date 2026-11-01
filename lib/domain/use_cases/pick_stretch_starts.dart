import '../models/boss_comparison.dart';
import '../models/enemy_group.dart';

/// Where to cut a fight into stretches: at the repeating add waves, else at
/// phase changes, else nowhere.
class PickStretchStarts {
  const PickStretchStarts();

  /// A start this close to the end leaves a stretch too short to read.
  static const shortestStretch = Duration(seconds: 1);

  /// Starts after the pull and before `end - shortestStretch`, where [end] is
  /// the length of the fought portion.
  (StretchSource, List<Duration>) call({
    required Duration end,
    required List<Duration> phaseStarts,
    required List<EnemyGroup> groups,
  }) {
    final last = end - shortestStretch;
    List<Duration> inside(Iterable<Duration> times) => [
      for (final t in times)
        if (t > Duration.zero && t < last) t,
    ];

    // The kind of enemy that comes in the most waves, and on a tie the one
    // whose first wave is later. One wave is not a pattern.
    List<Duration>? waves;
    for (final group in groups) {
      final starts = inside(group.waveStarts());
      if (starts.length < 2) continue;
      if (waves == null ||
          starts.length > waves.length ||
          (starts.length == waves.length && starts.first > waves.first)) {
        waves = starts;
      }
    }
    if (waves != null) return (StretchSource.waves, waves);

    final phases = inside(phaseStarts);
    if (phases.isNotEmpty) return (StretchSource.phases, phases);
    return (StretchSource.wholeFight, const []);
  }
}
