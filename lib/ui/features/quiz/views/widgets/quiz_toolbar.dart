import 'package:flutter/material.dart';

import '../../../../../domain/models/spec_definition.dart';
import '../../view_models/quiz_view_model.dart';
import 'quiz_formatting.dart';

/// Mode, build and set bonus pickers plus the running score.
class QuizToolbar extends StatelessWidget {
  const QuizToolbar({super.key, required this.viewModel});

  final QuizViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = viewModel;
    final average = vm.averageReactionTime;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<QuizMode>(
          segments: [
            for (final mode in QuizMode.values)
              ButtonSegment(value: mode, label: Text(mode.label)),
          ],
          selected: {vm.mode},
          onSelectionChanged: (s) => vm.setMode(s.first),
        ),
        DropdownButton<TalentLoadout>(
          value: vm.loadout,
          underline: const SizedBox.shrink(),
          items: [
            for (final loadout in vm.loadouts)
              DropdownMenuItem(value: loadout, child: Text(loadout.name)),
          ],
          onChanged: (loadout) {
            if (loadout != null) vm.selectLoadout(loadout);
          },
        ),
        for (final bonus in vm.spec.setBonuses)
          FilterChip(
            label: Text(bonus.name),
            selected: vm.setBonuses.contains(bonus.id),
            onSelected: (v) => vm.setSetBonus(bonus.id, v),
          ),
        Text(
          [
            'Score ${vm.correct}/${vm.answered}',
            'Streak ${vm.streak} (best ${vm.bestStreak})',
            if (vm.mode == QuizMode.hotkeys && average != null)
              'Avg ${formatSeconds(average)}',
          ].join('  ·  '),
          style: theme.textTheme.titleSmall,
        ),
        IconButton(
          tooltip: 'Reset score',
          onPressed: vm.resetScore,
          icon: const Icon(Icons.restart_alt),
        ),
      ],
    );
  }
}
