import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/apl/apl_document.dart';
import 'package:rotational_quiz/domain/models/enemy_presence.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/domain/models/replay_report.dart';
import 'package:rotational_quiz/domain/use_cases/replay_log.dart';

import '../test_helpers.dart';
import 'player_metrics_fixture_test.dart' show loadFixture, loadFixtureEnemies;

/// A short log with 40 Maelstrom from the pull and the given presses, all
/// instants at the given seconds.
FightLog syntheticLog(List<(double, String)> presses, [List<LogCast>? extra]) {
  Duration at(double seconds) =>
      Duration(milliseconds: (seconds * 1000).round());
  return FightLog(
    reportCode: 'synthetic',
    fight: const LogFight(
      id: 1,
      name: 'Dummy',
      encounterId: 1,
      kill: true,
      duration: Duration(minutes: 1),
      difficulty: 5,
      size: 20,
    ),
    playerName: '',
    playerId: 1,
    abilityNames: const {},
    casts: [
      ...?extra,
      for (final (seconds, id) in presses)
        LogCast(
          time: at(seconds),
          abilityId: spec.spells[id]!.spellId!,
          targetId: 2,
          isBegin: false,
        ),
    ],
    resourceGains: const [
      LogResourceGain(
        time: Duration.zero,
        abilityId: 1,
        type: maelstromResourceType,
        amount: 40,
        waste: 0,
        max: 125,
      ),
    ],
    buffEvents: const [],
    talents: spec.loadouts.first.talents,
  );
}

void main() {
  late AplDocument document;
  const replay = ReplayLog(spec);

  setUpAll(() async => document = (await loadedRepository()).document!);

  test("a log of the APL's own choices scores 100%", () {
    final presses = <(double, String)>[];
    for (var i = 0; i < 8; i++) {
      final time = 3.0 + i * 2;
      final report = replay(
        syntheticLog([...presses, (time, 'lightning_bolt')]),
        document,
      );
      presses.add((
        time,
        report.deviations.lastOrNull?.wanted ?? 'lightning_bolt',
      ));
    }

    final report = replay(syntheticLog(presses), document);

    expect(report.compared, 8);
    expect(report.agreementRate, 1);
    expect(report.deviations, isEmpty);
    // Not just Lightning Bolt every time.
    expect({for (final p in presses) p.$2}.length, greaterThan(1));
  });

  test('a different press is reported with the line that won', () {
    final report = replay(syntheticLog([(3, 'lightning_bolt')]), document);

    final deviation = report.deviations.single;
    expect(report.agreementRate, 0);
    expect(deviation.pressed, 'lightning_bolt');
    expect(deviation.wanted, isNotNull);
    expect(deviation.wanted, isNot('lightning_bolt'));
    expect(deviation.winningLine, contains(deviation.wanted));
    expect(deviation.time, const Duration(seconds: 3));
    expect(report.kinds.keys.single, startsWith('lightning_bolt instead of'));
  });

  test('presses of abilities outside the spell table are not compared', () {
    const ghostWolf = LogCast(
      time: Duration(seconds: 1),
      abilityId: 2645,
      targetId: -1,
      isBegin: false,
    );

    final report = replay(
      syntheticLog([(3, 'lightning_bolt')], [ghostWolf]),
      document,
    );

    expect(report.skippedPresses, 1);
    expect(report.compared, 1);
  });

  // Measured in docs/warcraft-logs.md ("APL replay"): 41% and 61%.
  group('fixtures', () {
    final presence = loadFixtureEnemies('twin_fangs_window');

    test("the owner's Sszorak window, one boss", () {
      final report = replay(
        loadFixture(),
        document,
        presence: EnemyPresence.single,
      );

      expect(report.compared, 46);
      expect(report.agreements, 19);
      expect(report.deviations, isNotEmpty);
    });

    test('rank 1 on Twin Fangs scores higher with the enemies it faced', () {
      final rank1 = replay(
        loadFixture('twin_fangs_window'),
        document,
        presence: presence,
      );
      final owner = replay(loadFixture(), document);

      expect(rank1.compared, 59);
      expect(rank1.agreementRate, greaterThan(0.58));
      expect(rank1.agreementRate, greaterThan(owner.agreementRate + 0.15));
    });

    test('rank 1 on Coiled Altar, with only the hittable boss counted', () {
      final report = replay(
        loadFixture('coiled_altar_window'),
        document,
        presence: loadFixtureEnemies('coiled_altar_window'),
      );

      // Both bosses up all fight scored 8 of 61 (13%).
      expect(report.compared, 61);
      expect(report.agreements, 11);
      expect(report.exactDeviations, hasLength(42));
    });

    test('the enemy count beats guessing one target', () {
      final log = loadFixture('twin_fangs_window');
      double rate({int targets = 1, EnemyPresence? presence}) => replay(
        log,
        document,
        targets: targets,
        presence: presence,
      ).agreementRate;

      expect(rate(presence: presence), greaterThan(rate()));
    });

    test('enemy counts are seen, so they are no longer estimates', () {
      final log = loadFixture('twin_fangs_window');
      bool guessesTargets(ReplayReport r) => r.deviations.any(
        (d) =>
            d.estimated.contains('spell_targets.chain_lightning') ||
            d.estimated.contains('active_enemies'),
      );

      expect(guessesTargets(replay(log, document, targets: 2)), isTrue);
      expect(
        guessesTargets(replay(log, document, presence: presence)),
        isFalse,
      );
    });
  });
}
