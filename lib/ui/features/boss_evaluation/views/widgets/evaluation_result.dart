import 'package:flutter/material.dart';

import '../../view_models/boss_evaluation_view_model.dart';
import 'fight_bar.dart';
import 'finding_card.dart';
import 'finding_evidence.dart';
import 'log_header_table.dart';
import 'metrics_table.dart';
import 'nsrt_note_bar.dart';
import 'pooling_table.dart';
import 'stretch_table.dart';

/// A loaded result: the findings first, then what is the same as rank 1, then
/// the tables folded away, then the NSRT note.
class EvaluationResult extends StatelessWidget {
  const EvaluationResult({super.key, required this.viewModel});

  final BossEvaluationViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final comparison = vm.comparison!;
    final report = vm.report!;
    final text = vm.text!;
    final theme = Theme.of(context);
    final same = text.sameAsRank1(report.same);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text.title(vm.bossName), style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        FightBar(
          stretches: comparison.stretches,
          shortfall: report.stretchShortfall,
        ),
        const SizedBox(height: 16),
        if (report.findings.isNotEmpty) ...[
          Text(
            'Ordered by what usually costs most, not by measured DPS.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
        for (final (i, finding) in report.findings.indexed) ...[
          FindingCard(
            number: i + 1,
            headline: text.headline(finding),
            where: text.where(finding),
            whatToTry: finding.whatToTry,
            evidence: FindingEvidence(
              finding: finding,
              comparison: comparison,
              text: text,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (same.isNotEmpty) Text(same),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: vm.showAll,
          onExpansionChanged: (open) => vm.showAll = open,
          title: const Text('All numbers'),
          children: [
            LogHeaderTable(comparison: comparison, bossName: vm.bossName),
            MetricsTable(
              comparison: comparison,
              resourceLabel: vm.resourceLabel,
            ),
            StretchTable(comparison: comparison),
            PoolingTable(
              comparison: comparison,
              resourceLabel: vm.resourceLabel,
            ),
          ],
        ),
        NsrtNoteBar(viewModel: vm),
      ],
    );
  }
}
