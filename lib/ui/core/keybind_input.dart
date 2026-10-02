import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../../domain/models/keybind.dart';

final _modifiers = {
  ...LogicalKeyboardKey.expandSynonyms({
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.meta,
  }),
  LogicalKeyboardKey.capsLock,
  LogicalKeyboardKey.fn,
};

/// Converts a key press into a [Keybind], or `null` for modifier-only
/// presses and key releases.
Keybind? keybindFromKeyEvent(KeyEvent event) {
  if (event is! KeyDownEvent) return null;
  if (_modifiers.contains(event.logicalKey)) return null;
  final keyboard = HardwareKeyboard.instance;
  return Keybind(
    code: event.physicalKey.usbHidUsage,
    keyLabel: _labelFor(event),
    ctrl: keyboard.isControlPressed || keyboard.isMetaPressed,
    alt: keyboard.isAltPressed,
    shift: keyboard.isShiftPressed,
  );
}

/// Converts a mouse button press (middle, back, forward) into a [Keybind].
/// Left and right clicks are left alone so the UI stays usable.
Keybind? keybindFromPointer(PointerDownEvent event) {
  if (event.kind != PointerDeviceKind.mouse) return null;
  final button = switch (event.buttons) {
    kMiddleMouseButton => 3,
    kBackMouseButton => 4,
    kForwardMouseButton => 5,
    _ => null,
  };
  if (button == null) return null;
  final keyboard = HardwareKeyboard.instance;
  return Keybind(
    code: Keybind.mouseCode(button),
    keyLabel: 'Mouse $button',
    ctrl: keyboard.isControlPressed || keyboard.isMetaPressed,
    alt: keyboard.isAltPressed,
    shift: keyboard.isShiftPressed,
  );
}

/// The unshifted label for a physical key, so that Shift+1 reads "Shift+1"
/// rather than "Shift+!".
String _labelFor(KeyEvent event) {
  final usage = event.physicalKey.usbHidUsage;
  // USB HID keyboard page: A..Z = 0x04..0x1d, 1..9,0 = 0x1e..0x27.
  const page = 0x00070000;
  if (usage >= page + 0x04 && usage <= page + 0x1d) {
    return String.fromCharCode(0x41 + usage - page - 0x04);
  }
  if (usage >= page + 0x1e && usage <= page + 0x27) {
    return '${(usage - page - 0x1e + 1) % 10}';
  }
  final label = event.logicalKey.keyLabel;
  if (label.trim().isNotEmpty) {
    return label.length == 1 ? label.toUpperCase() : label;
  }
  return event.physicalKey.debugName ?? 'Key ${usage.toRadixString(16)}';
}
