import '../models/combat_state.dart';
import '../models/spec_definition.dart';
import '../talents/talent_tree.dart';

/// Whether an ability can be pressed right now, and if not, why.
class SpellAvailability {
  const SpellAvailability.available() : reason = null;
  const SpellAvailability.unavailable(String this.reason);

  final String? reason;

  bool get isAvailable => reason == null;
}

/// Everything the sandbox needs to know about one class specialization.
///
/// Implementations describe the spell book and editable state, and answer
/// spec-specific questions such as resource costs. Generic APL expression
/// handling lives in the evaluator.
abstract class RotationSpec {
  const RotationSpec();

  /// Stable id, e.g. `shaman_elemental`.
  String get id;

  /// Display name, e.g. `Elemental Shaman`.
  String get name;

  /// Class and spec names as Warcraft Logs rankings spell them.
  String get logClassName;
  String get logSpecName;

  /// Blizzard specialization id (e.g. `262` for Elemental), used to check
  /// imported talent strings.
  int get specId;

  /// The class talent tree, for decoding talent export strings.
  TalentTree get talentTree;

  /// Display names of hero trees by SimC sub-tree id.
  Map<int, String> get heroTreeNames;

  /// SimC name of the primary resource, e.g. `maelstrom`.
  String get resourceName;

  /// Display name of the primary resource.
  String get resourceLabel;

  /// Bundled APL asset path.
  String get aplAssetPath;

  /// URL of the upstream APL in the SimulationCraft repository.
  Uri get remoteAplUrl;

  /// The SimC action list to evaluate. Usually the top-level list so that
  /// interrupts, defensives and `run_action_list` jumps are respected.
  String get entryList;

  /// The list the user mostly cares about; highlighted in the APL viewer.
  String get focusList;

  Map<String, SpellDefinition> get spells;
  List<AuraDefinition> get auras;
  List<CooldownDefinition> get cooldowns;
  List<TalentDefinition> get talents;
  List<TalentLoadout> get loadouts;
  List<SetBonusDefinition> get setBonuses;

  /// Actions the sandbox deliberately does not model (racials, trinkets,
  /// potions...). They are shown as skipped in the trace.
  Set<String> get unmodelledActions;

  /// Maximum charges of [cooldown] with [talents], or `null` if it doesn't
  /// use charges. Override when talents add charges.
  int? maxCharges(CooldownDefinition cooldown, Set<String> talents) =>
      cooldown.maxCharges;

  /// Maximum primary resource with [talents].
  double maxResource(Set<String> talents);

  /// Returns [state] with [talents], keeping derived values such as the
  /// resource cap consistent.
  CombatState withTalents(CombatState state, Set<String> talents) {
    final max = maxResource(talents);
    return state.copyWith(
      talents: talents,
      maxResource: max,
      resource: state.resource > max ? max : state.resource,
    );
  }

  /// A sensible starting state for [loadout].
  CombatState defaultState(TalentLoadout loadout);

  /// Whether [spellId] can be used in [state].
  SpellAvailability availability(String spellId, CombatState state);

  /// Resolves spec-specific scalar identifiers such as `maelstrom.deficit`.
  /// Generic ones (`buff.*`, `cooldown.*`, `talent.*`, `spell_targets.*`,
  /// `fight_remains`, `gcd`...) are handled by the evaluator.
  /// Returns `null` for identifiers the spec does not know.
  double? resolveScalar(String identifier, CombatState state);

  /// Applies the effect of pressing the off-GCD ability [spellId], so that
  /// later APL lines see e.g. the Ancestral Swiftness buff.
  CombatState applyOffGcd(String spellId, CombatState state) => state;

  /// Effective resource cost of [spell] in [state].
  double costOf(SpellDefinition spell, CombatState state) => spell.cost;

  AuraDefinition? auraDefinition(String id, AuraKind kind) {
    for (final aura in auras) {
      if (aura.id == id && aura.kind == kind) return aura;
    }
    return null;
  }

  CooldownDefinition? cooldownDefinition(String id) {
    for (final cooldown in cooldowns) {
      if (cooldown.id == id) return cooldown;
    }
    return null;
  }

  /// Spells that are known with the talents in [state], in action bar order.
  List<SpellDefinition> knownSpells(CombatState state) => [
    for (final spell in spells.values)
      if ((spell.requiredTalent == null ||
              state.hasTalent(spell.requiredTalent!)) &&
          (spell.replacedByTalent == null ||
              !state.hasTalent(spell.replacedByTalent!)))
        spell,
  ];
}
