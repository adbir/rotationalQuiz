import 'package:flutter/foundation.dart';

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
    this.raidFreeCasts = const [],
    this.raidCooldownSupport = const {},
    this.chanceProcs = const [],
  });

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

  /// Buffs from other players that pay for a cast.
  final List<RaidFreeCast> raidFreeCasts;

  /// Names of raid effects that change a cooldown, by cooldown id. They can't
  /// be told from a player's own timing, so results name them.
  final Map<String, List<String>> raidCooldownSupport;

  final List<ChanceProcRule> chanceProcs;
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
