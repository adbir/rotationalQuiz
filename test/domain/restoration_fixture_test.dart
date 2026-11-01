import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/models/buff_windows.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/domain/specs/restoration_shaman.dart';

import 'player_metrics_fixture_test.dart' show loadFixture;

const _fixture = 'coiled_altar_heroic_resto_window';

/// 75 seconds of the rank 1 Heroic Coiled Altar Restoration kill (305 s), from
/// 195 s to 270 s of the pull. It holds the second Ascendance, cast 0.8 s after
/// a Surging Totem, and the Spirit Link Totem just after it. Times are from the
/// window's start; the player's details are removed.
void main() {
  const resto = RestorationShaman();
  late FightLog log;

  setUpAll(() => log = loadFixture(_fixture));

  int casts(int abilityId) =>
      log.casts.where((c) => c.abilityId == abilityId && !c.isBegin).length;

  test('loads as a Heroic Coiled Altar Restoration window', () {
    expect(log.fight.encounterId, 3429);
    expect(log.fight.difficulty, 4);
    expect(log.fight.duration, const Duration(seconds: 75));
    expect(log.playerName, isEmpty);
    expect(log.talents, containsAll(['riptide', 'surging_totem']));
    expect(log.talents, containsAll(resto.loadouts.single.talents));
  });

  test('cast counts of the cooldowns the metrics look at', () {
    final byId = {for (final s in resto.spells.values) s.spellId: s.id};
    final counts = {
      for (final id in [61295, 5394, 444995, 114052, 98008, 1267068])
        byId[id]!: casts(id),
    };
    expect(counts, {
      'riptide': 15,
      'healing_stream_totem': 4,
      'surging_totem': 3,
      'ascendance': 1,
      'spirit_link_totem': 1,
      'stormstream_totem': 1,
    });
  });

  test('Ascendance follows a Surging Totem within a second', () {
    final ascendance = log.casts.singleWhere(
      (c) => c.abilityId == 114052 && !c.isBegin,
    );
    final before = log.casts.where(
      (c) => c.abilityId == 444995 && c.time < ascendance.time,
    );
    expect(
      ascendance.time - before.last.time,
      lessThan(const Duration(seconds: 1)),
    );
  });

  test('mana readings run from 0 to the log max', () {
    final readings = [
      for (final c in log.casts)
        for (final r in c.resources)
          if (r.type == resto.logRules.resourceType) r,
    ];
    expect(readings.length, greaterThan(40));
    for (final r in readings) {
      expect(r.max, 283920);
      expect(r.amount, inInclusiveRange(0, r.max));
    }
    expect(readings.where((r) => r.cost != null && r.cost! > 0), isNotEmpty);
  });

  test('Healing Rain is up for most of the window', () {
    final rain = BuffWindows.of(log, 1307888);
    final up = rain.windows.fold(
      Duration.zero,
      (sum, w) => sum + (w.end - w.start),
    );
    expect(up.inMilliseconds / 75000, greaterThan(0.8));
  });

  test('buffs the player applied and received are there', () {
    final buffIds = {for (final e in log.buffEvents) e.abilityId};
    expect(buffIds, containsAll([1307888, 1267089, 53390, 114052, 382024]));
    final received = {for (final b in log.receivedBuffs) b.abilityId};
    expect(received, containsAll([1307888, 61295, 53390, 29166]));
  });

  test('names no player and stays small', () {
    final file = File('test/fixtures/$_fixture.json');
    expect(file.lengthSync(), lessThan(200 * 1024));
    final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    expect(json['playerId'], 1);
    expect(json.keys, isNot(contains('playerName')));
  });
}
