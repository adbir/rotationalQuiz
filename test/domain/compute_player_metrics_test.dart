import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/domain/models/player_metrics.dart';
import 'package:rotational_quiz/domain/use_cases/compute_player_metrics.dart';

import '../test_helpers.dart';

const player = 7;
const lightningBolt = 188196;
const lavaBurst = 51505;
const elementalBlast = 117014;
const flameShock = 188389;
const flameShockEcho = 470411;
const stormkeeper = 191634;
const ascendance = 114050;
const ancestralSwiftness = 443454;
const spiritwalkersGrace = 79206;
const gustOfWind = 192063;
const masterOfTheElements = 260734;
const overcharge = 1300222;
const flowingElements = 1300219;
const timeSpiral = 375256;
const ancestorBuff = 447244;
const ancestorBuffAlt = 445624;

const farseerTalents = {
  'call_of_the_ancestors',
  'routine_communication',
  'ancient_fellowship',
  'offering_from_beyond',
  'master_of_the_elements',
  'ancestral_swiftness',
  'stormkeeper',
  'ascendance',
  'first_ascendant',
  'graceful_spirit',
};

Duration at(num seconds) => Duration(milliseconds: (seconds * 1000).round());

LogCast cast(num seconds, int ability, {List<LogResourceReading>? resources}) =>
    LogCast(
      time: at(seconds),
      abilityId: ability,
      targetId: 1,
      isBegin: false,
      resources: resources ?? const [],
    );

LogCast begin(num seconds, int ability) =>
    LogCast(time: at(seconds), abilityId: ability, targetId: 1, isBegin: true);

LogBuffEvent buff(
  num seconds,
  int ability,
  LogBuffChange change, {
  int target = player,
}) => LogBuffEvent(
  time: at(seconds),
  abilityId: ability,
  targetId: target,
  change: change,
);

LogBuffEvent on(num seconds, int ability, {int target = player}) =>
    buff(seconds, ability, LogBuffChange.apply, target: target);

LogBuffEvent off(num seconds, int ability, {int target = player}) =>
    buff(seconds, ability, LogBuffChange.remove, target: target);

LogResourceGain gain(num seconds, int amount, {int waste = 0, int? type}) =>
    LogResourceGain(
      time: at(seconds),
      abilityId: 1,
      type: type ?? maelstromResourceType,
      amount: amount,
      waste: waste,
      max: 125,
    );

PlayerMetrics metrics({
  List<LogCast> casts = const [],
  List<LogResourceGain> gains = const [],
  List<LogBuffEvent> buffs = const [],
  Set<String> talents = farseerTalents,
  num seconds = 60,
  List<Duration> phaseStarts = const [],
}) => ComputePlayerMetrics(spec)(
  FightLog(
    reportCode: 'test',
    fight: LogFight(
      id: 1,
      name: 'Test boss',
      encounterId: 1,
      kill: true,
      duration: at(seconds),
      difficulty: 5,
      size: 20,
      phaseStarts: phaseStarts,
    ),
    playerName: '',
    playerId: player,
    abilityNames: const {
      lightningBolt: 'Lightning Bolt',
      flameShock: 'Flame Shock',
      masterOfTheElements: 'Master of the Elements',
    },
    casts: casts,
    resourceGains: gains,
    buffEvents: buffs,
    talents: talents,
  ),
);

CooldownMetrics cooldown(PlayerMetrics result, String id) =>
    result.cooldowns.singleWhere((c) => c.id == id);

void main() {
  group('casts', () {
    test('counts finished casts, not cast starts', () {
      final result = metrics(
        casts: [
          begin(1, lightningBolt),
          cast(2, lightningBolt),
          begin(3, lightningBolt),
          cast(4, lightningBolt),
          begin(5, lavaBurst), // Cancelled.
        ],
        seconds: 30,
      );
      expect(result.casts.total, 2);
      expect(result.casts.perMinute, closeTo(4, 1e-9));
    });

    test("Flame Shock's echo event isn't a second press", () {
      final result = metrics(
        casts: [cast(1, flameShock), cast(1, flameShockEcho)],
      );
      expect(result.casts.total, 1);
      expect(result.casts.byAbility.single.abilityId, flameShock);
    });

    test('lists abilities by name, most cast first', () {
      final result = metrics(
        casts: [
          cast(1, 999),
          cast(2, lightningBolt),
          cast(3, lightningBolt),
          cast(4, lightningBolt),
        ],
        seconds: 30,
      );
      final bolt = result.casts.byAbility.first;
      expect(bolt.name, 'Lightning Bolt');
      expect(bolt.casts, 3);
      expect(bolt.perMinute, closeTo(6, 1e-9));
      expect(result.casts.byAbility.last.name, 'Ability 999');
    });

    test('splits casts by phase', () {
      final result = metrics(
        casts: [cast(5, lightningBolt), cast(25, lightningBolt)],
        seconds: 40,
        phaseStarts: [Duration.zero, at(10), at(30)],
      );
      expect([for (final p in result.casts.byPhase) p.casts], [1, 1, 0]);
      expect(result.casts.byPhase[1].start, at(10));
      expect(result.casts.byPhase[1].length, at(20));
      expect(result.casts.byPhase[1].perMinute, closeTo(3, 1e-9));
    });

    test('folds a phase that starts as the boss dies into the last one', () {
      final result = metrics(
        casts: [cast(39.99, lightningBolt)],
        seconds: 40,
        phaseStarts: [Duration.zero, at(39.98)],
      );
      expect(result.casts.byPhase, hasLength(1));
      expect(result.casts.byPhase.single.length, at(40));
      expect(result.casts.byPhase.single.casts, 1);
    });
  });

  group('gaps', () {
    test('finds gaps over 1.8 s between casts', () {
      final result = metrics(
        casts: [
          cast(1, flameShock),
          begin(2.8, lightningBolt), // Exactly 1.8 s isn't over.
          cast(4.5, lightningBolt),
          begin(6.5, lightningBolt), // 2 s after the cast before.
          cast(8, lightningBolt),
          cast(11, flameShock), // 3 s.
        ],
      );
      expect(result.gaps.count, 2);
      expect(result.gaps.longest, at(3));
    });

    test('time spent casting is no gap', () {
      final result = metrics(casts: [begin(1, lavaBurst), cast(4, lavaBurst)]);
      expect(result.gaps.count, 0);
    });

    test('a cancelled cast counts as activity that stopped', () {
      final result = metrics(
        casts: [
          cast(1, flameShock),
          begin(2, lightningBolt),
          begin(5, lavaBurst),
          cast(6, lavaBurst),
        ],
      );
      expect(result.gaps.count, 1);
      expect(result.gaps.longest, at(3));
    });
  });

  test('resource gained and wasted per minute, for one resource only', () {
    final result = metrics(
      gains: [
        gain(1, 80, waste: 5),
        gain(2, 20),
        gain(3, 500, waste: 500, type: 0), // Mana from a teammate.
      ],
      seconds: 30,
    );
    expect(result.resource.gained, 100);
    expect(result.resource.wasted, 5);
    expect(result.resource.gainedPerMinute, closeTo(200, 1e-9));
    expect(result.resource.wastedPerMinute, closeTo(10, 1e-9));
    expect(result.resource.wastedPercent, closeTo(5, 1e-9));
  });

  group('spenders with Master of the Elements', () {
    test('counts the buff when it ended on the same cast', () {
      final result = metrics(
        casts: [cast(5, elementalBlast), cast(15, elementalBlast)],
        buffs: [on(4, masterOfTheElements), off(5, masterOfTheElements)],
      );
      expect(result.spenders.casts, 2);
      expect(result.spenders.withBuff, 1);
      expect(result.spenders.withBuffPercent, closeTo(50, 1e-9));
      expect(result.spenders.buffName, 'Master of the Elements');
    });

    test('a removal logged just before the cast still counts', () {
      final result = metrics(
        casts: [cast(5, elementalBlast)],
        buffs: [on(4, masterOfTheElements), off(4.999, masterOfTheElements)],
      );
      expect(result.spenders.withBuff, 1);
    });

    test('a removal logged 50 ms before the cast still counts', () {
      final result = metrics(
        casts: [cast(5, elementalBlast)],
        buffs: [on(4, masterOfTheElements), off(4.95, masterOfTheElements)],
      );
      expect(result.spenders.withBuff, 1);
    });

    test('a removal 100 ms before the cast was spent on something else', () {
      final result = metrics(
        casts: [cast(5, elementalBlast)],
        buffs: [on(4, masterOfTheElements), off(4.9, masterOfTheElements)],
      );
      expect(result.spenders.withBuff, 0);
    });

    test('a buff applied on the same moment arrives too late', () {
      final result = metrics(
        casts: [cast(5, elementalBlast), cast(5, lavaBurst)],
        buffs: [on(5, masterOfTheElements)],
      );
      expect(result.spenders.withBuff, 0);
    });

    test('ignores the buff on someone else', () {
      final result = metrics(
        casts: [cast(5, elementalBlast)],
        buffs: [
          on(4, masterOfTheElements, target: 99),
          off(6, masterOfTheElements, target: 99),
        ],
      );
      expect(result.spenders.withBuff, 0);
    });

    test('a buff with no start was up from the pull', () {
      final result = metrics(
        casts: [cast(5, elementalBlast)],
        buffs: [off(5, masterOfTheElements)],
      );
      expect(result.spenders.withBuff, 1);
    });

    test('is empty without the talent', () {
      final result = metrics(
        casts: [cast(5, elementalBlast)],
        talents: const {'elemental_blast'},
      );
      expect(result.spenders.withBuff, isNull);
      expect(result.spenders.withBuffPercent, isNull);
      expect(result.spenders.skippedBuff, isNull);
    });

    test('counts spenders skipping it with both set procs up', () {
      final result = metrics(
        casts: [
          cast(5, elementalBlast), // Both procs, no buff: counted.
          cast(8, elementalBlast), // Both procs and the buff: not skipped.
          cast(12, elementalBlast), // Only Overcharge!: not counted.
        ],
        buffs: [
          on(1, flowingElements),
          on(2, overcharge),
          on(7, masterOfTheElements),
          off(8, masterOfTheElements),
          off(10, flowingElements),
          off(13, overcharge),
        ],
      );
      expect(result.spenders.withBuff, 1);
      expect(result.spenders.skippedBuff, 1);
    });
  });

  group('free spenders', () {
    const paid = [
      LogResourceReading(
        type: maelstromResourceType,
        amount: 100,
        max: 125,
        cost: 90,
      ),
    ];
    const noCost = [
      LogResourceReading(type: maelstromResourceType, amount: 100, max: 125),
    ];
    const manaOnly = [
      LogResourceReading(type: 0, amount: 100, max: 250000, cost: 500),
    ];

    test('counts Overcharge! up, whatever the reading says', () {
      final result = metrics(
        casts: [cast(5, elementalBlast), cast(15, elementalBlast)],
        buffs: [on(4, overcharge), off(5, overcharge)],
      );
      expect(result.spenders.free, 1);
    });

    test('counts a Maelstrom reading with no cost', () {
      final result = metrics(
        casts: [
          cast(5, elementalBlast, resources: noCost),
          cast(6, elementalBlast, resources: paid),
          cast(7, elementalBlast, resources: manaOnly),
        ],
      );
      expect(result.spenders.free, 1);
    });

    test('a refresh of Overcharge! is a lost free spender', () {
      final result = metrics(
        buffs: [
          on(4, overcharge),
          buff(6, overcharge, LogBuffChange.refresh),
          buff(7, overcharge, LogBuffChange.refresh, target: 99),
          buff(8, masterOfTheElements, LogBuffChange.refresh),
        ],
      );
      expect(result.spenders.lostFree, 1);
    });
  });

  group('cooldowns', () {
    test('measures drift from the shortest possible gap', () {
      final result = metrics(
        casts: [
          cast(0, ascendance),
          cast(120, ascendance),
          cast(250, ascendance),
          cast(371, ascendance),
        ],
        seconds: 400,
      );
      final ascendanceUse = cooldown(result, 'ascendance');
      expect(ascendanceUse.uses, 4);
      expect(ascendanceUse.cooldown, 120);
      expect(ascendanceUse.averageDrift, closeTo(11 / 3, 1e-9));
      expect(ascendanceUse.medianDrift, closeTo(1, 1e-9));
      expect(ascendanceUse.earlyPresses, 0);
    });

    test('uses the cooldown the talents give', () {
      final result = metrics(
        casts: [cast(0, ascendance), cast(227, ascendance)],
        seconds: 300,
        talents: farseerTalents.difference({'first_ascendant'}),
      );
      expect(cooldown(result, 'ascendance').cooldown, 180);
      expect(cooldown(result, 'ascendance').medianDrift, closeTo(47, 1e-9));
    });

    test('a gap under the cooldown is early, not negative drift', () {
      final result = metrics(
        casts: [
          cast(0, spiritwalkersGrace),
          cast(80, spiritwalkersGrace),
          cast(180, spiritwalkersGrace),
        ],
        seconds: 200,
      );
      final grace = cooldown(result, 'spiritwalkers_grace');
      expect(grace.earlyPresses, 1);
      expect(grace.averageDrift, closeTo(5, 1e-9));
    });

    test('a gap a few milliseconds short is timing noise, not early', () {
      final result = metrics(
        casts: [cast(0, ascendance), cast(119.985, ascendance)],
        seconds: 200,
      );
      expect(cooldown(result, 'ascendance').earlyPresses, 0);
      expect(cooldown(result, 'ascendance').medianDrift, 0);
    });

    test('leaves out charge spells and talents the player lacks', () {
      final result = metrics();
      final ids = [for (final c in result.cooldowns) c.id];
      expect(ids, contains('stormkeeper'));
      expect(ids, isNot(contains('lava_burst')));
      expect(ids, isNot(contains('natures_swiftness')));
      expect(ids, isNot(contains('voltaic_blaze')));
    });

    test('has no drift from a single use', () {
      final result = metrics(casts: [cast(0, ascendance)]);
      expect(cooldown(result, 'ascendance').uses, 1);
      expect(cooldown(result, 'ascendance').medianDrift, isNull);
    });
  });

  group('Stormkeeper press delay', () {
    test('takes 3 s off for each Ancestor before it comes ready', () {
      final result = metrics(
        casts: [
          cast(0, stormkeeper),
          begin(52, stormkeeper), // Ready at 51: 60 - 3 x 3.
          cast(53, stormkeeper),
        ],
        buffs: [
          on(0, ancestorBuff), // Stormkeeper's own Ancestor counts.
          on(10, ancestorBuff),
          on(49, ancestorBuffAlt),
          on(51.5, ancestorBuff), // After it was ready.
        ],
        seconds: 120,
      );
      final keeper = cooldown(result, 'stormkeeper');
      expect(keeper.medianDrift, closeTo(1, 1e-9));
      expect(keeper.shortening!.procName, 'Ancestors');
      expect(keeper.shortening!.secondsPerCycle, closeTo(9, 1e-9));
      expect(keeper.shortening!.fewestProcs, 3);
      expect(keeper.shortening!.mostProcs, 3);
    });

    test("an Ancestor logged just before the cast is still that cast's", () {
      final result = metrics(
        casts: [cast(10, stormkeeper), cast(70, stormkeeper)],
        buffs: [on(9.999, ancestorBuff)],
        seconds: 120,
      );
      expect(cooldown(result, 'stormkeeper').shortening!.mostProcs, 1);
    });

    test('an Ancestor stack counts like the first', () {
      final result = metrics(
        casts: [cast(0, stormkeeper), cast(57, stormkeeper)],
        buffs: [
          on(1, ancestorBuff),
          buff(2, ancestorBuff, LogBuffChange.applyStack),
          buff(3, ancestorBuff, LogBuffChange.refresh),
        ],
        seconds: 120,
      );
      expect(cooldown(result, 'stormkeeper').shortening!.mostProcs, 2);
    });

    test('a shortened cooldown keeps its base value next to it', () {
      final result = metrics(
        casts: [cast(0, stormkeeper), cast(60, stormkeeper)],
        seconds: 120,
      );
      expect(cooldown(result, 'stormkeeper').cooldown, 60);
      expect(cooldown(result, 'stormkeeper').shortening!.fewestProcs, 0);
    });

    test('needs Offering from Beyond', () {
      final result = metrics(
        casts: [cast(0, stormkeeper), cast(61, stormkeeper)],
        buffs: [on(1, ancestorBuff)],
        seconds: 120,
        talents: farseerTalents.difference({'offering_from_beyond'}),
      );
      expect(cooldown(result, 'stormkeeper').shortening, isNull);
      expect(cooldown(result, 'stormkeeper').medianDrift, closeTo(1, 1e-9));
    });
  });

  group('Time Spiral', () {
    test('a buff ending on a cast paid for that cast', () {
      final result = metrics(
        casts: [
          cast(10, spiritwalkersGrace),
          cast(30, spiritwalkersGrace),
          cast(50, gustOfWind),
        ],
        buffs: [
          on(25, timeSpiral),
          off(30.001, timeSpiral),
          on(45, timeSpiral),
          off(50.003, timeSpiral),
        ],
      );
      final spiral = result.raidFreeCasts.single;
      expect(spiral.name, 'Time Spiral');
      expect(spiral.available, 2);
      expect(spiral.spent, 2);
      expect(spiral.unspent, 0);

      final grace = cooldown(result, 'spiritwalkers_grace');
      expect(grace.uses, 2);
      expect(grace.freeUses, 1);
      expect(grace.normalUses, 1);
      expect(grace.raidDependsOn, ['Time Spiral', 'Blessing of the Bronze']);
    });

    test('a buff that ran out paid for nothing', () {
      final result = metrics(
        casts: [cast(30, spiritwalkersGrace)],
        buffs: [on(1, timeSpiral), off(11, timeSpiral)],
      );
      final spiral = result.raidFreeCasts.single;
      expect(spiral.spent, 0);
      expect(spiral.unspent, 1);
      expect(cooldown(result, 'spiritwalkers_grace').freeUses, 0);
    });

    test('overlapping buffs are one use', () {
      final result = metrics(
        casts: [cast(30, spiritwalkersGrace)],
        buffs: [
          on(20, timeSpiral),
          off(25, timeSpiral),
          on(25, timeSpiral),
          off(30, timeSpiral),
        ],
      );
      expect(result.raidFreeCasts.single.available, 1);
      expect(result.raidFreeCasts.single.spent, 1);
    });

    test('free casts leave the normal cooldown gaps alone', () {
      final result = metrics(
        casts: [
          cast(0, spiritwalkersGrace),
          cast(40, spiritwalkersGrace),
          cast(95, spiritwalkersGrace),
        ],
        buffs: [on(35, timeSpiral), off(40, timeSpiral)],
        seconds: 120,
      );
      final grace = cooldown(result, 'spiritwalkers_grace');
      expect(grace.normalUses, 2);
      expect(grace.medianDrift, closeTo(5, 1e-9));
    });

    test('flags a normal cast that only refreshed a free one', () {
      final result = metrics(
        casts: [cast(100, spiritwalkersGrace), cast(100.4, spiritwalkersGrace)],
        buffs: [
          on(90, timeSpiral),
          on(100, spiritwalkersGrace),
          off(100, timeSpiral),
          buff(100.4, spiritwalkersGrace, LogBuffChange.refresh),
        ],
        seconds: 120,
      );
      expect(result.raidFreeCasts.single.refreshedByNormalCast, [at(100.4)]);
    });

    test("doesn't flag a free cast refreshing a normal one", () {
      final result = metrics(
        casts: [cast(100, spiritwalkersGrace), cast(110, spiritwalkersGrace)],
        buffs: [
          on(100, spiritwalkersGrace),
          on(105, timeSpiral),
          buff(110, spiritwalkersGrace, LogBuffChange.refresh),
          off(110, timeSpiral),
        ],
        seconds: 120,
      );
      expect(result.raidFreeCasts.single.refreshedByNormalCast, isEmpty);
    });
  });

  group('Ancestors', () {
    final eligible = [for (var i = 0; i < 50; i++) cast(i + 1, lightningBolt)];

    test('compares actual with expected', () {
      final result = metrics(
        casts: [
          cast(0, stormkeeper),
          cast(5, ancestralSwiftness),
          ...eligible, // 50 x 0.08 = 4 rolls.
        ],
        buffs: [
          on(0, ancestorBuff),
          buff(1, ancestorBuff, LogBuffChange.applyStack),
          on(2, ancestorBuffAlt),
          buff(3, ancestorBuff, LogBuffChange.refresh),
          on(4, ancestorBuff, target: 99),
        ],
        seconds: 100,
      );
      final ancestors = result.chanceProcs.single;
      expect(ancestors.name, 'Ancestors');
      expect(ancestors.actual, 3);
      expect(ancestors.expected, closeTo((2 + 4) / 0.8, 1e-9));
      expect(ancestors.luck, closeTo(3 - 7.5, 1e-9));
      expect(ancestors.perCast, closeTo(3 / 52, 1e-9));
      // Variance: 6 x 0.3125 + (50 x 0.08 x 0.92) x 1.5625 = 7.625.
      expect(ancestors.spread, closeTo(2.7613, 1e-4));
      expect(ancestors.note, contains('Ascendance'));
    });

    test('leaves out the chance term without Routine Communication', () {
      final result = metrics(
        casts: [cast(0, stormkeeper), ...eligible],
        seconds: 100,
        talents: farseerTalents.difference({'routine_communication'}),
      );
      expect(result.chanceProcs.single.expected, closeTo(1 / 0.8, 1e-9));
    });

    test('leaves out the repeat term without Ancient Fellowship', () {
      final result = metrics(
        casts: [cast(0, stormkeeper), ...eligible],
        seconds: 100,
        talents: farseerTalents.difference({'ancient_fellowship'}),
      );
      expect(result.chanceProcs.single.expected, closeTo(1 + 4, 1e-9));
    });

    test('is absent without Call of the Ancestors', () {
      final result = metrics(
        casts: eligible,
        seconds: 100,
        talents: const {'stormkeeper'},
      );
      expect(result.chanceProcs, isEmpty);
    });
  });

  test('an empty fight gives zeros rather than errors', () {
    final result = metrics(seconds: 0);
    expect(result.casts.perMinute, 0);
    expect(result.resource.wastedPercent, 0);
    expect(result.gaps.count, 0);
    expect(result.gaps.longest, Duration.zero);
    expect(result.spenders.withBuffPercent, isNull);
  });
}
