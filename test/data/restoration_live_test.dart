// Reproduces the whole-log Restoration numbers of the three Heroic Coiled
// Altar logs in docs/warcraft-logs.md ("Restoration Shaman") from the real
// API, through the spec's log rules. Skipped unless WCL_LIVE is set; it costs
// about 24 points (see the doc).
//
//   WCL_LIVE=1 flutter test test/data/restoration_live_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/data/repositories/warcraft_logs_repository.dart';
import 'package:rotational_quiz/data/services/warcraft_logs_service.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/domain/models/player_metrics.dart';
import 'package:rotational_quiz/domain/specs/restoration_shaman.dart';
import 'package:rotational_quiz/domain/use_cases/compare_fights.dart';
import 'package:rotational_quiz/domain/use_cases/compute_player_metrics.dart';
import 'package:rotational_quiz/domain/use_cases/rank_findings.dart';
import 'package:rotational_quiz/utils/result.dart';

import 'warcraft_logs_live_test.dart' show clientToken;

/// Report, fight and player of the owner's kill, rank 50 and rank 1.
const _logs = [
  ('Owner', 'GaZ4Fj7VTm8YgqhQ', 30, 12),
  ('Rank 50', 'y93ZPmqCM7HJNLrf', 10, 8),
  ('Rank 1', 'PRkbJByN4VdzpHcC', 67, 611),
];

String _f(num? v, [int digits = 1]) => v?.toStringAsFixed(digits) ?? '-';

/// One line of the numbers the doc's table holds.
String _row(String label, FightLog log, PlayerMetrics m) {
  String cd(String id) {
    final c = m.cooldowns.where((c) => c.id == id).firstOrNull;
    return c == null ? '-' : '${c.uses}/${c.possible}';
  }

  double up(int id) => m.upkeep.singleWhere((u) => u.buffId == id).percent;
  final proc = m.heldProcs.single;
  final table = log.receivedBuffs.where((b) => b.abilityId == 1267089);
  final tableHold = table.isEmpty || table.single.uses == 0
      ? null
      : table.single.uptime.inMilliseconds / table.single.uses / 1000;
  final riptide = m.casts.byAbility.where((a) => a.abilityId == 61295);
  final mana = m.resourceLevels!;
  return [
    label,
    '${_f(m.fightLength.inMilliseconds / 1000)} s',
    'cpm ${_f(m.casts.perMinute)}',
    'phases ${[for (final p in m.casts.byPhase) _f(p.perMinute)].join('/')}',
    'HST ${cd('healing_stream_totem')}',
    'Stormstream ${m.casts.byAbility.where((a) => a.abilityId == 1267068).firstOrNull?.casts ?? 0}',
    'hold ${_f((proc.averageHold?.inMilliseconds ?? 0) / 1000, 2)} s',
    '(table ${_f(tableHold, 2)}, gained ${proc.gained}',
    'unspent ${proc.unspentAtEnd})',
    'Surging ${cd('surging_totem')}',
    'rain ${_f(up(1307888))}%',
    'Riptide ${riptide.firstOrNull?.casts ?? 0}',
    '(${_f(riptide.firstOrNull?.perMinute)}/min)',
    'Asc ${cd('ascendance')} SLT ${cd('spirit_link_totem')}',
    'NS ${cd('natures_swiftness')}',
    'ES ${_f(up(974))}% EL ${_f(up(382024))}%',
    'mana ${[for (final p in mana.atPhaseChanges) '${_f(p.percent, 0)}% at ${p.time.inSeconds} s'].join(', ')}',
    'end ${_f(mana.atEnd?.percent, 0)}%',
    '(lowest ${_f(mana.lowest?.percent, 0)}%), ${mana.readings} readings',
  ].join(' | ');
}

void main() {
  test(
    'whole-log metrics of the three Heroic Coiled Altar logs',
    skip: Platform.environment['WCL_LIVE'] == null,
    timeout: const Timeout(Duration(minutes: 5)),
    () async {
      const resto = RestorationShaman();
      final token = await clientToken();
      final repo = WarcraftLogsRepository(
        spec: resto,
        service: WarcraftLogsService(accessToken: () async => token),
      );
      final logs = <FightLog>[];
      for (final (_, code, fight, source) in _logs) {
        final loaded = await repo.loadFight(
          reportCode: code,
          fightId: fight,
          sourceId: source,
        );
        logs.add(switch (loaded) {
          Ok(:final value) => value,
          Error(:final error) => fail('$error'),
        });
      }
      final metrics = [
        for (final log in logs) ComputePlayerMetrics(resto)(log),
      ];
      for (final (i, (label, _, _, _)) in _logs.indexed) {
        // ignore: avoid_print, the numbers go into docs/warcraft-logs.md.
        print(_row(label, logs[i], metrics[i]));
      }
      final report = const RankFindings()(
        CompareFights(resto)([
          for (final (i, (label, _, _, _)) in _logs.indexed)
            FightToCompare(label: label, log: logs[i]),
        ], const []),
      );
      for (final f in [...report.findings, ...report.same]) {
        // ignore: avoid_print, as above.
        print(
          '${report.findings.contains(f) ? 'finding' : 'same'}: ${f.kind.name} '
          '${f.subject ?? ''} ${f.valuesByLog.map(_f).join(' / ')} '
          'share ${_f(f.share, 2)}',
        );
      }

      // The doc's table: Healing Stream of possible, hold time, Healing Rain.
      CooldownMetrics stream(PlayerMetrics m) =>
          m.cooldowns.singleWhere((c) => c.id == 'healing_stream_totem');
      expect([for (final m in metrics) stream(m).uses], [13, 16, 19]);
      expect([for (final m in metrics) stream(m).possible], [19, 20, 22]);
      final holds = [
        for (final m in metrics)
          m.heldProcs.single.averageHold!.inMilliseconds / 1000,
      ];
      // The doc's numbers are the buff table's uptime over uses; per proc,
      // two stacked procs both wait, so rank 50 reads 2.96 s against 2.84.
      for (final (i, hold) in [4.1, 2.8, 1.4].indexed) {
        expect(holds[i], closeTo(hold, 0.2));
      }
      final rain = [
        for (final m in metrics)
          m.upkeep.singleWhere((u) => u.buffId == 1307888).percent,
      ];
      for (final (i, percent) in [67, 85, 95].indexed) {
        expect(rain[i], closeTo(percent, 1));
      }
      expect(report.findings.length, lessThanOrEqualTo(3));
    },
  );
}
