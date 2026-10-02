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
}
