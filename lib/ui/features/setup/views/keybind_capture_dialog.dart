import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/keybind.dart';
import '../../../../domain/models/spec_definition.dart';
import '../../../core/keybind_input.dart';
import '../../../core/widgets/spell_button.dart';

/// Waits for the user to press a key (with modifiers) or a mouse button.
/// Escape cancels.
Future<Keybind?> showKeybindCaptureDialog(
  BuildContext context,
  SpellDefinition spell,
) {
  return showDialog<Keybind>(
    context: context,
    builder: (context) => _KeybindCaptureDialog(spell: spell),
  );
}

class _KeybindCaptureDialog extends StatelessWidget {
  const _KeybindCaptureDialog({required this.spell});

  final SpellDefinition spell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
          return KeyEventResult.handled;
        }
        final keybind = keybindFromKeyEvent(event);
        if (keybind == null) return KeyEventResult.ignored;
        Navigator.pop(context, keybind);
        return KeyEventResult.handled;
      },
      child: Listener(
        onPointerDown: (event) {
          final keybind = keybindFromPointer(event);
          if (keybind != null) Navigator.pop(context, keybind);
        },
        child: AlertDialog(
          title: Text('Bind ${spell.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpellButton(spell: spell, showName: false),
              const SizedBox(height: 16),
              Text(
                'Press the key you use in game, with Shift / Ctrl / Alt if '
                'needed.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Middle and side mouse buttons work too. Esc cancels.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
