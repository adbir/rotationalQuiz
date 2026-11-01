import '../../domain/models/enemy_group.dart';
import '../services/warcraft_logs_service.dart';
import 'warcraft_logs_mapper.dart';

/// The player's damage events, read as when each enemy was really hit.
class WarcraftLogsHits {
  /// A row is a hit when it did at least 1% of the damage it would have done
  /// (an immune enemy takes 0, or 1 from a tick). A direct hit that a shield
  /// took (`absorbed` above 0, `tick` not set) counts too, but only for an
  /// enemy kind that the player also really damaged: a kind that only ever
  /// absorbs (Barbed Bulwark) is not a target. Ticks never count by absorbing.
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
      } else if (shield is num && shield > 0 && row['tick'] != true) {
        absorbed.add(hit);
      }
    }
    final real = _targets;
    _hits.addAll(absorbed.where((h) => real.contains(h.$1)));
  }

  final _hits = <(int, int, int?, num)>[];

  Set<int> get _targets => {for (final h in _hits) h.$1};

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

  /// One group of every copy's stretches (see
  /// [WarcraftLogsMapper.hittableSpans]), in the order they began. Null when
  /// no copy was hit.
  static EnemyGroup? spansOfCopies(
    String name,
    Iterable<List<num>> copies,
    num start,
    Duration gap,
  ) {
    final spans = <(Duration, Duration?)>[];
    for (final hits in copies) {
      final group = WarcraftLogsMapper.hittableSpans(name, hits, start, gap);
      if (group == null) continue;
      for (var i = 0; i < group.arrivals.length; i++) {
        spans.add((group.arrivals[i], group.departures[i]));
      }
    }
    if (spans.isEmpty) return null;
    spans.sort((a, b) => a.$1.compareTo(b.$1));
    return EnemyGroup(
      name: name,
      arrivals: [for (final s in spans) s.$1],
      departures: [for (final s in spans) s.$2],
    );
  }

  static int? _int(Object? value) => value is num ? value.toInt() : null;
}
