import '../../domain/models/fight_log.dart';
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
      'applybuff' => LogBuffChange.apply,
      'applybuffstack' => LogBuffChange.applyStack,
      'refreshbuff' => LogBuffChange.refresh,
      'removebuffstack' => LogBuffChange.removeStack,
      'removebuff' => LogBuffChange.remove,
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
    );
  }

  /// When each enemy in [casts] first acted. [casts] are one enemy NPC's cast
  /// events, and `sourceInstance` tells its copies apart.
  static List<Duration> enemyArrivals(List<JsonMap> casts, num start) {
    final first = <int, num>{};
    for (final cast in casts) {
      final time = cast['timestamp'];
      if (time is num) {
        first.putIfAbsent(_int(cast['sourceInstance']) ?? 0, () => time);
      }
    }
    return [for (final time in first.values) _since(time, start)]..sort();
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
