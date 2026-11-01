import 'package:flutter/foundation.dart';

/// One kind of extra enemy in a fight, such as the adds of a boss.
@immutable
class EnemyGroup {
  const EnemyGroup({
    required this.name,
    required this.arrivals,
    this.departures = const [],
  });

  final String name;

  /// When each enemy first acted, from the pull, in time order. This is a
  /// little after it spawned, since the log shows an enemy only once it acts.
  final List<Duration> arrivals;

  /// When each enemy of [arrivals] was gone, by position. A `null` entry, or a
  /// list shorter than [arrivals], means it was up until the fight ended.
  final List<Duration?> departures;

  /// The first arrival of each wave: a wave starts when no enemy of this
  /// group has arrived for [gap].
  List<Duration> waveStarts({Duration gap = const Duration(seconds: 15)}) {
    final starts = <Duration>[];
    Duration? previous;
    for (final time in arrivals) {
      if (previous == null || time - previous > gap) starts.add(time);
      previous = time;
    }
    return starts;
  }

  /// Enemies of this kind up at [time].
  int aliveAt(Duration time) {
    var alive = 0;
    for (var i = 0; i < arrivals.length; i++) {
      final gone = i < departures.length ? departures[i] : null;
      if (arrivals[i] <= time && (gone == null || time < gone)) alive++;
    }
    return alive;
  }
}
