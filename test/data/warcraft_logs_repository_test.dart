import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rotational_quiz/data/repositories/warcraft_logs_mapper.dart';
import 'package:rotational_quiz/data/repositories/warcraft_logs_repository.dart';
import 'package:rotational_quiz/data/services/warcraft_logs_service.dart';
import 'package:rotational_quiz/domain/models/enemy_group.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/utils/result.dart';

import '../test_helpers.dart';

const _start = 1000000;

Map<String, Object?> get _report => {
  'masterData': {
    'actors': [
      {'id': 7, 'name': 'Tester', 'subType': 'Shaman'},
      {'id': 9, 'name': 'Other', 'subType': 'Mage'},
    ],
    'abilities': [
      {'gameID': 51505, 'name': 'Lava Burst'},
    ],
    'npcs': [
      {'id': 30, 'name': 'Boss'},
      {'id': 31, 'name': 'Add'},
    ],
  },
  'fights': [
    {
      'id': 58,
      'name': 'Sszorak',
      'encounterID': 3420,
      'kill': true,
      'startTime': _start,
      'endTime': _start + 371000,
      'difficulty': 5,
      'size': 20,
      'enemyNPCs': [
        {'id': 30, 'instanceCount': 1},
        {'id': 31, 'instanceCount': 4},
      ],
      'phaseTransitions': [
        {'id': 1, 'startTime': _start},
        {'id': 2, 'startTime': _start + 100000},
      ],
    },
  ],
};

/// Answers like the API, serving casts over two pages.
class FakeApi {
  final requests = <Map<String, Object?>>[];
  String? authorization;

  Map<String, Object?> variables(int i) =>
      requests[i]['variables']! as Map<String, Object?>;

  http.Response _ok(Map<String, Object?> data) =>
      http.Response(jsonEncode({'data': data}), 200);

  Map<String, Object?> _events(List<Object?> data, [num? next]) => {
    'reportData': {
      'report': {
        'events': {'nextPageTimestamp': next, 'data': data},
      },
    },
  };

  late final client = MockClient((request) async {
    authorization = request.headers['Authorization'];
    final body = jsonDecode(request.body) as Map<String, Object?>;
    requests.add(body);
    final vars = body['variables']! as Map<String, Object?>;
    final query = body['query']! as String;
    if (query.contains('characterRankings')) return _rankings(vars);
    if (query.contains('masterData')) {
      return _ok({
        'reportData': {'report': _report},
      });
    }
    if (vars['hostility'] == 'Enemies') {
      // Two copies of the add act, and the first acts twice.
      return _ok(
        _events([
          for (final (time, copy) in [(5000, 1), (6000, 1), (4000, 2)])
            {
              'timestamp': _start + time,
              'type': 'cast',
              'sourceInstance': copy,
              'abilityGameID': 5,
            },
        ]),
      );
    }
    return _ok(switch (vars['type']) {
      'Casts' =>
        vars['start'] == _start
            ? _events([
                {
                  'timestamp': _start + 1200,
                  'type': 'begincast',
                  'abilityGameID': 51505,
                  'targetID': 3,
                },
                {'timestamp': _start + 1300, 'type': 'unknown'},
              ], _start + 2000)
            : _events([
                {
                  'timestamp': _start + 3200,
                  'type': 'cast',
                  'abilityGameID': 117014,
                  'targetID': 3,
                  'classResources': [
                    {'amount': 113, 'max': 125, 'type': 11, 'cost': 90},
                  ],
                },
              ]),
      'Resources' => _events([
        {
          'timestamp': _start + 4000,
          'type': 'resourcechange',
          'abilityGameID': 285466,
          'resourceChange': 8,
          'resourceChangeType': maelstromResourceType,
          'maxResourceAmount': 125,
          'waste': 2,
        },
      ]),
      'Buffs' => _events([
        {
          'timestamp': _start + 5000,
          'type': 'removebuffstack',
          'abilityGameID': 191634,
          'targetID': 7,
          'stack': 1,
        },
        {'timestamp': _start + 5100, 'type': 'somethingelse'},
      ]),
      _ => _events([
        {
          'type': 'combatantinfo',
          'talentTree': [
            {'id': 101859, 'rank': 1, 'nodeID': 1},
            {'id': 999999, 'rank': 1, 'nodeID': 2},
          ],
        },
      ]),
    });
  });

  http.Response _rankings(Map<String, Object?> vars) {
    final page = vars['page']! as int;
    return _ok({
      'worldData': {
        'encounter': {
          'characterRankings': {
            'hasMorePages': page == 1,
            'rankings': [
              {
                'name': 'First$page',
                'amount': 288429.5,
                'duration': 288000,
                'bracketData': 336,
                'report': {'code': 'abc', 'fightID': 32},
              },
              {'name': 'Hidden', 'amount': 1, 'duration': 1},
            ],
          },
        },
      },
    });
  }
}

void main() {
  _castAliasTests();
  late FakeApi api;
  late WarcraftLogsRepository repo;

  WarcraftLogsRepository repoWith(http.Client client) => WarcraftLogsRepository(
    spec: spec,
    service: WarcraftLogsService(
      accessToken: () async => 'token',
      client: client,
    ),
  );

  setUp(() {
    api = FakeApi();
    repo = repoWith(api.client);
  });

  group('loadFight', () {
    test('combines a fight across every page and event type', () async {
      final result = await repo.loadFight(
        reportCode: 'ycBr',
        fightId: 58,
        sourceId: 7,
      );
      final log = (result as Ok<FightLog>).value;

      expect(log.fight.name, 'Sszorak');
      expect(log.fight.kill, isTrue);
      expect(log.fight.duration, const Duration(seconds: 371));
      expect(log.fight.phaseStarts.last, const Duration(seconds: 100));
      expect(log.playerName, 'Tester');
      expect(log.abilityNames[51505], 'Lava Burst');

      expect(log.casts, hasLength(2), reason: 'bad rows are skipped');
      expect(log.casts.first.isBegin, isTrue);
      expect(log.casts.first.time, const Duration(milliseconds: 1200));
      final reading = log.casts.last.resources.single;
      expect(reading.type, maelstromResourceType);
      expect(reading.cost, 90);

      final gain = log.resourceGains.single;
      expect((gain.amount, gain.waste, gain.max), (8, 2, 125));

      final buff = log.buffEvents.single;
      expect(buff.change, LogBuffChange.removeStack);
      expect(buff.stack, 1);

      expect(log.talents, {'stormkeeper'}, reason: 'unknown ids are dropped');
    });

    test('pages from the cursor the API returned', () async {
      await repo.loadFight(reportCode: 'ycBr', fightId: 58, sourceId: 7);
      final castRequests = [
        for (var i = 0; i < api.requests.length; i++)
          if (api.variables(i)['type'] == 'Casts') api.variables(i),
      ];
      expect(castRequests.map((v) => v['start']), [_start, _start + 2000]);
      expect(castRequests.first['resources'], isTrue);
    });

    test('finds a player by name, as rankings give it', () async {
      final result = await repo.loadFight(
        reportCode: 'ycBr',
        fightId: 58,
        playerName: 'Tester',
      );
      expect((result as Ok<FightLog>).value.playerId, 7);
    });

    test('sends the token and passes values as variables', () async {
      const code = 'x") { __typename } #';
      await repo.loadFight(reportCode: code, fightId: 58, sourceId: 7);
      expect(api.authorization, 'Bearer token');
      expect(api.requests.first['query'], isNot(contains('__typename')));
      expect(api.variables(0)['code'], code);
    });

    test('reports a missing player', () async {
      final result = await repo.loadFight(
        reportCode: 'ycBr',
        fightId: 58,
        sourceId: 123,
      );
      expect('${(result as Error<FightLog>).error}', contains('123'));
    });

    Future<String> errorFor(http.Response response) async {
      final result = await repoWith(MockClient((_) async => response))
          .loadFight(reportCode: 'ycBr', fightId: 58, sourceId: 7);
      return '${(result as Error<FightLog>).error}';
    }

    test('turns API failures into readable errors', () async {
      expect(await errorFor(http.Response('', 401)), contains('sign in'));
      expect(await errorFor(http.Response('', 429)), contains('rate limit'));
      expect(await errorFor(http.Response('', 500)), contains('500'));
      expect(await errorFor(http.Response('<html>', 200)), contains('unread'));
      expect(
        await errorFor(
          http.Response('{"errors":[{"message":"No such report"}]}', 200),
        ),
        contains('No such report'),
      );
      expect(
        await errorFor(
          http.Response('{"data":{"reportData":{"report":null}}}', 200),
        ),
        contains('not found'),
      );
    });

    test('network failures become an error result', () async {
      final result = await repoWith(
        MockClient((_) async => throw http.ClientException('offline')),
      ).loadFight(reportCode: 'ycBr', fightId: 58, sourceId: 7);
      expect(result, isA<Error<FightLog>>());
    });
  });

  group('loadEnemyGroups', () {
    test('lists the adds with when each first acted', () async {
      final result = await repo.loadEnemyGroups(reportCode: 'abc', fightId: 58);

      final groups = (result as Ok<List<EnemyGroup>>).value;
      expect(groups.single.name, 'Add');
      expect(groups.single.arrivals, const [
        Duration(seconds: 4),
        Duration(seconds: 5),
      ]);
      expect(api.variables(1)['hostility'], 'Enemies');
      expect(api.variables(1)['source'], 31);
    });
  });

  group('EnemyGroup', () {
    test('starts a wave after a gap with no arrivals', () {
      final group = EnemyGroup(
        name: 'Add',
        arrivals: [
          for (final s in [37, 38, 39, 98, 99]) Duration(seconds: s),
        ],
      );

      expect(group.waveStarts(), const [
        Duration(seconds: 37),
        Duration(seconds: 98),
      ]);
    });
  });

  group('topLogs', () {
    test('reads pages until it has enough, keeping true ranks', () async {
      final result = await repo.topLogs(
        encounterId: 3420,
        difficulty: 5,
        count: 2,
      );
      final logs = (result as Ok<List<RankedLog>>).value;

      expect(logs.map((l) => l.playerName), ['First1', 'First2']);
      expect(logs.map((l) => l.rank), [1, 3], reason: 'hidden rows still rank');
      expect(logs.first.itemLevel, 336);
      expect(logs.first.duration, const Duration(seconds: 288));
      expect(api.variables(0)['class'], spec.logClassName);
      expect(api.variables(0)['spec'], spec.logSpecName);
    });

    test('stops when there are no more pages', () async {
      final result = await repo.topLogs(encounterId: 3420, difficulty: 5);
      expect((result as Ok<List<RankedLog>>).value, hasLength(2));
      expect(api.requests, hasLength(2));
    });
  });
}

void _castAliasTests() {
  test('a cursor Earthquake loads as the target version', () {
    final cast = WarcraftLogsMapper.cast(
      {'type': 'cast', 'timestamp': 1500, 'abilityGameID': 61882},
      1000,
      aliases: spec.logRules.castAliases,
    );
    expect(cast?.abilityId, 462620);
  });
}
