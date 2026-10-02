import 'package:flutter/foundation.dart';

import '../../../../data/repositories/apl_repository.dart';
import '../../../../domain/apl/apl_evaluator.dart';
import '../../../../domain/models/combat_state.dart';
import '../../../../domain/models/spec_definition.dart';
import '../../../../domain/specs/rotation_spec.dart';

/// Holds the scenario being edited in the sandbox and re-evaluates the APL
/// whenever it changes.
class SandboxViewModel extends ChangeNotifier {
  SandboxViewModel({required AplRepository repository})
    : _repository = repository,
      _evaluator = AplEvaluator(repository.spec) {
    _loadout = spec.loadouts.first;
    _state = spec.defaultState(_loadout);
    _repository.addListener(_evaluate);
    _evaluate();
  }

  final AplRepository _repository;
  final AplEvaluator _evaluator;

  RotationSpec get spec => _repository.spec;

  late TalentLoadout _loadout;
  TalentLoadout get loadout => _loadout;

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

  /// Switches talents to [loadout], keeping the rest of the scenario.
  void selectLoadout(TalentLoadout loadout) {
    _loadout = loadout;
    _update(_state.copyWith(talents: loadout.talents));
  }

  void reset() => _update(spec.defaultState(_loadout));

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
    var next = _state.withTalent(talent.id, enabled);
    if (enabled) {
      for (final other in talent.exclusiveWith) {
        next = next.withTalent(other, false);
      }
    }
    _update(next);
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
    super.dispose();
  }
}
