import 'package:flutter/foundation.dart';

/// How much of the fight one aura the player keeps up was up, from the log's
/// buff table.
@immutable
class AuraUptime {
  const AuraUptime({
    required this.buffId,
    required this.name,
    required this.onOthers,
    required this.uptime,
    required this.percent,
  });

  final int buffId;
  final String name;

  /// On others, the table counts it up while it is on anyone.
  final bool onOthers;
  final Duration uptime;

  /// Of the whole fight, 0 to 100.
  final double percent;
}

/// How long a proc's buff waited before it went. A buff that went while
/// procs were still stacked gives up its oldest first.
@immutable
class HeldProcMetrics {
  const HeldProcMetrics({
    required this.buffId,
    required this.name,
    required this.gained,
    required this.spent,
    required this.unspentAtEnd,
    this.averageHold,
  });

  final int buffId;
  final String name;

  /// Applications and added stacks.
  final int gained;

  /// Procs that went before the end, spent or run out.
  final int spent;

  /// Procs still up when the log ends.
  final int unspentAtEnd;

  /// Over [spent] procs, or `null` with none.
  final Duration? averageHold;
}

/// One reading of the primary resource's level.
@immutable
class ResourceLevel {
  const ResourceLevel(this.time, this.percent);

  final Duration time;

  /// Of the reading's maximum, 0 to 100.
  final double percent;
}

/// The primary resource's level from the readings on casts. A reading is the
/// level as the cast went off.
@immutable
class ResourceLevelMetrics {
  const ResourceLevelMetrics({
    required this.readings,
    required this.atPhaseChanges,
    this.atEnd,
    this.lowest,
  });

  /// Casts with a reading.
  final int readings;

  /// The last reading before each phase change after the first phase, timed
  /// at the change.
  final List<ResourceLevel> atPhaseChanges;

  /// The last reading, or `null` with none.
  final ResourceLevel? atEnd;
  final ResourceLevel? lowest;
}
