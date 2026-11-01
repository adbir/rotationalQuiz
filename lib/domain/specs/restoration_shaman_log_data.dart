// How Restoration Shaman appears in Warcraft Logs. Ids come from three Heroic
// Coiled Altar logs (docs/restoration-shaman.md).
import '../models/log_rules.dart';

const restorationLogRules = SpecLogRules(
  // Warcraft Logs' resource type 0 is mana.
  resourceType: 0,
  // Healers are ranked on healing per second, not damage.
  rankingMetric: 'hps',
  // Earth Shield is 974 on others and 383648 on the Shaman.
  castAliases: {383648: 974},
  // Source of Magic's id is in no checked source yet.
  raidSupportIds: {29166: 'Innervate'},
  auraLogIds: {
    'healing_rain': {1307888},
    'earth_shield': {974},
    'earth_shield_self': {383648},
    'earthliving': {382024},
    'tidal_waves': {53390},
    'stormstream_totem': {1267089},
    'ascendance': {114052},
  },
);
