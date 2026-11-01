import 'package:flutter/foundation.dart';

import 'finding.dart';

/// How a spec shows up in a Warcraft Logs fight, as a table the metrics read.
///
/// Ids are the ones logged, and a buff's id can differ from its cast's. Spell
/// cast ids and cooldowns come from the spec's own tables.
@immutable
class SpecLogRules {
  const SpecLogRules({
    required this.resourceType,
    this.duplicateCastIds = const {},
    this.castAliases = const {},
    this.spenderBuffId,
    this.spenderBuffTalent,
    this.spenderBuffSkipIds = const {},
    this.freeSpenderBuffIds = const {},
    this.freeSpenderSourceIds = const {},
    this.movementFormId,
    this.graceId,
    this.castsBeforeWindow = const [],
    this.raidFreeCasts = const [],
    this.raidCooldownSupport = const {},
    this.raidSupportIds = const {},
    this.chanceProcs = const [],
    this.auraLogIds = const {},
    this.rankingMetric = 'dps',
    this.unobservableAuras = const {},
    this.aoeDamage = const {},
    this.possibleCasts = const [],
    this.upkeepAuras = const [],
    this.heldProcs = const [],
    this.freeCastWindows = const [],
    this.readsResourceLevel = false,
    this.findings = const FindingRules([]),
  });

  /// Cooldowns counted against the most casts the fight allowed.
  final List<PossibleCastsRule> possibleCasts;

  /// Auras the player keeps up, on themselves or on others.
  final List<UpkeepAura> upkeepAuras;

  /// Procs whose buff should be spent soon after it comes.
  final List<HeldProcRule> heldProcs;

  /// Buffs from other players that make every cast free for a while.
  final List<FreeCastWindowRule> freeCastWindows;

  /// Whether the metrics read the resource's level from cast readings: at
  /// each phase change, at the end and at its lowest.
  final bool readsResourceLevel;

  /// Which metrics are ranked against rank 1, and what "behind" means.
  final FindingRules findings;

  /// Warcraft Logs' number for the spec's primary resource.
  final int resourceType;

  /// Cast events that fire alongside another cast and aren't a press.
  final Set<int> duplicateCastIds;

  /// Logged cast ids that are the same press as the spec's spell id, such as
  /// a second version of a spell. Loading a fight maps the key to the value.
  final Map<int, int> castAliases;

  /// The buff a player aims to spend on spenders, if the spec has one.
  final int? spenderBuffId;

  /// The talent that gives [spenderBuffId].
  final String? spenderBuffTalent;

  /// With all of these up, a spender without [spenderBuffId] is correct play.
  final Set<int> spenderBuffSkipIds;

  /// Buffs that make a spender cost nothing. Refreshing one loses a free
  /// spender.
  final Set<int> freeSpenderBuffIds;

  /// Buffs whose fading eventually gives free spenders, for naming where a
  /// lost one came from.
  final Set<int> freeSpenderSourceIds;

  /// A form or buff the player moves in, cast or up. Gaps note it.
  final int? movementFormId;

  /// The spell that lets the player cast while moving. Its cast and buff share
  /// this id, and its cooldown comes from the spec's spell table.
  final int? graceId;

  /// Casts that belong before a buff window, not inside it.
  final List<CastBeforeWindow> castsBeforeWindow;

  /// Buffs from other players that pay for a cast.
  final List<RaidFreeCast> raidFreeCasts;

  /// Names of raid effects that change a cooldown, by cooldown id. They can't
  /// be told from a player's own timing, so results name them.
  final Map<String, List<String>> raidCooldownSupport;

  /// Buffs from other players worth showing beside a comparison, by logged id
  /// to display name. Shown, never blended into a score.
  final Map<int, String> raidSupportIds;

  final List<ChanceProcRule> chanceProcs;

  /// Buff ids as logged, by aura id, where they differ from the aura's spell
  /// id (Ascendance casts as 114050 and its buff is 1219480).
  final Map<String, Set<int>> auraLogIds;

  /// The Warcraft Logs ranking metric that sorts the spec's top logs: `dps`,
  /// or `hps` for a healer.
  final String rankingMetric;

  /// Auras a fight's events never show, so a replay can only guess them.
  final Set<String> unobservableAuras;

  /// Where an area cast's hits show up, by the cast's id.
  final Map<int, AoeDamage> aoeDamage;
}

/// The damage events that show who an area cast hit.
@immutable
class AoeDamage {
  const AoeDamage(this.damageId, {required this.within});

  /// The ability id on the damage events.
  final int damageId;

  /// How long after the cast its first hits land. A ticking effect lands its
  /// first tick this late, and later ticks are left out.
  final Duration within;
}

/// A cast that belongs before the buff [windowBuffId], because casting it
/// inside the window spends the window's time.
@immutable
class CastBeforeWindow {
  const CastBeforeWindow({
    required this.castId,
    required this.windowBuffId,
    required this.name,
  });

  final int castId;
  final int windowBuffId;

  /// What the finding calls it, such as "Stormkeeper during Ascendance".
  final String name;
}

/// A buff from another player that pays for one of [castIds].
@immutable
class RaidFreeCast {
  const RaidFreeCast({
    required this.name,
    required this.buffId,
    required this.castIds,
  });

  final String name;
  final int buffId;

  /// What the buff can be spent on. A free cast doesn't start the cooldown.
  final Set<int> castIds;
}

/// A proc that is part guaranteed and part chance, and may shorten a cooldown
/// each time it happens.
@immutable
class ChanceProcRule {
  const ChanceProcRule({
    required this.name,
    required this.requiredTalent,
    required this.buffIds,
    required this.guaranteedCastIds,
    required this.rollCastIds,
    required this.rollChance,
    required this.rollTalent,
    required this.repeatChance,
    required this.repeatTalent,
    this.cooldownId,
    this.cooldownSecondsPerProc = 0,
    this.cooldownTalent,
    this.note,
  });

  final String name;
  final String requiredTalent;

  /// Each application or added stack of these is one proc.
  final Set<int> buffIds;

  /// Casts that always give a proc.
  final Set<int> guaranteedCastIds;

  /// Casts that give a proc [rollChance] of the time, with [rollTalent].
  final Set<int> rollCastIds;
  final double rollChance;
  final String rollTalent;

  /// Chance that one proc gives another, with [repeatTalent].
  final double repeatChance;
  final String repeatTalent;

  /// The cooldown each proc shortens by [cooldownSecondsPerProc], with
  /// [cooldownTalent].
  final String? cooldownId;
  final double cooldownSecondsPerProc;
  final String? cooldownTalent;

  /// Anything known to be missing from the expected number.
  final String? note;
}

/// A cooldown whose casts are counted against the most the fight allowed:
/// its charges, one more per full cooldown, and one per cast that restores a
/// charge. The cooldown is the spec's own, before anything shortens it.
@immutable
class PossibleCastsRule {
  const PossibleCastsRule(this.cooldownId, {this.restoredByCastIds = const {}});

  final String cooldownId;

  /// Casts that each give back one charge.
  final Set<int> restoredByCastIds;
}

/// An aura the player keeps up. Its uptime comes from the log's buff table:
/// the player's own for an aura on them, the one of buffs they cast for an
/// aura on others. On others, the table counts it up while it is on anyone.
@immutable
class UpkeepAura {
  const UpkeepAura({
    required this.buffId,
    required this.name,
    this.onOthers = false,
  });

  final int buffId;
  final String name;
  final bool onOthers;
}

/// A proc whose buff waits on the player to spend it.
@immutable
class HeldProcRule {
  const HeldProcRule({required this.buffId, required this.name});

  final int buffId;
  final String name;
}

/// A buff on the player, from someone else, that makes every cast free while
/// it is up. The metrics list what was cast inside each window.
@immutable
class FreeCastWindowRule {
  const FreeCastWindowRule({required this.buffId, required this.name});

  final int buffId;
  final String name;
}
