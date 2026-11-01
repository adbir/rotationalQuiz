import '../models/fight_log.dart';

/// Chooses which ranked logs to put beside a player's fight: the one fought
/// for about as long (a short kill keeps more of the fight under Bloodlust),
/// and rank 1.
class PickComparisonLogs {
  const PickComparisonLogs();

  /// [top] is the rankings, best first. The closest log is picked from all but
  /// rank 1, so rank 1 never fills both places. On a tie the better rank wins.
  /// The result runs from the closest log to rank 1.
  List<RankedLog> call(List<RankedLog> top, Duration fought) {
    if (top.isEmpty) return const [];
    final best = top.reduce((a, b) => b.rank < a.rank ? b : a);
    RankedLog? closest;
    for (final log in top) {
      if (log == best) continue;
      final away = (log.duration - fought).abs();
      final current = closest;
      if (current == null ||
          away < (current.duration - fought).abs() ||
          (away == (current.duration - fought).abs() &&
              log.rank < current.rank)) {
        closest = log;
      }
    }
    return [?closest, best];
  }
}
