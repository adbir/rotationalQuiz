import 'package:flutter/material.dart';

import '../../../../../domain/models/spec_definition.dart';
import '../../../../core/widgets/spell_button.dart';
import '../../view_models/setup_view_model.dart';
import '../keybind_capture_dialog.dart';

/// Lists the active build's abilities with their keybinds.
class KeybindSection extends StatelessWidget {
  const KeybindSection({super.key, required this.viewModel});

  final SetupViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = viewModel;
    final spells = vm.bindableSpells;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Keybinds', style: theme.textTheme.titleLarge),
            ),
            Text(
              '${vm.boundCount}/${spells.length} bound',
              style: theme.textTheme.bodySmall,
            ),
            TextButton(
              onPressed: vm.boundCount == 0 ? null : vm.clearKeybinds,
              child: const Text('Clear all'),
            ),
          ],
        ),
        Text(
          'Use the same keys as in game; the Hot keys quiz uses them. Saved '
          'on this device.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              for (final spell in spells)
                _KeybindRow(
                  spell: spell,
                  label: vm.bindFor(spell.id)?.label,
                  onBind: () async {
                    final keybind = await showKeybindCaptureDialog(
                      context,
                      spell,
                    );
                    if (keybind != null) await vm.bind(spell, keybind);
                  },
                  onClear: () => vm.unbind(spell),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeybindRow extends StatelessWidget {
  const _KeybindRow({
    required this.spell,
    required this.label,
    required this.onBind,
    required this.onClear,
  });

  final SpellDefinition spell;
  final String? label;
  final VoidCallback onBind;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: SpellButton(spell: spell, size: 36, showName: false),
      title: Text(spell.name),
      subtitle: spell.offGcd ? const Text('Off the GCD') : null,
      onTap: onBind,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: onBind,
            child: Text(
              label ?? 'Set key',
              style: label == null
                  ? null
                  : theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
            ),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: label == null ? null : onClear,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
