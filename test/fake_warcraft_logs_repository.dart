import 'package:rotational_quiz/data/repositories/warcraft_logs_repository.dart';
import 'package:rotational_quiz/domain/models/enemy_group.dart';
import 'package:rotational_quiz/domain/models/enemy_presence.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/domain/specs/rotation_spec.dart';
import 'package:rotational_quiz/utils/result.dart';

import 'domain/player_metrics_fixture_test.dart' show loadFixture;
import 'test_helpers.dart' as helpers;

/// A Warcraft Logs repository that serves the Twin Fangs fixture and never
/// touches the network. Built for a healer, it serves the Heroic Coiled Altar
/// Restoration fixture instead, and the player never cast Surging Totem. The player's fight is a wipe with a fifth of the casts
/// missing, rank 53 misses every fifth, and rank 1 is the fixture as logged.
/// The two add waves (28 s and 58 s) are made up to fit the 75 s window.
class FakeWarcraftLogsRepository implements WarcraftLogsRepository {
  FakeWarcraftLogsRepository({
    this.error,
    this.hold,
    this.matchRank1 = false,
    RotationSpec? spec,
  }) : _spec = spec ?? helpers.spec;

  final RotationSpec _spec;

  bool get _healer => _spec.logRules.rankingMetric == 'hps';

  /// The player's fight is rank 1's, so nothing differs.
  final bool matchRank1;

  /// Fails every call with this, when set.
  final Exception? error;

  /// Every call waits for this first, when set.
  final Future<void>? hold;

  @override
  RotationSpec get spec => _spec;

  static const mine = 'mine';

  /// Ranked rows: rank 53 is 80 s long, the one nearest to the player's 75 s.
  static final top = _ranked(1);
  static final _healerTop = _ranked(1.3);

  static List<RankedLog> _ranked(double scale) => [
    for (final (rank, code, seconds, dps) in [
      (1, 'rank1', 420, 336697.0 * scale),
      (2, 'rank2', 300, 330000.0 * scale),
      (53, 'rank53', 80, 302100.0 * scale),
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
    bool includeTargetsHit = false,
  }) async {
    await hold;
    if (error != null) return Result.error(error!);
    final log = _healer
        ? loadFixture('coiled_altar_heroic_resto_window', _spec.logRules)
        : loadFixture('twin_fangs_window');
    final noTotem = _spec.spells['surging_totem']?.spellId;
    final (thin, kill) = switch (reportCode) {
      mine => matchRank1 ? (0, true) : (5, false),
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
          bossActorId: log.fight.bossActorId,
        ),
        playerName: playerName ?? '',
        playerId: log.playerId,
        abilityNames: log.abilityNames,
        casts: [
          for (final (i, cast) in log.casts.indexed)
            if (_healer && reportCode == mine && !matchRank1
                ? cast.abilityId != noTotem
                : thin == 0 || i % thin != 0)
              cast,
        ],
        resourceGains: log.resourceGains,
        buffEvents: log.buffEvents,
        talents: log.talents,
        debuffEvents: log.debuffEvents,
        receivedBuffs: log.receivedBuffs,
        appliedBuffs: log.appliedBuffs,
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
  Future<Result<EnemyPresence>> loadEnemyPresence({
    required String reportCode,
    required int fightId,
    required int playerId,
  }) async {
    await hold;
    if (error != null) return Result.error(error!);
    return Result.ok(EnemyPresence.single);
  }

  @override
  Future<Result<List<RankedLog>>> topLogs({
    required int encounterId,
    required int difficulty,
    int count = 100,
  }) async {
    await hold;
    if (error != null) return Result.error(error!);
    return Result.ok(_healer ? _healerTop : top);
  }
}
