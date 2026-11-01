import 'package:flutter/foundation.dart';

/// What a finding is about. Each kind has one fixed "what to try" sentence;
/// the same sentences are in `docs/glossary.md` next to the metric.
enum FindingKind {
  castsPerMinute(
    'Keep a cast going while you move, queue the next spell before this one '
    'ends, and use instant spells while you move.',
  ),
  wastedResource('Cast a spender before your resource reaches its cap.'),
  lostFreeSpenders(
    'Cast the free spender before you refresh the buff that gives it.',
  ),
  heldSpenders(
    'Let your resource build for about 10 s before an add wave, then cast a '
    'spender as it arrives.',
  ),
  castBeforeWindow('Cast Stormkeeper first, then Ascendance.');

  const FindingKind(this.whatToTry);

  /// One imperative sentence, the same every time.
  final String whatToTry;
}

/// One difference from rank 1: the two numbers, where it showed, and what to
/// try. Words are made from these in the view model.
@immutable
class Finding {
  const Finding({
    required this.kind,
    required this.yours,
    required this.rank1,
    required this.share,
    required this.behind,
    required this.valuesByLog,
    this.stretchIndexes = const [],
    this.waveTimes = const [],
  });

  final FindingKind kind;
  final double yours;
  final double rank1;

  /// How far behind rank 1, as a share of rank 1's value. Negative when ahead.
  final double share;

  /// How far behind rank 1 in the metric's own unit. Negative when ahead.
  final double behind;

  /// The metric for every compared log, in the comparison's order.
  final List<double> valuesByLog;

  /// Stretches the difference showed in, worst first.
  final List<int> stretchIndexes;

  /// Waves rank 1 held a spender for and you did not.
  final List<Duration> waveTimes;
}

/// The result of ranking: at most three [findings], the metrics within 10% of
/// rank 1, and how far behind each stretch was for the fight bar.
@immutable
class FindingsReport {
  const FindingsReport({
    required this.findings,
    required this.sameAsRank1,
    required this.stretchShortfall,
  });

  final List<Finding> findings;

  /// Metrics neither behind nor ahead of rank 1 by 10% or more.
  final List<FindingKind> sameAsRank1;

  /// Per stretch, 0 (on par or ahead) to 1 (the worst stretch behind).
  final List<double> stretchShortfall;
}
