import '../../../../domain/models/aura_metrics.dart';
import '../../../../domain/models/boss_comparison.dart';
import '../../../../domain/models/dot_uptime.dart';
import '../../../../domain/models/finding.dart';
import '../../../../domain/models/player_metrics.dart';
import '../../../../domain/models/window_cast.dart';
import 'evidence_details.dart';

/// The words for a result: facts and numbers, no adjectives. Lines stay short
/// so they read as one column.
class FindingText {
  const FindingText({
    required this.comparison,
    required this.resourceLabel,
    this.details,
  });

  final BossComparison comparison;
  final String resourceLabel;

  /// Your own log's times, for the "where" of an aura or a cooldown.
  final EvidenceDetails? details;

  /// "3 Spawn of Vexhul arrivals", "3 add waves" or "3 phases".
  String _events(int count) {
    final s = count == 1 ? '' : 's';
    return switch (comparison.stretchSource) {
      StretchSource.phases => '$count phase$s',
      _ when comparison.eventName != null =>
        '$count ${comparison.eventName} arrival$s',
      _ => '$count add wave$s',
    };
  }

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
    return switch (f.kind) {
      FindingKind.castsPerMinute =>
        'You pressed $you buttons a minute. Rank 1: $top.',
      FindingKind.wastedResource =>
        'You wasted $you $resourceLabel. Rank 1 wasted $top.',
      FindingKind.lostFreeSpenders =>
        'You lost $you free spenders by refreshing the buff that gives '
            'them. Rank 1 lost $top.',
      FindingKind.castBeforeWindow =>
        'You cast Stormkeeper during Ascendance $you '
            '${f.yours == 1 ? 'time' : 'times'}, losing about '
            '${_s(_windowLost())} s of it. Rank 1: $top.',
      FindingKind.dotUptime =>
        '${_dot().name} was up ${_p(f.yours)}% of the fight. '
            'Rank 1: ${_p(f.rank1)}%.',
      FindingKind.heldSpenders =>
        'Rank 1 held a spender before ${_events(f.rank1.round())} and cast '
            'one within 5 s. You held before $you.',
      FindingKind.castsAgainstPossible =>
        'You cast ${f.subject} ${_p(f.yours)}% of the times you could. '
            'Rank 1: ${_p(f.rank1)}%.',
      FindingKind.upkeep =>
        '${f.subject} was up ${_p(f.yours)}% of the fight. '
            'Rank 1: ${_p(f.rank1)}%.',
      FindingKind.procHoldTime =>
        'You held ${f.subject} procs ${_p(f.yours)} s on average. '
            'Rank 1: ${_p(f.rank1)} s.',
      FindingKind.abilityCastsPerMinute =>
        'You cast ${f.subject} ${_p(f.yours)} times a minute. '
            'Rank 1: ${_p(f.rank1)}.',
      FindingKind.resourceAtEnd =>
        'You ended with ${_p(f.yours)}% $resourceLabel. '
            'Rank 1: ${_p(f.rank1)}%.',
      FindingKind.freeCastValue =>
        '${f.subject} saved you $you mana on average. Rank 1: $top.',
    };
  }

  /// Which stretches or waves, or the nearest thing the log can say.
  String where(Finding f) {
    switch (f.kind) {
      case FindingKind.castsPerMinute:
        final worst = f.stretchIndexes.first;
        final s = comparison.stretches[worst];
        return '${_gapsWhere()}'
            '${f.stretchIndexes.length} of ${comparison.stretches.length} '
            'stretches behind; worst ${s.start.inSeconds}-'
            '${s.end.inSeconds} s '
            '(${_n(comparison.castsPerMinute.first[worst])} vs '
            '${_n(comparison.castsPerMinute.last[worst])}).';
      case FindingKind.heldSpenders:
        return '${_events(f.waveTimes.length)} at '
            '${[for (final t in f.waveTimes) t.inSeconds].join(', ')} s.';
      case FindingKind.lostFreeSpenders:
        final lost = comparison.logs.first.metrics.spenders.lostFreeDetails;
        return [
          for (final l in lost)
            l.sourceName == null
                ? 'at ${l.time.inSeconds} s'
                : 'at ${l.time.inSeconds} s after ${l.sourceName} faded',
        ].join(', ');
      case FindingKind.castBeforeWindow:
        return [
          for (final d in _windowDetails())
            'at ${d.time.inSeconds} s, ${_s(d.remaining)} s of it left',
        ].join(', ');
      case FindingKind.dotUptime:
        return 'down ${[for (final g in _dot().gaps) '${_s(g.start)}-${_s(g.start + g.length)} s'].join(', ')}';
      case FindingKind.castsAgainstPossible:
        return _castsWhere(f.subject);
      case FindingKind.upkeep:
        return _upkeepWhere(f.subject);
      case FindingKind.procHoldTime:
        return _procWhere(f.subject);
      case FindingKind.abilityCastsPerMinute ||
          FindingKind.resourceAtEnd ||
          FindingKind.freeCastValue:
        return 'the whole fought portion, ${comparison.fought.inSeconds} s.';
      case FindingKind.wastedResource:
        if (f.stretchIndexes.isEmpty || comparison.stretches.length == 1) {
          return 'the whole fought portion, ${comparison.fought.inSeconds} s.';
        }
        final worst = f.stretchIndexes.first;
        final s = comparison.stretches[worst];
        return 'mostly at ${s.start.inSeconds}-${s.end.inSeconds} s '
            '(${comparison.wastedResource.first[worst]} vs '
            '${comparison.wastedResource.last[worst]} for rank 1).';
    }
  }

  /// "3 of 4 possible casts, 2 of them late; rank 1: 4 of 4."
  String _castsWhere(String? name) {
    final mine = _cooldownOf(0, name);
    final top = _cooldownOf(comparison.logs.length - 1, name);
    if (mine == null) return _whole();
    final late =
        details
            ?.cooldownCasts(name!)
            .where((c) => (c.late ?? Duration.zero) > _lateAfter)
            .length ??
        0;
    return '${mine.uses} of ${mine.possible} possible casts'
        '${late == 0 ? '' : ', $late of them more than ${_lateAfter.inSeconds} s after it was ready'}'
        '${top == null ? '' : '; rank 1: ${top.uses} of ${top.possible}'}.';
  }

  /// "down 12.0-20.5 s", or the total for an aura the log gives no stretches.
  String _upkeepWhere(String? name) {
    final down = details?.downStretches(name!);
    if (down == null || down.isEmpty) return _whole();
    return 'down ${[for (final w in down) '${_s(w.start)}-${_s(w.end)} s'].join(', ')}.';
  }

  /// "1 of 1 procs held, 0.4 s on average; rank 1: 3 of 3."
  String _procWhere(String? name) {
    HeldProcMetrics? at(int i) => comparison.logs[i].metrics.heldProcs
        .where((p) => p.name == name)
        .firstOrNull;
    final mine = at(0);
    final top = at(comparison.logs.length - 1);
    if (mine == null) return _whole();
    return '${mine.spent} of ${mine.gained} procs spent'
        '${mine.unspentAtEnd == 0 ? '' : ', ${mine.unspentAtEnd} still up at the end'}'
        '${top == null ? '' : '; rank 1: ${top.spent} of ${top.gained}'}.';
  }

  static const _lateAfter = Duration(seconds: 3);

  String _whole() =>
      'the whole fought portion, ${comparison.fought.inSeconds} s.';

  CooldownMetrics? _cooldownOf(int log, String? name) => comparison
      .logs[log]
      .metrics
      .cooldowns
      .where((c) => c.name == name)
      .firstOrNull;

  DotUptime _dot() => comparison.logs.first.metrics.dotUptime.first;

  // ponytail: the headline names Stormkeeper and Ascendance; a second spec
  // would take the names from its log rules.
  List<WindowCastDetail> _windowDetails() => [
    for (final w in comparison.logs.first.metrics.windowCasts) ...w.details,
  ];

  Duration _windowLost() =>
      _windowDetails().fold(Duration.zero, (sum, d) => sum + d.lost);

  // ponytail: names the Elemental Shaman's Ghost Wolf and Spiritwalker's Grace
  // here; a second spec would take the names from its log rules.
  String _gapsWhere() {
    final gaps = comparison.logs.first.metrics.gaps;
    final details = gaps.details;
    if (details.isEmpty) return '';
    final shared = comparison.gapsAlsoInRank1;
    final counts = <String, int>{};
    for (final (i, g) in details.indexed) {
      final key = g.inMovementForm
          ? 'in Ghost Wolf'
          : g.graceUp
          ? "with Spiritwalker's Grace up"
          : i < shared.length && shared[i]
          ? 'at the same time as rank 1'
          : g.graceReady
          ? "with a Spiritwalker's Grace charge unused"
          : 'others';
      counts.update(key, (n) => n + 1, ifAbsent: () => 1);
    }
    final top = comparison.logs.last.metrics.gaps;
    return '${details.length} gaps over ${_s(gaps.threshold)} s (rank 1: '
        '${top.count}): '
        '${[for (final e in counts.entries) '${e.value} ${e.key}'].join(', ')}. '
        'Longest ${_s(gaps.longest)} s, rank 1: ${_s(top.longest)} s. ';
  }

  /// "Same as rank 1: casts per minute, gaps." Empty when nothing is.
  String sameAsRank1(List<Finding> same) => same.isEmpty
      ? ''
      : 'Same as rank 1: ${[for (final f in same) _label(f.kind, f.subject)].join(', ')}.';

  String _label(FindingKind kind, [String? subject]) => switch (kind) {
    FindingKind.castsPerMinute => 'casts per minute',
    FindingKind.wastedResource => 'wasted ${resourceLabel.toLowerCase()}',
    FindingKind.lostFreeSpenders => 'free spenders',
    FindingKind.heldSpenders => 'held spenders',
    FindingKind.castBeforeWindow => 'Stormkeeper during Ascendance',
    FindingKind.dotUptime => '${_dot().name} uptime',
    FindingKind.castsAgainstPossible => '$subject casts',
    FindingKind.upkeep => '$subject uptime',
    FindingKind.procHoldTime => '$subject hold time',
    FindingKind.abilityCastsPerMinute => '$subject casts per minute',
    FindingKind.resourceAtEnd => '${resourceLabel.toLowerCase()} at the end',
    FindingKind.freeCastValue => '$subject mana saved',
  };

  /// The column title for a metric's evidence rows.
  String metricName(Finding f) => switch (f.kind) {
    FindingKind.wastedResource => '$resourceLabel wasted',
    FindingKind.lostFreeSpenders => 'Free spenders lost',
    FindingKind.dotUptime => '${_dot().name} uptime, %',
    FindingKind.castsAgainstPossible => '${f.subject} of possible, %',
    FindingKind.upkeep => '${f.subject} uptime, %',
    FindingKind.procHoldTime => '${f.subject} hold, s',
    FindingKind.resourceAtEnd => '$resourceLabel at the end, %',
    _ => _label(f.kind, f.subject),
  };

  /// One evidence value: whole counts, or one decimal for a percentage,
  /// seconds or a rate.
  String value(Finding f, double v) => switch (f.kind) {
    FindingKind.dotUptime => '${_p(v)}%',
    FindingKind.castsAgainstPossible ||
    FindingKind.upkeep ||
    FindingKind.resourceAtEnd => '${_p(v)}%',
    FindingKind.procHoldTime || FindingKind.abilityCastsPerMinute => _p(v),
    _ => _n(v),
  };

  static String _p(double v) => v.toStringAsFixed(1);
  static String _n(double v) => v.round().toString();
  static String _s(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(1);
}
