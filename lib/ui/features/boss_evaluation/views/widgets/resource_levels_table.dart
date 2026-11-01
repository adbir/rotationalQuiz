import 'package:flutter/material.dart';

import '../../../../../domain/models/aura_metrics.dart';
import '../../../../../domain/models/boss_comparison.dart';
import 'comparison_grid.dart';

/// The resource's level, in percent of its maximum, at each phase change and
/// at the end, one column per log. Rank 1's is beside yours.
class ResourceLevelsTable extends StatelessWidget {
  const ResourceLevelsTable({
    super.key,
    required this.comparison,
    required this.resourceLabel,
  });

  final BossComparison comparison;
  final String resourceLabel;

  @override
  Widget build(BuildContext context) {
    final levels = [
      for (final log in comparison.logs) log.metrics.resourceLevels,
    ];
    final phases = levels.first?.atPhaseChanges ?? const <ResourceLevel>[];
    String pct(ResourceLevel? l) =>
        l == null ? '–' : '${l.percent.toStringAsFixed(0)}%';
    GridRow row(
      String label,
      ResourceLevel? Function(ResourceLevelMetrics) of,
    ) => GridRow(label, [
      for (final l in levels) GridCell(l == null ? '–' : pct(of(l))),
    ]);
    return ComparisonGrid(
      title: '$resourceLabel over the fight',
      caption:
          'A reading is the level as a cast went off. Phase changes are '
          'seconds from the pull.',
      columns: [for (final log in comparison.logs) log.label],
      labelWidth: 112,
      cellWidth: 78,
      rows: [
        for (final (i, p) in phases.indexed)
          GridRow('At ${p.time.inSeconds} s', [
            for (final l in levels)
              GridCell(
                l != null && i < l.atPhaseChanges.length
                    ? pct(l.atPhaseChanges[i])
                    : '–',
              ),
          ]),
        row('At the end', (l) => l.atEnd),
        row('Lowest', (l) => l.lowest),
      ],
    );
  }
}
