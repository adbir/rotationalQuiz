import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/local_store.dart';
import '../services/spell_icon_service.dart';

/// Spell id → icon image URL, looked up once and remembered on the device.
class SpellIconRepository extends ChangeNotifier {
  SpellIconRepository({required this._service, required this._store}) {
    _load();
  }

  final SpellIconService _service;
  final LocalStore _store;

  static const _key = 'spell_icons';

  final Map<int, String> _names = {};

  /// Lookups in flight or failed this session; failures retry next launch.
  final Set<int> _requested = {};

  /// The icon URL for [spellId], or `null` while it is being looked up or
  /// if it can't be found. Listeners are notified when a lookup completes.
  Uri? iconUrl(int spellId) {
    final name = _names[spellId];
    if (name != null) return _service.imageUrl(name);
    if (_requested.add(spellId)) unawaited(_lookUp(spellId));
    return null;
  }

  Future<void> _lookUp(int spellId) async {
    try {
      final name = await _service.iconName(spellId);
      if (name == null) return;
      _names[spellId] = name;
      notifyListeners();
      await _store.setString(
        _key,
        jsonEncode({for (final e in _names.entries) '${e.key}': e.value}),
      );
    } on Exception {
      // Offline or blocked: the UI keeps its text fallback.
    }
  }

  void _load() {
    final raw = _store.getString(_key);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return;
      for (final entry in json.entries) {
        final id = int.tryParse('${entry.key}');
        final name = entry.value;
        if (id != null &&
            name is String &&
            SpellIconService.validName.hasMatch(name)) {
          _names[id] = name;
        }
      }
    } on FormatException {
      // Corrupt cache: look everything up again.
    }
  }
}
