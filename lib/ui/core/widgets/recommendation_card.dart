import 'package:flutter/material.dart';

import '../../../domain/apl/apl_evaluator.dart';
import '../../../domain/specs/rotation_spec.dart';
import 'condition_view.dart';
import 'spell_button.dart';

/// Shows the next GCD button, any off-GCD buttons to weave in, and the APL
/// line that made the decision.
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.spec,
    required this.recommendation,
    this.title = 'Press next',
  });

  final RotationSpec spec;
  final AplRecommendation recommendation;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = recommendation.selected;
    final spell = selected == null ? null : spec.spells[selected.name];
    final entry = recommendation.trace
        .where((e) => e.outcome == TraceOutcome.selected)
        .firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Off-GCD abilities go first: e.g. Ancestral Swiftness makes
                // the following cast instant.
                for (final action in recommendation.offGcd)
                  if (spec.spells[action.name] case final offGcd?)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SpellButton(
                          spell: offGcd,
                          size: 48,
                          tooltip: '${offGcd.name} (off the GCD, press first)',
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          color: theme.colorScheme.outline,
                        ),
                      ],
                    ),
                if (spell != null)
                  SpellButton(
                    spell: spell,
                    size: 72,
                    mark: SpellButtonMark.recommended,
                  )
                else
                  Text('Nothing castable', style: theme.textTheme.titleLarge),
              ],
            ),
            if (selected != null) ...[
              const SizedBox(height: 16),
              Text(
                'Why: actions.${selected.listName} line ${selected.index + 1}',
                style: theme.textTheme.labelLarge,
              ),
              for (final comment in selected.comments)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    comment,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              if (selected.condition != null && entry != null)
                ConditionView(
                  expression: selected.condition!,
                  values: entry.nodeValues,
                )
              else
                Text(
                  'Unconditional: always pressed when available.',
                  style: theme.textTheme.bodySmall,
                ),
            ],
            if (recommendation.unknownIdentifiers.isNotEmpty) ...[
              const SizedBox(height: 12),
              _UnknownWarning(recommendation.unknownIdentifiers),
            ],
          ],
        ),
      ),
    );
  }
}

class _UnknownWarning extends StatelessWidget {
  const _UnknownWarning(this.identifiers);

  final Set<String> identifiers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber, size: 18, color: theme.colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'The APL reads state the sandbox does not model yet '
            '(treated as 0): ${identifiers.join(', ')}',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
