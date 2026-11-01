import 'package:flutter/material.dart';

import '../../../../../domain/models/boss_comparison.dart';
import '../../../../../domain/models/player_metrics.dart';
import 'comparison_grid.dart';

/// The `PlayerMetrics` rows side by side, one column per log.
class MetricsTable extends StatelessWidget {
  const MetricsTable({
    super.key,
    required this.comparison,
    required this.resourceLabel,
  });

  final BossComparison comparison;
  final String resourceLabel;

  @override
  Widget build(BuildContext context) {
    final all = [for (final log in comparison.logs) log.metrics];
    final first = all.first;
    final threshold = first.gaps.threshold.inMilliseconds / 1000;

    GridRow row(String label, String Function(PlayerMetrics m) cell) =>
        GridRow(label, [for (final m in all) GridCell(cell(m))]);

    final buff = first.spenders.buffName;
    final raidEffects = {
      for (final m in all)
        for (final c in m.cooldowns)
          if (c.raidDependsOn.isNotEmpty) c.name: c.raidDependsOn,
    };

    return ComparisonGrid(
      title: 'Metrics',
      caption: raidEffects.isEmpty
          ? null
          : 'Raid effects change: ${[for (final e in raidEffects.entries) '${e.key} (${e.value.join(', ')})'].join('; ')}.',
      columns: [for (final log in comparison.logs) log.label],
      labelWidth: 112,
      cellWidth: 78,
      rows: [
        row('Casts per minute', (m) => m.casts.perMinute.toStringAsFixed(1)),
        row(
          'Gaps over ${threshold.toStringAsFixed(1)} s',
          (m) => '${m.gaps.count}',
        ),
        row(
          '$resourceLabel per minute',
          (m) => m.resource.gainedPerMinute.round().toString(),
        ),
        row('$resourceLabel wasted', (m) => '${m.resource.wasted}'),
        if (buff != null)
          row(
            'Spenders with $buff',
            (m) => _of(m.spenders.withBuff, m.spenders.casts),
          ),
        row('Free spenders', (m) => _of(m.spenders.free, m.spenders.casts)),
        row(
          'Free spenders lost by refreshing',
          (m) => '${m.spenders.lostFree}',
        ),
        for (final proc in first.chanceProcs)
          row('${proc.name}, actual / expected', (m) {
            final match = m.chanceProcs.where((p) => p.name == proc.name);
            return match.isEmpty
                ? '–'
                : '${match.first.actual} / '
                      '${match.first.expected.toStringAsFixed(1)}';
          }),
        for (final cooldown in first.cooldowns)
          row('${cooldown.name}, uses · median delay', (m) {
            final match = m.cooldowns.where((c) => c.id == cooldown.id);
            if (match.isEmpty) return '–';
            final delay = match.first.medianDrift;
            return delay == null
                ? '${match.first.uses}'
                : '${match.first.uses} · ${delay.toStringAsFixed(2)} s';
          }),
        for (final free in first.raidFreeCasts)
          row('${free.name} spent / available', (m) {
            final match = m.raidFreeCasts.where((r) => r.name == free.name);
            return match.isEmpty
                ? '–'
                : '${match.first.spent} / ${match.first.available}';
          }),
      ],
    );
  }

  static String _of(int? part, int total) =>
      part == null ? '–' : '$part of $total';
}
