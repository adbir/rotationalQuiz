import '../models/combat_state.dart';
import '../models/log_rules.dart';
import '../models/spec_definition.dart';
import '../talents/generated/shaman_talent_tree.g.dart';
import '../talents/talent_tree.dart';
import 'restoration_shaman_data.dart';
import 'restoration_shaman_log_data.dart';
import 'rotation_spec.dart';

/// Restoration Shaman. It has no APL, so the sandbox and quiz don't apply;
/// the spec exists for Setup (talent builds) and Boss Evaluation.
class RestorationShaman extends RotationSpec {
  const RestorationShaman();

  @override
  String get id => 'restoration_shaman';

  @override
  String get name => 'Restoration Shaman';

  @override
  String get logClassName => 'Shaman';

  @override
  String get logSpecName => 'Restoration';

  @override
  int get specId => 264;

  @override
  TalentTree get talentTree => shamanTalentTree;

  /// The `subTree` of the Restoration hero selection entries in the tree.
  @override
  Map<int, String> get heroTreeNames => const {54: 'Totemic', 56: 'Farseer'};

  @override
  String get resourceName => 'mana';

  @override
  String get resourceLabel => 'Mana';

  @override
  Map<String, SpellDefinition> get spells => restorationSpells;

  @override
  List<AuraDefinition> get auras => restorationAuras;

  @override
  List<CooldownDefinition> get cooldowns => restorationCooldowns;

  @override
  List<TalentLoadout> get loadouts => restorationLoadouts;

  @override
  SpecLogRules get logRules => restorationLogRules;

  @override
  double maxResource(Set<String> talents) => 100;

  @override
  CombatState defaultState(TalentLoadout loadout) =>
      CombatState(resource: 100, maxResource: 100, talents: loadout.talents);

  @override
  SpellAvailability availability(String spellId, CombatState state) =>
      const SpellAvailability.unavailable('Not modelled');

  @override
  double? resolveScalar(String identifier, CombatState state) => null;
}
