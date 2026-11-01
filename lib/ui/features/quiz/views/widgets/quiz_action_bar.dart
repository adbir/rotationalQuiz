import 'package:flutter/material.dart';

import '../../../../../domain/models/spec_definition.dart';
import '../../../../core/widgets/spell_button.dart';
import '../../view_models/quiz_view_model.dart';
import 'quiz_formatting.dart';

/// The clickable action bar for action-bar and hot-key modes.
class QuizActionBar extends StatelessWidget {
  const QuizActionBar({super.key, required this.viewModel});

  final QuizViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final theme = Theme.of(context);
    final hotkeys = vm.mode == QuizMode.hotkeys;
    final showBinds = !hotkeys || vm.showKeybinds;

    Widget button(SpellDefinition spell, {double size = 56}) => SpellButton(
      spell: spell,
      size: size,
      mark: markSpell(vm, spell.id),
      keybindLabel: showBinds ? vm.keybindFor(spell.id)?.shortLabel : null,
      onPressed: vm.isAnswered ? null : () => vm.guessSpell(spell.id),
    );

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 12,
          children: [for (final spell in vm.actionBar) button(spell)],
        ),
        if (hotkeys && vm.offGcdBar.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Off the GCD', style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              for (final spell in vm.offGcdBar) button(spell, size: 44),
            ],
          ),
        ],
      ],
    );
  }
}
