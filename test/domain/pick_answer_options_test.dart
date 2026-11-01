import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/apl/apl_document.dart';
import 'package:rotational_quiz/domain/apl/apl_evaluator.dart';
import 'package:rotational_quiz/domain/models/combat_state.dart';
import 'package:rotational_quiz/domain/models/spec_definition.dart';
import 'package:rotational_quiz/domain/specs/elemental_shaman.dart';
import 'package:rotational_quiz/domain/use_cases/generate_scenario.dart';
import 'package:rotational_quiz/domain/use_cases/pick_answer_options.dart';

void main() {
  const spec = ElementalShaman();
  const evaluator = AplEvaluator(spec);
  final document = AplDocument.parse(
    File(spec.aplAssetPath).readAsStringSync(),
  );

  List<SpellDefinition> barFor(CombatState state) => [
    for (final s in spec.knownSpells(state))
      if (s.onActionBar && !s.offGcd) s,
  ];

  test('four distinct options with exactly one correct sequence', () {
    final random = Random(11);
    final generate = GenerateScenario(spec, random: random);
    final pick = PickAnswerOptions(spec, random: random);

    for (final loadout in spec.loadouts) {
      for (var i = 0; i < 200; i++) {
        final state = generate(loadout);
        final answer = evaluator.recommend(document, state);
        final options = pick(answer, barFor(state));

        expect(options.map((o) => o.name).toSet(), hasLength(4), reason: '$i');
        final correct = options.where((o) => o.isCorrect).toList();
        expect(correct, hasLength(1), reason: 'run $i');
        expect(correct.single.spells.map((s) => s.id), [
          ...answer.offGcd.map((a) => a.name),
          answer.selectedSpellId,
        ]);
      }
    }
  });

  test('skipping the off-GCD ability is offered as a wrong answer', () {
    final random = Random(5);
    final generate = GenerateScenario(spec, random: random);
    final pick = PickAnswerOptions(spec, random: random);

    var checked = 0;
    for (var i = 0; i < 300; i++) {
      final state = generate(spec.loadouts.first);
      final answer = evaluator.recommend(document, state);
      if (answer.offGcd.isEmpty) continue;
      checked++;
      final options = pick(answer, barFor(state));
      final skipped = options.where(
        (o) =>
            o.spells.length == 1 &&
            o.spells.single.id == answer.selectedSpellId,
      );
      expect(skipped, hasLength(1));
      expect(skipped.single.isCorrect, isFalse);
    }
    expect(checked, greaterThan(50));
  });

  test('wrong options favour near misses from the APL trace', () {
    final random = Random(9);
    final generate = GenerateScenario(spec, random: random);
    final pick = PickAnswerOptions(spec, random: random);

    for (var i = 0; i < 200; i++) {
      final state = generate(spec.loadouts.first);
      final answer = evaluator.recommend(document, state);
      final bar = barFor(state);
      final nearMisses = {
        for (final e in answer.trace)
          if ((e.outcome == TraceOutcome.conditionFalse ||
                  e.outcome == TraceOutcome.unavailable) &&
              e.action.name != answer.selectedSpellId &&
              bar.any((s) => s.id == e.action.name))
            e.action.name,
      };
      final options = pick(answer, bar);
      final included = options
          .where((o) => !o.isCorrect && nearMisses.contains(o.spells.last.id))
          .length;
      expect(
        included,
        greaterThanOrEqualTo(
          min(PickAnswerOptions.maxNearMisses, nearMisses.length),
        ),
        reason: 'run $i',
      );
    }
  });

  test('falls back to the bar when the answer is not on it', () {
    final state = spec.defaultState(spec.loadouts.first);
    final answer = evaluator.recommend(document, state);
    final bar = [
      for (final s in barFor(state))
        if (s.id != answer.selectedSpellId) s,
    ];
    final options = PickAnswerOptions(spec, random: Random(1))(answer, bar);
    expect(options, hasLength(4));
    expect(options.where((o) => o.isCorrect), isEmpty);
  });
}
