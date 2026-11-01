import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/domain/models/finding.dart';
import 'package:rotational_quiz/domain/models/player_metrics.dart';
import 'package:rotational_quiz/domain/specs/elemental_shaman.dart';
import 'package:rotational_quiz/domain/specs/restoration_shaman.dart';
import 'package:rotational_quiz/domain/use_cases/compare_fights.dart';
import 'package:rotational_quiz/domain/use_cases/compute_player_metrics.dart';
import 'package:rotational_quiz/domain/use_cases/rank_findings.dart';

import 'player_metrics_fixture_test.dart' show loadFixture;

const _innervate = 29166;
const _chainHeal = 1064;
const _riptide = 61295;
const _healingWave = 77472;

LogCast _cast(int ms, int id, {bool begin = false}) => LogCast(
  time: Duration(milliseconds: ms),
  abilityId: id,
  targetId: 2,
  isBegin: begin,
);

LogBuffEvent _buff(int ms, LogBuffChange change) => LogBuffEvent(
  time: Duration(milliseconds: ms),
  abilityId: _innervate,
  targetId: 1,
  change: change,
);

FightLog _log(List<LogCast> casts, List<LogBuffEvent> buffs) => FightLog(
  reportCode: 'made-up',
  fight: const LogFight(
    id: 1,
    name: 'Boss',
    encounterId: 1,
    kill: true,
    duration: Duration(seconds: 60),
    difficulty: 4,
    size: 20,
  ),
  playerName: '',
  playerId: 1,
  abilityNames: const {
    _chainHeal: 'Chain Heal',
    _riptide: 'Riptide',
    _healingWave: 'Healing Wave',
  },
  casts: casts,
  resourceGains: const [],
  buffEvents: buffs,
  talents: const {},
);

void main() {
  const resto = RestorationShaman();

  group('window logic on hand-made rows', () {
    // Innervate from 10 s to 18 s. Chain Heal 10,700, Healing Wave 5,950,
    // Riptide 3,800.
    final buffs = [
      _buff(10000, LogBuffChange.apply),
      _buff(18000, LogBuffChange.remove),
    ];

    test('counts casts that began inside, with nominal cost and fill', () {
      final metrics = ComputePlayerMetrics(resto)(
        _log([
          // Before the window: not counted.
          _cast(8000, _chainHeal),
          // Began 9.9 s, finished 10.5 s inside the window: began before.
          _cast(9900, _healingWave, begin: true),
          _cast(10500, _healingWave),
          // Two Chain Heals and a Riptide inside.
          _cast(11000, _chainHeal, begin: true),
          _cast(12500, _chainHeal),
          _cast(13000, _riptide),
          _cast(14000, _chainHeal, begin: true),
          _cast(15500, _chainHeal),
          // Straight after the window.
          _cast(18500, _chainHeal),
        ], buffs),
      );
      final window = metrics.freeCastWindows.single.windows.single;
      expect(metrics.freeCastWindows.single.name, 'Innervate');
      expect(window.start, const Duration(seconds: 10));
      expect(window.length, const Duration(seconds: 8));
      expect(
        [for (final c in window.casts) c.abilityId],
        [_chainHeal, _riptide, _chainHeal],
      );
      expect(window.manaSaved, 10700 + 3800 + 10700);
      // Chain Heal 11 to 12.5 s, Riptide 13 to 14.5 s, then Chain Heal from
      // 14 s, of which 14.5 to 15.5 s is new: 4 s of 8.
      expect(window.fill, closeTo(4 / 8, 0.001));
      expect(metrics.freeCastWindows.single.averageManaSaved, 25200);
    });

    test('a window with nothing cast saved nothing', () {
      final metrics = ComputePlayerMetrics(resto)(_log([], buffs));
      final window = metrics.freeCastWindows.single.windows.single;
      expect(window.casts, isEmpty);
      expect(window.manaSaved, 0);
      expect(window.fill, 0);
    });

    test('two Innervates are two windows; none is none', () {
      final twice = ComputePlayerMetrics(resto)(
        _log(
          [_cast(11000, _chainHeal), _cast(31000, _riptide)],
          [
            ...buffs,
            _buff(30000, LogBuffChange.apply),
            _buff(38000, LogBuffChange.remove),
          ],
        ),
      );
      final windows = twice.freeCastWindows.single.windows;
      expect([for (final w in windows) w.manaSaved], [10700, 3800]);
      final none = ComputePlayerMetrics(resto)(_log([], []));
      expect(none.freeCastWindows.single.windows, isEmpty);
      expect(none.freeCastWindows.single.averageManaSaved, isNull);
    });

    test('a finding only when both logs received one', () {
      FightToCompare fight(String label, FightLog log) =>
          FightToCompare(label: label, log: log);
      final big = _log([
        _cast(11000, _chainHeal),
        _cast(13000, _chainHeal),
      ], buffs);
      final small = _log([_cast(11000, _riptide)], buffs);
      final nothing = _log([_cast(11000, _riptide)], []);
      List<Finding> findings(FightLog mine) => const RankFindings()(
        CompareFights(resto)([fight('You', mine), fight('Rank 1', big)], []),
      ).findings.where((f) => f.kind == FindingKind.freeCastValue).toList();

      final behind = findings(small).single;
      expect(behind.subject, 'Innervate');
      expect([behind.yours, behind.rank1], [3800, 21400]);
      expect(
        behind.whatToTry,
        'Cast Chain Heal back to back while Innervate is up.',
      );
      // No Innervate received: no one is behind for not getting one.
      expect(findings(nothing), isEmpty);
    });
  });

  test('Elemental registers no free-cast window', () {
    expect(const ElementalShaman().logRules.freeCastWindows, isEmpty);
  });

  test('the fixture window holds one Innervate, with four casts in it', () {
    final log = loadFixture('coiled_altar_heroic_resto_window', resto.logRules);
    final PlayerMetrics metrics = ComputePlayerMetrics(resto)(log);
    final window = metrics.freeCastWindows.single.windows.single;
    expect(window.start, const Duration(milliseconds: 31692));
    expect(window.length, const Duration(milliseconds: 8009));
    expect(
      [for (final c in window.casts) c.name],
      ['Riptide', 'Chain Heal', 'Chain Heal', 'Riptide'],
    );
    expect(window.manaSaved, 29000);
    expect(window.fill, closeTo(0.68, 0.01));
  });
}
