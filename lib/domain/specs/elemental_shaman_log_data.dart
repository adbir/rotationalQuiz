// How Elemental Shaman appears in Warcraft Logs. Ids and rates were checked
// against three Mythic Sszorak logs (issue #10).
import '../models/fight_log.dart';
import '../models/log_rules.dart';
import 'elemental_shaman_data.dart';

const _lightningBolt = 188196;
const _lavaBurst = 51505;
const _flameShock = 188389;
const _voltaicBlaze = 470057;
const _chainLightning = 188443;
const _stormkeeper = 191634;
const _ancestralSwiftness = 443454;
const _spiritwalkersGrace = 79206;
const _gustOfWind = 192063;
const _ghostWolf = 2645;
const _ascendance = 114050;

const elementalLogRules = SpecLogRules(
  resourceType: maelstromResourceType,
  // Fires with every Flame Shock (188389) cast.
  duplicateCastIds: {470411},
  // Earthquake cast on the cursor (61882) is the same press as on the target
  // (462620), the id in the spell table.
  castAliases: {61882: 462620},
  spenderBuffId: 260734,
  spenderBuffTalent: ElementalTalents.masterOfTheElements,
  // With Flowing Elements and Overcharge! both up, a spender is right even
  // without Master of the Elements.
  spenderBuffSkipIds: {1300219, 1300222},
  // Overcharge!, from the Season 2 set. It is often the only sign of a free
  // spender, since few casts carry a Maelstrom reading.
  freeSpenderBuffIds: {1300222},
  // Flowing Elements (1300219) comes from the fade of either (docs).
  freeSpenderSourceIds: {_stormkeeper, _ascendance},
  movementFormId: _ghostWolf,
  graceId: _spiritwalkersGrace,
  raidFreeCasts: [
    RaidFreeCast(
      name: 'Time Spiral',
      buffId: 375256,
      castIds: {_spiritwalkersGrace, _gustOfWind},
    ),
  ],
  // Blessing of the Bronze takes 15% off, and a log shows gaps down to 78 s. It
  // goes up before the pull, so a fight's buff events never show it.
  raidCooldownSupport: {
    'spiritwalkers_grace': ['Time Spiral', 'Blessing of the Bronze'],
  },
  chanceProcs: [
    // Sources: Wowhead tooltips and `summon_ancestor` in SimC's sc_shaman.cpp.
    ChanceProcRule(
      name: 'Ancestors',
      requiredTalent: ElementalTalents.callOfTheAncestors,
      buffIds: {447244, 445624},
      guaranteedCastIds: {_stormkeeper, _ancestralSwiftness},
      rollCastIds: {
        _lightningBolt,
        _lavaBurst,
        _flameShock,
        _voltaicBlaze,
        _chainLightning,
      },
      rollChance: 0.08,
      rollTalent: ElementalTalents.routineCommunication,
      repeatChance: 0.2,
      repeatTalent: ElementalTalents.ancientFellowship,
      cooldownId: 'stormkeeper',
      cooldownSecondsPerProc: 3,
      cooldownTalent: ElementalTalents.offeringFromBeyond,
      note:
          'Expected runs 1.4 to 2.8 under actual in three logs. Ascendance '
          'also rolls in SimC and is not counted here, which is the likely '
          'reason.',
    ),
  ],
);
