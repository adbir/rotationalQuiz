import 'package:flutter/material.dart';

import '../../../../../domain/models/boss_comparison.dart';
import '../../../../../domain/models/finding.dart';
import '../../view_models/finding_text.dart';
import 'comparison_grid.dart';
import 'gap_table.dart';
import 'lost_free_table.dart';
import 'pooling_table.dart';
import 'stretch_table.dart';

/// The table rows a finding rests on.
class FindingEvidence extends StatelessWidget {
  const FindingEvidence({
    super.key,
    required this.finding,
    required this.comparison,
    required this.text,
  });

  final Finding finding;
  final BossComparison comparison;
  final FindingText text;

  @override
  Widget build(BuildContext context) {
    return switch (finding.kind) {
      FindingKind.castsPerMinute => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StretchTable(comparison: comparison),
          GapTable(comparison: comparison),
        ],
      ),
      FindingKind.heldSpenders => PoolingTable(
        comparison: comparison,
        resourceLabel: text.resourceLabel,
      ),
      FindingKind.lostFreeSpenders => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _values(),
          LostFreeTable(comparison: comparison),
        ],
      ),
      _ => _values(),
    };
  }

  Widget _values() => ComparisonGrid(
    title: text.metricName(finding.kind),
    columns: const ['Value'],
    labelWidth: 100,
    rows: [
      for (var i = 0; i < comparison.logs.length; i++)
        GridRow(comparison.logs[i].label, [
          GridCell(
            finding.kind == FindingKind.dotUptime
                ? '${finding.valuesByLog[i].toStringAsFixed(1)}%'
                : finding.valuesByLog[i].round().toString(),
          ),
        ]),
    ],
  );
}
