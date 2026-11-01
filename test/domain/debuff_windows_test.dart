import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/models/debuff_windows.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';

import 'player_metrics_fixture_test.dart';

const _shock = 188389;

FightLog _log(List<(int, LogBuffChange, int)> events, {int? boss = 9}) =>
    FightLog(
      reportCode: 'x',
      fight: LogFight(
        id: 1,
        name: '',
        encounterId: 1,
        kill: true,
        duration: const Duration(seconds: 100),
        difficulty: 5,
        size: 20,
        bossActorId: boss,
      ),
      playerName: '',
      playerId: 1,
      abilityNames: const {},
      casts: const [],
      resourceGains: const [],
      buffEvents: const [],
      talents: const {},
      debuffEvents: [
        for (final (s, change, target) in events)
          LogBuffEvent(
            time: Duration(seconds: s),
            abilityId: _shock,
            targetId: target,
            change: change,
          ),
      ],
    );

void main() {
  test('bands run from apply to remove, and gaps include both ends', () {
    final w = DebuffWindows.of(
      _log([
        (5, LogBuffChange.apply, 9),
        (20, LogBuffChange.refresh, 9),
        (30, LogBuffChange.remove, 9),
        (50, LogBuffChange.apply, 9),
        (60, LogBuffChange.apply, 7), // an add, not the boss
        (70, LogBuffChange.remove, 7),
        (95, LogBuffChange.remove, 9),
      ]),
      _shock,
    );

    expect(w.uptime, const Duration(seconds: 70));
    expect(w.uptimePercent, 70);
    expect(w.gaps, [
      (start: Duration.zero, length: const Duration(seconds: 5)),
      (start: const Duration(seconds: 30), length: const Duration(seconds: 20)),
      (start: const Duration(seconds: 95), length: const Duration(seconds: 5)),
    ]);
  });

  test('an open band closes at the fight end, and short gaps are skipped', () {
    final w = DebuffWindows.of(
      _log([
        (0, LogBuffChange.apply, 9),
        (40, LogBuffChange.remove, 9),
        (40, LogBuffChange.apply, 9),
      ]),
      _shock,
    );

    expect(w.uptimePercent, 100);
    expect(w.gaps, isEmpty);
  });

  test('without a boss id every target counts', () {
    final w = DebuffWindows.of(
      _log([(10, LogBuffChange.apply, 7)], boss: null),
      _shock,
    );
    expect(w.uptime, const Duration(seconds: 90));
  });

  test(
    'a window that starts mid-band, with only refreshes, is up throughout',
    () {
      final w = DebuffWindows.of(
        _log([(10, LogBuffChange.refresh, 9)]),
        _shock,
      );
      expect(w.uptimePercent, 100);
    },
  );

  group('fixtures', () {
    test('the Sszorak window has the debuff up throughout', () {
      final log = loadFixture();
      final w = DebuffWindows.of(log, _shock);
      expect(log.fight.bossActorId, 196);
      expect(log.debuffEvents, hasLength(6));
      expect(w.uptimePercent, 100);
      expect(w.gaps, isEmpty);
    });

    test('the Twin Fangs window ignores the adds it also hit', () {
      final log = loadFixture('twin_fangs_window');
      final w = DebuffWindows.of(log, _shock);
      expect(log.fight.bossActorId, 255);
      expect(log.debuffEvents.where((e) => e.targetId == 259), isNotEmpty);
      expect(w.uptimePercent, 100);
      expect(w.windows, hasLength(1));
    });
  });
}
