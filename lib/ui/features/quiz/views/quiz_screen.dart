import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/combat_state.dart';
import '../../../../domain/models/spec_definition.dart';
import '../../../core/keybind_input.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/recommendation_card.dart';
import '../../../core/widgets/spell_button.dart';
import '../../../core/widgets/state_summary.dart';
import '../view_models/quiz_view_model.dart';

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
        vm.guessSpell(vm.options[index].id);
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
            _QuizToolbar(viewModel: vm),
            if (vm.mode == QuizMode.hotkeys) ...[
              const SizedBox(height: 8),
              _HotkeySettings(viewModel: vm, onOpenSetup: widget.onOpenSetup),
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
                      _Countdown(
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
              QuizMode.multipleChoice => _MultipleChoice(viewModel: vm),
              QuizMode.actionBar ||
              QuizMode.hotkeys => _ActionBar(viewModel: vm),
            },
            const SizedBox(height: 16),
            if (vm.isAnswered && answer != null) ...[
              _Verdict(viewModel: vm),
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

class _QuizToolbar extends StatelessWidget {
  const _QuizToolbar({required this.viewModel});

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
              'Avg ${_seconds(average)}',
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

class _HotkeySettings extends StatelessWidget {
  const _HotkeySettings({required this.viewModel, required this.onOpenSetup});

  final QuizViewModel viewModel;
  final VoidCallback onOpenSetup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = viewModel;
    final unbound = vm.unboundSpells;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Time limit', style: theme.textTheme.bodyMedium),
            SizedBox(
              width: 220,
              child: Slider(
                value: vm.timeLimit.inMilliseconds / 1000,
                min: 1,
                max: 6,
                divisions: 10,
                label: _seconds(vm.timeLimit),
                onChanged: (v) =>
                    vm.setTimeLimit(Duration(milliseconds: (v * 1000).round())),
              ),
            ),
            Text(_seconds(vm.timeLimit)),
            const SizedBox(width: 12),
            Text('Show keybinds', style: theme.textTheme.bodyMedium),
            Switch(value: vm.showKeybinds, onChanged: vm.setShowKeybinds),
          ],
        ),
        if (unbound.isNotEmpty)
          Card(
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(
                Icons.keyboard_outlined,
                color: theme.colorScheme.onErrorContainer,
              ),
              title: Text(
                '${unbound.length} buttons have no keybind: '
                '${unbound.map((s) => s.name).join(', ')}',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
              trailing: FilledButton(
                onPressed: onOpenSetup,
                child: const Text('Set keybinds'),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.viewModel});

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
      mark: _markFor(vm, spell.id),
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

class _MultipleChoice extends StatelessWidget {
  const _MultipleChoice({required this.viewModel});

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
            for (final (i, spell) in vm.options.indexed)
              SizedBox(
                width: width,
                child: _OptionTile(
                  index: i,
                  spell: spell,
                  mark: _markFor(vm, spell.id),
                  onPressed: vm.isAnswered
                      ? null
                      : () => vm.guessSpell(spell.id),
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
    required this.spell,
    required this.mark,
    required this.onPressed,
    required this.textTheme,
  });

  final int index;
  final SpellDefinition spell;
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
              SpellButton(spell: spell, size: 44, showName: false),
              const SizedBox(width: 12),
              Expanded(child: Text(spell.name, style: textTheme.titleMedium)),
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

class _Verdict extends StatelessWidget {
  const _Verdict({required this.viewModel});

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
            : 'Correct! ${_seconds(vm.reactionTime!)}',
      ),
      QuizOutcome.timedOut => (
        Icons.timer_off_outlined,
        theme.colorScheme.error,
        'Too slow!',
      ),
      _ => (Icons.cancel, theme.colorScheme.error, 'Not quite.'),
    };
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(text, style: theme.textTheme.titleLarge?.copyWith(color: color)),
      ],
    );
  }
}

/// A bar that drains over [duration] while [running].
class _Countdown extends StatefulWidget {
  const _Countdown({super.key, required this.duration, required this.running});

  final Duration duration;
  final bool running;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.running) _controller.forward();
  }

  @override
  void didUpdateWidget(_Countdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.running) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final left = 1 - _controller.value;
        final color = Color.lerp(AppTheme.failColor, AppTheme.passColor, left);
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: left,
            minHeight: 8,
            color: color,
          ),
        );
      },
    );
  }
}

SpellButtonMark _markFor(QuizViewModel vm, String id) {
  if (vm.mode == QuizMode.hotkeys && vm.offGcdPressed.contains(id)) {
    return SpellButtonMark.correct;
  }
  if (!vm.isAnswered) return SpellButtonMark.none;
  if (id == vm.answer?.selectedSpellId) return SpellButtonMark.correct;
  if (id == vm.guess) return SpellButtonMark.wrong;
  return SpellButtonMark.none;
}

String _seconds(Duration d) =>
    '${(d.inMilliseconds / 1000).toStringAsFixed(2)}s';
