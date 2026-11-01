import 'dart:convert';

import 'package:http/http.dart' as http;

/// A JSON object from the API.
typedef JsonMap = Map<String, Object?>;

/// Supplies an API token. A secret must never ship in the web app, so the
/// app gets its token from the user's own sign-in. See `CLAUDE.md`.
typedef AccessTokenSource = Future<String> Function();

/// Kinds of events the API can return.
enum WclEventType {
  casts('Casts'),
  resources('Resources'),
  buffs('Buffs'),
  debuffs('Debuffs'),
  combatantInfo('CombatantInfo'),
  deaths('Deaths'),
  damageDone('DamageDone'),
  damageTaken('DamageTaken');

  const WclEventType(this.apiName);

  /// The value of the API's `EventDataType`.
  final String apiName;
}

class WarcraftLogsException implements Exception {
  const WarcraftLogsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to the Warcraft Logs v2 GraphQL API.
///
/// Values go through GraphQL variables, never string building, so a pasted
/// report code can't change a query.
class WarcraftLogsService {
  WarcraftLogsService({
    required this._accessToken,
    http.Client? client,
    Uri? endpoint,
  }) : _client = client ?? http.Client(),
       _endpoint = endpoint ?? clientEndpoint;

  /// For tokens from the client credentials flow.
  static final clientEndpoint = Uri.parse(
    'https://www.warcraftlogs.com/api/v2/client',
  );

  /// For tokens from a user signing in, which can also read private reports.
  static final userEndpoint = Uri.parse(
    'https://www.warcraftlogs.com/api/v2/user',
  );

  /// Stops a bad cursor looping forever. At 5,000 events a page this is far
  /// beyond any real fight.
  static const _maxPages = 100;

  static const _rankingsQuery = r'''
query ($encounter: Int!, $class: String!, $spec: String!, $difficulty: Int!, $page: Int!) {
  worldData {
    encounter(id: $encounter) {
      characterRankings(className: $class, specName: $spec, metric: dps, difficulty: $difficulty, page: $page)
    }
  }
}''';

  static const _reportQuery = r'''
query ($code: String!, $fight: Int!) {
  reportData {
    report(code: $code) {
      masterData {
        actors(type: "Player") { id name subType }
        abilities { gameID name }
        npcs: actors(type: "NPC") { id name }
      }
      fights(fightIDs: [$fight]) {
        id name encounterID kill startTime endTime difficulty size
        phaseTransitions { id startTime }
        enemyNPCs { id instanceCount }
      }
    }
  }
}''';

  static const _eventsQuery = r'''
query ($code: String!, $fight: Int!, $source: Int, $type: EventDataType!, $start: Float!, $end: Float!, $resources: Boolean!, $hostility: HostilityType!, $ability: Float) {
  reportData {
    report(code: $code) {
      events(fightIDs: [$fight], sourceID: $source, dataType: $type, startTime: $start, endTime: $end, limit: 5000, includeResources: $resources, hostilityType: $hostility, abilityID: $ability) {
        nextPageTimestamp
        data
      }
    }
  }
}''';

  static const _buffTableQuery = r'''
query ($code: String!, $fight: Int!, $source: Int!, $start: Float!, $end: Float!) {
  reportData {
    report(code: $code) {
      table(dataType: Buffs, fightIDs: [$fight], sourceID: $source, startTime: $start, endTime: $end)
    }
  }
}''';

  final AccessTokenSource _accessToken;
  final http.Client _client;
  final Uri _endpoint;

  /// One page of a boss's rankings: `rankings` and `hasMorePages`.
  Future<JsonMap> rankings({
    required int encounterId,
    required String className,
    required String specName,
    required int difficulty,
    required int page,
  }) async {
    final data = await _query(_rankingsQuery, {
      'encounter': encounterId,
      'class': className,
      'spec': specName,
      'difficulty': difficulty,
      'page': page,
    });
    final encounter = _map(_map(data['worldData'])?['encounter']);
    final rankings = _map(encounter?['characterRankings']);
    if (rankings == null) {
      throw const WarcraftLogsException('No rankings found for that boss.');
    }
    return rankings;
  }

  /// A report's players, abilities and the one fight: `masterData`, `fights`.
  Future<JsonMap> report({required String code, required int fightId}) async {
    final data = await _query(_reportQuery, {'code': code, 'fight': fightId});
    final report = _map(_map(data['reportData'])?['report']);
    if (report == null) {
      throw WarcraftLogsException('Report $code was not found.');
    }
    return report;
  }

  /// Every event of [type] for one source, across all pages. [start] and
  /// [end] are the fight's times from [report]. [enemy] reads an enemy NPC's
  /// events (its id from `enemyNPCs`) instead of a player's. Without a
  /// [sourceId] every source's events come back, which is how all enemy
  /// deaths come in one query. `DamageTaken` with [enemy] filters on the one
  /// taking the damage. [abilityId] keeps only that ability's events.
  Future<List<JsonMap>> events({
    required String code,
    required int fightId,
    int? sourceId,
    int? abilityId,
    required WclEventType type,
    required num start,
    required num end,
    bool includeResources = false,
    bool enemy = false,
  }) async {
    final events = <JsonMap>[];
    num? cursor = start;
    for (var page = 0; cursor != null; page++) {
      if (page == _maxPages) {
        throw const WarcraftLogsException('The log has too many pages.');
      }
      final data = await _query(_eventsQuery, {
        'code': code,
        'fight': fightId,
        'source': sourceId,
        'type': type.apiName,
        'start': cursor,
        'end': end,
        'resources': includeResources,
        'hostility': enemy ? 'Enemies' : 'Friendlies',
        'ability': abilityId,
      });
      final report = _map(_map(data['reportData'])?['report']);
      final result = _map(report?['events']);
      final rows = result?['data'];
      if (rows is List) events.addAll(rows.whereType<JsonMap>());
      cursor = result?['nextPageTimestamp'] as num?;
    }
    return events;
  }

  /// Every buff the player held in the window, with uptime and uses but no
  /// caster. It is the only place a buff that began before the pull shows.
  /// For `Buffs`, `sourceID` is the holder, not the caster.
  Future<JsonMap> buffTable({
    required String code,
    required int fightId,
    required int sourceId,
    required num start,
    required num end,
  }) async {
    final data = await _query(_buffTableQuery, {
      'code': code,
      'fight': fightId,
      'source': sourceId,
      'start': start,
      'end': end,
    });
    final report = _map(_map(data['reportData'])?['report']);
    return _map(_map(report?['table'])?['data']) ?? const {};
  }

  Future<JsonMap> _query(String query, JsonMap variables) async {
    final response = await _client
        .post(
          _endpoint,
          headers: {
            'Authorization': 'Bearer ${await _accessToken()}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'query': query, 'variables': variables}),
        )
        .timeout(const Duration(seconds: 30));

    switch (response.statusCode) {
      case 200:
        break;
      case 401:
        throw const WarcraftLogsException(
          'Warcraft Logs rejected the sign-in. Please sign in again.',
        );
      case 429:
        throw const WarcraftLogsException(
          'Warcraft Logs rate limit reached. Try again later.',
        );
      default:
        throw WarcraftLogsException(
          'Warcraft Logs returned an error (HTTP ${response.statusCode}).',
        );
    }

    final Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      throw const WarcraftLogsException(
        'Warcraft Logs sent an unreadable response.',
      );
    }
    final json = _map(body);
    final errors = json?['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = _map(errors.first)?['message'];
      throw WarcraftLogsException('Warcraft Logs: ${first ?? 'unknown error'}');
    }
    final data = _map(json?['data']);
    if (data == null) {
      throw const WarcraftLogsException('Warcraft Logs sent no data.');
    }
    return data;
  }

  static JsonMap? _map(Object? value) => value is JsonMap ? value : null;
}
