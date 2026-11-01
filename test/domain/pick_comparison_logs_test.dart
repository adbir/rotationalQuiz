import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/models/boss_comparison.dart';
import 'package:rotational_quiz/domain/models/enemy_group.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/domain/use_cases/compare_fights.dart';
import 'package:rotational_quiz/domain/use_cases/pick_comparison_logs.dart';
import 'package:rotational_quiz/domain/use_cases/pick_stretch_starts.dart';

import '../test_helpers.dart';
import 'player_metrics_fixture_test.dart' show loadFixture;

RankedLog ranked(int rank, int seconds) => RankedLog(
  rank: rank,
  playerName: 'P$rank',
  amount: 1,
  duration: Duration(seconds: seconds),
  itemLevel: 330,
  reportCode: 'r$rank',
  fightId: 1,
);

EnemyGroup adds(List<int> seconds) => EnemyGroup(
  name: 'g',
  arrivals: [for (final s in seconds) Duration(seconds: s)],
);

List<int> ranks(List<RankedLog> logs) => [for (final l in logs) l.rank];

void main() {
  const pick = PickComparisonLogs();
  const fought = Duration(seconds: 394);

  group('PickComparisonLogs', () {
    test('takes the closest length, then rank 1', () {
      final top = [
        ranked(1, 420),
        ranked(2, 300),
        ranked(3, 400),
        ranked(4, 380),
      ];
      expect(ranks(pick(top, fought)), [3, 1]);
    });

    test('rank 1 never takes both places', () {
      expect(ranks(pick([ranked(1, 394), ranked(2, 500)], fought)), [2, 1]);
    });

    test('a tie goes to the better rank', () {
      final top = [ranked(1, 420), ranked(7, 390), ranked(5, 398)];
      expect(pick(top, fought).first.rank, 5);
    });

    test('works with few or no logs', () {
      expect(pick(const [], fought), isEmpty);
      expect(ranks(pick([ranked(1, 400)], fought)), [1]);
    });
  });

  test('PickStretchStarts uses waves, then phases, then nothing', () {
    const pickStarts = PickStretchStarts();
    const end = Duration(seconds: 100);
    final (source, starts) = pickStarts(
      end: end,
      phaseStarts: const [Duration(seconds: 50)],
      groups: [
        adds([10, 40]),
        adds([20, 50, 80]),
        adds([99]),
      ],
    );
    expect(source, StretchSource.waves);
    expect([for (final s in starts) s.inSeconds], [20, 50, 80]);

    final (phaseSource, phases) = pickStarts(
      end: end,
      phaseStarts: const [Duration.zero, Duration(seconds: 50)],
      groups: [
        adds([10]),
      ],
    );
    expect(phaseSource, StretchSource.phases);
    expect([for (final s in phases) s.inSeconds], [50]);

    final (noneSource, _) = pickStarts(
      end: end,
      phaseStarts: const [],
      groups: const [],
    );
    expect(noneSource, StretchSource.wholeFight);
  });

  test('PickStretchStarts prefers the waves the caller scores highest', () {
    final (_, starts) = const PickStretchStarts()(
      end: const Duration(seconds: 100),
      phaseStarts: const [],
      groups: [
        adds([10, 40, 70]),
        adds([20, 50]),
      ],
      preference: (waves) => waves.first.inSeconds == 20 ? 1 : 0,
    );
    expect([for (final s in starts) s.inSeconds], [20, 50]);
  });

  test('CompareFights cuts the fought portion at the player waves', () {
    final log = loadFixture('twin_fangs_window');
    final comparison = const CompareFights(spec)(
      [
        FightToCompare(label: 'You', log: log),
        FightToCompare(label: 'Rank 1', log: log, ranked: ranked(1, 75)),
      ],
      [
        adds([28, 58]),
      ],
    );
    expect(comparison.fought, const Duration(seconds: 75));
    expect(comparison.stretchSource, StretchSource.waves);
    expect(
      [for (final s in comparison.stretches) s.start.inSeconds],
      [0, 28, 58],
    );
    expect(comparison.castsPerMinute.first, comparison.castsPerMinute.last);
    expect(comparison.pooling.first, hasLength(2));
    expect(comparison.logs.first.dps, isNull);
    expect(comparison.logs.last.dps, 1);
  });
}
