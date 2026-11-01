import 'package:flutter/foundation.dart';

/// The rebuilt value just after something changed it.
@immutable
class ResourcePoint {
  const ResourcePoint(this.time, this.amount);

  final Duration time;
  final double amount;
}

/// A logged reading next to what the rebuild had at that moment.
@immutable
class ResourceCheckpoint {
  const ResourceCheckpoint({
    required this.time,
    required this.logged,
    required this.rebuilt,
  });

  final Duration time;
  final int logged;
  final double rebuilt;

  /// Rebuilt minus logged. Positive means the rebuild is too high.
  double get drift => rebuilt - logged;
}

/// A player's primary resource across one fight, rebuilt from events.
@immutable
class ResourceTimeline {
  const ResourceTimeline({
    required this.start,
    required this.points,
    required this.checkpoints,
    required this.end,
  });

  /// The amount at the pull.
  final double start;

  /// In time order.
  final List<ResourcePoint> points;
  final List<ResourceCheckpoint> checkpoints;
  final Duration end;

  /// The amount at [time], after everything logged up to it.
  double at(Duration time) {
    var amount = start;
    for (final point in points) {
      if (point.time > time) break;
      amount = point.amount;
    }
    return amount;
  }

  /// The time-weighted mean amount from [from] to [to].
  double mean(Duration from, Duration to) {
    final span = (to - from).inMicroseconds;
    if (span <= 0) return at(from);
    var total = 0.0;
    var cursor = from;
    var amount = at(from);
    for (final point in points) {
      if (point.time <= from) continue;
      if (point.time >= to) break;
      total += amount * (point.time - cursor).inMicroseconds;
      cursor = point.time;
      amount = point.amount;
    }
    total += amount * (to - cursor).inMicroseconds;
    return total / span;
  }

  double get maxAbsDrift => checkpoints.fold(
    0.0,
    (worst, c) => c.drift.abs() > worst ? c.drift.abs() : worst,
  );

  double get meanAbsDrift => checkpoints.isEmpty
      ? 0
      : checkpoints.fold(0.0, (sum, c) => sum + c.drift.abs()) /
            checkpoints.length;
}
