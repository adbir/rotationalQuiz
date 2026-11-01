import 'dart:math';

import '../models/combat_state.dart';
import '../models/spec_definition.dart';
import '../specs/rotation_spec.dart';

/// Builds random but plausible combat situations for quiz mode.
///
/// Only the spec metadata is used, so new specs get quiz support for free.
class GenerateScenario {
  GenerateScenario(this.spec, {Random? random}) : _random = random ?? Random();

  final RotationSpec spec;
  final Random _random;

  CombatState call(
    TalentLoadout loadout, {
    Set<String>? setBonuses,
    double movingChance = 0.25,
  }) {
    final steps = spec.maxResource(loadout.talents) ~/ 5;
    final state = spec
        .defaultState(loadout)
        .copyWith(
          setBonuses: setBonuses,
          resource: (_random.nextInt(steps + 1) * 5).toDouble(),
          moving: _random.nextDouble() < movingChance,
          fightRemains: 30 + _random.nextInt(270).toDouble(),
        );

    final buffs = {...state.buffs};
    final dots = {...state.dots};
    final debuffs = {...state.debuffs};
    for (final aura in spec.auras) {
      final chance = aura.quizChance;
      if (chance == null) continue;
      if (aura.requiredTalent != null &&
          !state.hasTalent(aura.requiredTalent!)) {
        continue;
      }
      if (aura.requiredSetBonus != null &&
          !state.setBonuses.contains(aura.requiredSetBonus)) {
        continue;
      }
      final target = switch (aura.kind) {
        AuraKind.buff => buffs,
        AuraKind.dot => dots,
        AuraKind.debuff => debuffs,
      };
      if (_random.nextDouble() < chance) {
        target[aura.id] = AuraState(
          stacks: 1 + _random.nextInt(aura.maxStacks),
          remains: _roundTenth(0.5 + _random.nextDouble() * aura.duration),
        );
      } else {
        target.remove(aura.id);
      }
    }

    final cooldowns = {...state.cooldowns};
    for (final cooldown in spec.cooldowns) {
      final maxCharges = spec.maxCharges(cooldown, loadout.talents);
      final readyChance = cooldown.quizReadyChance;
      if (maxCharges != null) {
        cooldowns[cooldown.id] = CooldownState(
          charges: _roundTenth(_rollCharges(maxCharges, readyChance)),
        );
      } else if (_random.nextDouble() < (readyChance ?? 0.5)) {
        cooldowns[cooldown.id] = CooldownState.ready;
      } else {
        cooldowns[cooldown.id] = CooldownState(
          remains: _roundTenth(
            _random.nextDouble() * min(cooldown.duration, 90),
          ),
        );
      }
    }

    // A buff from a cooldown (e.g. Ascendance) means the cooldown was used
    // `duration - remains` seconds ago.
    for (final cooldown in spec.cooldowns) {
      final aura = buffs[cooldown.id];
      final definition = spec.auraDefinition(cooldown.id, AuraKind.buff);
      if (aura == null || definition == null || cooldown.maxCharges != null) {
        continue;
      }
      final elapsed = max(0, definition.duration - aura.remains);
      cooldowns[cooldown.id] = CooldownState(
        remains: _roundTenth(max(0, cooldown.duration - elapsed)),
      );
    }

    return state.copyWith(
      buffs: buffs,
      dots: dots,
      debuffs: debuffs,
      cooldowns: cooldowns,
    );
  }

  /// Fractional charges: spread evenly, or at least one [readyChance] of the
  /// time.
  double _rollCharges(int maxCharges, double? readyChance) {
    if (readyChance == null) return _random.nextDouble() * maxCharges;
    return _random.nextDouble() < readyChance
        ? 1 + _random.nextDouble() * (maxCharges - 1)
        : _random.nextDouble() * 0.9;
  }

  static double _roundTenth(double value) => (value * 10).round() / 10;
}
