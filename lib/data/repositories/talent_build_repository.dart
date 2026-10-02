import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/models/spec_definition.dart';
import '../../domain/specs/rotation_spec.dart';
import '../../domain/talents/talent_string_codec.dart';
import '../../utils/result.dart';
import '../services/local_store.dart';

/// Talent builds: the spec's reference builds plus the user's own, and which
/// one the user is playing.
class TalentBuildRepository extends ChangeNotifier {
  TalentBuildRepository({required this.spec, required this._store}) {
    _load();
  }

  final RotationSpec spec;
  final LocalStore _store;

  String get _buildsKey => 'talent_builds.${spec.id}';
  String get _activeKey => 'active_talent_build.${spec.id}';

  List<TalentLoadout> _custom = [];
  String? _activeId;

  /// Reference builds first, then the user's.
  List<TalentLoadout> get loadouts => [...spec.loadouts, ..._custom];

  List<TalentLoadout> get customLoadouts => List.unmodifiable(_custom);

  /// The build the user is playing; defaults to the first reference build.
  TalentLoadout get active =>
      loadouts.where((l) => l.id == _activeId).firstOrNull ??
      spec.loadouts.first;

  Future<void> setActive(TalentLoadout loadout) async {
    _activeId = loadout.id;
    notifyListeners();
    await _store.setString(_activeKey, loadout.id);
  }

  /// Decodes an in-game export string without saving it, for previews.
  Result<DecodedTalentBuild> decode(String exportString) {
    try {
      return Result.ok(
        TalentStringCodec(spec.talentTree)
            .decode(exportString, expectedSpecId: spec.specId),
      );
    } on TalentStringException catch (e) {
      return Result.error(e);
    }
  }

  /// Saves an in-game export string as a build and makes it active.
  Future<Result<TalentLoadout>> importBuild({
    required String name,
    required String exportString,
  }) async {
    final decoded = decode(exportString);
    switch (decoded) {
      case Error(:final error):
        return Result.error(error);
      case Ok(:final value):
        final hero = spec.heroTreeNames[value.heroTreeId];
        return Result.ok(
          await _add(
            TalentLoadout(
              id: _newId(),
              name: name.trim().isEmpty ? 'My build' : name.trim(),
              talents: value.tokens,
              exportString: exportString.trim(),
              description: hero == null ? 'Imported' : 'Imported · $hero',
              isCustom: true,
            ),
          ),
        );
    }
  }

  /// Saves a hand-edited set of talents (e.g. from the sandbox).
  Future<TalentLoadout> saveTalents({
    required String name,
    required Set<String> talents,
  }) {
    return _add(
      TalentLoadout(
        id: _newId(),
        name: name.trim().isEmpty ? 'My build' : name.trim(),
        talents: talents,
        description: 'Saved from the sandbox',
        isCustom: true,
      ),
    );
  }

  Future<void> delete(TalentLoadout loadout) async {
    _custom.removeWhere((l) => l.id == loadout.id);
    if (_activeId == loadout.id) _activeId = null;
    await _save();
  }

  Future<TalentLoadout> _add(TalentLoadout loadout) async {
    _custom = [..._custom, loadout];
    _activeId = loadout.id;
    await _save();
    return loadout;
  }

  String _newId() => 'custom_${DateTime.now().microsecondsSinceEpoch}';

  void _load() {
    _activeId = _store.getString(_activeKey);
    final raw = _store.getString(_buildsKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw);
      if (json is! List) return;
      _custom = [for (final item in json) ?_fromJson(item)];
    } on FormatException {
      _custom = [];
    }
  }

  TalentLoadout? _fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) return null;
    final exportString = json['export'] as String?;
    // Re-decode export strings so builds pick up talent data updates.
    final talents = switch (exportString == null
        ? null
        : decode(exportString)) {
      Ok(:final value) => value.tokens,
      _ => {...?(json['talents'] as List?)?.whereType<String>()},
    };
    return TalentLoadout(
      id: id,
      name: name,
      talents: talents,
      exportString: exportString,
      description: json['description'] as String?,
      isCustom: true,
    );
  }

  Future<void> _save() async {
    notifyListeners();
    await _store.setString(
      _buildsKey,
      jsonEncode([
        for (final l in _custom)
          {
            'id': l.id,
            'name': l.name,
            'export': ?l.exportString,
            'description': ?l.description,
            'talents': l.talents.toList()..sort(),
          },
      ]),
    );
    if (_activeId == null) {
      await _store.remove(_activeKey);
    } else {
      await _store.setString(_activeKey, _activeId!);
    }
  }
}
