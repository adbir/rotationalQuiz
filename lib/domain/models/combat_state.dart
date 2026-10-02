import 'package:flutter/foundation.dart';

/// State of a buff, debuff or damage-over-time effect.
@immutable
class AuraState {
  const AuraState({this.stacks = 0, this.remains = 0});

  /// An aura that is up with [stacks] and [remains] seconds left.
  const AuraState.up({this.stacks = 1, this.remains = 30});

  static const down = AuraState();

  /// Number of stacks. An aura is up when it has at least one stack.
  final int stacks;

  /// Seconds until the aura expires.
  final double remains;

  bool get isUp => stacks > 0 && remains > 0;

  AuraState copyWith({int? stacks, double? remains}) => AuraState(
    stacks: stacks ?? this.stacks,
    remains: remains ?? this.remains,
  );

  @override
  bool operator ==(Object other) =>
      other is AuraState && other.stacks == stacks && other.remains == remains;

  @override
  int get hashCode => Object.hash(stacks, remains);
}

/// State of a spell cooldown.
@immutable
class CooldownState {
  const CooldownState({this.remains = 0, this.charges});

  static const ready = CooldownState();

  /// Seconds until the spell is off cooldown. For charge-based spells this is
  /// derived from [charges] instead.
  final double remains;

  /// Fractional charges for charge-based spells (e.g. `1.6` means one charge
  /// available and the second 60% recharged). `null` for normal cooldowns.
  final double? charges;

  CooldownState copyWith({double? remains, double? charges}) => CooldownState(
    remains: remains ?? this.remains,
    charges: charges ?? this.charges,
  );

  @override
  bool operator ==(Object other) =>
      other is CooldownState &&
      other.remains == remains &&
      other.charges == charges;

  @override
  int get hashCode => Object.hash(remains, charges);
}

/// A snapshot of everything the APL can ask about: resources, auras,
/// cooldowns, talents and the encounter.
///
/// Missing map entries mean "down" / "ready" / "not talented", which mirrors
/// how SimC treats unknown state.
@immutable
class CombatState {
  const CombatState({
    required this.resource,
    required this.maxResource,
    this.targets = 1,
    this.moving = false,
    this.targetCasting = false,
    this.fightRemains = 180,
    this.gcd = 1.2,
    this.buffs = const {},
    this.debuffs = const {},
    this.dots = const {},
    this.cooldowns = const {},
    this.talents = const {},
    this.setBonuses = const {},
  });

  /// Primary resource (Maelstrom for Elemental Shaman).
  final double resource;
  final double maxResource;

  /// Number of enemies in range (`spell_targets.*`, `active_enemies`).
  final int targets;

  /// Whether the player has to move right now.
  final bool moving;

  /// Whether the target is casting something interruptible.
  final bool targetCasting;

  /// Seconds left in the encounter (`fight_remains`).
  final double fightRemains;

  /// Current global cooldown in seconds (`gcd`).
  final double gcd;

  final Map<String, AuraState> buffs;
  final Map<String, AuraState> debuffs;
  final Map<String, AuraState> dots;
  final Map<String, CooldownState> cooldowns;
  final Set<String> talents;
  final Set<String> setBonuses;

  double get resourceDeficit => maxResource - resource;

  AuraState buff(String name) => buffs[name] ?? AuraState.down;
  AuraState debuff(String name) => debuffs[name] ?? AuraState.down;
  AuraState dot(String name) => dots[name] ?? AuraState.down;
  CooldownState cooldown(String name) => cooldowns[name] ?? CooldownState.ready;
  bool hasTalent(String name) => talents.contains(name);

  CombatState copyWith({
    double? resource,
    double? maxResource,
    int? targets,
    bool? moving,
    bool? targetCasting,
    double? fightRemains,
    double? gcd,
    Map<String, AuraState>? buffs,
    Map<String, AuraState>? debuffs,
    Map<String, AuraState>? dots,
    Map<String, CooldownState>? cooldowns,
    Set<String>? talents,
    Set<String>? setBonuses,
  }) {
    return CombatState(
      resource: resource ?? this.resource,
      maxResource: maxResource ?? this.maxResource,
      targets: targets ?? this.targets,
      moving: moving ?? this.moving,
      targetCasting: targetCasting ?? this.targetCasting,
      fightRemains: fightRemains ?? this.fightRemains,
      gcd: gcd ?? this.gcd,
      buffs: buffs ?? this.buffs,
      debuffs: debuffs ?? this.debuffs,
      dots: dots ?? this.dots,
      cooldowns: cooldowns ?? this.cooldowns,
      talents: talents ?? this.talents,
      setBonuses: setBonuses ?? this.setBonuses,
    );
  }

  CombatState withBuff(String name, AuraState aura) =>
      copyWith(buffs: {...buffs, name: aura});

  CombatState withDot(String name, AuraState aura) =>
      copyWith(dots: {...dots, name: aura});

  CombatState withCooldown(String name, CooldownState cooldown) =>
      copyWith(cooldowns: {...cooldowns, name: cooldown});

  CombatState withTalent(String name, bool enabled) => copyWith(
    talents: enabled ? {...talents, name} : ({...talents}..remove(name)),
  );

  CombatState withSetBonus(String name, bool enabled) => copyWith(
    setBonuses: enabled
        ? {...setBonuses, name}
        : ({...setBonuses}..remove(name)),
  );

  @override
  bool operator ==(Object other) =>
      other is CombatState &&
      other.resource == resource &&
      other.maxResource == maxResource &&
      other.targets == targets &&
      other.moving == moving &&
      other.targetCasting == targetCasting &&
      other.fightRemains == fightRemains &&
      other.gcd == gcd &&
      mapEquals(other.buffs, buffs) &&
      mapEquals(other.debuffs, debuffs) &&
      mapEquals(other.dots, dots) &&
      mapEquals(other.cooldowns, cooldowns) &&
      setEquals(other.talents, talents) &&
      setEquals(other.setBonuses, setBonuses);

  @override
  int get hashCode => Object.hash(
    resource,
    maxResource,
    targets,
    moving,
    targetCasting,
    fightRemains,
    gcd,
    Object.hashAllUnordered(
      buffs.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(
      dots.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(
      cooldowns.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(talents),
    Object.hashAllUnordered(setBonuses),
  );
}
