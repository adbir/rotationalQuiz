import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/domain/models/finding.dart';
import 'package:rotational_quiz/domain/use_cases/compare_fights.dart';
import 'package:rotational_quiz/domain/use_cases/compute_player_metrics.dart';
import 'package:rotational_quiz/domain/use_cases/rank_findings.dart';
import 'package:rotational_quiz/ui/features/boss_evaluation/view_models/finding_text.dart';

import '../test_helpers.dart';
import 'compute_player_metrics_test.dart'
    show at, begin, cast, metrics, off, on, stormkeeper;
import 'player_metrics_fixture_test.dart' show loadFixture;

const _ascendanceBuff = 114050;

/// [log] with two Ascendance windows, and a Stormkeeper cast of 1.3 s inside
/// each.
FightLog _withWindowCasts(FightLog log) {
  LogBuffEvent buff(num t, LogBuffChange change) => LogBuffEvent(
    time: at(t),
    abilityId: _ascendanceBuff,
    targetId: log.playerId,
    change: change,
  );
  LogCast sk(num t, {required bool isBegin}) => LogCast(
    time: at(t),
    abilityId: stormkeeper,
    targetId: log.playerId,
    isBegin: isBegin,
  );
  return FightLog(
    reportCode: log.reportCode,
    fight: log.fight,
    playerName: log.playerName,
    playerId: log.playerId,
    abilityNames: log.abilityNames,
    casts: [
      ...log.casts,
      sk(5, isBegin: true),
      sk(6.3, isBegin: false),
      sk(40, isBegin: true),
      sk(41.3, isBegin: false),
    ]..sort((a, b) => a.time.compareTo(b.time)),
    resourceGains: log.resourceGains,
    buffEvents: [
      ...log.buffEvents,
      buff(3, LogBuffChange.apply),
      buff(15, LogBuffChange.remove),
      buff(38, LogBuffChange.apply),
      buff(48, LogBuffChange.remove),
    ],
    talents: log.talents,
  );
}

void main() {
  group('Stormkeeper during Ascendance', () {
    test('counts the cast inside the window, not the one before it', () {
      final result = metrics(
        casts: [
          begin(10, stormkeeper),
          cast(11.3, stormkeeper),
          begin(22, stormkeeper),
          cast(23.3, stormkeeper),
        ],
        buffs: [on(20, _ascendanceBuff), off(35, _ascendanceBuff)],
      );
      final inside = result.windowCasts.single;
      expect(inside.name, 'Stormkeeper during Ascendance');
      expect(inside.count, 1);
      expect(inside.details.single.time, at(22));
      expect(inside.details.single.remaining, at(13));
      expect(inside.details.single.lost, at(1.3));
      expect(inside.timeLost, at(1.3));
    });

    test('uses the cast time when no begincast is logged', () {
      final result = metrics(
        casts: [cast(22, stormkeeper)],
        buffs: [on(20, _ascendanceBuff), off(35, _ascendanceBuff)],
      );
      expect(result.windowCasts.single.details.single.lost, at(1.5));
    });

    test('is none without an Ascendance buff', () {
      final result = metrics(casts: [cast(22, stormkeeper)]);
      expect(result.windowCasts.single.count, 0);
    });

    // Neither fixture holds events of the Ascendance buff, so the window is
    // the Ascendance cast plus 15 s. Sszorak casts Ascendance at 19.3 s and
    // begins Stormkeeper at 23.986 s, finishing at 24.968 s; Twin Fangs has no
    // Ascendance.
    test('the Sszorak fixture shows the cast, Twin Fangs none', () {
      final sszorak = ComputePlayerMetrics(spec)(loadFixture()).windowCasts;
      expect(sszorak.single.count, 1);
      expect(sszorak.single.details.single.time, at(23.986));
      expect(sszorak.single.timeLost, at(0.982));
      final fangs = loadFixture('twin_fangs_window');
      expect(ComputePlayerMetrics(spec)(fangs).windowCasts.single.count, 0);
    });

    test('is a finding with its text, when you do it and rank 1 does not', () {
      final mine = loadFixture('twin_fangs_window');
      final comparison = CompareFights(spec)([
        FightToCompare(label: 'You', log: _withWindowCasts(mine)),
        FightToCompare(label: 'Rank 1', log: mine),
      ], const []);
      final text = FindingText(
        comparison: comparison,
        resourceLabel: 'Maelstrom',
      );
      final finding = const RankFindings()(comparison).findings
          .firstWhere((f) => f.kind == FindingKind.castBeforeWindow);
      expect(finding.yours, 2);
      expect(finding.rank1, 0);
      expect(
        text.headline(finding),
        'You cast Stormkeeper during Ascendance 2 times, losing about '
        '2.6 s of it. Rank 1: 0.',
      );
      expect(
        text.where(finding),
        'at 5 s, 10.0 s of it left, at 40 s, 8.0 s of it left',
      );
      expect(
        finding.kind.whatToTry,
        'Cast Stormkeeper first, then Ascendance.',
      );
    });
  });
}
