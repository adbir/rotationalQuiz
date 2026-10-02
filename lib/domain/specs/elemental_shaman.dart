import '../models/combat_state.dart';
import '../models/spec_definition.dart';
import 'rotation_spec.dart';

/// Elemental Shaman, modelled for the single-target sandbox.
///
/// Numbers here (costs, durations, cooldowns) are approximations used to
/// decide whether a button is pressable. The *priority* itself always comes
/// from the SimC APL, so keep these in sync with the game when patches land.
class ElementalShaman extends RotationSpec {
  const ElementalShaman();

  // Talent ids, as used by `talent.<id>` in the APL.
  static const callOfTheAncestors = 'call_of_the_ancestors';
  static const tempestTalent = 'tempest';
  static const masterOfTheElements = 'master_of_the_elements';
  static const eyeOfTheStorm = 'eye_of_the_storm';
  static const elementalBlastTalent = 'elemental_blast';
  static const stormkeeperTalent = 'stormkeeper';
  static const ascendanceTalent = 'ascendance';
  static const fireElemental = 'fire_elemental';
  static const stormElemental = 'storm_elemental';
  static const voltaicBlazeTalent = 'voltaic_blaze';
  static const purgingFlames = 'purging_flames';
  static const moltenWrath = 'molten_wrath';
  static const cracklingFury = 'crackling_fury';
  static const ancestralSwiftnessTalent = 'ancestral_swiftness';
  static const naturesSwiftnessTalent = 'natures_swiftness';

  static const flameShockDuration = 18.0;

  @override
  String get id => 'shaman_elemental';

  @override
  String get name => 'Elemental Shaman';

  @override
  String get resourceName => 'maelstrom';

  @override
  String get resourceLabel => 'Maelstrom';

  @override
  String get aplAssetPath => 'assets/apl/shaman_elemental.simc';

  @override
  Uri get remoteAplUrl => Uri.parse(
    'https://raw.githubusercontent.com/simulationcraft/simc/midnight/'
    'ActionPriorityLists/default/shaman_elemental.simc',
  );

  @override
  String get entryList => 'default';

  @override
  String get focusList => 'single_target';

  @override
  Map<String, SpellDefinition> get spells => const {
    'lava_burst': SpellDefinition(
      id: 'lava_burst',
      name: 'Lava Burst',
      abbreviation: 'LvB',
      school: SpellSchool.fire,
      castTime: 2,
      usesCharges: true,
    ),
    'lightning_bolt': SpellDefinition(
      id: 'lightning_bolt',
      name: 'Lightning Bolt',
      abbreviation: 'LB',
      school: SpellSchool.nature,
      castTime: 2,
    ),
    'tempest': SpellDefinition(
      id: 'tempest',
      name: 'Tempest',
      abbreviation: 'Tmp',
      school: SpellSchool.nature,
      castTime: 2,
      requiredTalent: tempestTalent,
      requiredBuff: 'tempest',
    ),
    'chain_lightning': SpellDefinition(
      id: 'chain_lightning',
      name: 'Chain Lightning',
      abbreviation: 'CL',
      school: SpellSchool.nature,
      castTime: 2,
    ),
    'flame_shock': SpellDefinition(
      id: 'flame_shock',
      name: 'Flame Shock',
      abbreviation: 'FS',
      school: SpellSchool.fire,
      cooldownId: 'flame_shock',
    ),
    'voltaic_blaze': SpellDefinition(
      id: 'voltaic_blaze',
      name: 'Voltaic Blaze',
      abbreviation: 'VB',
      school: SpellSchool.fire,
      requiredTalent: voltaicBlazeTalent,
      cooldownId: 'voltaic_blaze',
    ),
    'earth_shock': SpellDefinition(
      id: 'earth_shock',
      name: 'Earth Shock',
      abbreviation: 'ES',
      school: SpellSchool.earth,
      cost: 60,
      replacedByTalent: elementalBlastTalent,
    ),
    'elemental_blast': SpellDefinition(
      id: 'elemental_blast',
      name: 'Elemental Blast',
      abbreviation: 'EB',
      school: SpellSchool.earth,
      cost: 90,
      requiredTalent: elementalBlastTalent,
    ),
    'earthquake': SpellDefinition(
      id: 'earthquake',
      name: 'Earthquake',
      abbreviation: 'EQ',
      school: SpellSchool.earth,
      cost: 60,
    ),
    'frost_shock': SpellDefinition(
      id: 'frost_shock',
      name: 'Frost Shock',
      abbreviation: 'FrS',
      school: SpellSchool.frost,
    ),
    'stormkeeper': SpellDefinition(
      id: 'stormkeeper',
      name: 'Stormkeeper',
      abbreviation: 'SK',
      school: SpellSchool.nature,
      castTime: 1.5,
      requiredTalent: stormkeeperTalent,
      cooldownId: 'stormkeeper',
    ),
    'ascendance': SpellDefinition(
      id: 'ascendance',
      name: 'Ascendance',
      abbreviation: 'Asc',
      school: SpellSchool.fire,
      requiredTalent: ascendanceTalent,
      cooldownId: 'ascendance',
    ),
    'ancestral_swiftness': SpellDefinition(
      id: 'ancestral_swiftness',
      name: 'Ancestral Swiftness',
      abbreviation: 'AS',
      school: SpellSchool.nature,
      offGcd: true,
      requiredTalent: ancestralSwiftnessTalent,
      cooldownId: 'ancestral_swiftness',
    ),
    'natures_swiftness': SpellDefinition(
      id: 'natures_swiftness',
      name: "Nature's Swiftness",
      abbreviation: 'NS',
      school: SpellSchool.nature,
      offGcd: true,
      requiredTalent: naturesSwiftnessTalent,
      replacedByTalent: ancestralSwiftnessTalent,
      cooldownId: 'natures_swiftness',
    ),
    'spiritwalkers_grace': SpellDefinition(
      id: 'spiritwalkers_grace',
      name: "Spiritwalker's Grace",
      abbreviation: 'SWG',
      school: SpellSchool.arcane,
      offGcd: true,
      cooldownId: 'spiritwalkers_grace',
      onActionBar: false,
    ),
    'wind_shear': SpellDefinition(
      id: 'wind_shear',
      name: 'Wind Shear',
      abbreviation: 'WS',
      school: SpellSchool.nature,
      offGcd: true,
      cooldownId: 'wind_shear',
      onActionBar: false,
    ),
    'lightning_shield': SpellDefinition(
      id: 'lightning_shield',
      name: 'Lightning Shield',
      abbreviation: 'LS',
      school: SpellSchool.nature,
      onActionBar: false,
    ),
  };

  @override
  List<AuraDefinition> get auras => const [
    AuraDefinition(
      id: 'flame_shock',
      name: 'Flame Shock',
      kind: AuraKind.dot,
      duration: flameShockDuration,
      description: 'Refreshable below 30% duration (pandemic).',
      quizChance: 0.85,
    ),
    AuraDefinition(
      id: 'master_of_the_elements',
      name: 'Master of the Elements',
      requiredTalent: masterOfTheElements,
      description: 'Lava Burst empowers your next spender.',
    ),
    AuraDefinition(
      id: 'lava_surge',
      name: 'Lava Surge',
      duration: 10,
      description: 'Next Lava Burst is instant and free.',
    ),
    AuraDefinition(
      id: 'stormkeeper',
      name: 'Stormkeeper',
      maxStacks: 3,
      requiredTalent: stormkeeperTalent,
    ),
    AuraDefinition(
      id: 'tempest',
      name: 'Tempest',
      maxStacks: 2,
      requiredTalent: tempestTalent,
      description: 'Stormbringer: Lightning Bolt becomes Tempest.',
    ),
    AuraDefinition(
      id: 'call_of_the_ancestors',
      name: 'Call of the Ancestors',
      maxStacks: 5,
      requiredTalent: callOfTheAncestors,
      description: 'Farseer: number of active Ancestors.',
    ),
    AuraDefinition(
      id: 'ascendance',
      name: 'Ascendance',
      requiredTalent: ascendanceTalent,
    ),
    AuraDefinition(
      id: 'fire_elemental',
      name: 'Fire Elemental',
      duration: 30,
      requiredTalent: fireElemental,
    ),
    AuraDefinition(
      id: 'storm_elemental',
      name: 'Storm Elemental',
      duration: 30,
      requiredTalent: stormElemental,
    ),
    AuraDefinition(
      id: 'wind_gust',
      name: 'Wind Gust',
      maxStacks: 4,
      requiredTalent: stormElemental,
    ),
    AuraDefinition(
      id: 'purging_flames',
      name: 'Purging Flames',
      requiredTalent: purgingFlames,
    ),
    AuraDefinition(
      id: 'flowing_elements',
      name: 'Flowing Elements',
      description: 'Tier set proc.',
      quizChance: 0.1,
    ),
    AuraDefinition(
      id: 'overcharge_tier',
      name: 'Overcharge',
      description: 'Tier set proc.',
      quizChance: 0.1,
    ),
    AuraDefinition(
      id: 'ancestral_swiftness',
      name: 'Ancestral Swiftness',
      requiredTalent: ancestralSwiftnessTalent,
      description: 'Next cast is instant.',
      quizChance: 0.1,
    ),
    AuraDefinition(
      id: 'natures_swiftness',
      name: "Nature's Swiftness",
      requiredTalent: naturesSwiftnessTalent,
      description: 'Next cast is instant.',
      quizChance: 0.1,
    ),
    AuraDefinition(
      id: 'spiritwalkers_grace',
      name: "Spiritwalker's Grace",
      description: 'Cast while moving.',
      quizChance: 0,
    ),
    AuraDefinition(
      id: 'bloodlust',
      name: 'Bloodlust',
      duration: 40,
      quizChance: 0.15,
    ),
    AuraDefinition(
      id: 'lightning_shield',
      name: 'Lightning Shield',
      quizChance: null,
    ),
  ];

  @override
  List<CooldownDefinition> get cooldowns => const [
    CooldownDefinition(
      id: 'lava_burst',
      name: 'Lava Burst',
      duration: 8,
      maxCharges: 2,
    ),
    CooldownDefinition(id: 'flame_shock', name: 'Flame Shock', duration: 6),
    CooldownDefinition(
      id: 'voltaic_blaze',
      name: 'Voltaic Blaze',
      duration: 30,
      requiredTalent: voltaicBlazeTalent,
    ),
    CooldownDefinition(
      id: 'stormkeeper',
      name: 'Stormkeeper',
      duration: 60,
      requiredTalent: stormkeeperTalent,
    ),
    CooldownDefinition(
      id: 'ascendance',
      name: 'Ascendance',
      duration: 180,
      requiredTalent: ascendanceTalent,
    ),
    CooldownDefinition(
      id: 'ancestral_swiftness',
      name: 'Ancestral Swiftness',
      duration: 60,
      requiredTalent: ancestralSwiftnessTalent,
    ),
    CooldownDefinition(
      id: 'natures_swiftness',
      name: "Nature's Swiftness",
      duration: 60,
      requiredTalent: naturesSwiftnessTalent,
    ),
  ];

  @override
  List<TalentDefinition> get talents => const [
    TalentDefinition(
      id: callOfTheAncestors,
      name: 'Farseer (Call of the Ancestors)',
      group: 'Hero tree',
      exclusiveWith: [tempestTalent],
    ),
    TalentDefinition(
      id: tempestTalent,
      name: 'Stormbringer (Tempest)',
      group: 'Hero tree',
      exclusiveWith: [callOfTheAncestors],
    ),
    TalentDefinition(
      id: elementalBlastTalent,
      name: 'Elemental Blast',
      group: 'Spec',
      description: 'Replaces Earth Shock.',
    ),
    TalentDefinition(
      id: masterOfTheElements,
      name: 'Master of the Elements',
      group: 'Spec',
    ),
    TalentDefinition(
      id: eyeOfTheStorm,
      name: 'Eye of the Storm',
      group: 'Spec',
    ),
    TalentDefinition(id: stormkeeperTalent, name: 'Stormkeeper', group: 'Spec'),
    TalentDefinition(id: ascendanceTalent, name: 'Ascendance', group: 'Spec'),
    TalentDefinition(
      id: fireElemental,
      name: 'Fire Elemental',
      group: 'Spec',
      exclusiveWith: [stormElemental],
    ),
    TalentDefinition(
      id: stormElemental,
      name: 'Storm Elemental',
      group: 'Spec',
      exclusiveWith: [fireElemental],
    ),
    TalentDefinition(
      id: voltaicBlazeTalent,
      name: 'Voltaic Blaze',
      group: 'Spec',
    ),
    TalentDefinition(id: purgingFlames, name: 'Purging Flames', group: 'Spec'),
    TalentDefinition(id: moltenWrath, name: 'Molten Wrath', group: 'Spec'),
    TalentDefinition(id: cracklingFury, name: 'Crackling Fury', group: 'Spec'),
    TalentDefinition(
      id: ancestralSwiftnessTalent,
      name: 'Ancestral Swiftness',
      group: 'Class',
      exclusiveWith: [naturesSwiftnessTalent],
    ),
    TalentDefinition(
      id: naturesSwiftnessTalent,
      name: "Nature's Swiftness",
      group: 'Class',
      exclusiveWith: [ancestralSwiftnessTalent],
    ),
  ];

  @override
  List<TalentLoadout> get loadouts => const [
    TalentLoadout(
      name: 'Farseer',
      description:
          'Call of the Ancestors, Earth Shock, Master of the Elements.',
      talents: {
        callOfTheAncestors,
        masterOfTheElements,
        eyeOfTheStorm,
        stormkeeperTalent,
        ascendanceTalent,
        fireElemental,
        voltaicBlazeTalent,
        purgingFlames,
        ancestralSwiftnessTalent,
      },
    ),
    TalentLoadout(
      name: 'Stormbringer',
      description: 'Tempest, Elemental Blast, Master of the Elements.',
      talents: {
        tempestTalent,
        elementalBlastTalent,
        masterOfTheElements,
        eyeOfTheStorm,
        stormkeeperTalent,
        ascendanceTalent,
        fireElemental,
        voltaicBlazeTalent,
        naturesSwiftnessTalent,
      },
    ),
  ];

  @override
  List<SetBonusDefinition> get setBonuses => const [
    SetBonusDefinition(id: 'mid2_4pc', name: 'Midnight Season 2 (4-piece)'),
  ];

  @override
  Set<String> get unmodelledActions => const {
    'snapshot_stats',
    'flametongue_weapon',
    'thunderstrike_ward',
    'blood_fury',
    'berserking',
    'fireblood',
    'ancestral_call',
    'use_item',
    'potion',
    'invoke_external_buff',
  };

  @override
  CombatState defaultState(TalentLoadout loadout) {
    return CombatState(
      resource: 40,
      maxResource: 100,
      talents: loadout.talents,
      buffs: const {'lightning_shield': AuraState.up(remains: 3600)},
      dots: const {'flame_shock': AuraState.up(remains: 12)},
      cooldowns: const {
        'lava_burst': CooldownState(charges: 1),
        'stormkeeper': CooldownState(remains: 30),
        'ascendance': CooldownState(remains: 60),
      },
    );
  }

  @override
  double costOf(SpellDefinition spell, CombatState state) {
    if (spell.cost == 0) return 0;
    if (spell.id == 'lava_burst' && state.buff('lava_surge').isUp) return 0;
    var cost = spell.cost;
    if (state.hasTalent(eyeOfTheStorm)) {
      cost -= spell.id == 'elemental_blast' ? 10 : 5;
    }
    return cost;
  }

  @override
  SpellAvailability availability(String spellId, CombatState state) {
    final spell = spells[spellId];
    if (spell == null) {
      return const SpellAvailability.unavailable('Not in the spell book');
    }
    if (spell.requiredTalent != null &&
        !state.hasTalent(spell.requiredTalent!)) {
      return const SpellAvailability.unavailable('Not talented');
    }
    if (spell.replacedByTalent != null &&
        state.hasTalent(spell.replacedByTalent!)) {
      return SpellAvailability.unavailable(
        'Replaced by ${_talentName(spell.replacedByTalent!)}',
      );
    }
    if (spell.requiredBuff != null && !state.buff(spell.requiredBuff!).isUp) {
      return SpellAvailability.unavailable(
        'Needs a ${_auraName(spell.requiredBuff!)} proc',
      );
    }
    if (spell.id == 'wind_shear' && !state.targetCasting) {
      return const SpellAvailability.unavailable('Nothing to interrupt');
    }

    if (spell.usesCharges) {
      final charges = state.cooldown(spell.id).charges ?? 0;
      final surge = spell.id == 'lava_burst' && state.buff('lava_surge').isUp;
      if (charges < 1 && !surge) {
        return const SpellAvailability.unavailable('No charges');
      }
    } else if (spell.cooldownId != null) {
      final remains = state.cooldown(spell.cooldownId!).remains;
      if (remains > 0) {
        return SpellAvailability.unavailable(
          'On cooldown (${remains.toStringAsFixed(remains < 10 ? 1 : 0)}s)',
        );
      }
    }

    final cost = costOf(spell, state);
    if (cost > state.resource) {
      return SpellAvailability.unavailable(
        'Needs ${cost.round()} $resourceLabel',
      );
    }

    if (state.moving && spell.castTime > 0 && !_isInstant(spell, state)) {
      return const SpellAvailability.unavailable("Can't cast while moving");
    }
    return const SpellAvailability.available();
  }

  bool _isInstant(SpellDefinition spell, CombatState state) {
    if (state.buff('spiritwalkers_grace').isUp ||
        state.buff('ancestral_swiftness').isUp ||
        state.buff('natures_swiftness').isUp) {
      return true;
    }
    return switch (spell.id) {
      'lava_burst' => state.buff('lava_surge').isUp,
      'lightning_bolt' || 'chain_lightning' => state.buff('stormkeeper').isUp,
      _ => false,
    };
  }

  @override
  double? resolveScalar(String identifier, CombatState state) {
    if (identifier.startsWith('spell_targets.')) {
      return state.targets.toDouble();
    }
    return switch (identifier) {
      'maelstrom' => state.resource,
      'maelstrom.deficit' => state.resourceDeficit,
      'maelstrom.max' => state.maxResource,
      'maelstrom.pct' => state.resource / state.maxResource * 100,
      'active_enemies' => state.targets.toDouble(),
      'fight_remains' || 'target.time_to_die' => state.fightRemains,
      'gcd' || 'gcd.max' => state.gcd,
      'movement.distance' => state.moving ? 10 : 0,
      'lightning_rod' => state.debuff('lightning_rod').isUp ? 1 : 0,
      _ => null,
    };
  }

  @override
  CombatState applyOffGcd(String spellId, CombatState state) {
    final cooldown = cooldownDefinition(spellId)?.duration;
    var next = state;
    if (cooldown != null) {
      next = next.withCooldown(spellId, CooldownState(remains: cooldown));
    }
    return switch (spellId) {
      'ancestral_swiftness' ||
      'natures_swiftness' => next.withBuff(spellId, const AuraState.up()),
      'spiritwalkers_grace' =>
        next
            .withBuff(spellId, const AuraState.up(remains: 15))
            .withCooldown(spellId, const CooldownState(remains: 120)),
      'wind_shear' =>
        next
            .copyWith(targetCasting: false)
            .withCooldown(spellId, const CooldownState(remains: 12)),
      _ => next,
    };
  }

  String _talentName(String id) =>
      talents.where((t) => t.id == id).firstOrNull?.name ?? id;

  String _auraName(String id) =>
      auras.where((a) => a.id == id).firstOrNull?.name ?? id;
}
