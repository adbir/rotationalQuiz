import 'package:rotational_quiz/data/repositories/warcraft_logs_repository.dart';
import 'package:rotational_quiz/domain/models/enemy_group.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/domain/specs/rotation_spec.dart';
import 'package:rotational_quiz/utils/result.dart';

import 'domain/player_metrics_fixture_test.dart' show loadFixture;
import 'test_helpers.dart' as helpers;

/// A Warcraft Logs repository that serves the Twin Fangs fixture and never
/// touches the network. The player's fight is a wipe with a fifth of the casts
/// missing, rank 53 misses every fifth, and rank 1 is the fixture as logged.
/// The two add waves (28 s and 58 s) are made up to fit the 75 s window.
class FakeWarcraftLogsRepository implements WarcraftLogsRepository {
  FakeWarcraftLogsRepository({this.error, this.hold});

  /// Fails every call with this, when set.
  final Exception? error;

  /// Every call waits for this first, when set.
  final Future<void>? hold;

  @override
  RotationSpec get spec => helpers.spec;

  static const mine = 'mine';

  /// Ranked rows: rank 53 is 80 s long, the one nearest to the player's 75 s.
  static final top = [
    for (final (rank, code, seconds, dps) in [
      (1, 'rank1', 420, 336697.0),
      (2, 'rank2', 300, 330000.0),
      (53, 'rank53', 80, 302100.0),
    ])
      RankedLog(
        rank: rank,
        playerName: 'Player$rank',
        amount: dps,
        duration: Duration(seconds: seconds),
        itemLevel: 333,
        reportCode: code,
        fightId: 2,
      ),
  ];

  @override
  Future<Result<FightLog>> loadFight({
    required String reportCode,
    required int fightId,
    int? sourceId,
    String? playerName,
  }) async {
    await hold;
    if (error != null) return Result.error(error!);
    final log = loadFixture('twin_fangs_window');
    final (thin, kill) = switch (reportCode) {
      mine => (5, false),
      'rank53' => (6, true),
      _ => (0, true),
    };
    return Result.ok(
      FightLog(
        reportCode: reportCode,
        fight: LogFight(
          id: fightId,
          name: log.fight.name,
          encounterId: log.fight.encounterId,
          kill: kill,
          duration: log.fight.duration,
          difficulty: log.fight.difficulty,
          size: log.fight.size,
        ),
        playerName: playerName ?? '',
        playerId: log.playerId,
        abilityNames: log.abilityNames,
        casts: [
          for (final (i, cast) in log.casts.indexed)
            if (thin == 0 || i % thin != 0) cast,
        ],
        resourceGains: log.resourceGains,
        buffEvents: log.buffEvents,
        talents: log.talents,
      ),
    );
  }

  @override
  Future<Result<List<EnemyGroup>>> loadEnemyGroups({
    required String reportCode,
    required int fightId,
  }) async {
    await hold;
    if (error != null) return Result.error(error!);
    return Result.ok([
      EnemyGroup(
        name: 'Spawn of Vexhul',
        arrivals: [
          for (final ms in [28000, 28100, 28200, 58000, 58100, 58200])
            Duration(milliseconds: ms),
        ],
      ),
    ]);
  }

  @override
  Future<Result<List<RankedLog>>> topLogs({
    required int encounterId,
    required int difficulty,
    int count = 100,
  }) async {
    await hold;
    if (error != null) return Result.error(error!);
    return Result.ok(top);
  }
}
