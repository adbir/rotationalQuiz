import 'package:flutter/material.dart';

import '../../../../../domain/models/boss_comparison.dart';
import 'comparison_grid.dart';

/// How long a proc waited before it was spent, for every log.
class HeldProcsTable extends StatelessWidget {
  const HeldProcsTable({
    super.key,
    required this.name,
    required this.comparison,
  });

  final String name;
  final BossComparison comparison;

  @override
  Widget build(BuildContext context) {
    return ComparisonGrid(
      title: '$name procs',
      caption:
          'Hold is the time from a proc coming to it going, averaged over '
          'the procs that went.',
      columns: const ['Procs', 'Spent', 'Hold'],
      labelWidth: 100,
      rows: [
        for (final log in comparison.logs)
          GridRow(log.label, [
            for (final p in log.metrics.heldProcs.where(
              (p) => p.name == name,
            )) ...[
              GridCell('${p.gained}'),
              GridCell('${p.spent}'),
              GridCell(
                p.averageHold == null
                    ? '–'
                    : '${(p.averageHold!.inMilliseconds / 1000).toStringAsFixed(1)} s',
              ),
            ],
          ]),
      ],
    );
  }
}
