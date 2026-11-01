import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/domain/models/finding.dart';
import 'package:rotational_quiz/domain/use_cases/compare_fights.dart';
import 'package:rotational_quiz/domain/use_cases/compute_player_metrics.dart';
import 'package:rotational_quiz/domain/use_cases/rank_findings.dart';
import 'package:rotational_quiz/ui/features/boss_evaluation/view_models/finding_text.dart';

import '../test_helpers.dart';
import 'player_metrics_fixture_test.dart' show loadFixture;

const _shock = 188389;

/// The Twin Fangs fixture with Flame Shock applied at each of [bands]'s starts
/// and removed at its ends, then refreshed once inside the first band.
FightLog _shocked(FightLog log, List<(num, num)> bands) {
  LogBuffEvent e(num t, LogBuffChange change) => LogBuffEvent(
    time: Duration(milliseconds: (t * 1000).round()),
    abilityId: _shock,
    targetId: log.fight.bossActorId ?? 0,
    change: change,
  );
  return FightLog(
    reportCode: log.reportCode,
    fight: log.fight,
    playerName: log.playerName,
    playerId: log.playerId,
    abilityNames: {...log.abilityNames, _shock: 'Flame Shock'},
    casts: log.casts,
    resourceGains: log.resourceGains,
    buffEvents: log.buffEvents,
    talents: log.talents,
    debuffEvents: [
      for (final (a, b) in bands) ...[
        e(a, LogBuffChange.apply),
        e(b, LogBuffChange.remove),
      ],
      e(bands.first.$1 + 1, LogBuffChange.refresh),
    ]..sort((x, y) => x.time.compareTo(y.time)),
  );
}

void main() {
  test('the Sszorak fixture holds Flame Shock up the whole fight', () {
    final dot = ComputePlayerMetrics(spec)(loadFixture()).dotUptime.single;
    expect(dot.percent, closeTo(100, 0.5));
    expect(dot.gaps, isEmpty);
  });

  final fangs = loadFixture('twin_fangs_window');
  final length = fangs.fight.duration.inMilliseconds / 1000;

  test('is per DoT of the spec, with gaps and apply/refresh rows', () {
    final log = _shocked(fangs, [(0, 20), (30, length)]);
    final dot = ComputePlayerMetrics(spec)(log).dotUptime.single;
    expect(dot.name, 'Flame Shock');
    expect(dot.down, const Duration(seconds: 10));
    expect(dot.percent, closeTo(100 * (length - 10) / length, 1e-9));
    expect(dot.gaps.single.start, const Duration(seconds: 20));
    expect(dot.gaps.single.length, const Duration(seconds: 10));
    expect(dot.applications, 3);
  });

  test('is a finding with its text, when you are below rank 1', () {
    final comparison = CompareFights(spec)([
      FightToCompare(
        label: 'You',
        log: _shocked(fangs, [(0, 20), (30, 50), (60, length)]),
      ),
      FightToCompare(label: 'Rank 1', log: _shocked(fangs, [(0, length)])),
    ], const []);
    final text = FindingText(
      comparison: comparison,
      resourceLabel: 'Maelstrom',
    );
    final finding = const RankFindings()(comparison).findings
        .firstWhere((f) => f.kind == FindingKind.dotUptime);
    expect(finding.rank1, 100);
    expect(
      text.headline(finding),
      'Flame Shock was up ${finding.yours.toStringAsFixed(1)}% of the fight. '
      'Rank 1: 100.0%.',
    );
    expect(text.where(finding), 'down 20.0-30.0 s, 50.0-60.0 s');
    expect(finding.kind.whatToTry, 'Refresh Flame Shock before it falls off.');
  });

  test('is not ranked when you match rank 1', () {
    final log = _shocked(fangs, [(0, length)]);
    final comparison = CompareFights(spec)([
      FightToCompare(label: 'You', log: log),
      FightToCompare(label: 'Rank 1', log: log),
    ], const []);
    final report = const RankFindings()(comparison);
    expect(
      report.findings.map((f) => f.kind),
      isNot(contains(FindingKind.dotUptime)),
    );
    expect(report.sameAsRank1, contains(FindingKind.dotUptime));
  });
}
