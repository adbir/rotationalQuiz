import 'package:flutter/foundation.dart';

import '../../../../data/repositories/keybind_repository.dart';
import '../../../../data/repositories/talent_build_repository.dart';
import '../../../../data/services/pkce_access_token_source.dart';
import '../../../../domain/models/keybind.dart';
import '../../../../domain/models/spec_definition.dart';
import '../../../../domain/specs/rotation_spec.dart';
import '../../../../domain/talents/talent_string_codec.dart';
import '../../../../utils/result.dart';

/// What an export string decodes to, shown before saving it.
class BuildPreview {
  const BuildPreview({
    this.heroTree,
    this.aplTalents = const [],
    this.totalTalents = 0,
    this.error,
  });

  final String? heroTree;

  /// Talents from the build that the APL checks, by display name.
  final List<String> aplTalents;
  final int totalTalents;
  final String? error;

  bool get isValid => error == null;
}

/// Lets the user import their talent build and bind their abilities.
class SetupViewModel extends ChangeNotifier {
  SetupViewModel({
    required this._talentBuilds,
    required this._keybinds,
    required this._warcraftLogs,
  }) {
    _talentBuilds.addListener(notifyListeners);
    _keybinds.addListener(notifyListeners);
    _warcraftLogs.addListener(notifyListeners);
  }

  final TalentBuildRepository _talentBuilds;
  final KeybindRepository _keybinds;
  final PkceAccessTokenSource _warcraftLogs;

  RotationSpec get spec => _talentBuilds.spec;

  // ---- Talent builds ------------------------------------------------------

  List<TalentLoadout> get loadouts => _talentBuilds.loadouts;
  TalentLoadout get active => _talentBuilds.active;

  void setActive(TalentLoadout loadout) => _talentBuilds.setActive(loadout);

  Future<void> delete(TalentLoadout loadout) => _talentBuilds.delete(loadout);

  BuildPreview? _preview;

  /// Preview of the export string being typed, or `null` when empty.
  BuildPreview? get preview => _preview;

  String? _message;

  /// One-shot feedback for a snackbar; cleared by [consumeMessage].
  String? consumeMessage() {
    final message = _message;
    _message = null;
    return message;
  }

  void updatePreview(String exportString) {
    if (exportString.trim().isEmpty) {
      _preview = null;
    } else {
      _preview = switch (_talentBuilds.decode(exportString)) {
        Ok(:final value) => _previewOf(value),
        Error(:final error) => BuildPreview(error: '$error'),
      };
    }
    notifyListeners();
  }

  /// Returns whether the build was saved.
  Future<bool> importBuild({
    required String name,
    required String exportString,
  }) async {
    final result = await _talentBuilds.importBuild(
      name: name,
      exportString: exportString,
    );
    switch (result) {
      case Ok(:final value):
        _message = 'Saved "${value.name}" and made it your active build.';
        _preview = null;
        notifyListeners();
        return true;
      case Error(:final error):
        _preview = BuildPreview(error: '$error');
        notifyListeners();
        return false;
    }
  }

  BuildPreview _previewOf(DecodedTalentBuild build) {
    return BuildPreview(
      heroTree: spec.heroTreeNames[build.heroTreeId],
      aplTalents: [
        for (final talent in spec.talents)
          if (build.tokens.contains(talent.id)) talent.name,
      ],
      totalTalents: build.tokens.length,
    );
  }

  // ---- Warcraft Logs ------------------------------------------------------

  bool get isSignedInToWarcraftLogs => _warcraftLogs.isSignedIn;
  String? get warcraftLogsError => _warcraftLogs.error;

  Future<void> signInToWarcraftLogs() => _warcraftLogs.signIn();

  Future<void> signOutOfWarcraftLogs() => _warcraftLogs.signOut();

  // ---- Keybinds -----------------------------------------------------------

  /// Every ability the active build knows, GCD abilities first.
  List<SpellDefinition> get bindableSpells {
    final state = spec.defaultState(active);
    final known = spec.knownSpells(state);
    return [...known.where((s) => !s.offGcd), ...known.where((s) => s.offGcd)];
  }

  Keybind? bindFor(String spellId) => _keybinds.bindFor(spellId);

  int get boundCount =>
      bindableSpells.where((s) => _keybinds.bindFor(s.id) != null).length;

  Future<void> bind(SpellDefinition spell, Keybind keybind) async {
    final displaced = await _keybinds.bind(spell.id, keybind);
    if (displaced != null) {
      final name = spec.spells[displaced]?.name ?? displaced;
      _message = '${keybind.label} was on $name; it is now ${spell.name}.';
      notifyListeners();
    }
  }

  Future<void> unbind(SpellDefinition spell) => _keybinds.unbind(spell.id);

  Future<void> clearKeybinds() => _keybinds.clear();

  @override
  void dispose() {
    _talentBuilds.removeListener(notifyListeners);
    _keybinds.removeListener(notifyListeners);
    _warcraftLogs.removeListener(notifyListeners);
    super.dispose();
  }
}
