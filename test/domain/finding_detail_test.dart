import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/domain/models/finding.dart';
import 'package:rotational_quiz/domain/use_cases/compare_fights.dart';
import 'package:rotational_quiz/domain/use_cases/compute_player_metrics.dart';
import 'package:rotational_quiz/domain/use_cases/rank_findings.dart';
import 'package:rotational_quiz/ui/features/boss_evaluation/view_models/finding_text.dart';

import '../fake_warcraft_logs_repository.dart';
import '../test_helpers.dart';
import 'player_metrics_fixture_test.dart' show loadFixture;
import 'rank_findings_test.dart' show compare, wasting;

Duration s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

/// The Twin Fangs fixture with Stormkeeper and Ascendance fading and
/// Overcharge! refreshed after each.
FightLog withLostSpenders() {
  final log = loadFixture('twin_fangs_window');
  LogBuffEvent event(num t, int id, LogBuffChange change) => LogBuffEvent(
    time: s(t),
    abilityId: id,
    targetId: log.playerId,
    change: change,
  );
  return FightLog(
    reportCode: log.reportCode,
    fight: log.fight,
    playerName: log.playerName,
    playerId: log.playerId,
    abilityNames: {
      ...log.abilityNames,
      191634: 'Stormkeeper',
      114050: 'Ascendance',
    },
    casts: log.casts,
    resourceGains: log.resourceGains,
    buffEvents: [
      ...log.buffEvents,
      event(10, 191634, LogBuffChange.remove),
      event(12, 1300222, LogBuffChange.refresh),
      event(30, 114050, LogBuffChange.remove),
      event(33, 1300222, LogBuffChange.refresh),
      event(50, 1300222, LogBuffChange.refresh),
    ],
    talents: log.talents,
  );
}

void main() {
  group('gaps', () {
    test('say when, how long and what was up', () {
      final gaps = ComputePlayerMetrics(spec)(loadFixture()).gaps.details;
      expect(gaps.map((g) => g.start), [
        s(4.713),
        s(31.862),
        s(59.706),
        s(61.654),
      ]);
      expect(gaps[3].length, s(2.474));
      // Ghost Wolf and Spiritwalker's Grace (a free cast at 18.9 s, a normal
      // one at 19.3 s) are both up over the second gap.
      expect(
        [for (final g in gaps) g.inMovementForm],
        [false, true, true, true],
      );
      expect([for (final g in gaps) g.graceUp], [false, true, false, false]);
      // Ready before the first normal cast, and on its 90 s cooldown after.
      expect([for (final g in gaps) g.graceReady], [true, false, false, false]);
    });

    test('are matched to rank 1 gaps within 3 s', () async {
      final c = await compare([FakeWarcraftLogsRepository.mine, 'rank1']);
      final mine = c.logs.first.metrics.gaps.details;
      expect(c.gapsAlsoInRank1, hasLength(mine.length));
      expect(c.gapsAlsoInRank1.where((shared) => shared), hasLength(1));
    });

    test('Where sums them up', () async {
      final c = await compare([
        FakeWarcraftLogsRepository.mine,
        'rank53',
        'rank1',
      ]);
      final text = FindingText(comparison: c, resourceLabel: 'Maelstrom');
      final gaps = const RankFindings()(c).findings
          .firstWhere((f) => f.kind == FindingKind.castsPerMinute);
      expect(
        text.where(gaps),
        "5 gaps over 1.8 s (rank 1: 1): 4 with Spiritwalker's Grace up, 1 "
        'at the same time as rank 1. Longest 2.5 s, rank 1: 1.9 s. '
        '3 of 3 stretches behind; worst 28-58 s (38 vs 52).',
      );
    });
  });

  test('a lost free spender names the fade before it', () async {
    final log = withLostSpenders();
    final lost = ComputePlayerMetrics(spec)(log).spenders.lostFreeDetails;
    expect([for (final l in lost) l.time], [s(12), s(33), s(50)]);
    expect(
      [for (final l in lost) l.sourceName],
      ['Stormkeeper', 'Ascendance', 'Ascendance'],
    );

    final comparison = CompareFights(spec)([
      FightToCompare(label: 'You', log: log),
      FightToCompare(label: 'Rank 1', log: loadFixture('twin_fangs_window')),
    ], const []);
    final text = FindingText(
      comparison: comparison,
      resourceLabel: 'Maelstrom',
    );
    final finding = const RankFindings()(comparison).findings
        .firstWhere((f) => f.kind == FindingKind.lostFreeSpenders);
    expect(
      text.where(finding),
      'at 12 s after Stormkeeper faded, at 33 s after Ascendance faded, '
      'at 50 s after Ascendance faded',
    );
  });

  test('wasted resource names the worst stretch', () {
    final c = CompareFights(spec)([
      FightToCompare(label: 'You', log: wasting({10: 5, 40: 34})),
      FightToCompare(label: 'Rank 1', log: wasting({10: 1, 40: 2})),
    ], const []);
    final text = FindingText(comparison: c, resourceLabel: 'Maelstrom');
    final f = const RankFindings()(c).findings
        .firstWhere((f) => f.kind == FindingKind.wastedResource);
    expect(text.where(f), 'mostly at 30-60 s (34 vs 2 for rank 1).');
  });

  test('wasted resource on one stretch is the whole fought portion', () {
    final c = CompareFights(spec)([
      FightToCompare(label: 'You', log: loadFixture('twin_fangs_window')),
      FightToCompare(label: 'Rank 1', log: loadFixture()),
    ], const []);
    final text = FindingText(comparison: c, resourceLabel: 'Maelstrom');
    final f = Finding(
      kind: FindingKind.wastedResource,
      yours: 9,
      rank1: 1,
      share: 8,
      behind: 8,
      valuesByLog: const [9, 1],
    );
    expect(text.where(f), startsWith('the whole fought portion'));
  });

  test('names the add instead of saying waves', () async {
    final c = await compare([FakeWarcraftLogsRepository.mine, 'rank1']);
    expect(c.eventName, 'Spawn of Vexhul');
    final text = FindingText(comparison: c, resourceLabel: 'Maelstrom');
    final held = Finding(
      kind: FindingKind.heldSpenders,
      yours: 0,
      rank1: 4,
      share: 1,
      behind: 4,
      valuesByLog: const [0, 4],
      waveTimes: [s(98), s(192)],
    );
    expect(
      text.headline(held),
      'Rank 1 held a spender before 4 Spawn of Vexhul arrivals and cast one '
      'within 5 s. You held before 0.',
    );
    expect(text.where(held), '2 Spawn of Vexhul arrivals at 98, 192 s.');
    expect(FindingKind.heldSpenders.whatToTry, contains('add wave'));
  });
}
