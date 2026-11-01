// How Restoration Shaman appears in Warcraft Logs. Ids come from three Heroic
// Coiled Altar logs (docs/restoration-shaman.md).
import '../models/finding.dart';
import '../models/log_rules.dart';

const _healingRain = 1307888;
const _earthShield = 974;
const _earthliving = 382024;
const _stormstreamProc = 1267089;
const _stormstreamTotem = 1267068;
const _riptide = 61295;
const _innervate = 29166;

/// Casts against possible, on a 0 to 100 scale.
RankedMetric _possible(String cooldownId, String whatToTry) => RankedMetric(
  FindingKind.castsAgainstPossible,
  cooldownId: cooldownId,
  higherIsBetter: true,
  fullScale: 100,
  whatToTry: whatToTry,
);

/// Uptime, on a 0 to 100 scale.
RankedMetric _upkeep(int buffId, String whatToTry) => RankedMetric(
  FindingKind.upkeep,
  abilityId: buffId,
  higherIsBetter: true,
  fullScale: 100,
  whatToTry: whatToTry,
);

final restorationLogRules = SpecLogRules(
  // Warcraft Logs' resource type 0 is mana.
  resourceType: 0,
  // Healers are ranked on healing per second, not damage.
  rankingMetric: 'hps',
  // Earth Shield is 974 on others and 383648 on the Shaman.
  castAliases: const {383648: _earthShield},
  // Source of Magic lands on the Shaman as 372571 (the fixture's abilities
  // table); the Evoker's cast is 369459 on Wowhead.
  raidSupportIds: const {_innervate: 'Innervate', 372571: 'Source of Magic'},
  auraLogIds: const {
    'healing_rain': {_healingRain},
    'earth_shield': {_earthShield},
    'earth_shield_self': {383648},
    'earthliving': {_earthliving},
    'tidal_waves': {53390},
    'stormstream_totem': {_stormstreamProc},
    'ascendance': {114052},
  },
  // A Stormstream Totem cast restores a Healing Stream charge (Wowhead).
  // Riptide is left out until what shortens its cooldown is known.
  possibleCasts: const [
    PossibleCastsRule(
      'healing_stream_totem',
      restoredByCastIds: {_stormstreamTotem},
    ),
    PossibleCastsRule('surging_totem'),
    PossibleCastsRule('ascendance'),
    PossibleCastsRule('spirit_link_totem'),
    PossibleCastsRule('natures_swiftness'),
  ],
  upkeepAuras: const [
    UpkeepAura(buffId: _healingRain, name: 'Healing Rain'),
    UpkeepAura(buffId: _earthShield, name: 'Earth Shield', onOthers: true),
    // Shown, not ranked: rank 50 kept Earth Shield only on itself.
    UpkeepAura(buffId: 383648, name: 'Earth Shield (self)'),
    UpkeepAura(buffId: _earthliving, name: 'Earthliving', onOthers: true),
  ],
  heldProcs: const [
    HeldProcRule(buffId: _stormstreamProc, name: 'Stormstream Totem'),
  ],
  // Every cast inside Innervate is free. Its count stays in raid support.
  freeCastWindows: const [
    FreeCastWindowRule(buffId: _innervate, name: 'Innervate'),
  ],
  readsResourceLevel: true,
  // The units differ (percent, seconds, casts a minute), so the ones behind
  // are ordered by share. Mana at phase changes is shown, not ranked: without
  // the boss's health, neither direction is behind (docs/warcraft-logs.md).
  findings: FindingRules([
    const RankedMetric(FindingKind.castsPerMinute, higherIsBetter: true),
    _possible(
      'surging_totem',
      'Cast Surging Totem each time it comes off cooldown.',
    ),
    _upkeep(
      _healingRain,
      'Keep Surging Totem down so Healing Rain never stops.',
    ),
    const RankedMetric(
      FindingKind.abilityCastsPerMinute,
      abilityId: _riptide,
      higherIsBetter: true,
      whatToTry: 'Cast Riptide whenever it has a charge.',
    ),
    _possible(
      'healing_stream_totem',
      'Cast Healing Stream Totem whenever it has a charge.',
    ),
    const RankedMetric(
      FindingKind.procHoldTime,
      abilityId: _stormstreamProc,
      whatToTry: 'Cast Stormstream Totem as soon as it procs.',
    ),
    _possible('ascendance', 'Cast Ascendance each time it comes off cooldown.'),
    _possible(
      'spirit_link_totem',
      'Cast Spirit Link Totem each time it comes off cooldown.',
    ),
    _possible(
      'natures_swiftness',
      "Cast Nature's Swiftness each time it comes off cooldown.",
    ),
    const RankedMetric(
      FindingKind.resourceAtEnd,
      fullScale: 100,
      whatToTry: 'Spend your mana so that it runs out as the boss dies.',
    ),
    // Absent from a log with no Innervate, so no one is behind for not
    // receiving one. Wowhead and Icy Veins state no rule: the owner's
    // (docs/restoration-shaman.md).
    const RankedMetric(
      FindingKind.freeCastValue,
      abilityId: _innervate,
      higherIsBetter: true,
      onlyWhenSeen: true,
      whatToTry: 'Cast Chain Heal back to back while Innervate is up.',
    ),
    _upkeep(_earthShield, 'Keep Earth Shield on a tank all fight.'),
    _upkeep(_earthliving, 'Keep Earthliving Weapon on all fight.'),
  ], orderByShare: true),
);
