import 'package:flutter/material.dart';

import '../../../../../domain/models/boss_comparison.dart';
import '../../view_models/evidence_details.dart';
import 'comparison_grid.dart';

/// A cooldown's casts against the most the fight allowed, for every log, then
/// each of your casts with how long after the cooldown was back you made it.
class PossibleCastsTable extends StatelessWidget {
  const PossibleCastsTable({
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
    final casts = details?.cooldownCasts(name) ?? const <CooldownCast>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComparisonGrid(
          title: '$name casts of possible',
          columns: const ['Cast', 'Possible'],
          labelWidth: 100,
          rows: [
            for (final log in comparison.logs)
              GridRow(log.label, [
                for (final m in log.metrics.cooldowns.where(
                  (c) => c.name == name,
                )) ...[GridCell('${m.uses}'), GridCell('${m.possible ?? '–'}')],
              ]),
          ],
        ),
        if (casts.isNotEmpty)
          ComparisonGrid(
            title: 'Your $name casts',
            caption:
                'Seconds from the pull. "After ready" is the time past the '
                'cooldown since your last cast; a cooldown with charges has '
                'none.',
            columns: const ['After ready'],
            labelWidth: 72,
            rows: [
              for (final c in casts)
                GridRow('${_s(c.time)} s', [
                  GridCell(c.late == null ? '–' : '${_s(c.late!)} s'),
                ]),
            ],
          ),
      ],
    );
  }

  static String _s(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(1);
}
