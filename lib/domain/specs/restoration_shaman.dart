import '../models/combat_state.dart';
import '../models/log_rules.dart';
import '../models/spec_definition.dart';
import '../talents/generated/shaman_talent_tree.g.dart';
import '../talents/talent_tree.dart';
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

  /// A placeholder, so a build is always selected. The top-log build replaces
  /// it once the research ticket supplies one.
  @override
  List<TalentLoadout> get loadouts => const [
    TalentLoadout(
      id: 'restoration_none',
      name: 'No build yet',
      talents: {},
      description: 'Import your build in Setup.',
    ),
  ];

  /// Warcraft Logs' resource type 0 is mana.
  @override
  SpecLogRules get logRules => const SpecLogRules(resourceType: 0);

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
