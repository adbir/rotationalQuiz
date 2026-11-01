import 'package:flutter/material.dart';

import '../../../../core/theme.dart';

/// One finding in four parts, always in this order: what happened with both
/// numbers, where, what to try, and the evidence folded away.
class FindingCard extends StatelessWidget {
  const FindingCard({
    super.key,
    required this.number,
    required this.headline,
    required this.where,
    required this.whatToTry,
    required this.evidence,
  });

  final int number;
  final String headline;
  final String where;
  final String whatToTry;
  final Widget evidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final label = text?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.bold,
    );
    Widget part(String name, String body) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$name  ', style: label),
            TextSpan(text: body),
          ],
        ),
        style: text,
      ),
    );

    return Card(
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppTheme.gapColor, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$number  $headline', style: text?.copyWith(fontSize: 16)),
            part('Where:', where),
            part('Try:', whatToTry),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                dense: true,
                title: const Text('Show the numbers'),
                children: [evidence],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
