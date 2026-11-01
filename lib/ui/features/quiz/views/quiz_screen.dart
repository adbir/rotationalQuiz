import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/combat_state.dart';
import '../../../core/keybind_input.dart';
import '../../../core/widgets/recommendation_card.dart';
import '../../../core/widgets/state_summary.dart';
import '../view_models/quiz_view_model.dart';
import 'widgets/countdown_bar.dart';
import 'widgets/hotkey_settings.dart';
import 'widgets/multiple_choice_options.dart';
import 'widgets/quiz_action_bar.dart';
import 'widgets/quiz_toolbar.dart';
import 'widgets/quiz_verdict.dart';

/// Random scenarios: pick the button you would press, then compare with the
/// APL.
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.viewModel,
    required this.onOpenInSandbox,
    required this.onOpenSetup,
    this.isActive = true,
  });

  final QuizViewModel viewModel;
  final ValueChanged<CombatState> onOpenInSandbox;
  final VoidCallback onOpenSetup;

  /// Whether the quiz tab is visible; it grabs keyboard focus when it is.
  final bool isActive;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _focusNode = FocusNode(debugLabel: 'quiz');

  QuizViewModel get vm => widget.viewModel;

  @override
  void didUpdateWidget(QuizScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (vm.isAnswered) {
      final autoAdvancing = vm.mode == QuizMode.hotkeys && vm.isCorrect;
      if (!autoAdvancing &&
          (key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter)) {
        vm.nextQuestion();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (vm.mode == QuizMode.multipleChoice) {
      const digits = [
        PhysicalKeyboardKey.digit1,
        PhysicalKeyboardKey.digit2,
        PhysicalKeyboardKey.digit3,
        PhysicalKeyboardKey.digit4,
      ];
      final index = digits.indexOf(event.physicalKey);
      if (index >= 0 && index < vm.options.length) {
        vm.guessOption(vm.options[index]);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final keybind = keybindFromKeyEvent(event);
    if (keybind != null && vm.pressKeybind(keybind)) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (vm.mode == QuizMode.multipleChoice || vm.isAnswered) return;
    final keybind = keybindFromPointer(event);
    if (keybind != null) vm.pressKeybind(keybind);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.isActive,
      onKeyEvent: _onKey,
      child: Listener(
        onPointerDown: _onPointerDown,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _focusNode.requestFocus,
          child: ListenableBuilder(
            listenable: vm,
            builder: (context, _) => _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final state = vm.state;
    if (state == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    final answer = vm.answer;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            QuizToolbar(viewModel: vm),
            if (vm.mode == QuizMode.hotkeys) ...[
              const SizedBox(height: 8),
              HotkeySettings(viewModel: vm, onOpenSetup: widget.onOpenSetup),
            ],
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
                    if (vm.mode == QuizMode.hotkeys) ...[
                      const SizedBox(height: 8),
                      CountdownBar(
                        key: ValueKey(vm.questionNumber),
                        duration: vm.timeLimit,
                        running: !vm.isAnswered,
                      ),
                    ],
                    const SizedBox(height: 12),
                    StateSummary(spec: vm.spec, state: state),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            switch (vm.mode) {
              QuizMode.multipleChoice => MultipleChoiceOptions(viewModel: vm),
              QuizMode.actionBar ||
              QuizMode.hotkeys => QuizActionBar(viewModel: vm),
            },
            const SizedBox(height: 16),
            if (vm.isAnswered && answer != null) ...[
              QuizVerdict(viewModel: vm),
              const SizedBox(height: 12),
              RecommendationCard(
                spec: vm.spec,
                recommendation: answer,
                title: 'The APL says',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Space / Enter: next', style: theme.textTheme.bodySmall),
                  OutlinedButton.icon(
                    onPressed: () => widget.onOpenInSandbox(state),
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Explore in sandbox'),
                  ),
                  FilledButton.icon(
                    onPressed: vm.nextQuestion,
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
  }
}
