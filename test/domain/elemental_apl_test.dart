import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/apl/apl_document.dart';
import 'package:rotational_quiz/domain/apl/apl_evaluator.dart';
import 'package:rotational_quiz/domain/models/combat_state.dart';
import 'package:rotational_quiz/domain/specs/elemental_shaman.dart';

void main() {
  const spec = ElementalShaman();
  const evaluator = AplEvaluator(spec);
  late AplDocument document;

  final farseer = spec.loadouts.firstWhere((l) => l.name == 'Farseer');
  final stormbringer = spec.loadouts.firstWhere(
    (l) => l.name == 'Stormbringer',
  );

  /// Farseer with Ancestral Swiftness on cooldown so that only the GCD
  /// ability matters.
  CombatState base() => spec
      .defaultState(farseer)
      .withCooldown('ancestral_swiftness', const CooldownState(remains: 30));

  setUpAll(() {
    document = AplDocument.parse(
      File(spec.aplAssetPath).readAsStringSync(),
      origin: spec.aplAssetPath,
    );
  });

  group('parsing the bundled APL', () {
    test('finds every action list', () {
      expect(
        document.lists.keys,
        containsAll(['precombat', 'default', 'aoe', 'single_target']),
      );
      expect(document['single_target']!.actions.length, greaterThan(20));
    });

    test('every condition parses', () {
      final errors = [
        for (final list in document.lists.values)
          for (final action in list.actions)
            if (action.conditionError != null)
              '${action.rawLine}: ${action.conditionError}',
      ];
      expect(errors, isEmpty);
    });

    test('keeps the comments above each action', () {
      final ascendance = document['single_target']!.actions.firstWhere(
        (a) => a.name == 'ascendance',
      );
      expect(ascendance.comments.single, contains('Ascendance on CD'));
    });

    test('the single-target sandbox reads no unknown state', () {
      final result = evaluator.recommend(document, base());
      expect(result.unknownIdentifiers, isEmpty);
    });
  });

  group('single-target recommendations', () {
    String? pick(CombatState state) =>
        evaluator.recommend(document, state).selectedSpellId;

    test('Lightning Bolt is the filler', () {
      expect(pick(base()), 'lightning_bolt');
    });

    test('off-GCD Ancestral Swiftness is suggested alongside', () {
      final result = evaluator.recommend(document, spec.defaultState(farseer));
      expect(result.selectedSpellId, 'lightning_bolt');
      expect(result.offGcd.map((a) => a.name), ['ancestral_swiftness']);
    });

    test('refreshes Flame Shock in the pandemic window', () {
      final state = base().withDot(
        'flame_shock',
        const AuraState.up(remains: 3),
      );
      expect(pick(state), 'flame_shock');
    });

    test('Lava Burst to proc Master of the Elements with enough Maelstrom', () {
      expect(pick(base().copyWith(resource: 50)), 'lava_burst');
    });

    test('Lava Burst before capping charges', () {
      final state = base().withCooldown(
        'lava_burst',
        const CooldownState(charges: 1.9),
      );
      expect(pick(state), 'lava_burst');
    });

    test('Earth Shock with Master of the Elements up', () {
      final state = base()
          .copyWith(resource: 70)
          .withBuff('master_of_the_elements', const AuraState.up());
      expect(pick(state), 'earth_shock');
    });

    test('Earth Shock is not pressable without the Maelstrom', () {
      final state = base()
          .copyWith(resource: 30)
          .withBuff('master_of_the_elements', const AuraState.up());
      expect(pick(state), isNot('earth_shock'));
    });

    test('Stormkeeper when everything is ready', () {
      final state = base()
          .withCooldown('stormkeeper', CooldownState.ready)
          .withCooldown('ascendance', CooldownState.ready);
      expect(pick(state), 'stormkeeper');
    });

    test('Ascendance when ready and Stormkeeper is far away', () {
      final state = base().withCooldown('ascendance', CooldownState.ready);
      expect(pick(state), 'ascendance');
    });

    test('Tempest with Master of the Elements (Stormbringer)', () {
      final state = spec
          .defaultState(stormbringer)
          .withCooldown('natures_swiftness', const CooldownState(remains: 30))
          .withBuff('tempest', const AuraState.up())
          .withBuff('master_of_the_elements', const AuraState.up());
      expect(pick(state), 'tempest');
    });

    test("moving: Spiritwalker's Grace keeps Lightning Bolt castable", () {
      final result = evaluator.recommend(
        document,
        base().copyWith(moving: true),
      );
      expect(result.offGcd.map((a) => a.name), ['spiritwalkers_grace']);
      expect(result.selectedSpellId, 'lightning_bolt');
    });

    test('moving without Spiritwalker\'s Grace falls back to instants', () {
      final state = base()
          .copyWith(moving: true)
          .withCooldown(
            'spiritwalkers_grace',
            const CooldownState(remains: 60),
          );
      expect(pick(state), 'flame_shock');
    });

    test('interrupts when the target is casting', () {
      final result = evaluator.recommend(
        document,
        base().copyWith(targetCasting: true),
      );
      expect(result.offGcd.map((a) => a.name), contains('wind_shear'));
    });
  });
}
