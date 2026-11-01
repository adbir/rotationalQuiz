import 'package:flutter/material.dart';

import '../../../../../domain/models/boss_comparison.dart';
import 'comparison_grid.dart';

/// Each of the player's gaps: when, how long, and what the log shows then.
// ponytail: the column names are the Elemental Shaman's; a second spec would
// take them from its log rules.
class GapTable extends StatelessWidget {
  const GapTable({
    super.key,
    required this.comparison,
    this.showMovement = true,
  });

  final BossComparison comparison;

  /// Whether the Ghost Wolf and Grace columns mean anything for the spec.
  final bool showMovement;

  @override
  Widget build(BuildContext context) {
    final details = comparison.logs.first.metrics.gaps.details;
    final shared = comparison.gapsAlsoInRank1;
    String yes(bool v) => v ? 'yes' : '–';
    return ComparisonGrid(
      title: 'Your gaps',
      caption: showMovement
          ? "Seconds from the pull. Ghost Wolf cast or up, Spiritwalker's "
                'Grace up, a Grace charge off cooldown by your own casts, and '
                "a gap of rank 1's within 3 s of the start."
          : 'Seconds from the pull, and whether rank 1 has a gap within 3 s'
                'of the start.',
      columns: [
        'Length',
        if (showMovement) ...['Ghost Wolf', 'Grace up', 'Grace ready'],
        'Rank 1',
      ],
      labelWidth: 72,
      rows: [
        for (final (i, g) in details.indexed)
          GridRow('${g.start.inSeconds} s', [
            GridCell(
              '${(g.length.inMilliseconds / 1000).toStringAsFixed(1)} s',
            ),
            if (showMovement) ...[
              GridCell(yes(g.inMovementForm)),
              GridCell(yes(g.graceUp)),
              GridCell(yes(g.graceReady)),
            ],
            GridCell(yes(i < shared.length && shared[i])),
          ]),
      ],
    );
  }
}
