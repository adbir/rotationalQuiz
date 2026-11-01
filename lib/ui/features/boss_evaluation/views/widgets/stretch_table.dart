import 'package:flutter/material.dart';

import '../../../../../domain/models/boss_comparison.dart';
import 'comparison_grid.dart';

/// Casts per minute in each stretch of the fought portion.
class StretchTable extends StatelessWidget {
  const StretchTable({super.key, required this.comparison});

  final BossComparison comparison;

  @override
  Widget build(BuildContext context) {
    final source = switch (comparison.stretchSource) {
      StretchSource.waves =>
        'Cut where each add wave arrives in your log, and the same times '
            'used for the other logs.',
      StretchSource.phases => 'Cut at the phase changes in your log.',
      StretchSource.wholeFight =>
        'No add waves or phases were found, so this is the whole fought '
            'portion.',
    };
    return ComparisonGrid(
      title: 'Casts per minute by stretch',
      caption: '$source Seconds from the pull.',
      columns: [
        for (final s in comparison.stretches)
          '${s.start.inSeconds}-${s.end.inSeconds} s',
      ],
      labelWidth: 80,
      cellWidth: 84,
      rows: [
        for (var i = 0; i < comparison.logs.length; i++)
          GridRow(comparison.logs[i].label, [
            for (final cpm in comparison.castsPerMinute[i])
              GridCell(cpm.toStringAsFixed(1)),
          ]),
      ],
    );
  }
}
