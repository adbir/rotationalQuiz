import 'package:flutter/foundation.dart';

import 'combat_state.dart';

/// Broad school used to colour spell buttons.
enum SpellSchool { fire, nature, frost, earth, physical, arcane }

/// Static description of an ability the APL can recommend.
@immutable
class SpellDefinition {
  const SpellDefinition({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.school,
    this.cost = 0,
    this.castTime = 0,
    this.offGcd = false,
    this.requiredTalent,
    this.replacedByTalent,
    this.requiredBuff,
    this.cooldownId,
    this.usesCharges = false,
    this.onActionBar = true,
    this.spellId,
  });

  /// The SimC action name, e.g. `lava_burst`.
  final String id;

  /// Display name, e.g. `Lava Burst`.
  final String name;

  /// Short label for compact buttons, e.g. `LvB`.
  final String abbreviation;

  final SpellSchool school;

  /// Primary resource cost before modifiers.
  final double cost;

  /// Cast time in seconds; `0` means instant.
  final double castTime;

  /// Whether the ability is used alongside the next GCD ability.
  final bool offGcd;

  /// Talent that must be selected for the spell to be known.
  final String? requiredTalent;

  /// Talent that replaces this spell (e.g. Elemental Blast replaces
  /// Earth Shock).
  final String? replacedByTalent;

  /// Buff that must be up to cast the spell (e.g. Tempest).
  final String? requiredBuff;

  /// Cooldown key in [CombatState.cooldowns]; defaults to [id] when the spell
  /// has a cooldown.
  final String? cooldownId;

  /// Whether the cooldown is charge-based.
  final bool usesCharges;

  /// Whether the spell shows up as a button in quiz mode.
  final bool onActionBar;

  /// The in-game spell id, used to look up the spell's icon. Check new ids
  /// against SimulationCraft's `engine/dbc/generated/sc_spell_data.inc`.
  final int? spellId;
}

/// Kinds of state the scenario editor knows how to edit.
enum AuraKind { buff, dot, debuff }

/// Editor metadata for an aura the APL reads.
@immutable
class AuraDefinition {
  const AuraDefinition({
    required this.id,
    required this.name,
    this.kind = AuraKind.buff,
    this.maxStacks = 1,
    this.duration = 15,
    this.requiredTalent,
    this.requiredSetBonus,
    this.description,
    this.quizChance = 0.3,
    this.spellId,
  });

  final String id;
  final String name;
  final AuraKind kind;
  final int maxStacks;

  /// Base duration in seconds; used for sliders and pandemic maths.
  final double duration;

  /// Hide the aura in the editor unless this talent is selected.
  final String? requiredTalent;

  /// Hide the aura in the editor unless this set bonus is active.
  final String? requiredSetBonus;

  final String? description;

  /// Probability that a random quiz scenario has this aura up. `null` keeps
  /// the value from the spec's default state.
  final double? quizChance;

  /// The in-game spell id of the buff or debuff, used to look up its icon.
  final int? spellId;
}

/// Editor metadata for a cooldown the APL reads.
@immutable
class CooldownDefinition {
  const CooldownDefinition({
    required this.id,
    required this.name,
    required this.duration,
    this.maxCharges,
    this.requiredTalent,
  });

  final String id;
  final String name;
  final double duration;

  /// Non-null for charge-based cooldowns.
  final int? maxCharges;

  final String? requiredTalent;
}

/// A talent the APL checks with `talent.<id>`.
@immutable
class TalentDefinition {
  const TalentDefinition({
    required this.id,
    required this.name,
    required this.group,
    this.exclusiveWith = const [],
    this.description,
  });

  final String id;
  final String name;

  /// Section heading in the talent editor (e.g. `Hero tree`).
  final String group;

  /// Talents that cannot be selected together with this one (choice nodes
  /// and hero trees).
  final List<String> exclusiveWith;

  final String? description;
}

/// A named talent build.
@immutable
class TalentLoadout {
  const TalentLoadout({
    required this.id,
    required this.name,
    required this.talents,
    this.description,
    this.exportString,
    this.isCustom = false,
  });

  /// Stable id used for persistence and selection.
  final String id;
  final String name;

  /// SimC talent tokens, as used by `talent.<token>`.
  final Set<String> talents;
  final String? description;

  /// The in-game export string the build came from, if any.
  final String? exportString;

  /// Whether the user created this build.
  final bool isCustom;

  @override
  bool operator ==(Object other) => other is TalentLoadout && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A tier set bonus the APL checks with `set_bonus.<id>`.
@immutable
class SetBonusDefinition {
  const SetBonusDefinition({required this.id, required this.name});

  final String id;
  final String name;
}
