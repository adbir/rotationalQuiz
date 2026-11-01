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

  test(
    'finds the Twin Fangs add waves in a top log',
    skip: env['WCL_LIVE'] == null,
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      final token = await _clientToken();
      final repo = WarcraftLogsRepository(
        spec: spec,
        service: WarcraftLogsService(accessToken: () async => token),
      );
      final top = await repo.topLogs(
        encounterId: 3421,
        difficulty: 5,
        count: 1,
      );
      final log = (top as Ok<List<RankedLog>>).value.single;
      final result = await repo.loadEnemyGroups(
        reportCode: log.reportCode,
        fightId: log.fightId,
      );
      final groups = switch (result) {
        Ok(:final value) => value,
        Error(:final error) => fail('$error'),
      };
      final adds = groups.singleWhere((g) => g.name == 'Spawn of Vexhul');
      expect(adds.waveStarts().length, greaterThanOrEqualTo(5));
    },
  );

  test(
    'counts the enemies alive and the targets hit in the Twin Fangs logs',
    skip: env['WCL_LIVE'] == null,
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      final token = await _clientToken();
      final repo = WarcraftLogsRepository(
        spec: spec,
        service: WarcraftLogsService(accessToken: () async => token),
      );
      // Rank 1's report, fight and player.
      const code = 'CGjdNa8RBfcQtAWg';
      const fight = 33;
      const player = 25;
      final result = await repo.loadEnemyPresence(
        reportCode: code,
        fightId: fight,
        playerId: player,
      );
      final presence = switch (result) {
        Ok(:final value) => value,
        Error(:final error) => fail('$error'),
      };
      // The two bosses alone at first, and still alone while a Barbed Bulwark
      // wave is up (11 s): they are crowd controlled, not damaged.
      expect(presence.aliveAt(const Duration(seconds: 5)), 2);
      expect(presence.aliveAt(const Duration(seconds: 13)), 2);
      // The first Vexhul wave brings 3 Vexhul; Broodlings count only while the
      // player's own spells hit them.
      expect(presence.aliveAt(const Duration(seconds: 40)), 5);
      expect(presence.aliveAt(const Duration(seconds: 65)), 2);
      // Both bosses are hit all fight, so each is one stretch, not several.
      for (final name in ['Vexhul', 'Ithraz']) {
        final boss = presence.groups.singleWhere((g) => g.name == name);
        expect(boss.arrivals, hasLength(1), reason: name);
        expect(boss.departures.single!.inSeconds, greaterThan(400));
      }

      final rank1 = await repo.loadFight(
        reportCode: code,
        fightId: fight,
        sourceId: player,
        includeTargetsHit: true,
      );
      final log = switch (rank1) {
        Ok(:final value) => value,
        Error(:final error) => fail('$error'),
      };
      final chain = [
        for (final cast in log.casts)
          if (cast.abilityId == 188443 && !cast.isBegin) cast.targetsHit,
      ];
      expect(chain, isNotEmpty);
      expect(chain, everyElement(isNotNull));
      expect(
        chain.whereType<int>().reduce((a, b) => a > b ? a : b),
        greaterThan(3),
      );
    },
  );

  test(
    'finds the Coiled Altar Soulcoiler waves and leaves the objects out',
    skip: env['WCL_LIVE'] == null,
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      final token = await _clientToken();
      final repo = WarcraftLogsRepository(
        spec: spec,
        service: WarcraftLogsService(accessToken: () async => token),
      );
      // Rank 1 on 2026-11-01: report, fight and player.
      final result = await repo.loadEnemyPresence(
        reportCode: 'n4jBN71KbyRkt28X',
        fightId: 36,
        playerId: 68,
      );
      final presence = switch (result) {
        Ok(:final value) => value,
        Error(:final error) => fail('$error'),
      };
      final names = presence.groups.map((g) => g.name).toSet();
      // The player never damages Manifestation of Dread or Axegrinder.
      expect(names, {'Spiteful Soulcoiler', "Zul'jan", 'Hex Lord Malacrass'});
      final waves = presence.groups
          .singleWhere((g) => g.name == 'Spiteful Soulcoiler')
          .waveStarts();
      // Only the copies the player's own spells hit: wave 3 (249.5 s) was hit
      // by gear procs alone, and wave 4's copy counts from 296 s.
      expect(waves, hasLength(5));
      expect(waves[1].inMilliseconds, closeTo(296000, 200));

      // Zul'jan has two stretches. Malacrass's shield takes hits through his
      // untargetable gaps ("Untargetable stretches" in
      // docs/warcraft-logs.md), and an absorbed hit counts, so he is one.
      List<(double, double)> spans(String name) {
        final g = presence.groups.singleWhere((g) => g.name == name);
        return [
          for (var i = 0; i < g.arrivals.length; i++)
            (
              g.arrivals[i].inMilliseconds / 1000,
              g.departures[i]!.inMilliseconds / 1000,
            ),
        ];
      }

      void expectSpans(String name, List<(double, double)> want) {
        final got = spans(name);
        expect(got, hasLength(want.length), reason: name);
        for (var i = 0; i < want.length; i++) {
          expect(got[i].$1, closeTo(want[i].$1, 1), reason: '$name $i start');
          expect(got[i].$2, closeTo(want[i].$2, 1), reason: '$name $i end');
        }
      }

      expectSpans("Zul'jan", [(0, 139.2), (323.5, 510.4)]);
      expectSpans('Hex Lord Malacrass', [(147.1, 513.8)]);
    },
  );
}
