import '../models/boss_comparison.dart';
import '../models/finding.dart';

/// Picks what to tell the player: the metrics they control, ordered by how far
/// they are from rank 1 as a share of rank 1's value. Cooldown press delays are
/// left out because top players delay too. Interim rule: #28 decides the real
/// one and replaces this.
class RankFindings {
  const RankFindings();

  /// A difference smaller than this share of rank 1's value is "the same".
  static const sameShare = 0.10;
  static const maxFindings = 3;

  /// The last log of [comparison] is rank 1; the first is the player's.
  FindingsReport call(BossComparison comparison) {
    final logs = comparison.logs;
    if (logs.length < 2) {
      return const FindingsReport(
        findings: [],
        sameAsRank1: [],
        stretchShortfall: [],
      );
    }
    final all = [for (final log in logs) log.metrics];

    final casts = _shortfalls(comparison);
    final candidates = <Finding>[
      _finding(
        FindingKind.castsPerMinute,
        [for (final m in all) m.casts.perMinute],
        higherIsBetter: true,
        stretchIndexes: [
          for (final i in _worstFirst(casts))
            if (casts[i] >= sameShare) i,
        ],
      ),
      _finding(FindingKind.gaps, [
        for (final m in all) m.gaps.count.toDouble(),
      ]),
      _finding(FindingKind.wastedResource, [
        for (final m in all) m.resource.wasted.toDouble(),
      ]),
      _finding(FindingKind.lostFreeSpenders, [
        for (final m in all) m.spenders.lostFree.toDouble(),
      ]),
      if (comparison.pooling.isNotEmpty) _held(comparison),
    ];

    final byGap = [...candidates]..sort((a, b) => b.share.compareTo(a.share));
    return FindingsReport(
      findings: [
        for (final f in byGap)
          if (f.share >= sameShare) f,
      ].take(maxFindings).toList(),
      sameAsRank1: [
        for (final f in candidates)
          if (f.share.abs() < sameShare) f.kind,
      ],
      stretchShortfall: _normalised(casts),
    );
  }

  Finding _finding(
    FindingKind kind,
    List<double> values, {
    bool higherIsBetter = false,
    List<int> stretchIndexes = const [],
    List<Duration> waveTimes = const [],
  }) {
    final yours = values.first;
    final rank1 = values.last;
    final behind = higherIsBetter ? rank1 - yours : yours - rank1;
    return Finding(
      kind: kind,
      yours: yours,
      rank1: rank1,
      share: behind / (rank1 < 1 ? 1 : rank1),
      valuesByLog: values,
      stretchIndexes: stretchIndexes,
      waveTimes: waveTimes,
    );
  }

  Finding _held(BossComparison c) {
    final top = c.logs.length - 1;
    int held(int log) => c.pooling[log].where((w) => w.isHeld).length;
    return _finding(
      FindingKind.heldSpenders,
      [for (var i = 0; i < c.logs.length; i++) held(i).toDouble()],
      higherIsBetter: true,
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

  List<int> _worstFirst(List<double> shortfalls) =>
      List.generate(shortfalls.length, (i) => i)
        ..sort((a, b) => shortfalls[b].compareTo(shortfalls[a]));

  List<double> _normalised(List<double> shortfalls) {
    final worst = shortfalls.fold(0.0, (a, b) => a > b ? a : b);
    return [for (final s in shortfalls) worst == 0 ? 0 : s / worst];
  }
}
