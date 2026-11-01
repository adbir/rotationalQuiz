import '../../domain/models/enemy_group.dart';
import '../../domain/models/fight_log.dart';
import '../../domain/models/log_rules.dart';
import '../services/warcraft_logs_service.dart';

/// Turns raw Warcraft Logs JSON into domain models. Malformed rows are
/// skipped, so one odd event can't lose a whole fight.
abstract final class WarcraftLogsMapper {
  /// Start of the fight within the report, in report time.
  static num fightStart(JsonMap fight) => (fight['startTime'] as num?) ?? 0;

  /// End of the fight within the report, in report time.
  static num fightEnd(JsonMap fight) => (fight['endTime'] as num?) ?? 0;

  static LogFight fight(JsonMap json) {
    final start = fightStart(json);
    final phases = json['phaseTransitions'];
    final enemies = json['enemyNPCs'];
    return LogFight(
      id: _int(json['id']) ?? 0,
      name: json['name'] as String? ?? '',
      encounterId: _int(json['encounterID']) ?? 0,
      kill: json['kill'] == true,
      duration: _since(fightEnd(json), start),
      difficulty: _int(json['difficulty']) ?? 0,
      size: _int(json['size']) ?? 0,
      phaseStarts: [
        if (phases is List)
          for (final phase in phases.whereType<JsonMap>())
            if (phase['startTime'] case final num time) _since(time, start),
      ],
      // ponytail: the first enemy with a single copy. Twin Fangs has two
      // bosses; the first listed (Vexhul) stands for both.
      bossActorId: enemies is List
          ? _int(
              enemies
                  .whereType<JsonMap>()
                  .where((e) => e['instanceCount'] == 1)
                  .firstOrNull?['id'],
            )
          : null,
    );
  }

  static LogCast? cast(
    JsonMap json,
    num start, {
    Map<int, int> aliases = const {},
  }) {
    final type = json['type'];
    final time = json['timestamp'];
    final ability = _int(json['abilityGameID']);
    if ((type != 'cast' && type != 'begincast') ||
        time is! num ||
        ability == null) {
      return null;
    }
    final readings = json['classResources'];
    return LogCast(
      time: _since(time, start),
      abilityId: aliases[ability] ?? ability,
      targetId: _int(json['targetID']) ?? -1,
      isBegin: type == 'begincast',
      resources: [
        if (readings is List)
          for (final reading in readings.whereType<JsonMap>())
            ?_reading(reading),
      ],
    );
  }

  static LogResourceGain? resourceGain(JsonMap json, num start) {
    final time = json['timestamp'];
    final ability = _int(json['abilityGameID']);
    final type = _int(json['resourceChangeType']);
    final amount = _int(json['resourceChange']);
    if (json['type'] != 'resourcechange' ||
        time is! num ||
        ability == null ||
        type == null ||
        amount == null) {
      return null;
    }
    return LogResourceGain(
      time: _since(time, start),
      abilityId: ability,
      type: type,
      amount: amount,
      waste: _int(json['waste']) ?? 0,
      max: _int(json['maxResourceAmount']) ?? 0,
    );
  }

  static LogBuffEvent? buffEvent(JsonMap json, num start) {
    final change = switch (json['type']) {
      'applybuff' || 'applydebuff' => LogBuffChange.apply,
      'applybuffstack' => LogBuffChange.applyStack,
      'refreshbuff' || 'refreshdebuff' => LogBuffChange.refresh,
      'removebuffstack' => LogBuffChange.removeStack,
      'removebuff' || 'removedebuff' => LogBuffChange.remove,
      _ => null,
    };
    final time = json['timestamp'];
    final ability = _int(json['abilityGameID']);
    if (change == null || time is! num || ability == null) return null;
    return LogBuffEvent(
      time: _since(time, start),
      abilityId: ability,
      targetId: _int(json['targetID']) ?? -1,
      change: change,
      stack: _int(json['stack']),
      sourceId: _int(json['sourceID']),
    );
  }

  /// The rows of a buff table (`data` of `table(dataType: Buffs)`).
  static List<LogReceivedBuff> receivedBuffs(JsonMap table) {
    final auras = table['auras'];
    return [
      if (auras is List)
        for (final row in auras.whereType<JsonMap>())
          if (_int(row['guid']) case final id?)
            LogReceivedBuff(
              abilityId: id,
              name: row['name'] as String? ?? '',
              uptime: Duration(milliseconds: _int(row['totalUptime']) ?? 0),
              uses: _int(row['totalUses']) ?? 0,
            ),
    ];
  }

  /// One kind of enemy, with when each copy first acted and when it was gone.
  /// [casts] are the NPC's cast events, and `sourceInstance` tells its copies
  /// apart. [endEvents] are events on the copies (`targetInstance`): their deaths, or
  /// the damage they took. A copy is gone at its last one; a copy with none is
  /// gone as it arrives when [unseenGoneAtArrival], else up until the fight
  /// ends.
  static EnemyGroup enemyGroup(
    String name,
    List<JsonMap> casts,
    num start, {
    List<JsonMap> endEvents = const [],
    bool unseenGoneAtArrival = false,
  }) {
    final first = <int, num>{};
    for (final cast in casts) {
      final time = cast['timestamp'];
      if (time is num) {
        first.putIfAbsent(_int(cast['sourceInstance']) ?? 0, () => time);
      }
    }
    final last = <int, num>{};
    for (final event in endEvents) {
      final time = event['timestamp'];
      final instance = _int(event['targetInstance']) ?? 0;
      if (time is num && (last[instance] ?? time) <= time) {
        last[instance] = time;
      }
    }
    final instances = first.keys.toList()
      ..sort((a, b) => first[a]!.compareTo(first[b]!));
    return EnemyGroup(
      name: name,
      arrivals: [for (final i in instances) _since(first[i]!, start)],
      departures: [
        for (final i in instances)
          if (last[i] case final num end)
            _since(end > first[i]! ? end : first[i]!, start)
          else if (unseenGoneAtArrival)
            _since(first[i]!, start)
          else
            null,
      ],
    );
  }

  /// The enemy NPCs the player really damaged: some hit for at least 1% of
  /// what it would have done. Hits on an immune or absorbing enemy land for 0,
  /// or for 1 from a tick, and don't count.
  static Set<int> damagedTargets(List<JsonMap> damage, int playerId) {
    final targets = <int>{};
    for (final row in damage) {
      final target = _int(row['targetID']);
      final amount = row['amount'];
      final raw = row['unmitigatedAmount'];
      if (target != null &&
          _int(row['sourceID']) == playerId &&
          amount is num &&
          amount > 0 &&
          (raw is! num || amount * 100 >= raw)) {
        targets.add(target);
      }
    }
    return targets;
  }

  /// Sets [LogCast.targetsHit] on each finished cast of an area ability in
  /// [rules]: the distinct enemies the player's [damage] events hit within the
  /// rule's time after the cast. A cast with no hit at all gets 0.
  static List<LogCast> withTargetsHit(
    List<LogCast> casts,
    List<JsonMap> damage,
    num start,
    int playerId,
    Map<int, AoeDamage> rules,
  ) {
    final hits = <int, List<(Duration, (int, int))>>{};
    for (final row in damage) {
      final time = row['timestamp'];
      final ability = _int(row['abilityGameID']);
      final target = _int(row['targetID']);
      if (time is! num ||
          ability == null ||
          target == null ||
          _int(row['sourceID']) != playerId) {
        continue;
      }
      hits.putIfAbsent(ability, () => []).add((
        _since(time, start),
        (target, _int(row['targetInstance']) ?? 0),
      ));
    }
    const before = Duration(milliseconds: 50);
    return [
      for (final cast in casts)
        switch (cast.isBegin ? null : rules[cast.abilityId]) {
          null => cast,
          final rule => cast.withTargetsHit(
            {
              for (final (time, target)
                  in hits[rule.damageId] ?? <(Duration, (int, int))>[])
                if (time >= cast.time - before &&
                    time <= cast.time + rule.within)
                  target,
            }.length,
          ),
        },
    ];
  }

  /// A rankings row, or `null` when it has no public report behind it.
  static RankedLog? rankedLog(JsonMap json, int rank) {
    final report = json['report'];
    final amount = json['amount'];
    final duration = json['duration'];
    if (report is! JsonMap || amount is! num || duration is! num) return null;
    final code = report['code'];
    final fightId = _int(report['fightID']);
    if (code is! String || fightId == null) return null;
    return RankedLog(
      rank: rank,
      playerName: json['name'] as String? ?? '',
      amount: amount.toDouble(),
      duration: Duration(milliseconds: duration.round()),
      itemLevel: _int(json['bracketData']) ?? 0,
      reportCode: code,
      fightId: fightId,
    );
  }

  /// Ids of the talents in a `CombatantInfo` event.
  static List<int> talentEntryIds(JsonMap json) {
    final tree = json['talentTree'];
    return [
      if (tree is List)
        for (final talent in tree.whereType<JsonMap>()) ?_int(talent['id']),
    ];
  }

  static LogResourceReading? _reading(JsonMap json) {
    final type = _int(json['type']);
    final amount = _int(json['amount']);
    final max = _int(json['max']);
    if (type == null || amount == null || max == null) return null;
    return LogResourceReading(
      type: type,
      amount: amount,
      max: max,
      cost: _int(json['cost']),
    );
  }

  static Duration _since(num time, num start) =>
      Duration(milliseconds: (time - start).round());

  static int? _int(Object? value) => value is num ? value.toInt() : null;
}
