import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../view_models/quiz_view_model.dart';
import 'quiz_formatting.dart';

/// "Correct!", "Not quite." or "Too slow!" after an answer.
class QuizVerdict extends StatelessWidget {
  const QuizVerdict({super.key, required this.viewModel});

  final QuizViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = viewModel;
    final (IconData icon, Color color, String text) = switch (vm.outcome) {
      QuizOutcome.correct => (
        Icons.check_circle,
        AppTheme.passColor,
        vm.reactionTime == null
            ? 'Correct!'
            : 'Correct! ${formatSeconds(vm.reactionTime!)}',
      ),
      QuizOutcome.timedOut => (
        Icons.timer_off_outlined,
        theme.colorScheme.error,
        'Too slow!',
      ),
      _ => (Icons.cancel, theme.colorScheme.error, 'Not quite.'),
    };
    final skipped = [
      for (final id in vm.skippedOffGcd) vm.spec.spells[id]?.name ?? id,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              text,
              style: theme.textTheme.titleLarge?.copyWith(color: color),
            ),
          ],
        ),
        if (skipped.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 32),
            child: Text(
              'Press ${skipped.join(' and ')} first: it is off the GCD.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}
