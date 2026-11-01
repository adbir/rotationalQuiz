import 'package:flutter/material.dart';

import '../../../../../domain/models/boss_comparison.dart';
import '../../view_models/evidence_details.dart';
import 'comparison_grid.dart';

/// An aura's uptime for every log, then the stretches yours was down.
class UpkeepTable extends StatelessWidget {
  const UpkeepTable({
    super.key,
    required this.name,
    required this.comparison,
    required this.details,
  });

  final String name;
  final BossComparison comparison;
  final EvidenceDetails? details;

  @override
  Widget build(BuildContext context) {
    final down = details?.downStretches(name) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComparisonGrid(
          title: '$name uptime',
          columns: const ['Up', 'Down'],
          labelWidth: 100,
          rows: [
            for (final log in comparison.logs)
              GridRow(log.label, [
                for (final u in log.metrics.upkeep.where(
                  (u) => u.name == name,
                )) ...[
                  GridCell('${u.percent.toStringAsFixed(1)}%'),
                  GridCell('${_s(log.metrics.fightLength - u.uptime)} s'),
                ],
              ]),
          ],
        ),
        if (down.isNotEmpty)
          ComparisonGrid(
            title: 'When yours was down',
            caption: 'Seconds from the pull.',
            columns: const ['Length'],
            labelWidth: 100,
            rows: [
              for (final w in down)
                GridRow('${_s(w.start)}-${_s(w.end)} s', [
                  GridCell('${_s(w.end - w.start)} s'),
                ]),
            ],
          ),
      ],
    );
  }

  static String _s(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(1);
}
