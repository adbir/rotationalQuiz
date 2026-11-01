import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/data/repositories/warcraft_logs_mapper.dart';
import 'package:rotational_quiz/data/services/warcraft_logs_service.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/domain/models/player_metrics.dart';
import 'package:rotational_quiz/domain/use_cases/compute_player_metrics.dart';

import '../test_helpers.dart';

/// 75 seconds of a real Mythic Sszorak kill, as raw Warcraft Logs events with
/// the player's details removed. The window runs from 225 s to 300 s of the
/// pull, so it starts with buffs already up. Times below are from its start.
FightLog loadFixture() {
  final json = jsonDecode(
    File('test/fixtures/sszorak_window.json').readAsStringSync(),
  ) as JsonMap;
  final fight = json['fight'] as JsonMap;
  final start = WarcraftLogsMapper.fightStart(fight);
  Iterable<JsonMap> rows(String key) =>
      (json[key] as List).whereType<JsonMap>();
  return FightLog(
    reportCode: 'fixture',
    fight: WarcraftLogsMapper.fight(fight),
    playerName: '',
    playerId: json['playerId'] as int,
    abilityNames: {
      for (final ability in rows('abilities'))
        ability['gameID'] as int: ability['name'] as String,
    },
    casts: [for (final r in rows('casts')) ?WarcraftLogsMapper.cast(r, start)],
    resourceGains: [
      for (final r in rows('resources'))
        ?WarcraftLogsMapper.resourceGain(r, start),
    ],
    buffEvents: [
      for (final r in rows('buffs')) ?WarcraftLogsMapper.buffEvent(r, start),
    ],
    talents: {...(json['talents'] as List).cast<String>()},
  );
}

void main() {
  late PlayerMetrics result;

  setUpAll(() => result = ComputePlayerMetrics(spec)(loadFixture()));

  CooldownMetrics cooldown(String id) =>
      result.cooldowns.singleWhere((c) => c.id == id);

  test('casts', () {
    expect(result.fightLength, const Duration(seconds: 75));
    // 60 cast events less the 5 Flame Shock echoes.
    expect(result.casts.total, 55);
    expect(result.casts.perMinute, closeTo(44, 1e-9));

    final byName = {for (final a in result.casts.byAbility) a.name: a.casts};
    expect(byName['Lava Burst'], 16);
    expect(byName['Lightning Bolt'], 14);
    expect(byName['Elemental Blast'], 8);
    expect(byName['Flame Shock'], 5);
    expect(byName['Ghost Wolf'], 3);

    expect([for (final p in result.casts.byPhase) p.casts], [1, 22, 32]);
    expect(
      result.casts.byPhase[1].perMinute,
      closeTo(22 / (25.038 / 60), 1e-9),
    );
  });

  test('gaps', () {
    // 1.897, 1.948, 2.011 and 2.474 s.
    expect(result.gaps.count, 4);
    expect(result.gaps.longest, const Duration(milliseconds: 2474));
  });

  test('Maelstrom', () {
    expect(result.resource.gained, 350);
    expect(result.resource.wasted, 79);
    expect(result.resource.gainedPerMinute, closeTo(280, 1e-9));
    expect(result.resource.wastedPerMinute, closeTo(63.2, 1e-9));
    expect(result.resource.wastedPercent, closeTo(22.571, 1e-3));
  });

  test('spenders', () {
    final spenders = result.spenders;
    expect(spenders.casts, 8);
    // The last one is at 74.327 s, and its buff ended 1 ms before the cast.
    expect(spenders.withBuff, 8);
    expect(spenders.withBuffPercent, closeTo(100, 1e-9));
    // 36.033, 38.720, 43.713, 46.577 and 74.327 s have no cost.
    expect(spenders.free, 5);
    expect(spenders.lostFree, 0);
    expect(spenders.skippedBuff, 0);
  });

  test('Stormkeeper', () {
    final keeper = cooldown('stormkeeper');
    expect(keeper.uses, 2);
    // Cast at 24.968. Six Ancestors from that moment on take it from 60 s to
    // 42 s, so it was ready at 66.968, and the next began at 68.941.
    expect(keeper.medianDrift, closeTo(1.973, 1e-9));
    expect(keeper.shortening!.secondsPerCycle, closeTo(18, 1e-9));
    expect(keeper.shortening!.fewestProcs, 6);
    expect(keeper.shortening!.mostProcs, 6);
  });

  test('other cooldowns', () {
    // 19.441 and 52.158 s, with a 30 s cooldown.
    expect(cooldown('ancestral_swiftness').uses, 2);
    expect(cooldown('ancestral_swiftness').medianDrift, closeTo(2.717, 1e-9));
    expect(cooldown('ascendance').uses, 1);
    expect(cooldown('ascendance').medianDrift, isNull);
  });

  test("Spiritwalker's Grace and Time Spiral", () {
    final grace = cooldown('spiritwalkers_grace');
    expect(grace.uses, 2);
    expect(grace.freeUses, 1);
    expect(grace.normalUses, 1);
    expect(grace.raidDependsOn, contains('Time Spiral'));

    // Two buffs meet at 10.333 s and end on the cast at 18.941 s. The normal
    // cast at 19.282 s then only refreshes it.
    final spiral = result.raidFreeCasts.single;
    expect(spiral.available, 1);
    expect(spiral.spent, 1);
    expect(spiral.unspent, 0);
    expect(spiral.refreshedByNormalCast, [const Duration(milliseconds: 19282)]);
  });

  test('Ancestors', () {
    final ancestors = result.chanceProcs.single;
    expect(ancestors.actual, 11);
    // (4 guaranteed + 0.08 x 35 rolls) / 0.8.
    expect(ancestors.expected, closeTo(8.5, 1e-9));
    expect(ancestors.luck, closeTo(2.5, 1e-9));
    expect(ancestors.spread, closeTo(2.4799, 1e-4));
    expect(ancestors.perCast, closeTo(0.2, 1e-9));
  });
}
