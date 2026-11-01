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
