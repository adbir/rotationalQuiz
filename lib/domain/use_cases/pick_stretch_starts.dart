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
  ///
  /// [preference] scores a kind of enemy's wave times; the highest wins.
  /// Without it, or on a tie, the kind with the most waves wins, then the one
  /// whose first wave is later.
  (StretchSource, List<Duration>) call({
    required Duration end,
    required List<Duration> phaseStarts,
    required List<EnemyGroup> groups,
    int Function(List<Duration> waves)? preference,
  }) {
    final last = end - shortestStretch;
    List<Duration> inside(Iterable<Duration> times) => [
      for (final t in times)
        if (t > Duration.zero && t < last) t,
    ];

    // One wave is not a pattern.
    List<Duration>? waves;
    var best = 0;
    for (final group in groups) {
      final starts = inside(group.waveStarts());
      if (starts.length < 2) continue;
      final score = preference?.call(starts) ?? 0;
      if (waves == null ||
          score > best ||
          (score == best &&
              (starts.length > waves.length ||
                  (starts.length == waves.length &&
                      starts.first > waves.first)))) {
        waves = starts;
        best = score;
      }
    }
    if (waves != null) return (StretchSource.waves, waves);

    final phases = inside(phaseStarts);
    if (phases.isNotEmpty) return (StretchSource.phases, phases);
    return (StretchSource.wholeFight, const []);
  }
}
