import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/domain/use_cases/detect_pooling.dart';
import 'package:rotational_quiz/domain/use_cases/rebuild_resource_timeline.dart';

import '../test_helpers.dart';
import 'player_metrics_fixture_test.dart' show loadFixture;

const _earthShock = 8042;
const _lavaBurst = 51505;

Duration _s(int seconds) => Duration(seconds: seconds);

/// A made-up 60 s fight: 3 Maelstrom a second, 60 spent by an Earth Shock at
/// each of [shocks].
FightLog _syntheticLog(List<int> shocks) => FightLog(
  reportCode: 'synthetic',
  fight: LogFight(
    id: 1,
    name: 'Test',
    encounterId: 1,
    kill: true,
    duration: _s(60),
    difficulty: 5,
    size: 20,
  ),
  playerName: '',
  playerId: 1,
  abilityNames: const {},
  casts: [
    for (final t in shocks)
      LogCast(time: _s(t), abilityId: _earthShock, targetId: 1, isBegin: false),
  ],
  resourceGains: [
    for (var t = 1; t <= 60; t++)
      LogResourceGain(
        time: _s(t),
        abilityId: _lavaBurst,
        type: maelstromResourceType,
        amount: 3,
        waste: 0,
        max: 125,
      ),
  ],
  buffEvents: const [],
  talents: const {},
);

void main() {
  const rebuild = RebuildResourceTimeline(spec);

  group('rebuild', () {
    test('stays within 8 Maelstrom of 19 logged readings', () {
      final timeline = rebuild(loadFixture());

      expect(timeline.checkpoints, hasLength(19));
      // One missed or extra Lava Burst gain is 8.
      expect(timeline.maxAbsDrift, lessThanOrEqualTo(8));
      expect(timeline.meanAbsDrift, lessThan(2));
    });

    test('never goes below 0 or above the cap', () {
      final timeline = rebuild(loadFixture());

      for (final point in timeline.points) {
        expect(point.amount, inInclusiveRange(0, 125));
      }
    });

    test('a hand-made fight adds gains and subtracts costs', () {
      final timeline = rebuild(_syntheticLog([40]), startAmount: 0);

      expect(timeline.at(_s(30)), 90);
      expect(timeline.at(_s(40)), 120 - 60);
      expect(timeline.at(_s(41)), 63);
    });
  });

  group('pooling', () {
    const detect = DetectPooling(spec);

    test('flags Maelstrom held high before an event and spent after', () {
      // Nothing spent for 36 s, then two Earth Shocks after the event.
      final log = _syntheticLog([37, 38, 50]);
      final report = detect(log, rebuild(log, startAmount: 0), [_s(36)]).single;

      expect(report.isHeld, isTrue);
      expect(report.firstSpenderAfter, _s(1));
    });

    test('does not flag a player spending steadily through the event', () {
      final log = _syntheticLog([10, 20, 30, 40, 45, 50, 55]);
      final report = detect(log, rebuild(log, startAmount: 0), [_s(36)]).single;

      expect(report.isHeld, isFalse);
    });

    test('does not flag a high level that nothing spends afterwards', () {
      final log = _syntheticLog([]);
      final report = detect(log, rebuild(log, startAmount: 0), [_s(36)]).single;

      expect(report.firstSpenderAfter, isNull);
      expect(report.isHeld, isFalse);
    });
  });
}
