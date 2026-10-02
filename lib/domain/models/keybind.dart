import 'package:flutter/foundation.dart';

/// A key (or mouse button) plus modifiers that the user pressed for an
/// ability, the way WoW action bars bind them.
@immutable
class Keybind {
  const Keybind({
    required this.code,
    required this.keyLabel,
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
  });

  /// Physical key USB HID usage, or a negative [mouseCode] for mouse
  /// buttons. Physical keys keep binds layout-independent, like WoW.
  final int code;

  /// What is printed on the key, e.g. `1`, `Q`, `F2`, `Mouse 4`.
  final String keyLabel;
  final bool ctrl;
  final bool alt;
  final bool shift;

  /// Code for mouse [button] (`4` for back, `5` for forward, `3` middle).
  static int mouseCode(int button) => -button;

  bool get isMouse => code < 0;

  /// Full label, e.g. `Shift+1`.
  String get label => [
    if (ctrl) 'Ctrl',
    if (alt) 'Alt',
    if (shift) 'Shift',
    keyLabel,
  ].join('+');

  /// WoW action bar style label, e.g. `S1`, `CQ`, `M4`.
  String get shortLabel {
    final key = isMouse ? 'M${-code}' : keyLabel;
    return '${ctrl ? 'C' : ''}${alt ? 'A' : ''}${shift ? 'S' : ''}$key';
  }

  Map<String, Object> toJson() => {
    'code': code,
    'label': keyLabel,
    if (ctrl) 'ctrl': true,
    if (alt) 'alt': true,
    if (shift) 'shift': true,
  };

  static Keybind? fromJson(Object? json) {
    if (json is! Map) return null;
    final code = json['code'];
    final label = json['label'];
    if (code is! int || label is! String) return null;
    return Keybind(
      code: code,
      keyLabel: label,
      ctrl: json['ctrl'] == true,
      alt: json['alt'] == true,
      shift: json['shift'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Keybind &&
      other.code == code &&
      other.ctrl == ctrl &&
      other.alt == alt &&
      other.shift == shift;

  @override
  int get hashCode => Object.hash(code, ctrl, alt, shift);

  @override
  String toString() => label;
}
