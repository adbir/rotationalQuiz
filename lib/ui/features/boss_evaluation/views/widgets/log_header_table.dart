import 'package:flutter/material.dart';

import '../../../../../domain/models/boss_comparison.dart';
import 'comparison_grid.dart';

/// Who is compared: fought length with kill or wipe, then DPS and item level
/// where the rankings give them (blank otherwise).
class LogHeaderTable extends StatelessWidget {
  const LogHeaderTable({
    super.key,
    required this.comparison,
    required this.bossName,
  });

  final BossComparison comparison;
  final String bossName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _grid(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Raid support', style: theme.textTheme.titleSmall),
                for (final log in comparison.logs)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${log.label}: ${raidSupportText(log)}'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// "Power Infusion 13.5% (4), Ebon Might 90% (43)", or "none seen". The
  /// percent is of the whole fight.
  static String raidSupportText(ComparedLog log) => log.raidSupport.isEmpty
      ? 'none seen'
      : log.raidSupport
            .map(
              (r) =>
                  '${r.name} ${r.uptimePercent.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}% (${r.uses})',
            )
            .join(', ');

  Widget _grid() {
    return ComparisonGrid(
      title: bossName,
      caption:
          'Everything below compares the first '
          '${comparison.fought.inSeconds} s, which all logs fought.',
      columns: const ['Fought', 'DPS', 'Item level'],
      labelWidth: 70,
      cellWidth: 94,
      rows: [
        for (final log in comparison.logs)
          GridRow(log.label, [
            GridCell('${log.fought.inSeconds} s ${log.kill ? 'kill' : 'wipe'}'),
            GridCell(log.dps == null ? '' : _thousands(log.dps!.round())),
            GridCell(log.itemLevel?.toString() ?? ''),
          ]),
      ],
    );
  }

  static String _thousands(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
}
