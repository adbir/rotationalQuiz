import 'package:flutter/foundation.dart';

import 'player_metrics.dart';
import 'pooling_report.dart';

/// What the stretches of a comparison are cut at.
enum StretchSource { waves, phases, wholeFight }

/// One log in a comparison, with the numbers the rankings add when they have
/// them. A missing [dps] or [itemLevel] is blank, never a guess.
@immutable
class ComparedLog {
  const ComparedLog({
    required this.label,
    required this.metrics,
    required this.kill,
    this.dps,
    this.itemLevel,
  });

  /// "You", "Rank 53" or "Rank 1".
  final String label;
  final PlayerMetrics metrics;
  final bool kill;
  final double? dps;
  final int? itemLevel;

  Duration get fought => metrics.fightLength;
}

/// A span of the fought portion.
@immutable
class Stretch {
  const Stretch(this.start, this.end);

  final Duration start;
  final Duration end;
}

/// Several logs of one encounter side by side, over the portion every one of
/// them fought. The first log is the player's.
@immutable
class BossComparison {
  const BossComparison({
    required this.logs,
    required this.fought,
    required this.stretchSource,
    required this.stretches,
    required this.castsPerMinute,
    required this.pooling,
    this.gapsAlsoInRank1 = const [],
    this.eventName,
  });

  final List<ComparedLog> logs;

  /// The shortest fought length of [logs].
  final Duration fought;
  final StretchSource stretchSource;

  /// Cut at the player's add waves or phases. Always at least one.
  final List<Stretch> stretches;

  /// By log, then by stretch.
  final List<List<double>> castsPerMinute;

  /// By log, then by stretch start after the first. Empty when the stretches
  /// are the whole fight, which has no event to check before.
  final List<List<PoolingReport>> pooling;

  /// For each gap of the first log (`metrics.gaps.details`): whether rank 1, the
  /// last log, also has a gap starting within a few seconds. An intermission
  /// shows in both.
  final List<bool> gapsAlsoInRank1;

  /// The name of the add that comes in the waves the stretches are cut at, when
  /// [stretchSource] is waves.
  final String? eventName;
}
