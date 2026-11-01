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
  });

  final Duration time;
  final int abilityId;
  final int targetId;
  final LogBuffChange change;

  /// Stacks after the change, when the log reports them.
  final int? stack;
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
