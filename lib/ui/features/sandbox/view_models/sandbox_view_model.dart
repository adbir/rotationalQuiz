import 'package:flutter/foundation.dart';

import '../../../../data/repositories/apl_repository.dart';
import '../../../../data/repositories/talent_build_repository.dart';
import '../../../../domain/apl/apl_evaluator.dart';
import '../../../../domain/models/combat_state.dart';
import '../../../../domain/models/spec_definition.dart';
import '../../../../domain/specs/rotation_spec.dart';

/// Holds the scenario being edited in the sandbox and re-evaluates the APL
/// whenever it changes.
class SandboxViewModel extends ChangeNotifier {
  SandboxViewModel({
    required AplRepository repository,
    required this._talentBuilds,
  }) : _repository = repository,
       _evaluator = AplEvaluator(repository.spec) {
    _loadoutId = _talentBuilds.active.id;
    _state = spec.defaultState(_talentBuilds.active);
    _repository.addListener(_evaluate);
    _talentBuilds.addListener(_onBuildChanged);
    _evaluate();
  }

  final AplRepository _repository;
  final TalentBuildRepository _talentBuilds;
  final AplEvaluator _evaluator;

  RotationSpec get spec => _repository.spec;

  late String _loadoutId;
  TalentLoadout get loadout => _talentBuilds.active;
  List<TalentLoadout> get loadouts => _talentBuilds.loadouts;

  /// Whether the talents were edited by hand since picking [loadout].
  bool get talentsEdited => !setEquals(_state.talents, loadout.talents);

  late CombatState _state;
  CombatState get state => _state;

  AplRecommendation? _recommendation;

  /// `null` until the APL has loaded.
  AplRecommendation? get recommendation => _recommendation;

  bool _showSkipped = false;
  bool get showSkipped => _showSkipped;

  void setShowSkipped(bool value) {
    _showSkipped = value;
    notifyListeners();
  }

  /// Switches talents to [loadout], keeping the rest of the scenario. This
  /// also becomes the build used by the quiz.
  void selectLoadout(TalentLoadout loadout) => _talentBuilds.setActive(loadout);

  /// Saves the current (hand-edited) talents as a new build.
  Future<void> saveTalentsAs(String name) =>
      _talentBuilds.saveTalents(name: name, talents: _state.talents);

  void reset() => _update(spec.defaultState(loadout));

  void _onBuildChanged() {
    if (_talentBuilds.active.id == _loadoutId) {
      notifyListeners();
      return;
    }
    _loadoutId = _talentBuilds.active.id;
    _update(spec.withTalents(_state, loadout.talents));
  }

  /// Replaces the whole scenario, e.g. when opening a quiz question.
  void loadState(CombatState state) => _update(state);

  void setResource(double value) => _update(_state.copyWith(resource: value));

  void setMoving(bool value) => _update(_state.copyWith(moving: value));

  void setTargetCasting(bool value) =>
      _update(_state.copyWith(targetCasting: value));

  void setFightRemains(double value) =>
      _update(_state.copyWith(fightRemains: value));

  void setAura(AuraDefinition aura, AuraState value) {
    _update(switch (aura.kind) {
      AuraKind.buff => _state.withBuff(aura.id, value),
      AuraKind.dot => _state.withDot(aura.id, value),
      AuraKind.debuff => _state.copyWith(
        debuffs: {..._state.debuffs, aura.id: value},
      ),
    });
  }

  AuraState auraState(AuraDefinition aura) => switch (aura.kind) {
    AuraKind.buff => _state.buff(aura.id),
    AuraKind.dot => _state.dot(aura.id),
    AuraKind.debuff => _state.debuff(aura.id),
  };

  void setCooldown(String id, CooldownState value) =>
      _update(_state.withCooldown(id, value));

  /// Toggles a talent, deselecting talents it is exclusive with.
  void setTalent(TalentDefinition talent, bool enabled) {
    final talents = {..._state.talents};
    if (enabled) {
      talents.add(talent.id);
      talents.removeAll(talent.exclusiveWith);
    } else {
      talents.remove(talent.id);
    }
    _update(spec.withTalents(_state, talents));
  }

  void setSetBonus(String id, bool enabled) =>
      _update(_state.withSetBonus(id, enabled));

  void _update(CombatState state) {
    _state = state;
    _evaluate();
  }

  void _evaluate() {
    final document = _repository.document;
    _recommendation = document == null
        ? null
        : _evaluator.recommend(document, _state);
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.removeListener(_evaluate);
    _talentBuilds.removeListener(_onBuildChanged);
    super.dispose();
  }
}
