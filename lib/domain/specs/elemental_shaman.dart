import '../models/combat_state.dart';
import '../models/log_rules.dart';
import '../models/spec_definition.dart';
import '../talents/generated/shaman_talent_tree.g.dart';
import '../talents/talent_tree.dart';
import 'elemental_shaman_data.dart';
import 'elemental_shaman_log_data.dart';
import 'rotation_spec.dart';

/// Elemental Shaman, modelled for the single-target sandbox.
///
/// Numbers here (costs, durations, cooldowns) are approximations used to
/// decide whether a button is pressable. The *priority* itself always comes
/// from the SimC APL, so keep these in sync with the game when patches land.
class ElementalShaman extends RotationSpec {
  const ElementalShaman();

  @override
  String get id => 'shaman_elemental';

  @override
  String get name => 'Elemental Shaman';

  @override
  String get logClassName => 'Shaman';

  @override
  String get logSpecName => 'Elemental';

  @override
  int get specId => 262;

  @override
  TalentTree get talentTree => shamanTalentTree;

  @override
  Map<int, String> get heroTreeNames => const {
    54: 'Totemic',
    55: 'Stormbringer',
    56: 'Farseer',
  };

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
  Map<String, SpellDefinition> get spells => elementalSpells;

  @override
  List<AuraDefinition> get auras => elementalAuras;

  @override
  List<CooldownDefinition> get cooldowns => elementalCooldowns;

  @override
  List<TalentDefinition> get talents => elementalTalentToggles;

  @override
  List<TalentLoadout> get loadouts => elementalLoadouts;

  @override
  List<SetBonusDefinition> get setBonuses => elementalSetBonuses;

  @override
  Set<String> get unmodelledActions => elementalUnmodelledActions;

  @override
  SpecLogRules get logRules => elementalLogRules;

  /// The cooldown table assumes First Ascendant (60 s off) and Graceful Spirit
  /// (30 s off), which not every log has.
  @override
  double cooldownDuration(CooldownDefinition cooldown, Set<String> talents) =>
      cooldown.duration +
      switch (cooldown.id) {
        'ascendance' when !talents.contains(ElementalTalents.firstAscendant) =>
          60,
        'spiritwalkers_grace'
            when !talents.contains(ElementalTalents.gracefulSpirit) =>
          30,
        _ => 0,
      };

  /// Swelling Maelstrom adds 50 and Primordial Capacity adds 25 (in-game
  /// tooltips; a rank-1 Farseer log shows a cap of 125).
  @override
  int? maxCharges(CooldownDefinition cooldown, Set<String> talents) {
    if (cooldown.id != 'lava_burst') return super.maxCharges(cooldown, talents);
    return 1 +
        (talents.contains(ElementalTalents.echoOfTheElements) ? 1 : 0) +
        (talents.contains(ElementalTalents.elementalReverb) ? 1 : 0);
  }

  @override
  double maxResource(Set<String> talents) =>
      100 +
      (talents.contains(ElementalTalents.swellingMaelstrom) ? 50 : 0) +
      (talents.contains(ElementalTalents.primordialCapacity) ? 25 : 0);

  @override
  CombatState defaultState(TalentLoadout loadout) {
    return CombatState(
      resource: 40,
      maxResource: maxResource(loadout.talents),
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
    var cost = spell.cost;
    if (state.hasTalent(ElementalTalents.eyeOfTheStorm)) {
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
    return switch (identifier) {
      'maelstrom' => state.resource,
      'maelstrom.deficit' => state.resourceDeficit,
      'maelstrom.max' => state.maxResource,
      'maelstrom.pct' => state.resource / state.maxResource * 100,
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
      'spiritwalkers_grace' => next.withBuff(
        spellId,
        const AuraState.up(remains: 15),
      ),
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
