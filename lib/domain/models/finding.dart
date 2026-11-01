import 'package:flutter/foundation.dart';

/// What a finding is about. Each kind has one fixed "what to try" sentence;
/// the same sentences are in `docs/glossary.md` next to the metric. A spec's
/// [RankedMetric] can give a sentence that names its subject instead.
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
  castBeforeWindow('Cast Stormkeeper first, then Ascendance.'),
  dotUptime('Refresh Flame Shock before it falls off.'),

  /// Casts of one cooldown as a percentage of the most the fight allowed.
  castsAgainstPossible('Cast it each time it comes off cooldown.'),

  /// How much of the fight one aura was up, on the player or on others.
  upkeep('Keep it up all fight.'),

  /// Average seconds a proc's buff was held before it went.
  procHoldTime('Spend the proc as soon as it comes.'),

  /// One ability's casts per minute.
  abilityCastsPerMinute('Cast it whenever it has a charge.'),

  /// The resource left at the end, as a percentage of its maximum.
  resourceAtEnd('Spend your resource so that it runs out as the boss dies.'),

  /// Average mana the casts inside a free-cast buff would have cost.
  freeCastValue(
    'Cast your most expensive spells, back to back, while the buff is up.',
  );

  const FindingKind(this.whatToTry);

  /// One imperative sentence, the same every time.
  final String whatToTry;
}

/// One metric a spec ranks against rank 1, and what "behind" means for it.
@immutable
class RankedMetric {
  const RankedMetric(
    this.kind, {
    this.higherIsBetter = false,
    this.fullScale,
    this.onlyWhenSeen = false,
    this.cooldownId,
    this.abilityId,
    this.whatToTry,
  });

  final FindingKind kind;

  /// Whether a higher value is better. Otherwise lower is.
  final bool higherIsBetter;

  /// What the difference is a share of: this, such as 100 for a percentage,
  /// or rank 1's own value when `null`.
  final double? fullScale;

  /// Leave it out when every log's value is zero.
  final bool onlyWhenSeen;

  /// The cooldown a [FindingKind.castsAgainstPossible] counts.
  final String? cooldownId;

  /// The logged id of the aura, proc or ability the metric is about.
  final int? abilityId;

  /// A sentence naming the subject, in place of the kind's own.
  final String? whatToTry;
}

/// Which metrics a spec's findings rank, and how the ones behind are ordered
/// after casts per minute, which always leads.
@immutable
class FindingRules {
  const FindingRules(this.metrics, {this.orderByShare = false});

  /// In the order "the same as rank 1" lists them.
  final List<RankedMetric> metrics;

  /// Order by how far behind as a share (see [Finding.share]). Otherwise by
  /// how far behind in each metric's own unit.
  final bool orderByShare;
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
    this.subject,
    this._whatToTry,
  });

  final FindingKind kind;
  final double yours;
  final double rank1;

  /// How far behind rank 1, as a share of rank 1's value (or of the metric's
  /// full scale). Negative when ahead.
  final double share;

  /// How far behind rank 1 in the metric's own unit. Negative when ahead.
  final double behind;

  /// The metric for every compared log, in the comparison's order.
  final List<double> valuesByLog;

  /// Stretches the difference showed in, worst first.
  final List<int> stretchIndexes;

  /// Waves rank 1 held a spender for and you did not.
  final List<Duration> waveTimes;

  /// The cooldown, aura or ability the finding is about, by name.
  final String? subject;

  final String? _whatToTry;

  /// One imperative sentence, the same every time for this metric.
  String get whatToTry => _whatToTry ?? kind.whatToTry;
}

/// The result of ranking: at most three [findings], the metrics within 10% of
/// rank 1, and how far behind each stretch was for the fight bar.
@immutable
class FindingsReport {
  const FindingsReport({
    required this.findings,
    required this.same,
    required this.stretchShortfall,
  });

  final List<Finding> findings;

  /// Metrics neither behind nor ahead of rank 1 by 10% or more.
  final List<Finding> same;

  /// The kinds of [same], in order.
  List<FindingKind> get sameAsRank1 => [for (final f in same) f.kind];

  /// Per stretch, 0 (on par or ahead) to 1 (the worst stretch behind).
  final List<double> stretchShortfall;
}
