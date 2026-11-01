// Static data for Elemental Shaman: spells, auras, cooldowns, talents and
// reference builds. Behaviour lives in elemental_shaman.dart.
import '../models/spec_definition.dart';
import '../talents/generated/shaman_talent_tree.g.dart';
import '../talents/talent_string_codec.dart';

const _flameShockDuration = 18.0;

/// Talent tokens (`talent.<token>`) the spec code refers to by name.
abstract final class ElementalTalents {
  static const callOfTheAncestors = 'call_of_the_ancestors';
  static const tempestTalent = 'tempest';
  static const masterOfTheElements = 'master_of_the_elements';
  static const eyeOfTheStorm = 'eye_of_the_storm';
  static const elementalBlastTalent = 'elemental_blast';
  static const earthShockTalent = 'earth_shock';
  static const stormkeeperTalent = 'stormkeeper';
  static const ascendanceTalent = 'ascendance';
  static const stormElemental = 'storm_elemental';
  static const infernoArc = 'inferno_arc';
  static const flametongueWeapon = 'flametongue_weapon';
  static const voltaicBlazeTalent = 'voltaic_blaze';
  static const purgingFlames = 'purging_flames';
  static const moltenWrath = 'molten_wrath';
  static const cracklingFury = 'crackling_fury';
  static const ancestralSwiftnessTalent = 'ancestral_swiftness';
  static const naturesSwiftnessTalent = 'natures_swiftness';

  static const swellingMaelstrom = 'swelling_maelstrom';
  static const primordialCapacity = 'primordial_capacity';
}

const elementalSpells = <String, SpellDefinition>{
  'lava_burst': SpellDefinition(
    id: 'lava_burst',
    spellId: 51505,
    name: 'Lava Burst',
    abbreviation: 'LvB',
    school: SpellSchool.fire,
    castTime: 2,
    usesCharges: true,
  ),
  'lightning_bolt': SpellDefinition(
    id: 'lightning_bolt',
    spellId: 188196,
    name: 'Lightning Bolt',
    abbreviation: 'LB',
    school: SpellSchool.nature,
    castTime: 2,
  ),
  'tempest': SpellDefinition(
    id: 'tempest',
    spellId: 452201,
    name: 'Tempest',
    abbreviation: 'Tmp',
    school: SpellSchool.nature,
    castTime: 2,
    requiredTalent: ElementalTalents.tempestTalent,
    requiredBuff: 'tempest',
  ),
  'chain_lightning': SpellDefinition(
    id: 'chain_lightning',
    spellId: 188443,
    name: 'Chain Lightning',
    abbreviation: 'CL',
    school: SpellSchool.nature,
    castTime: 2,
  ),
  'flame_shock': SpellDefinition(
    id: 'flame_shock',
    spellId: 188389,
    name: 'Flame Shock',
    abbreviation: 'FS',
    school: SpellSchool.fire,
  ),
  'voltaic_blaze': SpellDefinition(
    id: 'voltaic_blaze',
    spellId: 470057,
    name: 'Voltaic Blaze',
    abbreviation: 'VB',
    school: SpellSchool.fire,
    requiredTalent: ElementalTalents.voltaicBlazeTalent,
    cooldownId: 'voltaic_blaze',
  ),
  'earth_shock': SpellDefinition(
    id: 'earth_shock',
    spellId: 8042,
    name: 'Earth Shock',
    abbreviation: 'ES',
    school: SpellSchool.earth,
    cost: 60,
    requiredTalent: ElementalTalents.earthShockTalent,
  ),
  'elemental_blast': SpellDefinition(
    id: 'elemental_blast',
    spellId: 117014,
    name: 'Elemental Blast',
    abbreviation: 'EB',
    school: SpellSchool.earth,
    cost: 90,
    requiredTalent: ElementalTalents.elementalBlastTalent,
  ),
  'earthquake': SpellDefinition(
    id: 'earthquake',
    spellId: 61882,
    name: 'Earthquake',
    abbreviation: 'EQ',
    school: SpellSchool.earth,
    cost: 60,
  ),
  'frost_shock': SpellDefinition(
    id: 'frost_shock',
    spellId: 196840,
    name: 'Frost Shock',
    abbreviation: 'FrS',
    school: SpellSchool.frost,
  ),
  'stormkeeper': SpellDefinition(
    id: 'stormkeeper',
    spellId: 191634,
    name: 'Stormkeeper',
    abbreviation: 'SK',
    school: SpellSchool.nature,
    castTime: 1.5,
    requiredTalent: ElementalTalents.stormkeeperTalent,
    cooldownId: 'stormkeeper',
  ),
  'ascendance': SpellDefinition(
    id: 'ascendance',
    spellId: 114050,
    name: 'Ascendance',
    abbreviation: 'Asc',
    school: SpellSchool.fire,
    requiredTalent: ElementalTalents.ascendanceTalent,
    cooldownId: 'ascendance',
  ),
  'ancestral_swiftness': SpellDefinition(
    id: 'ancestral_swiftness',
    spellId: 443454,
    name: 'Ancestral Swiftness',
    abbreviation: 'AS',
    school: SpellSchool.nature,
    offGcd: true,
    requiredTalent: ElementalTalents.ancestralSwiftnessTalent,
    cooldownId: 'ancestral_swiftness',
  ),
  'natures_swiftness': SpellDefinition(
    id: 'natures_swiftness',
    spellId: 378081,
    name: "Nature's Swiftness",
    abbreviation: 'NS',
    school: SpellSchool.nature,
    offGcd: true,
    requiredTalent: ElementalTalents.naturesSwiftnessTalent,
    replacedByTalent: ElementalTalents.ancestralSwiftnessTalent,
    cooldownId: 'natures_swiftness',
  ),
  'spiritwalkers_grace': SpellDefinition(
    id: 'spiritwalkers_grace',
    spellId: 79206,
    name: "Spiritwalker's Grace",
    abbreviation: 'SWG',
    school: SpellSchool.arcane,
    offGcd: true,
    usesCharges: true,
    onActionBar: false,
  ),
  'wind_shear': SpellDefinition(
    id: 'wind_shear',
    spellId: 57994,
    name: 'Wind Shear',
    abbreviation: 'WS',
    school: SpellSchool.nature,
    offGcd: true,
    cooldownId: 'wind_shear',
    onActionBar: false,
  ),
  'lightning_shield': SpellDefinition(
    id: 'lightning_shield',
    spellId: 192106,
    name: 'Lightning Shield',
    abbreviation: 'LS',
    school: SpellSchool.nature,
    onActionBar: false,
  ),
};

const elementalAuras = <AuraDefinition>[
  AuraDefinition(
    id: 'flame_shock',
    spellId: 188389,
    name: 'Flame Shock',
    kind: AuraKind.dot,
    duration: _flameShockDuration,
    description: 'Refreshable below 30% duration (pandemic).',
    quizChance: 0.85,
  ),
  AuraDefinition(
    id: 'master_of_the_elements',
    spellId: 260734,
    name: 'Master of the Elements',
    requiredTalent: ElementalTalents.masterOfTheElements,
    description: 'Lava Burst empowers your next spender.',
  ),
  AuraDefinition(
    id: 'lava_surge',
    spellId: 77762,
    name: 'Lava Surge',
    duration: 10,
    description: 'Next Lava Burst is instant and free.',
  ),
  AuraDefinition(
    id: 'stormkeeper',
    spellId: 191634,
    name: 'Stormkeeper',
    maxStacks: 3,
    requiredTalent: ElementalTalents.stormkeeperTalent,
  ),
  AuraDefinition(
    id: 'tempest',
    spellId: 454015,
    name: 'Tempest',
    maxStacks: 2,
    requiredTalent: ElementalTalents.tempestTalent,
    description: 'Stormbringer: Lightning Bolt becomes Tempest.',
  ),
  AuraDefinition(
    id: 'call_of_the_ancestors',
    spellId: 443450,
    name: 'Call of the Ancestors',
    maxStacks: 5,
    requiredTalent: ElementalTalents.callOfTheAncestors,
    description: 'Farseer: number of active Ancestors.',
  ),
  AuraDefinition(
    id: 'ascendance',
    spellId: 114050,
    name: 'Ascendance',
    requiredTalent: ElementalTalents.ascendanceTalent,
  ),
  AuraDefinition(
    id: 'fire_elemental',
    spellId: 188592,
    name: 'Fire Elemental',
    duration: 30,
  ),
  AuraDefinition(
    id: 'storm_elemental',
    spellId: 192249,
    name: 'Storm Elemental',
    duration: 30,
    requiredTalent: ElementalTalents.stormElemental,
  ),
  AuraDefinition(
    id: 'wind_gust',
    spellId: 263806,
    name: 'Wind Gust',
    maxStacks: 4,
    requiredTalent: ElementalTalents.stormElemental,
  ),
  AuraDefinition(
    id: 'purging_flames',
    spellId: 1259491,
    name: 'Purging Flames',
    requiredTalent: ElementalTalents.purgingFlames,
  ),
  AuraDefinition(
    id: 'flowing_elements',
    spellId: 1300219,
    name: 'Flowing Elements',
    description: 'Tier set proc.',
    quizChance: 0.1,
  ),
  AuraDefinition(
    id: 'overcharge_tier',
    spellId: 1251026,
    name: 'Overcharge',
    description: 'Tier set proc.',
    quizChance: 0.1,
  ),
  AuraDefinition(
    id: 'ancestral_swiftness',
    spellId: 448861,
    name: 'Ancestral Swiftness',
    requiredTalent: ElementalTalents.ancestralSwiftnessTalent,
    description: 'Next cast is instant.',
    quizChance: 0.1,
  ),
  AuraDefinition(
    id: 'natures_swiftness',
    spellId: 378081,
    name: "Nature's Swiftness",
    requiredTalent: ElementalTalents.naturesSwiftnessTalent,
    description: 'Next cast is instant.',
    quizChance: 0.1,
  ),
  AuraDefinition(
    id: 'spiritwalkers_grace',
    spellId: 79206,
    name: "Spiritwalker's Grace",
    description: 'Cast while moving.',
    quizChance: 0,
  ),
  AuraDefinition(
    id: 'bloodlust',
    spellId: 2825,
    name: 'Bloodlust',
    duration: 40,
    quizChance: 0.15,
  ),
  AuraDefinition(
    id: 'lightning_shield',
    spellId: 192106,
    name: 'Lightning Shield',
    quizChance: null,
  ),
];

/// Durations come from in-game tooltips. Where a talent changes them, the
/// value assumes the talents both reference builds take.
const elementalCooldowns = <CooldownDefinition>[
  CooldownDefinition(
    id: 'lava_burst',
    name: 'Lava Burst',
    duration: 8,
    maxCharges: 2,
  ),
  CooldownDefinition(
    id: 'voltaic_blaze',
    name: 'Voltaic Blaze',
    duration: 10,
    requiredTalent: ElementalTalents.voltaicBlazeTalent,
  ),
  // Offering from Beyond takes 3 s off per Ancestor called, so gaps of 40-55 s
  // show up in logs. That depends on play, so this stays the base value.
  CooldownDefinition(
    id: 'stormkeeper',
    name: 'Stormkeeper',
    duration: 60,
    requiredTalent: ElementalTalents.stormkeeperTalent,
  ),
  // 180 s, minus 60 s from First Ascendant.
  CooldownDefinition(
    id: 'ascendance',
    name: 'Ascendance',
    duration: 120,
    requiredTalent: ElementalTalents.ascendanceTalent,
  ),
  CooldownDefinition(
    id: 'ancestral_swiftness',
    name: 'Ancestral Swiftness',
    duration: 30,
    requiredTalent: ElementalTalents.ancestralSwiftnessTalent,
  ),
  CooldownDefinition(
    id: 'natures_swiftness',
    name: "Nature's Swiftness",
    duration: 60,
    requiredTalent: ElementalTalents.naturesSwiftnessTalent,
  ),
  // 120 s, minus 30 s from Graceful Spirit. Logs show two casts 0.2 s apart, so
  // it has at least two charges. Pairs 9-20 s apart suggest faster recharge
  // than this in some logs; the cause isn't known yet.
  CooldownDefinition(
    id: 'spiritwalkers_grace',
    name: "Spiritwalker's Grace",
    duration: 90,
    maxCharges: 2,
  ),
];

/// Talents the APL (or spell availability) cares about. Imported builds
/// may contain many more; those are kept but not shown as toggles.
const elementalTalentToggles = <TalentDefinition>[
  TalentDefinition(
    id: ElementalTalents.callOfTheAncestors,
    name: 'Farseer (Call of the Ancestors)',
    group: 'Hero tree',
    exclusiveWith: [ElementalTalents.tempestTalent],
  ),
  TalentDefinition(
    id: ElementalTalents.tempestTalent,
    name: 'Stormbringer (Tempest)',
    group: 'Hero tree',
    exclusiveWith: [ElementalTalents.callOfTheAncestors],
  ),
  TalentDefinition(
    id: ElementalTalents.ancestralSwiftnessTalent,
    name: 'Ancestral Swiftness (Farseer)',
    group: 'Hero tree',
    description: "Replaces Nature's Swiftness.",
  ),
  TalentDefinition(
    id: ElementalTalents.earthShockTalent,
    name: 'Earth Shock',
    group: 'Spec',
    exclusiveWith: [ElementalTalents.elementalBlastTalent],
    description: 'Choice node with Elemental Blast.',
  ),
  TalentDefinition(
    id: ElementalTalents.elementalBlastTalent,
    name: 'Elemental Blast',
    group: 'Spec',
    exclusiveWith: [ElementalTalents.earthShockTalent],
    description: 'Choice node with Earth Shock.',
  ),
  TalentDefinition(
    id: ElementalTalents.masterOfTheElements,
    name: 'Master of the Elements',
    group: 'Spec',
  ),
  TalentDefinition(
    id: ElementalTalents.eyeOfTheStorm,
    name: 'Eye of the Storm',
    group: 'Spec',
  ),
  TalentDefinition(
    id: ElementalTalents.stormkeeperTalent,
    name: 'Stormkeeper',
    group: 'Spec',
  ),
  TalentDefinition(
    id: ElementalTalents.ascendanceTalent,
    name: 'Ascendance',
    group: 'Spec',
  ),
  TalentDefinition(
    id: ElementalTalents.voltaicBlazeTalent,
    name: 'Voltaic Blaze',
    group: 'Spec',
  ),
  TalentDefinition(
    id: ElementalTalents.purgingFlames,
    name: 'Purging Flames',
    group: 'Spec',
  ),
  TalentDefinition(
    id: ElementalTalents.moltenWrath,
    name: 'Molten Wrath',
    group: 'Spec',
  ),
  TalentDefinition(
    id: ElementalTalents.cracklingFury,
    name: 'Crackling Fury',
    group: 'Spec',
  ),
  TalentDefinition(
    id: ElementalTalents.infernoArc,
    name: 'Inferno Arc',
    group: 'Spec',
  ),
  TalentDefinition(
    id: ElementalTalents.naturesSwiftnessTalent,
    name: "Nature's Swiftness",
    group: 'Class',
  ),
  TalentDefinition(
    id: ElementalTalents.flametongueWeapon,
    name: 'Flametongue Weapon',
    group: 'Class',
  ),
];

const elementalSetBonuses = <SetBonusDefinition>[
  SetBonusDefinition(id: 'mid2_4pc', name: 'Midnight Season 2 (4-piece)'),
];

const elementalUnmodelledActions = <String>{
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

/// Builds from SimulationCraft's `profiles/MID2` directory.
const _simcFarseer =
    'CYQAAAAAAAAAAAAAAAAAAAAAAAAAAAzMbbzMmZmZZbZMMjBAAAAsYmNYADY2YCZWAgZbmZGjtF'
    'TYmxYxMzMmZWsMjFzMMzyAAGGAzMGGGA';
const _simcStormbringer =
    'CYQAAAAAAAAAAAAAAAAAAAAAAAAAAAzMbbzMmZmZZbZgxMDAAAAAWMjhNYBmRDN2AgZbmZGjtF'
    'TYmxYxMzMmZWsMjFzMjZWAAGGYmBGGGA';

final elementalLoadouts = [
  TalentLoadout(
    id: 'simc_farseer',
    name: 'Farseer',
    description: 'SimulationCraft MID2 Farseer profile.',
    exportString: _simcFarseer,
    talents: const TalentStringCodec(shamanTalentTree)
        .decode(_simcFarseer)
        .tokens,
  ),
  TalentLoadout(
    id: 'simc_stormbringer',
    name: 'Stormbringer',
    description: 'SimulationCraft MID2 Stormbringer profile.',
    exportString: _simcStormbringer,
    talents: const TalentStringCodec(shamanTalentTree)
        .decode(_simcStormbringer)
        .tokens,
  ),
];
