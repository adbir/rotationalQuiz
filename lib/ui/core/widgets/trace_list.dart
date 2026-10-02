import 'package:flutter/material.dart';

import '../../../domain/apl/apl_evaluator.dart';
import '../../../domain/specs/rotation_spec.dart';
import '../theme.dart';
import 'condition_view.dart';

/// Lists every APL line the evaluator looked at, explaining why each one was
/// or wasn't chosen.
class TraceList extends StatelessWidget {
  const TraceList({
    super.key,
    required this.spec,
    required this.trace,
    this.showSkipped = false,
  });

  final RotationSpec spec;
  final List<AplTraceEntry> trace;

  /// Whether to include lines that were never really candidates (unmodelled
  /// actions and `moving=1` lines while standing still).
  final bool showSkipped;

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final entry in trace)
        if (showSkipped ||
            (entry.outcome != TraceOutcome.notModelled &&
                entry.outcome != TraceOutcome.notMoving))
          entry,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries) TraceTile(spec: spec, entry: entry),
      ],
    );
  }
}

class TraceTile extends StatelessWidget {
  const TraceTile({super.key, required this.spec, required this.entry});

  final RotationSpec spec;
  final AplTraceEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = entry.action;
    final color = AppTheme.outcomeColor(entry.outcome, theme.colorScheme);
    final spell = spec.spells[action.name];
    final isWinner =
        entry.outcome == TraceOutcome.selected ||
        entry.outcome == TraceOutcome.offGcd;

    final (IconData icon, String label) = switch (entry.outcome) {
      TraceOutcome.selected => (Icons.play_circle, 'Selected'),
      TraceOutcome.offGcd => (Icons.add_circle, 'Off-GCD'),
      TraceOutcome.jumped => (Icons.subdirectory_arrow_right, 'Jump'),
      TraceOutcome.conditionFalse => (Icons.cancel_outlined, 'Condition false'),
      TraceOutcome.unavailable => (Icons.hourglass_bottom, 'Not available'),
      TraceOutcome.notMoving => (Icons.directions_walk, 'Skipped'),
      TraceOutcome.notModelled => (Icons.remove_circle_outline, 'Skipped'),
      TraceOutcome.error => (Icons.error_outline, 'Error'),
    };

    return Container(
      decoration: BoxDecoration(
        color: isWinner ? color.withValues(alpha: 0.08) : null,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: spell?.name ?? action.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: '  ${action.listName} #${action.index + 1}',
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                entry.reason == null ? label : '$label · ${entry.reason}',
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
          if (action.comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                action.comments.join(' '),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (action.condition != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ConditionView(
                expression: action.condition!,
                values: entry.nodeValues,
              ),
            ),
        ],
      ),
    );
  }
}
