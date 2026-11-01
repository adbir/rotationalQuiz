import 'package:flutter/material.dart';

import '../../../../../domain/models/boss_comparison.dart';
import '../../../../../domain/models/pooling_report.dart';
import 'comparison_grid.dart';

/// For each add wave (named after the add when known): the resource at the spawn, the time since the last spender,
/// and the first spender after it.
class PoolingTable extends StatelessWidget {
  const PoolingTable({
    super.key,
    required this.comparison,
    required this.resourceLabel,
  });

  final BossComparison comparison;
  final String resourceLabel;

  @override
  Widget build(BuildContext context) {
    final event = comparison.stretchSource == StretchSource.phases
        ? 'phase'
        : comparison.eventName == null
        ? 'add wave'
        : '${comparison.eventName} arrival';
    if (comparison.pooling.isEmpty) {
      return ComparisonGrid(
        title: '$resourceLabel before each $event',
        caption: 'There is no $event to check before in this fight.',
        columns: const [],
        rows: const [],
      );
    }
    return ComparisonGrid(
      title: '$resourceLabel at each $event',
      caption:
          '$resourceLabel at the spawn, seconds since the last spender, and '
          'the first spender after. Red means a spender was held back for '
          'the $event: no spender for over 10 s or twice the player\'s '
          'median gap, and one cast within 5 s after. Brackets are the '
          'median gap.',
      columns: [
        for (final w in comparison.pooling.first) '${w.eventTime.inSeconds} s',
      ],
      labelWidth: 100,
      cellWidth: 104,
      rows: [
        for (var i = 0; i < comparison.logs.length; i++)
          GridRow(
            '${comparison.logs[i].label} (${_median(comparison.pooling[i])})',
            [for (final w in comparison.pooling[i]) _cell(w)],
          ),
      ],
    );
  }

  static String _median(List<PoolingReport> waves) {
    final median = waves.first.medianSpenderGap;
    return median == null ? '–' : '${_seconds(median)} s';
  }

  static GridCell _cell(PoolingReport w) {
    final next = w.firstSpenderAfter;
    return GridCell(
      '${w.levelAtEvent.round()} · ${_seconds(w.gapSinceLastSpender)} s\n'
      '${next == null ? 'none after' : '+${_seconds(next)} s ${w.firstSpenderAfterName}'}',
      flag: w.isHeld,
    );
  }

  static String _seconds(Duration d) =>
      (d.inMilliseconds / 1000).toStringAsFixed(1);
}
