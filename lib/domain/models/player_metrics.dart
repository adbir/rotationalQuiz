import 'package:flutter/foundation.dart';

import 'gap_detail.dart';

/// What one player did in one pull, in numbers two fights can be compared on.
/// A metric says what happened, never why. Effects that depend on the raid are
/// named rather than blended in: see [raidFreeCasts] and
/// [CooldownMetrics.raidDependsOn].
///
/// Damage share, DPS and deaths are left out because `FightLog` doesn't hold
/// them yet.
@immutable
class PlayerMetrics {
  const PlayerMetrics({
    required this.fightLength,
    required this.casts,
    required this.gaps,
    required this.resource,
    required this.spenders,
    required this.cooldowns,
    required this.raidFreeCasts,
    required this.chanceProcs,
  });

  final Duration fightLength;
  final CastMetrics casts;
  final GapMetrics gaps;
  final ResourceMetrics resource;
  final SpenderMetrics spenders;
  final List<CooldownMetrics> cooldowns;
  final List<RaidFreeCastMetrics> raidFreeCasts;
  final List<ChanceProcMetrics> chanceProcs;
}

/// Finished casts, counting each press once.
@immutable
class CastMetrics {
  const CastMetrics({
    required this.total,
    required this.perMinute,
    required this.byAbility,
    required this.byPhase,
  });

  final int total;
  final double perMinute;

  /// Most cast first.
  final List<AbilityCasts> byAbility;

  /// In fight order. A fight with no phases has no entries.
  final List<PhaseCasts> byPhase;
}

@immutable
class AbilityCasts {
  const AbilityCasts({
    required this.abilityId,
    required this.name,
    required this.casts,
    required this.perMinute,
  });

  final int abilityId;
  final String name;
  final int casts;
  final double perMinute;
}

/// One stretch between phase changes. Phases repeat in many fights, so this is
/// a stretch of the fight rather than a numbered phase.
@immutable
class PhaseCasts {
  const PhaseCasts({
    required this.start,
    required this.length,
    required this.casts,
    required this.perMinute,
  });

  final Duration start;
  final Duration length;
  final int casts;
  final double perMinute;
}

/// Time between cast events when no finished cast was in progress. A cancelled
/// cast counts as activity that stopped where it started, because the log
/// doesn't show when it was cancelled.
@immutable
class GapMetrics {
  const GapMetrics({
    required this.threshold,
    required this.count,
    required this.longest,
    this.details = const [],
  });

  /// The shortest time that counts as a gap.
  final Duration threshold;

  /// Gaps over [threshold].
  final int count;
  final Duration longest;

  /// Every gap over [threshold], in fight order.
  final List<GapDetail> details;
}

/// Gains of the spec's primary resource. [gained] includes [wasted].
@immutable
class ResourceMetrics {
  const ResourceMetrics({
    required this.gained,
    required this.wasted,
    required this.gainedPerMinute,
    required this.wastedPerMinute,
  });

  final int gained;
  final int wasted;
  final double gainedPerMinute;
  final double wastedPerMinute;

  double get wastedPercent => gained == 0 ? 0 : wasted / gained * 100;
}

/// Spender casts. A higher [withBuffPercent] isn't simply better: some spenders
/// are right without the buff, which is why [skippedBuff] sits next to it.
@immutable
class SpenderMetrics {
  const SpenderMetrics({
    required this.casts,
    required this.free,
    required this.lostFree,
    this.lostFreeDetails = const [],
    this.withBuff,
    this.skippedBuff,
    this.buffName,
  });

  final int casts;

  /// Spenders that cost nothing.
  final int free;

  /// Free spenders lost to a refresh of the buff that gives them.
  final int lostFree;

  /// When each was lost and what gave the buff.
  final List<LostFreeSpender> lostFreeDetails;

  /// Spenders with the spec's spender buff up, or `null` without the talent.
  final int? withBuff;

  /// Spenders without that buff while the procs that justify skipping it were
  /// up, or `null` without the talent.
  final int? skippedBuff;
  final String? buffName;

  double? get withBuffPercent =>
      withBuff == null || casts == 0 ? null : withBuff! / casts * 100;
}

/// One cooldown's use. Drift is how long after the cooldown came ready the
/// next normal use started, so it counts from the shortest possible gap.
@immutable
class CooldownMetrics {
  const CooldownMetrics({
    required this.id,
    required this.name,
    required this.cooldown,
    required this.uses,
    required this.freeUses,
    required this.earlyPresses,
    this.averageDrift,
    this.medianDrift,
    this.shortening,
    this.raidDependsOn = const [],
  });

  final String id;
  final String name;

  /// Seconds, with the player's talents, before anything shortens it in play.
  final double cooldown;

  /// Every cast, free or not.
  final int uses;

  /// Casts another player paid for.
  final int freeUses;

  int get normalUses => uses - freeUses;

  /// Normal uses that came sooner than the cooldown allows. Something shortened
  /// it that the log doesn't show. Their drift counts as zero.
  final int earlyPresses;

  /// Seconds, or `null` with fewer than two normal uses.
  final double? averageDrift;
  final double? medianDrift;

  /// Set when a proc shortens this cooldown during the fight. Drift already
  /// allows for it.
  final CooldownShortening? shortening;

  /// Raid effects that change this cooldown's numbers.
  final List<String> raidDependsOn;
}

/// How much a proc shortened a cooldown, per gap between uses.
@immutable
class CooldownShortening {
  const CooldownShortening({
    required this.procName,
    required this.secondsPerCycle,
    required this.fewestProcs,
    required this.mostProcs,
  });

  final String procName;
  final double secondsPerCycle;
  final int fewestProcs;
  final int mostProcs;
}

/// Casts paid for by a buff from another player. How many a player gets
/// depends on the raid, so this isn't a measure of their play.
@immutable
class RaidFreeCastMetrics {
  const RaidFreeCastMetrics({
    required this.name,
    required this.available,
    required this.spent,
    required this.refreshedByNormalCast,
  });

  final String name;

  /// Uses the player had. Overlapping buffs are one use.
  final int available;
  final int spent;

  int get unspent => available - spent;

  /// When a normal cast straight after a free one only refreshed its buff.
  final List<Duration> refreshedByNormalCast;
}

/// A chance-based proc compared with what its rules predict.
@immutable
class ChanceProcMetrics {
  const ChanceProcMetrics({
    required this.name,
    required this.actual,
    required this.expected,
    required this.spread,
    required this.perCast,
    this.note,
  });

  final String name;
  final int actual;

  /// Only uses terms for talents the player took.
  final double expected;

  /// One standard deviation of [actual] if every roll were independent. Read
  /// [luck] next to this: it isn't a verdict.
  final double spread;

  /// Procs per finished cast of any ability.
  final double perCast;

  /// Anything known to be missing from [expected].
  final String? note;

  double get luck => actual - expected;
}
