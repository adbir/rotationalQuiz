import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/specs/elemental_shaman.dart';
import 'package:rotational_quiz/domain/use_cases/generate_scenario.dart';

void main() {
  const spec = ElementalShaman();

  test('generated scenarios respect talents and cooldown/buff pairs', () {
    final generate = GenerateScenario(spec, random: Random(42));
    for (final loadout in spec.loadouts) {
      for (var i = 0; i < 300; i++) {
        final state = generate(loadout);
        expect(state.talents, loadout.talents);
        expect(state.resource, inInclusiveRange(0, state.maxResource));
        for (final aura in spec.auras) {
          final talent = aura.requiredTalent;
          if (talent != null && !loadout.talents.contains(talent)) {
            expect(state.buff(aura.id).isUp, isFalse, reason: aura.id);
          }
        }
        if (state.buff('ascendance').isUp) {
          expect(state.cooldown('ascendance').remains, greaterThan(0));
        }
      }
    }
  });

  test('on-cooldown abilities are ready in most scenarios', () {
    final generate = GenerateScenario(spec, random: Random(3));
    final farseer = spec.loadouts.first;
    const runs = 1000;
    var swiftness = 0;
    var grace = 0;
    for (var i = 0; i < runs; i++) {
      final state = generate(farseer);
      if (spec.availability('ancestral_swiftness', state).isAvailable) {
        swiftness++;
      }
      if (state.cooldown('spiritwalkers_grace').remains <= 0) grace++;
    }
    expect(swiftness / runs, greaterThan(0.7));
    expect(grace / runs, greaterThan(0.7));
  });

  test('a quarter of scenarios are moving', () {
    final generate = GenerateScenario(spec, random: Random(4));
    const runs = 1000;
    var moving = 0;
    for (var i = 0; i < runs; i++) {
      if (generate(spec.loadouts.first).moving) moving++;
    }
    expect(moving / runs, closeTo(0.25, 0.05));
  });

  test('cooldowns without a ready chance keep their usual spread', () {
    final generate = GenerateScenario(spec, random: Random(6));
    const runs = 1000;
    var ready = 0;
    for (var i = 0; i < runs; i++) {
      if (generate(spec.loadouts.first).cooldown('voltaic_blaze').remains <=
          0) {
        ready++;
      }
    }
    expect(ready / runs, closeTo(0.5, 0.1));
  });

  test('Lava Burst charges use the build\'s own cap', () {
    final generate = GenerateScenario(spec, random: Random(8));
    final lavaBurst = spec.cooldownDefinition('lava_burst')!;
    for (final loadout in spec.loadouts) {
      final cap = spec.maxCharges(lavaBurst, loadout.talents)!;
      final seen = [
        for (var i = 0; i < 500; i++)
          generate(loadout).cooldown('lava_burst').charges!,
      ];
      expect(seen.reduce(max), inInclusiveRange(cap - 0.5, cap));
    }
  });

  test('generated Maelstrom spans the whole range up to the cap', () {
    final generate = GenerateScenario(spec, random: Random(7));
    for (final loadout in spec.loadouts) {
      final cap = spec.maxResource(loadout.talents);
      final seen = {for (var i = 0; i < 2000; i++) generate(loadout).resource};
      expect(seen, contains(cap), reason: loadout.name);
      expect(seen, contains(0), reason: loadout.name);
      expect(seen.every((r) => r % 5 == 0), isTrue);
    }
  });
}
