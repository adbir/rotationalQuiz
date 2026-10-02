import 'package:flutter/material.dart';

import '../../../../domain/models/combat_state.dart';
import '../../../core/widgets/recommendation_card.dart';
import '../../../core/widgets/spell_button.dart';
import '../../../core/widgets/state_summary.dart';
import '../view_models/quiz_view_model.dart';

/// Random scenarios: pick the button you would press, then compare with the
/// APL.
class QuizScreen extends StatelessWidget {
  const QuizScreen({
    super.key,
    required this.viewModel,
    required this.onOpenInSandbox,
  });

  final QuizViewModel viewModel;
  final ValueChanged<CombatState> onOpenInSandbox;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final state = viewModel.state;
        if (state == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final theme = Theme.of(context);
        final answer = viewModel.answer;
        final correctId = answer?.selectedSpellId;

        SpellButtonMark markFor(String id) {
          if (!viewModel.hasGuessed) return SpellButtonMark.none;
          if (id == correctId) return SpellButtonMark.correct;
          if (id == viewModel.guess) return SpellButtonMark.wrong;
          return SpellButtonMark.none;
        }

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _QuizToolbar(viewModel: viewModel),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Single target. What do you press next?',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        StateSummary(spec: viewModel.spec, state: state),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 12,
                  children: [
                    for (final spell in viewModel.actionBar)
                      SpellButton(
                        spell: spell,
                        mark: markFor(spell.id),
                        onPressed: viewModel.hasGuessed
                            ? null
                            : () => viewModel.guessSpell(spell.id),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (viewModel.hasGuessed && answer != null) ...[
                  _Verdict(correct: viewModel.isCorrect),
                  const SizedBox(height: 12),
                  RecommendationCard(
                    spec: viewModel.spec,
                    recommendation: answer,
                    title: 'The APL says',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => onOpenInSandbox(state),
                        icon: const Icon(Icons.science_outlined),
                        label: const Text('Explore in sandbox'),
                      ),
                      FilledButton.icon(
                        onPressed: viewModel.nextQuestion,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next scenario'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuizToolbar extends StatelessWidget {
  const _QuizToolbar({required this.viewModel});

  final QuizViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = viewModel.spec;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton(
          segments: [
            for (final loadout in spec.loadouts)
              ButtonSegment(
                value: loadout,
                label: Text(loadout.name),
                tooltip: loadout.description,
              ),
          ],
          selected: {viewModel.loadout},
          onSelectionChanged: (s) => viewModel.selectLoadout(s.first),
        ),
        for (final bonus in spec.setBonuses)
          FilterChip(
            label: Text(bonus.name),
            selected: viewModel.setBonuses.contains(bonus.id),
            onSelected: (v) => viewModel.setSetBonus(bonus.id, v),
          ),
        Text(
          'Score ${viewModel.correct}/${viewModel.answered}'
          '  ·  Streak ${viewModel.streak}',
          style: theme.textTheme.titleSmall,
        ),
        IconButton(
          tooltip: 'Reset score',
          onPressed: viewModel.resetScore,
          icon: const Icon(Icons.restart_alt),
        ),
      ],
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.correct});

  final bool correct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = correct ? const Color(0xFF2E9E5B) : theme.colorScheme.error;
    return Row(
      children: [
        Icon(correct ? Icons.check_circle : Icons.cancel, color: color),
        const SizedBox(width: 8),
        Text(
          correct ? 'Correct!' : 'Not quite.',
          style: theme.textTheme.titleLarge?.copyWith(color: color),
        ),
      ],
    );
  }
}
