import 'package:flutter/material.dart';

import '../../../../../domain/use_cases/pick_answer_options.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/spell_button.dart';
import '../../view_models/quiz_view_model.dart';
import 'quiz_formatting.dart';

/// The four answer options in multiple-choice mode.
class MultipleChoiceOptions extends StatelessWidget {
  const MultipleChoiceOptions({super.key, required this.viewModel});

  final QuizViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (i, option) in vm.options.indexed)
              SizedBox(
                width: width,
                child: _OptionTile(
                  index: i,
                  option: option,
                  mark: markOption(vm, option),
                  onPressed: vm.isAnswered
                      ? null
                      : () => vm.guessOption(option),
                  textTheme: theme.textTheme,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.index,
    required this.option,
    required this.mark,
    required this.onPressed,
    required this.textTheme,
  });

  final int index;
  final AnswerOption option;
  final SpellButtonMark mark;
  final VoidCallback? onPressed;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = switch (mark) {
      SpellButtonMark.correct => AppTheme.passColor,
      SpellButtonMark.wrong => AppTheme.failColor,
      _ => scheme.outlineVariant,
    };
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: border,
          width: mark == SpellButtonMark.none ? 1 : 3,
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                child: Text('${index + 1}', style: textTheme.labelLarge),
              ),
              const SizedBox(width: 12),
              for (final (i, spell) in option.spells.indexed) ...[
                if (i > 0)
                  Icon(Icons.arrow_forward, size: 16, color: scheme.outline),
                SpellButton(
                  spell: spell,
                  size: option.spells.length > 1 ? 36 : 44,
                  showName: false,
                ),
              ],
              const SizedBox(width: 12),
              Expanded(child: Text(option.name, style: textTheme.titleMedium)),
              if (mark == SpellButtonMark.correct)
                const Icon(Icons.check_circle, color: AppTheme.passColor),
              if (mark == SpellButtonMark.wrong)
                const Icon(Icons.cancel, color: AppTheme.failColor),
            ],
          ),
        ),
      ),
    );
  }
}
