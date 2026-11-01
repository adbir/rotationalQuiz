import 'package:flutter/material.dart';

import '../../../../../domain/models/boss_comparison.dart';
import 'comparison_grid.dart';

/// Each free spender the player lost: when, and which fade gave the buff.
class LostFreeTable extends StatelessWidget {
  const LostFreeTable({super.key, required this.comparison});

  final BossComparison comparison;

  @override
  Widget build(BuildContext context) {
    final lost = comparison.logs.first.metrics.spenders.lostFreeDetails;
    return ComparisonGrid(
      title: 'Your lost free spenders',
      caption:
          'Seconds from the pull, and the latest fade of a buff that gives '
          'them before the loss.',
      columns: const ['Fade before'],
      labelWidth: 72,
      cellWidth: 140,
      rows: [
        for (final l in lost)
          GridRow('${l.time.inSeconds} s', [GridCell(l.sourceName ?? '–')]),
      ],
    );
  }
}
