import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/use_cases/detect_pooling.dart';
import 'package:rotational_quiz/domain/use_cases/rebuild_resource_timeline.dart';

import '../test_helpers.dart';
import 'player_metrics_fixture_test.dart' show loadFixture, loadFixtureEnemies;

/// 75 seconds of a real Mythic Coiled Altar kill (rank 1, 514 s), from 225 s
/// to 300 s of the pull. Two pairs of Spiteful Soulcoilers arrive in it, at
/// 24.5 s and 57.5 s into the window (249.5 s and 282.5 s of the pull). Six
/// Manifestations of Dread arrive just before each pair, and the player
/// damages neither them nor the Axegrinders, so they are not in the fixture.
void main() {
  final log = loadFixture('coiled_altar_window');
  final timeline = const RebuildResourceTimeline(spec)(log);
  final enemies = loadFixtureEnemies('coiled_altar_window').groups;
  final soulcoilers = enemies.singleWhere(
    (e) => e.name == 'Spiteful Soulcoiler',
  );

  test('rebuilds Maelstrom within 9 of every logged reading', () {
    expect(timeline.checkpoints, hasLength(11));
    // 9 is the Stormkeeper cast at 23.0 s: its reading and a Lava Burst gain
    // share a millisecond and the gain lands first (see docs/warcraft-logs.md,
    // "Reading a fight"). Of the other ten, nine are exact and one is 4 off.
    expect(timeline.maxAbsDrift, lessThanOrEqualTo(9));
    expect(timeline.meanAbsDrift, lessThan(2));
    expect(timeline.checkpoints.where((c) => c.drift.abs() > 4), hasLength(1));
  });

  test('finds both Soulcoiler waves from the first enemy actions', () {
    final waves = soulcoilers.waveStarts();
    expect(waves, hasLength(2));
    expect(waves[0].inMilliseconds, closeTo(24500, 100));
    expect(waves[1].inMilliseconds, closeTo(57500, 100));
    // Two arrive together each time.
    expect(soulcoilers.arrivals, hasLength(4));
  });

  test('counts the hittable boss and the Soulcoilers up', () {
    // Zul'jan is not hittable in 225 to 300 s, and Malacrass from 231.3 s, so
    // one boss is up (see "Untargetable stretches" in docs/warcraft-logs.md).
    final malacrass = enemies.singleWhere(
      (e) => e.name == 'Hex Lord Malacrass',
    );
    expect(enemies.map((e) => e.name), isNot(contains("Zul'jan")));
    expect(malacrass.aliveAt(const Duration(seconds: 5)), 0);
    expect(malacrass.aliveAt(const Duration(seconds: 7)), 1);
    expect(malacrass.aliveAt(const Duration(seconds: 75)), 1);
    expect(soulcoilers.aliveAt(const Duration(seconds: 26)), 2);
    expect(soulcoilers.aliveAt(const Duration(seconds: 70)), 2);
    expect(soulcoilers.aliveAt(const Duration(seconds: 40)), 2);
    expect(soulcoilers.aliveAt(const Duration(seconds: 56)), 0);
  });

  test('top player holds a spender for both waves', () {
    final reports = const DetectPooling(spec)(
      log,
      timeline,
      soulcoilers.waveStarts(),
    );

    // No spender for 12 s or more (over 10 s), then an Elemental Blast within
    // 4 s of the arrival.
    for (final report in reports) {
      expect(report.isHeld, isTrue);
      expect(
        report.gapSinceLastSpender,
        greaterThan(const Duration(seconds: 10)),
      );
      expect(report.firstSpenderAfterName, 'Elemental Blast');
      expect(report.firstSpenderAfter, lessThan(const Duration(seconds: 4)));
    }
  });
}
