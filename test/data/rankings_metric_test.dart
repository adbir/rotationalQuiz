import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rotational_quiz/data/repositories/warcraft_logs_repository.dart';
import 'package:rotational_quiz/data/services/warcraft_logs_service.dart';
import 'package:rotational_quiz/domain/specs/elemental_shaman.dart';
import 'package:rotational_quiz/domain/specs/restoration_shaman.dart';
import 'package:rotational_quiz/domain/specs/rotation_spec.dart';

void main() {
  final queries = <String>[];
  final client = MockClient((request) async {
    queries.add(
      (jsonDecode(request.body) as Map<String, Object?>)['query']! as String,
    );
    return http.Response(
      jsonEncode({
        'data': {
          'worldData': {
            'encounter': {
              'characterRankings': {
                'hasMorePages': false,
                'rankings': <Object?>[],
              },
            },
          },
        },
      }),
      200,
    );
  });

  Future<String> requestedQuery(RotationSpec spec) async {
    queries.clear();
    final repo = WarcraftLogsRepository(
      spec: spec,
      service: WarcraftLogsService(
        accessToken: () async => 'token',
        client: client,
      ),
    );
    await repo.topLogs(encounterId: 3429, difficulty: 4, count: 1);
    return queries.single;
  }

  test('Elemental rankings still ask for dps', () async {
    final query = await requestedQuery(const ElementalShaman());
    expect(query, contains('metric: dps,'));
    expect(query, isNot(contains('hps')));
  });

  test('Restoration rankings ask for hps', () async {
    final query = await requestedQuery(const RestorationShaman());
    expect(query, contains('metric: hps,'));
    expect(query, isNot(contains('dps')));
  });

  test('a metric that is not a plain name is refused', () {
    final service = WarcraftLogsService(
      accessToken: () async => 'token',
      client: client,
    );
    expect(
      () => service.rankings(
        encounterId: 1,
        className: 'Shaman',
        specName: 'Restoration',
        difficulty: 4,
        page: 1,
        metric: 'hps) { x }',
      ),
      throwsA(isA<WarcraftLogsException>()),
    );
  });
}
