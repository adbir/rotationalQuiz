import 'package:flutter/foundation.dart';

/// Warcraft Logs' number for the Maelstrom resource.
const maelstromResourceType = 11;

/// Basic facts about one pull in a report.
@immutable
class LogFight {
  const LogFight({
    required this.id,
    required this.name,
    required this.encounterId,
    required this.kill,
    required this.duration,
    required this.difficulty,
    required this.size,
    this.phaseStarts = const [],
    this.bossActorId,
  });

  final int id;
  final String name;
  final int encounterId;
  final bool kill;
  final Duration duration;

  /// 5 Mythic, 4 Heroic, 3 Normal, 1 LFR.
  final int difficulty;
  final int size;

  /// When each phase began, measured from the pull.
  final List<Duration> phaseStarts;

  /// The boss's id within the report, to tell debuffs on it from those on
  /// adds. `null` when the report doesn't say.
  final int? bossActorId;
}

/// A resource reading attached to a cast.
@immutable
class LogResourceReading {
  const LogResourceReading({
    required this.type,
    required this.amount,
    required this.max,
    this.cost,
  });

  final int type;
  final int amount;
  final int max;
  final int? cost;
}

/// A spell starting or finishing.
@immutable
class LogCast {
  const LogCast({
    required this.time,
    required this.abilityId,
    required this.targetId,
    required this.isBegin,
    this.resources = const [],
    this.targetsHit,
  });

  /// Measured from the pull.
  final Duration time;
  final int abilityId;
  final int targetId;

  /// True for a cast starting, false for one finishing.
  final bool isBegin;
  final List<LogResourceReading> resources;

  /// Enemies this cast's damage hit, for an area ability whose damage was
  /// loaded. `null` when unknown.
  final int? targetsHit;

  LogCast withTargetsHit(int targets) => LogCast(
    time: time,
    abilityId: abilityId,
    targetId: targetId,
    isBegin: isBegin,
    resources: resources,
    targetsHit: targets,
  );
}

/// A resource gain, with how much of it was lost to the cap.
@immutable
class LogResourceGain {
  const LogResourceGain({
    required this.time,
    required this.abilityId,
    required this.type,
    required this.amount,
    required this.waste,
    required this.max,
  });

  final Duration time;
  final int abilityId;
  final int type;
  final int amount;
  final int waste;
  final int max;
}

enum LogBuffChange { apply, applyStack, refresh, removeStack, remove }

/// A buff changing.
@immutable
class LogBuffEvent {
  const LogBuffEvent({
    required this.time,
    required this.abilityId,
    required this.targetId,
    required this.change,
    this.stack,
    this.sourceId,
  });

  final Duration time;
  final int abilityId;
  final int targetId;
  final LogBuffChange change;

  /// Who cast the buff (an id in the report), `null` if the log omits it.
  final int? sourceId;

  /// Stacks after the change, when the log reports them.
  final int? stack;
}

/// A row of the buff table: how long a buff was up and how often it was gained.
@immutable
class LogReceivedBuff {
  const LogReceivedBuff({
    required this.abilityId,
    required this.name,
    required this.uptime,
    required this.uses,
  });

  final int abilityId;
  final String name;
  final Duration uptime;
  final int uses;
}

/// Everything one player did in one pull.
@immutable
class FightLog {
  const FightLog({
    required this.reportCode,
    required this.fight,
    required this.playerName,
    required this.playerId,
    required this.abilityNames,
    required this.casts,
    required this.resourceGains,
    required this.buffEvents,
    required this.talents,
    this.debuffEvents = const [],
    this.receivedBuffs = const [],
    this.appliedBuffs = const [],
  });

  final String reportCode;
  final LogFight fight;
  final String playerName;

  /// The player's id within this report.
  final int playerId;

  /// Ability names by id, for every ability in the report.
  final Map<int, String> abilityNames;

  final List<LogCast> casts;
  final List<LogResourceGain> resourceGains;
  final List<LogBuffEvent> buffEvents;

  /// The player's damage-over-time debuffs on enemies, as the spec lists them.
  /// `targetId` is the enemy hit.
  final List<LogBuffEvent> debuffEvents;

  /// Every buff the player held, from the log's buff table. It has what the
  /// events lack, such as a buff that began before the pull.
  final List<LogReceivedBuff> receivedBuffs;

  /// Every buff the player cast, on anyone, from the buff table read by
  /// caster. Loaded only when the spec keeps an aura up on others; a buff on
  /// several players at once counts up while it is on any of them.
  final List<LogReceivedBuff> appliedBuffs;

  /// SimC talent tokens.
  final Set<String> talents;
}

/// One entry on a boss's rankings.
@immutable
class RankedLog {
  const RankedLog({
    required this.rank,
    required this.playerName,
    required this.amount,
    required this.duration,
    required this.itemLevel,
    required this.reportCode,
    required this.fightId,
  });

  final int rank;
  final String playerName;

  /// Damage per second when ranked on DPS.
  final double amount;
  final Duration duration;
  final int itemLevel;
  final String reportCode;
  final int fightId;
}
