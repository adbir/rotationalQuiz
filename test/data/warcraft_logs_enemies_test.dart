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

/// A fight with a boss (30) and three kinds of add: 31 is hit by the player's
/// Lightning Bolt (188196) in two stretches on its first copy and one on its
/// second, 32 only by a gear proc (1287663), and 33 only barely or by a shield.
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
    ('DamageDone', 7) => [
      // Adder copy 1: 4 to 5 s, and again 30 to 31 s. Copy 2: 5 to 9 s, its last hit
      // fully taken by a shield.
      for (final (target, instance, seconds, amount, absorbed) in [
        (31, 1, 4.0, 900, 0),
        (31, 1, 5.0, 900, 0),
        (31, 1, 30.0, 900, 0),
        (31, 1, 31.0, 900, 0),
        (31, 2, 5.0, 900, 0),
        (31, 2, 9.0, 0, 500),
        // Imp: gear procs only.
        (32, 1, 4.0, 800, 0),
        (32, 2, 4.0, 800, 0),
        // Wall: a hit for 1 of 5000, a hit for 0, and a shield taking one.
        (33, 1, 4.0, 1, 0),
        (33, 1, 4.0, 0, 0),
        (33, 2, 4.0, 0, 700),
      ])
        {
          'timestamp': _start + (seconds * 1000).round(),
          'sourceID': 7,
          'targetID': target,
          'targetInstance': instance,
          'abilityGameID': target == 31 ? 188196 : 1287663,
          'amount': amount,
          'absorbed': absorbed,
          'unmitigatedAmount': 5000,
        },
      // The boss is hit to 5.8 s, is immune at 12 s (a hit for 0), then is hit
      // from 20 s: two stretches, more than 8 s apart.
      for (final (seconds, amount) in [
        (1.0, 900),
        (5.8, 900),
        (12.0, 0),
        for (final t in [20.0, 27.0, 34.0, 41.0, 48.0, 55.0, 59.5]) (t, 900),
      ])
        {
          'timestamp': _start + (seconds * 1000).round(),
          'sourceID': 7,
          'targetID': 30,
          'amount': amount,
          'unmitigatedAmount': 5000,
        },
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

    test('counts an add copy while the player hits it', () {
      expect(presence.aliveAt(_s(3)), 1);
      expect(presence.aliveByKindAt(_s(4.5)), {'Boss': 1, 'Adder': 1});
      // Copy 1 is gone at its last hit of the stretch (5 s), copy 2 is up from
      // 5 s to 9 s.
      expect(presence.aliveByKindAt(_s(6))['Adder'], 1);
      expect(presence.aliveByKindAt(_s(9.5)).containsKey('Adder'), isFalse);
    });

    test('a copy with two hit stretches is up in each', () {
      final adder = presence.groups.singleWhere((g) => g.name == 'Adder');
      expect(adder.arrivals, [_s(4), _s(5), _s(30)]);
      expect(adder.departures, [_s(5), _s(9), _s(31)]);
      // Between the stretches it is out of reach, as a boss is.
      expect(adder.aliveAt(_s(20)), 0);
      expect(adder.aliveAt(_s(30.5)), 1);
    });

    test('a shield that took a hit counts for a kind really damaged', () {
      // Copy 2's hit at 9 s did 0 and was absorbed: it still ends the stretch
      // there, not at its last real hit (5 s).
      final adder = presence.groups.singleWhere((g) => g.name == 'Adder');
      expect(adder.departures[1], _s(9));
      expect(adder.aliveAt(_s(8)), 1);
    });

    test('holds a boss only while the player hits it', () {
      final boss = presence.groups.firstWhere((g) => g.name == 'Boss');
      expect(boss.arrivals, [_s(1), _s(20)]);
      expect(boss.departures, [_s(5.8), _s(59.5)]);
      expect(boss.aliveAt(_s(3)), 1);
      // Immune at 12 s: the 0 hit opens no stretch.
      expect(boss.aliveAt(_s(12)), 0);
      expect(boss.aliveAt(_s(30)), 1);
    });

    test('leaves out a kind hit only by gear procs, barely or by a shield', () {
      // Imp took gear procs, Wall hits for 1 and 0 of 5000 and a shield.
      expect(presence.groups.map((g) => g.name), ['Boss', 'Adder']);
    });

    test('asks only for the player damage', () {
      final types = [
        for (final r in requests)
          if ((r['variables']! as Map)['type'] case final String type)
            '$type ${(r['variables']! as Map)['source']}',
      ];
      expect(types, ['DamageDone 7']);
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
