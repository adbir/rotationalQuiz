import '../models/combat_state.dart';
import '../models/spec_definition.dart';
import '../specs/rotation_spec.dart';

/// Answers the state questions an APL condition asks: `buff.*`, `dot.*`,
/// `cooldown.*`, `talent.*`, `spell_targets.*`, `fight_remains`... Anything
/// spec-specific (e.g. the primary resource) is delegated to
/// [RotationSpec.resolveScalar].
class AplStateResolver {
  const AplStateResolver(this.spec);

  final RotationSpec spec;

  double? resolve(String identifier, CombatState state) {
    final parts = identifier.split('.');
    switch (parts) {
      case ['buff' || 'debuff' || 'dot', final name, final property]:
        final kind = switch (parts[0]) {
          'buff' => AuraKind.buff,
          'debuff' => AuraKind.debuff,
          _ => AuraKind.dot,
        };
        final aura = switch (kind) {
          AuraKind.buff => state.buff(name),
          AuraKind.debuff => state.debuff(name),
          AuraKind.dot => state.dot(name),
        };
        final definition = spec.auraDefinition(name, kind);
        return _auraProperty(aura, definition, property);
      case ['cooldown', final name, final property]:
        return _cooldownProperty(state, name, property);
      case ['talent', final name] || ['talent', final name, 'enabled']:
        return state.hasTalent(name) ? 1 : 0;
      case ['set_bonus', final name]:
        return state.setBonuses.contains(name) ? 1 : 0;
      case ['active_dot', final name]:
        return state.dot(name).isUp ? 1 : 0;
      case ['spell_targets', _]:
        return state.targets.toDouble();
    }
    return switch (identifier) {
      'active_enemies' => state.targets.toDouble(),
      'fight_remains' || 'target.time_to_die' => state.fightRemains,
      'gcd' || 'gcd.max' => state.gcd,
      'movement.distance' => state.moving ? 10 : 0,
      _ => spec.resolveScalar(identifier, state),
    };
  }

  double? _auraProperty(
    AuraState aura,
    AuraDefinition? definition,
    String property,
  ) {
    final up = aura.isUp;
    final duration = definition?.duration ?? 15;
    return switch (property) {
      'up' || 'ticking' => up ? 1 : 0,
      'react' || 'stack' => up ? aura.stacks.toDouble() : 0,
      'down' => up ? 0 : 1,
      'remains' => up ? aura.remains : 0,
      'refreshable' => !up || aura.remains < duration * 0.3 ? 1 : 0,
      'duration' => duration,
      'max_stack' => (definition?.maxStacks ?? 1).toDouble(),
      _ => null,
    };
  }

  double? _cooldownProperty(CombatState state, String name, String property) {
    final definition = spec.cooldownDefinition(name);
    final cooldown = state.cooldown(name);
    final duration = definition?.duration ?? 0;
    final maxCharges = definition == null
        ? null
        : spec.maxCharges(definition, state.talents);

    final double fractional;
    final double remains;
    if (maxCharges != null) {
      fractional = (cooldown.charges ?? maxCharges.toDouble()).clamp(
        0,
        maxCharges.toDouble(),
      );
      remains = fractional >= 1 ? 0 : (1 - fractional) * duration;
    } else {
      remains = cooldown.remains;
      fractional = remains <= 0
          ? 1
          : (duration <= 0 ? 0 : (1 - remains / duration).clamp(0, 1));
    }

    return switch (property) {
      'remains' => remains,
      'ready' || 'up' => remains <= 0 ? 1 : 0,
      'charges' => fractional.floorToDouble(),
      'charges_fractional' => fractional,
      'max_charges' => (maxCharges ?? 1).toDouble(),
      'duration' => duration,
      'full_recharge_time' =>
        ((maxCharges ?? 1) - fractional).clamp(0, double.infinity) * duration,
      _ => null,
    };
  }
}
