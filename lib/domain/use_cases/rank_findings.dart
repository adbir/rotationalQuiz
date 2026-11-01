import '../models/aura_metrics.dart';
import '../models/boss_comparison.dart';
import '../models/finding.dart';
import '../models/player_metrics.dart';

/// Picks what to tell the player (decided in #28). The spec's [FindingRules]
/// name the metrics and what "behind" means for each (#78). Casts per minute
/// leads whenever the player is 10% or more behind rank 1, and its gaps are
/// part of it. The other metrics follow by how far behind rank 1 they are, in
/// their own unit or as a share, up to three findings in all.
class RankFindings {
  const RankFindings();

  /// A difference smaller than this share of rank 1's value is "the same".
  static const sameShare = 0.10;
  static const maxFindings = 3;

  /// The last log of [comparison] is rank 1; the first is the player's.
  FindingsReport call(BossComparison comparison) {
    final logs = comparison.logs;
    if (logs.length < 2) {
      return const FindingsReport(findings: [], same: [], stretchShortfall: []);
    }
    final casts = _shortfalls(comparison);
    final rules = comparison.findingRules;
    final candidates = [
      for (final rule in rules.metrics) ?_candidate(comparison, rule, casts),
    ];

    double order(Finding f) => rules.orderByShare ? f.share : f.behind;
    final behind = [
      for (final f in candidates)
        if (f.share >= sameShare) f,
    ];
    final lead = behind.where((f) => f.kind == FindingKind.castsPerMinute);
    final others =
        behind.where((f) => f.kind != FindingKind.castsPerMinute).toList()
          ..sort((a, b) => order(b).compareTo(order(a)));
    return FindingsReport(
      findings: [...lead, ...others].take(maxFindings).toList(),
      same: [
        for (final f in candidates)
          if (f.share.abs() < sameShare) f,
      ],
      stretchShortfall: _normalised(casts),
    );
  }

  /// The rule's finding, or `null` when a log lacks the metric or the rule
  /// leaves it out.
  Finding? _candidate(
    BossComparison c,
    RankedMetric rule,
    List<double> castShortfalls,
  ) {
    final all = [for (final log in c.logs) log.metrics];
    final values = <double>[];
    for (final m in all) {
      final value = _value(m, rule);
      if (value == null) return null;
      values.add(value);
    }
    if (rule.kind == FindingKind.heldSpenders && c.pooling.isEmpty) return null;
    if (rule.onlyWhenSeen && values.every((v) => v <= 0)) return null;
    return switch (rule.kind) {
      FindingKind.castsPerMinute => _finding(
        rule,
        values,
        stretchIndexes: [
          for (final i in _worstFirst(castShortfalls))
            if (castShortfalls[i] >= sameShare) i,
        ],
      ),
      FindingKind.wastedResource => _finding(
        rule,
        values,
        stretchIndexes: [
          for (final i in _worstFirst(_excessWaste(c)))
            if (_excessWaste(c)[i] > 0) i,
        ],
      ),
      FindingKind.heldSpenders => _held(c, rule),
      _ => _finding(rule, values, subject: _subject(all, rule)),
    };
  }

  /// One log's value of [rule]'s metric, or `null` when it has none.
  double? _value(PlayerMetrics m, RankedMetric rule) => switch (rule.kind) {
    FindingKind.castsPerMinute => m.casts.perMinute,
    FindingKind.wastedResource => m.resource.wasted.toDouble(),
    FindingKind.lostFreeSpenders => m.spenders.lostFree.toDouble(),
    FindingKind.castBeforeWindow =>
      m.windowCasts.fold(0, (n, w) => n + w.count).toDouble(),
    // ponytail: the first DoT stands for all; the Elemental Shaman has one.
    FindingKind.dotUptime =>
      m.dotUptime.isEmpty ? 0 : m.dotUptime.first.percent,
    FindingKind.heldSpenders => 0,
    FindingKind.castsAgainstPossible => switch (_cooldown(m, rule)) {
      CooldownMetrics(:final uses, possible: final possible?)
          when possible > 0 =>
        100 * uses / possible,
      _ => null,
    },
    FindingKind.upkeep => _upkeep(m, rule)?.percent,
    FindingKind.procHoldTime => switch (_proc(m, rule)?.averageHold) {
      final hold? => hold.inMilliseconds / 1000,
      null => null,
    },
    FindingKind.abilityCastsPerMinute =>
      m.casts.byAbility
              .where((a) => a.abilityId == rule.abilityId)
              .firstOrNull
              ?.perMinute ??
          0,
    FindingKind.resourceAtEnd => m.resourceLevels?.atEnd?.percent,
  };

  String? _subject(List<PlayerMetrics> all, RankedMetric rule) {
    for (final m in all) {
      final name = switch (rule.kind) {
        FindingKind.castsAgainstPossible => _cooldown(m, rule)?.name,
        FindingKind.upkeep => _upkeep(m, rule)?.name,
        FindingKind.procHoldTime => _proc(m, rule)?.name,
        FindingKind.abilityCastsPerMinute =>
          m.casts.byAbility
              .where((a) => a.abilityId == rule.abilityId)
              .firstOrNull
              ?.name,
        _ => null,
      };
      if (name != null) return name;
    }
    return null;
  }

  CooldownMetrics? _cooldown(PlayerMetrics m, RankedMetric rule) =>
      m.cooldowns.where((c) => c.id == rule.cooldownId).firstOrNull;

  AuraUptime? _upkeep(PlayerMetrics m, RankedMetric rule) =>
      m.upkeep.where((u) => u.buffId == rule.abilityId).firstOrNull;

  HeldProcMetrics? _proc(PlayerMetrics m, RankedMetric rule) =>
      m.heldProcs.where((p) => p.buffId == rule.abilityId).firstOrNull;

  Finding _finding(
    RankedMetric rule,
    List<double> values, {
    List<int> stretchIndexes = const [],
    List<Duration> waveTimes = const [],
    String? subject,
  }) {
    final yours = values.first;
    final rank1 = values.last;
    final behind = rule.higherIsBetter ? rank1 - yours : yours - rank1;
    return Finding(
      kind: rule.kind,
      yours: yours,
      rank1: rank1,
      share: behind / (rule.fullScale ?? (rank1 < 1 ? 1 : rank1)),
      behind: behind,
      valuesByLog: values,
      stretchIndexes: stretchIndexes,
      waveTimes: waveTimes,
      subject: subject,
      whatToTry: rule.whatToTry,
    );
  }

  Finding _held(BossComparison c, RankedMetric rule) {
    final top = c.logs.length - 1;
    int held(int log) => c.pooling[log].where((w) => w.isHeld).length;
    return _finding(
      rule,
      [for (var i = 0; i < c.logs.length; i++) held(i).toDouble()],
      waveTimes: [
        for (var w = 0; w < c.pooling[top].length; w++)
          if (c.pooling[top][w].isHeld && !c.pooling.first[w].isHeld)
            c.pooling[top][w].eventTime,
      ],
    );
  }

  /// Per stretch: how far the player's casts per minute were behind rank 1's,
  /// as a share of rank 1's. Zero when on par or ahead.
  List<double> _shortfalls(BossComparison c) {
    final mine = c.castsPerMinute.first;
    final top = c.castsPerMinute.last;
    return [
      for (var i = 0; i < mine.length; i++)
        top[i] <= 0 ? 0 : ((top[i] - mine[i]) / top[i]).clamp(0, 1).toDouble(),
    ];
  }

  /// Per stretch: how much more the player wasted than rank 1. Negative when
  /// the player wasted less.
  List<double> _excessWaste(BossComparison c) => [
    for (var i = 0; i < c.stretches.length; i++)
      (c.wastedResource.first[i] - c.wastedResource.last[i]).toDouble(),
  ];

  List<int> _worstFirst(List<double> shortfalls) =>
      List.generate(shortfalls.length, (i) => i)
        ..sort((a, b) => shortfalls[b].compareTo(shortfalls[a]));

  List<double> _normalised(List<double> shortfalls) {
    final worst = shortfalls.fold(0.0, (a, b) => a > b ? a : b);
    return [for (final s in shortfalls) worst == 0 ? 0 : s / worst];
  }
}
