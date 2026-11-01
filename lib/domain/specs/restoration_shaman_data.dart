// Static data for Restoration Shaman: spells, auras, cooldowns and reference
// builds. Ids, costs and cooldowns are sourced in docs/restoration-shaman.md.
import '../models/spec_definition.dart';

/// Talent tokens the tables refer to by name.
abstract final class RestorationTalents {
  static const echoOfTheElements = 'echo_of_the_elements';
  static const healingStreamTotem = 'healing_stream_totem';
  static const stormstreamTotem = 'stormstream_totem';
  static const surgingTotem = 'surging_totem';
  static const ascendance = 'ascendance';
  static const spiritLinkTotem = 'spirit_link_totem';
}

/// There is no quiz, so none of these is on the action bar. Costs are mana, as
/// the logs' `classResources` read them (Flame Shock and Lava Burst: the
/// tooltip's percentage of the 250,000 base mana).
const restorationSpells = <String, SpellDefinition>{
  'riptide': SpellDefinition(
    id: 'riptide',
    spellId: 61295,
    name: 'Riptide',
    abbreviation: 'Rip',
    school: SpellSchool.nature,
    cost: 3800,
    cooldownId: 'riptide',
    usesCharges: true,
    onActionBar: false,
  ),
  'chain_heal': SpellDefinition(
    id: 'chain_heal',
    spellId: 1064,
    name: 'Chain Heal',
    abbreviation: 'CH',
    school: SpellSchool.nature,
    cost: 10700,
    onActionBar: false,
  ),
  'healing_wave': SpellDefinition(
    id: 'healing_wave',
    spellId: 77472,
    name: 'Healing Wave',
    abbreviation: 'HW',
    school: SpellSchool.nature,
    cost: 5950,
    onActionBar: false,
  ),
  'healing_stream_totem': SpellDefinition(
    id: 'healing_stream_totem',
    spellId: 5394,
    name: 'Healing Stream Totem',
    abbreviation: 'HST',
    school: SpellSchool.nature,
    cost: 4500,
    requiredTalent: RestorationTalents.healingStreamTotem,
    cooldownId: 'healing_stream_totem',
    usesCharges: true,
    onActionBar: false,
  ),
  'stormstream_totem': SpellDefinition(
    id: 'stormstream_totem',
    spellId: 1267068,
    name: 'Stormstream Totem',
    abbreviation: 'SST',
    school: SpellSchool.nature,
    cost: 4500,
    requiredTalent: RestorationTalents.stormstreamTotem,
    requiredBuff: 'stormstream_totem',
    onActionBar: false,
  ),
  'surging_totem': SpellDefinition(
    id: 'surging_totem',
    spellId: 444995,
    name: 'Surging Totem',
    abbreviation: 'Surg',
    school: SpellSchool.nature,
    cost: 16250,
    requiredTalent: RestorationTalents.surgingTotem,
    cooldownId: 'surging_totem',
    onActionBar: false,
  ),
  'ascendance': SpellDefinition(
    id: 'ascendance',
    spellId: 114052,
    name: 'Ascendance',
    abbreviation: 'Asc',
    school: SpellSchool.nature,
    offGcd: true,
    requiredTalent: RestorationTalents.ascendance,
    cooldownId: 'ascendance',
    onActionBar: false,
  ),
  'spirit_link_totem': SpellDefinition(
    id: 'spirit_link_totem',
    spellId: 98008,
    name: 'Spirit Link Totem',
    abbreviation: 'SLT',
    school: SpellSchool.nature,
    cost: 5500,
    requiredTalent: RestorationTalents.spiritLinkTotem,
    cooldownId: 'spirit_link_totem',
    onActionBar: false,
  ),
  'earth_shield': SpellDefinition(
    id: 'earth_shield',
    spellId: 974,
    name: 'Earth Shield',
    abbreviation: 'ES',
    school: SpellSchool.earth,
    cost: 5000,
    onActionBar: false,
  ),
  'natures_swiftness': SpellDefinition(
    id: 'natures_swiftness',
    spellId: 378081,
    name: "Nature's Swiftness",
    abbreviation: 'NS',
    school: SpellSchool.nature,
    offGcd: true,
    cooldownId: 'natures_swiftness',
    onActionBar: false,
  ),
  'spiritwalkers_grace': SpellDefinition(
    id: 'spiritwalkers_grace',
    spellId: 79206,
    name: "Spiritwalker's Grace",
    abbreviation: 'SG',
    school: SpellSchool.nature,
    offGcd: true,
    cost: 7050,
    cooldownId: 'spiritwalkers_grace',
    onActionBar: false,
  ),
  'lightning_bolt': SpellDefinition(
    id: 'lightning_bolt',
    spellId: 188196,
    name: 'Lightning Bolt',
    abbreviation: 'LB',
    school: SpellSchool.nature,
    cost: 500,
    castTime: 2.5,
    onActionBar: false,
  ),
  'flame_shock': SpellDefinition(
    id: 'flame_shock',
    spellId: 188389,
    name: 'Flame Shock',
    abbreviation: 'FS',
    school: SpellSchool.fire,
    cost: 750,
    onActionBar: false,
  ),
  'lava_burst': SpellDefinition(
    id: 'lava_burst',
    spellId: 51505,
    name: 'Lava Burst',
    abbreviation: 'LvB',
    school: SpellSchool.fire,
    cost: 1250,
    castTime: 2,
    onActionBar: false,
  ),
};

/// Base cooldowns from the tooltips, in seconds.
const restorationCooldowns = <CooldownDefinition>[
  // A second charge comes from Echo of the Elements, which the build takes.
  CooldownDefinition(
    id: 'riptide',
    name: 'Riptide',
    duration: 6,
    maxCharges: 2,
  ),
  // The second charge comes from the second node.
  CooldownDefinition(
    id: 'healing_stream_totem',
    name: 'Healing Stream Totem',
    duration: 30,
    maxCharges: 2,
    requiredTalent: RestorationTalents.healingStreamTotem,
  ),
  CooldownDefinition(
    id: 'surging_totem',
    name: 'Surging Totem',
    duration: 25,
    requiredTalent: RestorationTalents.surgingTotem,
  ),
  CooldownDefinition(
    id: 'natures_swiftness',
    name: "Nature's Swiftness",
    duration: 60,
  ),
  CooldownDefinition(
    id: 'ascendance',
    name: 'Ascendance',
    duration: 180,
    requiredTalent: RestorationTalents.ascendance,
  ),
  CooldownDefinition(
    id: 'spirit_link_totem',
    name: 'Spirit Link Totem',
    duration: 180,
    requiredTalent: RestorationTalents.spiritLinkTotem,
  ),
  CooldownDefinition(
    id: 'spiritwalkers_grace',
    name: "Spiritwalker's Grace",
    duration: 120,
  ),
];

/// Buffs a healing log reads. `quizChance` is null: there is no quiz.
const restorationAuras = <AuraDefinition>[
  AuraDefinition(
    id: 'healing_rain',
    spellId: 1307888,
    name: 'Healing Rain',
    duration: 25,
    requiredTalent: RestorationTalents.surgingTotem,
    description: "Surging Totem's rain, up as long as the totem.",
    quizChance: null,
  ),
  // Earth Shield is 974 on others and 383648 on the Shaman.
  AuraDefinition(
    id: 'earth_shield',
    spellId: 974,
    name: 'Earth Shield',
    duration: 600,
    quizChance: null,
  ),
  AuraDefinition(
    id: 'earth_shield_self',
    spellId: 383648,
    name: 'Earth Shield (self)',
    duration: 600,
    quizChance: null,
  ),
  AuraDefinition(
    id: 'earthliving',
    spellId: 382024,
    name: 'Earthliving',
    duration: 6,
    quizChance: null,
  ),
  AuraDefinition(
    id: 'tidal_waves',
    spellId: 53390,
    name: 'Tidal Waves',
    maxStacks: 2,
    quizChance: null,
  ),
  AuraDefinition(
    id: 'stormstream_totem',
    spellId: 1267089,
    name: 'Stormstream Totem',
    maxStacks: 2,
    duration: 60,
    requiredTalent: RestorationTalents.stormstreamTotem,
    description: 'Upgrades the next Healing Stream Totem.',
    quizChance: null,
  ),
  AuraDefinition(
    id: 'ascendance',
    spellId: 114052,
    name: 'Ascendance',
    requiredTalent: RestorationTalents.ascendance,
    quizChance: null,
  ),
];

/// The spec and hero talents of the build 14 of the Heroic top 20 run. Class
/// talents are left out: they differ between players.
const _topHeroicTokens = {
  'ancestral_reach',
  'ascendance',
  'coalescing_water',
  'current_control',
  'deeply_rooted_elements',
  'deluge',
  'earthliving_weapon',
  'echo_of_the_elements',
  'healing_rain',
  'healing_stream_totem',
  'living_stream',
  'overflowing_shores',
  'preeminence',
  'primal_tide_core',
  'quickstream',
  'resurgence',
  'rip_current',
  'riptide',
  'soothing_rain',
  'spirit_link_totem',
  'stormstream_totem',
  'swelling_tides',
  'tidal_waves',
  'tidewaters',
  'torrent',
  'undercurrent',
  'water_totem_mastery',
  'wavespeakers_blessing',
  'white_water',
  // Totemic, hero tree 54.
  'amplification_core',
  'earthsurge',
  'elemental_attunement',
  'imbuement_mastery',
  'lively_totems',
  'oversized_totems',
  'primal_catalyst',
  'splitstream',
  'supportive_imbuements',
  'surging_totem',
  'totemic_momentum',
  'totemic_rebound',
  'whirling_elements',
  'wind_barrier',
};

/// Rank 1's own tree, written from that log's `CombatantInfo` (spec and hero
/// talents as in [_topHeroicTokens]). The tree hash is zero, as third-party
/// tools write it.
const topHeroicExport =
    'CgQAAAAAAAAAAAAAAAAAAAAAAAAAAgBAAAAzMzsssNjZGjZGzMYsAbwMWMjtBwMwmZYGmtx'
    'YmZWWmZWMjZhFzMzYwsMAAAwMzgZGAYwM';

const restorationLoadouts = [
  TalentLoadout(
    id: 'top_heroic_totemic',
    name: 'Top Heroic logs, Totemic, 2026-11-01',
    description:
        'The Totemic build 14 of the top 20 Heroic Coiled Altar Restoration '
        "logs run, and the owner's Heroic kill. The export string is rank 1's "
        'full tree, class talents included.',
    exportString: topHeroicExport,
    talents: _topHeroicTokens,
  ),
];
