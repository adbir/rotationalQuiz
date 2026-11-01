// Checks the data layer against the real Warcraft Logs API. It's skipped
// unless WCL_LIVE is set, so normal runs make no network calls and spend no
// API points. It reads credentials from a git-ignored .env file:
//
//   WCL_CLIENT_ID=...
//   WCL_CLIENT_SECRET=...
//
// Optional: WCL_REPORT, WCL_FIGHT and WCL_SOURCE pick your own log.
//
//   WCL_LIVE=1 flutter test test/data/warcraft_logs_live_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rotational_quiz/data/repositories/warcraft_logs_repository.dart';
import 'package:rotational_quiz/data/services/warcraft_logs_service.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/utils/result.dart';

import '../test_helpers.dart';

Future<String> _clientToken() async {
  final vars = <String, String>{
    for (final line in File('.env').readAsLinesSync())
      if (line.indexOf('=') case final i when i > 0)
        line.substring(0, i).trim(): line.substring(i + 1).trim(),
  };
  final credentials = base64Encode(
    utf8.encode('${vars['WCL_CLIENT_ID']}:${vars['WCL_CLIENT_SECRET']}'),
  );
  final response = await http.post(
    Uri.parse('https://www.warcraftlogs.com/oauth/token'),
    headers: {'Authorization': 'Basic $credentials'},
    body: {'grant_type': 'client_credentials'},
  );
  expect(response.statusCode, 200, reason: 'token request');
  final body = jsonDecode(response.body) as Map<String, Object?>;
  return body['access_token']! as String;
}

void main() {
  final env = Platform.environment;

  test(
    'loads rankings and a full fight from the real API',
    skip: env['WCL_LIVE'] == null,
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      final token = await _clientToken();
      final repo = WarcraftLogsRepository(
        spec: spec,
        service: WarcraftLogsService(accessToken: () async => token),
      );

      const sszorak = 3420;
      final top = await repo.topLogs(
        encounterId: sszorak,
        difficulty: 5,
        count: 3,
      );
      final logs = switch (top) {
        Ok(:final value) => value,
        Error(:final error) => fail('$error'),
      };
      expect(logs, hasLength(3));
      expect(logs.first.amount, greaterThan(logs.last.amount));

      final report = env['WCL_REPORT'];
      final loaded = await repo.loadFight(
        reportCode: report ?? logs.first.reportCode,
        fightId: report == null
            ? logs.first.fightId
            : int.parse(env['WCL_FIGHT']!),
        sourceId: report == null ? null : int.parse(env['WCL_SOURCE']!),
        playerName: report == null ? logs.first.playerName : null,
      );
      final log = switch (loaded) {
        Ok(:final value) => value,
        Error(:final error) => fail('$error'),
      };

      expect(log.fight.encounterId, sszorak);
      expect(log.fight.kill, isTrue);
      expect(log.casts.where((c) => !c.isBegin).length, greaterThan(100));
      final maelstrom = log.resourceGains.where(
        (g) => g.type == maelstromResourceType,
      );
      expect(maelstrom.length, greaterThan(100));
      expect(log.buffEvents.length, greaterThan(100));
      expect(log.talents, contains('stormkeeper'));
      expect(log.abilityNames[51505], 'Lava Burst');
    },
  );
}
