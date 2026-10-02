import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/models/keybind.dart';
import '../../domain/specs/rotation_spec.dart';
import '../services/local_store.dart';

/// The user's keybinds for one spec, saved on the device.
class KeybindRepository extends ChangeNotifier {
  KeybindRepository({required this.spec, required this._store}) {
    _load();
  }

  final RotationSpec spec;
  final LocalStore _store;

  String get _key => 'keybinds.${spec.id}';

  Map<String, Keybind> _binds = {};

  /// Binds by spell id.
  Map<String, Keybind> get binds => Map.unmodifiable(_binds);

  Keybind? bindFor(String spellId) => _binds[spellId];

  /// The spell bound to [keybind], if any.
  String? spellFor(Keybind keybind) {
    for (final entry in _binds.entries) {
      if (entry.value == keybind) return entry.key;
    }
    return null;
  }

  /// Binds [spellId] to [keybind]. A key can only do one thing, so any other
  /// spell on the same key is unbound; its id is returned.
  Future<String?> bind(String spellId, Keybind keybind) async {
    final displaced = spellFor(keybind);
    if (displaced != null && displaced != spellId) _binds.remove(displaced);
    _binds[spellId] = keybind;
    await _save();
    return displaced == spellId ? null : displaced;
  }

  Future<void> unbind(String spellId) async {
    if (_binds.remove(spellId) != null) await _save();
  }

  Future<void> clear() async {
    _binds = {};
    await _save();
  }

  void _load() {
    final raw = _store.getString(_key);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return;
      _binds = {
        for (final entry in json.entries)
          entry.key as String: ?Keybind.fromJson(entry.value),
      };
    } on FormatException {
      _binds = {};
    }
  }

  Future<void> _save() async {
    notifyListeners();
    await _store.setString(
      _key,
      jsonEncode({for (final e in _binds.entries) e.key: e.value.toJson()}),
    );
  }
}
