import 'package:flutter/material.dart';

import '../../view_models/quiz_view_model.dart';
import 'quiz_formatting.dart';

/// Time limit and keybind display options for hot-key mode, and a
/// warning about unbound buttons.
class HotkeySettings extends StatelessWidget {
  const HotkeySettings({
    super.key,
    required this.viewModel,
    required this.onOpenSetup,
  });

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
                label: formatSeconds(vm.timeLimit),
                onChanged: (v) =>
                    vm.setTimeLimit(Duration(milliseconds: (v * 1000).round())),
              ),
            ),
            Text(formatSeconds(vm.timeLimit)),
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
