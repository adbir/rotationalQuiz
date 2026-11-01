import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rotational_quiz/data/repositories/warcraft_logs_mapper.dart';
import 'package:rotational_quiz/data/repositories/warcraft_logs_repository.dart';
import 'package:rotational_quiz/data/services/warcraft_logs_service.dart';
import 'package:rotational_quiz/domain/models/enemy_presence.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/domain/models/log_rules.dart';
import 'package:rotational_quiz/utils/result.dart';

import '../domain/player_metrics_fixture_test.dart' show loadFixture;
import '../test_helpers.dart';

const _start = 1000000;

Duration _s(double seconds) => Duration(milliseconds: (seconds * 1000).round());

Map<String, Object?> _row(double seconds, int instance, String key) => {
  'timestamp': _start + (seconds * 1000).round(),
  key: instance,
};

/// A fight with a boss (30) and two kinds of add: 31 has a death event for its
/// first copy only, and 32 has none, so its end is the last damage it took.
http.Response _answer(http.Request request) {
  final body = jsonDecode(request.body) as Map<String, Object?>;
  final vars = body['variables']! as Map<String, Object?>;
  if ((body['query']! as String).contains('masterData')) {
    return http.Response(
      jsonEncode({
        'data': {
          'reportData': {
            'report': {
              'masterData': {
                'npcs': [
                  {'id': 30, 'name': 'Boss'},
                  {'id': 31, 'name': 'Adder'},
                  {'id': 32, 'name': 'Imp'},
                  {'id': 33, 'name': 'Wall'},
                ],
              },
              'fights': [
                {
                  'id': 1,
                  'startTime': _start,
                  'endTime': _start + 60000,
                  'enemyNPCs': [
                    {'id': 30, 'instanceCount': 1},
                    {'id': 31, 'instanceCount': 2},
                    {'id': 32, 'instanceCount': 2},
                    {'id': 33, 'instanceCount': 5},
                  ],
                },
              ],
            },
          },
        },
      }),
      200,
    );
  }
  final rows = switch ((vars['type'], vars['source'])) {
    ('Deaths', null) => [
      {..._row(9, 1, 'targetInstance'), 'targetID': 31},
    ],
    ('DamageDone', 7) => [
      for (final (target, amount) in [(31, 900), (32, 800), (33, 1), (33, 0)])
        {
          'timestamp': _start + 4000,
          'sourceID': 7,
          'targetID': target,
          'amount': amount,
          'unmitigatedAmount': 5000,
        },
    ],
    ('Casts', 31) => [
      _row(4, 1, 'sourceInstance'),
      _row(5, 2, 'sourceInstance'),
    ],
    ('Casts', 32) => [
      _row(6, 1, 'sourceInstance'),
      _row(7, 2, 'sourceInstance'),
    ],
    ('DamageTaken', 32) => [
      _row(8, 1, 'targetInstance'),
      _row(8.5, 1, 'targetInstance'),
    ],
    _ => throw StateError('unexpected query $vars'),
  };
  return http.Response(
    jsonEncode({
      'data': {
        'reportData': {
          'report': {
            'events': {'nextPageTimestamp': null, 'data': rows},
          },
        },
      },
    }),
    200,
  );
}

void main() {
  group('loadEnemyPresence', () {
    late List<Map<String, Object?>> requests;
    late EnemyPresence presence;

    setUp(() async {
      requests = [];
      final repo = WarcraftLogsRepository(
        spec: spec,
        service: WarcraftLogsService(
          accessToken: () async => 'token',
          client: MockClient((request) async {
            requests.add(jsonDecode(request.body) as Map<String, Object?>);
            return _answer(request);
          }),
        ),
      );
      final result = await repo.loadEnemyPresence(
        reportCode: 'abc',
        fightId: 1,
        playerId: 7,
      );
      presence = (result as Ok<EnemyPresence>).value;
    });

    test('counts the boss throughout and each add from arrival to death', () {
      expect(presence.aliveAt(_s(3)), 1);
      expect(presence.aliveByKindAt(_s(5.5)), {'Boss': 1, 'Adder': 2});
      // The first Adder dies at 9 s; the second has no death and stays up.
      expect(presence.aliveByKindAt(_s(8.9))['Adder'], 2);
      expect(presence.aliveByKindAt(_s(9.5))['Adder'], 1);
      expect(presence.aliveAt(_s(59)), 2);
    });

    test('ends an add with no death at the last damage it took', () {
      // Imp 1 acts at 6 s and last takes damage at 8.5 s; imp 2 takes none, so
      // it is gone as it arrives at 7 s.
      expect(presence.aliveByKindAt(_s(6.5))['Imp'], 1);
      expect(presence.aliveByKindAt(_s(7.5))['Imp'], 1);
      expect(presence.aliveByKindAt(_s(8.6)).containsKey('Imp'), isFalse);
    });

    test('leaves out an add the player never really damaged', () {
      // Wall took hits for 1 and 0 of 5000: crowd controlled, not killed.
      expect(presence.groups.map((g) => g.name), ['Boss', 'Adder', 'Imp']);
    });

    test('asks for deaths once and damage only for the kind with none', () {
      final types = [
        for (final r in requests)
          if ((r['variables']! as Map)['type'] case final String type)
            '$type ${(r['variables']! as Map)['source']}',
      ];
      expect(types, [
        'Deaths null',
        'DamageDone 7',
        'Casts 31',
        'Casts 32',
        'DamageTaken 32',
      ]);
      expect((requests[1]['variables']! as Map)['hostility'], 'Enemies');
    });
  });

  group('targets hit per cast', () {
    test('counts the distinct enemies hit just after a Chain Lightning', () {
      LogCast cast(int ms) => LogCast(
        time: Duration(milliseconds: ms),
        abilityId: 188443,
        targetId: 3,
        isBegin: false,
      );
      Map<String, Object?> hit(int ms, int target, int instance) => {
        'timestamp': _start + ms,
        'sourceID': 7,
        'targetID': target,
        'targetInstance': instance,
        'abilityGameID': 188443,
      };

      final casts = WarcraftLogsMapper.withTargetsHit(
        [cast(1000), cast(5000), cast(9000)],
        [
          // The first cast hit a boss and two copies of an add, one twice.
          hit(1002, 3, 0),
          hit(1002, 9, 1),
          hit(1002, 9, 2),
          hit(1003, 9, 2),
          // The second hit only the boss, and a pet's hit is not the player's.
          hit(5001, 3, 0),
          {...hit(5001, 9, 1), 'sourceID': 8},
          // A hit long after belongs to no cast.
          hit(8000, 3, 0),
        ],
        _start,
        7,
        const {188443: AoeDamage(188443, within: Duration(seconds: 1))},
      );

      expect(casts.map((c) => c.targetsHit), [3, 1, 0]);
    });

    test('rank 1 hit four enemies with its first Chain Lightning', () {
      final log = loadFixture('twin_fangs_window');
      final chain = [
        for (final c in log.casts)
          if (c.abilityId == 188443 && !c.isBegin) c,
      ];

      // Two bosses and two Bulwarks, then the same two Bulwarks plus more.
      expect(chain.first.targetsHit, 4);
      expect(
        chain.map((c) => c.targetsHit!).reduce((a, b) => a > b ? a : b),
        5,
      );
      expect(chain.where((c) => c.targetsHit == 2), hasLength(greaterThan(10)));
    });

    test('Earthquake counts the targets of its first tick', () {
      final log = loadFixture('twin_fangs_window');
      final quakes = log.casts.where(
        (c) => c.abilityId == 462620 && !c.isBegin,
      );

      // Three Spawn of Vexhul stood in it.
      expect(quakes.map((c) => c.targetsHit), [3, 3]);
    });

    test('casts that are not area abilities stay unknown', () {
      final log = loadFixture('twin_fangs_window');
      final lava = log.casts.where((c) => c.abilityId == 51505 && !c.isBegin);

      expect(lava, isNotEmpty);
      expect(lava.every((c) => c.targetsHit == null), isTrue);
    });
  });
}
