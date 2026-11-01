import 'package:flutter/material.dart';

import '../../../../../domain/models/boss_comparison.dart';
import 'comparison_grid.dart';

/// The resource held in the lead-up to each wave, and the spenders cast
/// after it.
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
        : 'wave';
    if (comparison.pooling.isEmpty) {
      return ComparisonGrid(
        title: '$resourceLabel before each $event',
        caption: 'There is no $event to check before in this fight.',
        columns: const [],
        rows: const [],
      );
    }
    final waves = comparison.pooling.first;
    return ComparisonGrid(
      title: '$resourceLabel before each $event',
      caption:
          'Mean $resourceLabel in the 8 s before, then spenders cast in the 8 '
          's after. Red means held back: well above the fight mean (in '
          'brackets) with spenders after. It says what happened, not why.',
      columns: [for (final w in waves) '${w.eventTime.inSeconds} s'],
      labelWidth: 100,
      cellWidth: 72,
      rows: [
        for (var i = 0; i < comparison.logs.length; i++)
          GridRow(
            '${comparison.logs[i].label} '
            '(${comparison.pooling[i].first.normalLevel.round()})',
            [
              for (final w in comparison.pooling[i])
                GridCell(
                  '${w.meanBefore.round()} / ${w.spendersAfter}',
                  flag: w.isPooled,
                ),
            ],
          ),
      ],
    );
  }
}
