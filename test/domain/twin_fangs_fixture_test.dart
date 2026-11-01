import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/data/services/warcraft_logs_service.dart';
import 'package:rotational_quiz/domain/models/enemy_group.dart';
import 'package:rotational_quiz/domain/use_cases/detect_pooling.dart';
import 'package:rotational_quiz/domain/use_cases/rebuild_resource_timeline.dart';

import '../test_helpers.dart';
import 'player_metrics_fixture_test.dart' show loadFixture;

/// 75 seconds of a real Mythic Twin Fangs kill (rank 1, 420 s), from 225 s to
/// 300 s of the pull. The Spawn of Vexhul and Broodling wave arrives at 28 s
/// into the window, and a Barbed Bulwark wave at 2 s.
void main() {
  final log = loadFixture('twin_fangs_window');
  final timeline = const RebuildResourceTimeline(spec)(log);
  final enemies = [
    for (final e
        in (jsonDecode(
              File('test/fixtures/twin_fangs_window.json').readAsStringSync(),
            ) as JsonMap)['enemies']!
            as List)
      EnemyGroup(
        name: (e as JsonMap)['name']! as String,
        arrivals: [
          for (final t in e['arrivals']! as List)
            Duration(milliseconds: (t as num).toInt()),
        ],
      ),
  ];

  test('rebuilds Maelstrom within 8 of every logged reading', () {
    expect(timeline.checkpoints, hasLength(17));
    expect(timeline.maxAbsDrift, lessThanOrEqualTo(8));
    expect(timeline.meanAbsDrift, lessThan(2));
  });

  test('finds the add wave from the first enemy actions', () {
    final adds = enemies.singleWhere((e) => e.name == 'Spawn of Vexhul');
    expect(adds.waveStarts().single.inMilliseconds, closeTo(28100, 100));
  });

  test('top player holds a spender for the add wave', () {
    final wave = enemies
        .singleWhere((e) => e.name == 'Spawn of Vexhul')
        .waveStarts();
    final report = const DetectPooling(spec)(log, timeline, wave).single;

    // No spender for 15 s (over 10 s), then an Earthquake 2 s after the spawn.
    expect(report.isHeld, isTrue);
    expect(
      report.gapSinceLastSpender,
      greaterThan(const Duration(seconds: 10)),
    );
    expect(report.firstSpenderAfterName, 'Earthquake');
    expect(report.firstSpenderAfter, lessThan(const Duration(seconds: 3)));
    expect(report.lowestBefore, lessThan(report.levelAtEvent));
  });
}
