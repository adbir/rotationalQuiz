import '../../domain/models/enemy_group.dart';
import '../services/warcraft_logs_service.dart';

/// The player's damage events, read as when each enemy was really hit.
class WarcraftLogsHits {
  /// A row is a hit when it did at least 1% of the damage it would have done
  /// (an immune enemy takes 0, or 1 from a tick). A shield that took the hit
  /// (`absorbed` above 0) counts too, but only for an enemy kind that the
  /// player also really damaged: a kind that only ever absorbs (Barbed
  /// Bulwark) is not a target.
  WarcraftLogsHits(List<JsonMap> damage, int playerId) {
    final absorbed = <(int, int, int?, num)>[];
    for (final row in damage) {
      final target = _int(row['targetID']);
      final time = row['timestamp'];
      final amount = row['amount'];
      final raw = row['unmitigatedAmount'];
      final shield = row['absorbed'];
      if (target == null ||
          time is! num ||
          _int(row['sourceID']) != playerId ||
          amount is! num) {
        continue;
      }
      final hit = (
        target,
        _int(row['targetInstance']) ?? 0,
        _int(row['abilityGameID']),
        time,
      );
      if (amount > 0 && (raw is! num || amount * 100 >= raw)) {
        _hits.add(hit);
      } else if (shield is num && shield > 0) {
        absorbed.add(hit);
      }
    }
    final real = targets;
    _hits.addAll(absorbed.where((h) => real.contains(h.$1)));
  }

  final _hits = <(int, int, int?, num)>[];

  /// Enemy NPC ids with at least one hit.
  Set<int> get targets => {for (final h in _hits) h.$1};

  /// The times (log milliseconds) of hits on enemy NPC [target].
  List<num> timesOn(int target) => [
    for (final h in _hits)
      if (h.$1 == target) h.$4,
  ];

  /// The times of hits on [target] by [abilities], per copy of it.
  Map<int, List<num>> timesByCopy(int target, Set<int> abilities) {
    final copies = <int, List<num>>{};
    for (final h in _hits) {
      if (h.$1 == target && abilities.contains(h.$3)) {
        copies.putIfAbsent(h.$2, () => []).add(h.$4);
      }
    }
    return copies;
  }

  /// The stretches a single enemy was hittable, from the [hits] on it (log
  /// milliseconds): a stretch ends at the last hit before a silence longer
  /// than [gap]. One arrival and departure per stretch, from the pull. Null
  /// when there are no hits, so the caller can keep the whole-fight span.
  static EnemyGroup? hittableSpans(
    String name,
    List<num> hits,
    num start,
    Duration gap,
  ) => spansOfCopies(name, [hits], start, gap);

  /// One group of every copy's stretches (see [hittableSpans]), in the order
  /// they began. Null when no copy was hit.
  static EnemyGroup? spansOfCopies(
    String name,
    Iterable<List<num>> copies,
    num start,
    Duration gap,
  ) {
    final spans = <(Duration, Duration)>[];
    for (final hits in copies) {
      if (hits.isEmpty) continue;
      final times = [...hits]..sort();
      var begun = times.first;
      for (var i = 1; i < times.length; i++) {
        if (times[i] - times[i - 1] > gap.inMilliseconds) {
          spans.add((_since(begun, start), _since(times[i - 1], start)));
          begun = times[i];
        }
      }
      spans.add((_since(begun, start), _since(times.last, start)));
    }
    if (spans.isEmpty) return null;
    spans.sort((a, b) => a.$1.compareTo(b.$1));
    return EnemyGroup(
      name: name,
      arrivals: [for (final s in spans) s.$1],
      departures: [for (final s in spans) s.$2],
    );
  }

  static Duration _since(num time, num start) =>
      Duration(milliseconds: (time - start).round());

  static int? _int(Object? value) => value is num ? value.toInt() : null;
}
