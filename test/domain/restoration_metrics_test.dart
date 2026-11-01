import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/domain/models/finding.dart';
import 'package:rotational_quiz/domain/models/player_metrics.dart';
import 'package:rotational_quiz/domain/specs/restoration_shaman.dart';
import 'package:rotational_quiz/domain/use_cases/compare_fights.dart';
import 'package:rotational_quiz/domain/use_cases/compute_player_metrics.dart';
import 'package:rotational_quiz/domain/use_cases/rank_findings.dart';

import 'player_metrics_fixture_test.dart' show loadFixture;

/// 75 s of the rank 1 Heroic Coiled Altar Restoration kill (195 to 270 s of
/// the pull; see restoration_fixture_test.dart), measured by the spec's log
/// rules.
void main() {
  const resto = RestorationShaman();
  late FightLog log;
  late PlayerMetrics metrics;

  setUpAll(() {
    log = loadFixture('coiled_altar_heroic_resto_window', resto.logRules);
    metrics = ComputePlayerMetrics(resto)(log);
  });

  CooldownMetrics cooldown(String id) =>
      metrics.cooldowns.singleWhere((c) => c.id == id);
  int casts(int abilityId) =>
      metrics.casts.byAbility
          .where((a) => a.abilityId == abilityId)
          .firstOrNull
          ?.casts ??
      0;

  test('Healing Rain is up about 95% of the window', () {
    final rain = metrics.upkeep.singleWhere((u) => u.buffId == 1307888);
    expect(rain.onOthers, isFalse);
    expect(rain.uptime, const Duration(milliseconds: 71213));
    expect(rain.percent, closeTo(95, 0.1));
  });

  test('Earth Shield and Earthliving come from the buffs the Shaman cast', () {
    final shield = metrics.upkeep.singleWhere((u) => u.buffId == 974);
    final earthliving = metrics.upkeep.singleWhere((u) => u.buffId == 382024);
    expect(shield.onOthers, isTrue);
    // The window's caster table has no Earth Shield: none was out.
    expect(shield.percent, 0);
    expect(earthliving.percent, 100);
  });

  test('cooldown casts against possible', () {
    // 2 charges, 2 full cooldowns in 75 s, and 1 restored by Stormstream.
    final stream = cooldown('healing_stream_totem');
    expect([stream.uses, stream.possible], [4, 5]);
    expect(stream.averageDrift, isNull);
    expect(casts(1267068), 1);
    final surging = cooldown('surging_totem');
    expect([surging.uses, surging.possible], [3, 4]);
    expect(
      [cooldown('ascendance').uses, cooldown('ascendance').possible],
      [1, 1],
    );
    final link = cooldown('spirit_link_totem');
    expect([link.uses, link.possible], [1, 1]);
    final swiftness = cooldown('natures_swiftness');
    expect([swiftness.uses, swiftness.possible], [1, 2]);
    // A cooldown without a rule has no possible count.
    expect(cooldown('spiritwalkers_grace').possible, isNull);
  });

  test('Riptide is counted per minute, not against possible', () {
    expect(casts(61295), 15);
    expect(metrics.cooldowns.where((c) => c.id == 'riptide'), isEmpty);
    final riptide = metrics.casts.byAbility.singleWhere(
      (a) => a.abilityId == 61295,
    );
    expect(riptide.perMinute, closeTo(12, 0.01));
  });

  test('the one Stormstream proc spent was held 0.4 s', () {
    final proc = metrics.heldProcs.single;
    expect(proc.name, 'Stormstream Totem');
    expect(proc.gained, 2);
    expect(proc.spent, 1);
    // The second came 0.9 s before the window ends.
    expect(proc.unspentAtEnd, 1);
    expect(proc.averageHold, const Duration(milliseconds: 408));
  });

  test('mana readings, with the last one as the end', () {
    final mana = metrics.resourceLevels!;
    expect(mana.readings, 63);
    // The window has no phase changes.
    expect(mana.atPhaseChanges, isEmpty);
    expect(mana.atEnd!.percent, inInclusiveRange(0, 100));
    expect(mana.lowest!.percent, lessThanOrEqualTo(mana.atEnd!.percent));
  });

  group('findings', () {
    FightToCompare fight(String label, FightLog log) =>
        FightToCompare(label: label, log: log);

    test(
      'a log identical to rank 1 has none, every ranked metric the same',
      () {
        final c = CompareFights(resto)([
          fight('You', log),
          fight('Rank 1', log),
        ], const []);
        final report = const RankFindings()(c);
        expect(report.findings, isEmpty);
        // Twelve rules: all measurable in the window.
        expect(report.same, hasLength(resto.logRules.findings.metrics.length));
        expect(
          report.same.map((f) => f.subject),
          containsAll(['Healing Stream Totem', 'Healing Rain', 'Riptide']),
        );
      },
    );

    test('a log that skipped Stormstream and Riptide is behind on them', () {
      final skipped = _without(log, {61295, 1267068, 1267089});
      final report = const RankFindings()(
        CompareFights(resto)([
          fight('You', skipped),
          fight('Rank 1', log),
        ], const []),
      );
      expect(report.findings.length, lessThanOrEqualTo(3));
      expect(report.findings.first.kind, FindingKind.castsPerMinute);
      final riptide = report.findings.firstWhere(
        (f) => f.kind == FindingKind.abilityCastsPerMinute,
      );
      expect(riptide.subject, 'Riptide');
      expect(riptide.yours, 0);
      expect(riptide.whatToTry, 'Cast Riptide whenever it has a charge.');
      // Without Stormstream, Healing Stream's possible drops to 4: 4 of 4 is
      // ahead of rank 1's 4 of 5, so it is neither behind nor the same.
      final stream = ComputePlayerMetrics(resto)(skipped).cooldowns
          .singleWhere((c) => c.id == 'healing_stream_totem');
      expect([stream.uses, stream.possible], [4, 4]);
      expect(
        [...report.findings, ...report.same].map((f) => f.subject),
        isNot(contains('Healing Stream Totem')),
      );
    });
  });
}

/// [log] without the casts and buff events of [ids].
FightLog _without(FightLog log, Set<int> ids) => FightLog(
  reportCode: log.reportCode,
  fight: log.fight,
  playerName: log.playerName,
  playerId: log.playerId,
  abilityNames: log.abilityNames,
  casts: [
    for (final c in log.casts)
      if (!ids.contains(c.abilityId)) c,
  ],
  resourceGains: log.resourceGains,
  buffEvents: [
    for (final e in log.buffEvents)
      if (!ids.contains(e.abilityId)) e,
  ],
  talents: log.talents,
  receivedBuffs: log.receivedBuffs,
  appliedBuffs: log.appliedBuffs,
);
