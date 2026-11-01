import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/apl/apl_document.dart';
import 'package:rotational_quiz/domain/apl/apl_evaluator.dart';
import 'package:rotational_quiz/domain/specs/elemental_shaman.dart';
import 'package:rotational_quiz/domain/use_cases/generate_scenario.dart';
import 'package:rotational_quiz/domain/use_cases/pick_answer_options.dart';

void main() {
  const spec = ElementalShaman();
  const evaluator = AplEvaluator(spec);
  final document = AplDocument.parse(
    File(spec.aplAssetPath).readAsStringSync(),
  );

  test('four distinct options, the answer, and near misses first', () {
    final random = Random(11);
    final generate = GenerateScenario(spec, random: random);
    final pick = PickAnswerOptions(random: random);

    for (final loadout in spec.loadouts) {
      for (var i = 0; i < 200; i++) {
        final state = generate(loadout);
        final answer = evaluator.recommend(document, state);
        final bar = [
          for (final s in spec.knownSpells(state))
            if (s.onActionBar && !s.offGcd) s,
        ];
        final options = pick(answer, bar);
        final ids = options.map((s) => s.id).toList();

        expect(ids.toSet(), hasLength(4), reason: 'run $i');
        expect(ids, contains(answer.selectedSpellId));

        final nearMisses = {
          for (final e in answer.trace)
            if ((e.outcome == TraceOutcome.conditionFalse ||
                    e.outcome == TraceOutcome.unavailable) &&
                e.action.name != answer.selectedSpellId &&
                bar.any((s) => s.id == e.action.name))
              e.action.name,
        };
        final included = ids.where(nearMisses.contains).length;
        expect(
          included,
          greaterThanOrEqualTo(
            min(PickAnswerOptions.maxNearMisses, nearMisses.length),
          ),
          reason: 'run $i',
        );
      }
    }
  });

  test('falls back to the bar when the answer is not on it', () {
    final state = spec.defaultState(spec.loadouts.first);
    final answer = evaluator.recommend(document, state);
    final bar = [
      for (final s in spec.knownSpells(state))
        if (s.id != answer.selectedSpellId && s.onActionBar) s,
    ];
    expect(PickAnswerOptions(random: Random(1))(answer, bar), hasLength(4));
  });
}
