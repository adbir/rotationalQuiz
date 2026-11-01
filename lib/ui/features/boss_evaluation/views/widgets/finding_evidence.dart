import 'package:flutter/material.dart';

import '../../../../../domain/models/boss_comparison.dart';
import '../../../../../domain/models/finding.dart';
import '../../view_models/evidence_details.dart';
import '../../view_models/finding_text.dart';
import 'comparison_grid.dart';
import 'gap_table.dart';
import 'held_procs_table.dart';
import 'lost_free_table.dart';
import 'pooling_table.dart';
import 'possible_casts_table.dart';
import 'resource_levels_table.dart';
import 'stretch_table.dart';
import 'upkeep_table.dart';

/// The table rows a finding rests on.
class FindingEvidence extends StatelessWidget {
  const FindingEvidence({
    super.key,
    required this.finding,
    required this.comparison,
    required this.text,
    required this.details,
    required this.showMovement,
  });

  final Finding finding;
  final BossComparison comparison;
  final FindingText text;
  final EvidenceDetails? details;

  /// Whether the spec has a movement form or a cast-while-moving spell.
  final bool showMovement;

  @override
  Widget build(BuildContext context) {
    return switch (finding.kind) {
      FindingKind.castsPerMinute => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StretchTable(comparison: comparison),
          GapTable(comparison: comparison, showMovement: showMovement),
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
      FindingKind.castsAgainstPossible => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _values(),
          PossibleCastsTable(
            name: finding.subject!,
            comparison: comparison,
            details: details,
          ),
        ],
      ),
      FindingKind.upkeep => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _values(),
          UpkeepTable(
            name: finding.subject!,
            comparison: comparison,
            details: details,
          ),
        ],
      ),
      FindingKind.procHoldTime => HeldProcsTable(
        name: finding.subject!,
        comparison: comparison,
      ),
      FindingKind.resourceAtEnd => ResourceLevelsTable(
        comparison: comparison,
        resourceLabel: text.resourceLabel,
      ),
      _ => _values(),
    };
  }

  Widget _values() => ComparisonGrid(
    title: text.metricName(finding),
    columns: const ['Value'],
    labelWidth: 100,
    rows: [
      for (var i = 0; i < comparison.logs.length; i++)
        GridRow(comparison.logs[i].label, [
          GridCell(text.value(finding, finding.valuesByLog[i])),
        ]),
    ],
  );
}
