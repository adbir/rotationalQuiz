import '../../../../domain/models/boss_comparison.dart';
import '../../../../domain/models/finding.dart';

/// The words for a result: facts and numbers, no adjectives. Lines stay short
/// so they read as one column.
class FindingText {
  const FindingText({required this.comparison, required this.resourceLabel});

  final BossComparison comparison;
  final String resourceLabel;

  String get _event =>
      comparison.stretchSource == StretchSource.phases ? 'phase' : 'wave';

  /// "The Twin Fangs · your 394 s wipe vs rank 1 (420 s)".
  String title(String bossName) {
    final mine = comparison.logs.first;
    final top = comparison.logs.last;
    return '$bossName · your ${mine.fought.inSeconds} s '
        '${mine.kill ? 'kill' : 'wipe'} vs rank 1 '
        '(${top.fought.inSeconds} s)';
  }

  /// What happened, with both numbers.
  String headline(Finding f) {
    final you = _n(f.yours);
    final top = _n(f.rank1);
    final gap = comparison.logs.first.metrics.gaps.threshold;
    return switch (f.kind) {
      FindingKind.castsPerMinute =>
        'You pressed $you buttons a minute. Rank 1: $top.',
      FindingKind.gaps =>
        'You stopped casting $you times for over ${_s(gap)} s. '
            'Rank 1: $top.',
      FindingKind.wastedResource =>
        'You wasted $you $resourceLabel. Rank 1 wasted $top.',
      FindingKind.lostFreeSpenders =>
        'You lost $you free spenders by refreshing the buff that gives '
            'them. Rank 1 lost $top.',
      FindingKind.heldSpenders =>
        'Rank 1 held a spender before $top ${_event}s and cast one within '
            '5 s. You held before $you.',
    };
  }

  /// Which stretches or waves, or the nearest thing the log can say.
  String where(Finding f) {
    switch (f.kind) {
      case FindingKind.castsPerMinute:
        final worst = f.stretchIndexes.first;
        final s = comparison.stretches[worst];
        return '${f.stretchIndexes.length} of ${comparison.stretches.length} '
            'stretches behind; worst ${s.start.inSeconds}-'
            '${s.end.inSeconds} s '
            '(${_n(comparison.castsPerMinute.first[worst])} vs '
            '${_n(comparison.castsPerMinute.last[worst])}).';
      case FindingKind.gaps:
        final mine = comparison.logs.first.metrics.gaps.longest;
        final top = comparison.logs.last.metrics.gaps.longest;
        return 'longest gap ${_s(mine)} s. Rank 1: ${_s(top)} s.';
      case FindingKind.heldSpenders:
        return '${_event}s at '
            '${[for (final t in f.waveTimes) t.inSeconds].join(', ')} s.';
      case FindingKind.wastedResource:
      case FindingKind.lostFreeSpenders:
        // ponytail: the metrics have no times, so this is the whole fight.
        return 'the whole fought portion, ${comparison.fought.inSeconds} s.';
    }
  }

  /// "Same as rank 1: casts per minute, gaps." Empty when nothing is.
  String sameAsRank1(List<FindingKind> kinds) => kinds.isEmpty
      ? ''
      : 'Same as rank 1: ${[for (final k in kinds) _label(k)].join(', ')}.';

  String _label(FindingKind kind) => switch (kind) {
    FindingKind.castsPerMinute => 'casts per minute',
    FindingKind.gaps => 'gaps',
    FindingKind.wastedResource => 'wasted ${resourceLabel.toLowerCase()}',
    FindingKind.lostFreeSpenders => 'free spenders',
    FindingKind.heldSpenders => 'held spenders',
  };

  /// The column title for a metric's evidence rows.
  String metricName(FindingKind kind) => switch (kind) {
    FindingKind.wastedResource => '$resourceLabel wasted',
    FindingKind.lostFreeSpenders => 'Free spenders lost',
    FindingKind.gaps => 'Gaps',
    _ => _label(kind),
  };

  static String _n(double v) => v.round().toString();
  static String _s(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(1);
}
