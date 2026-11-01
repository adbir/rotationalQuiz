import 'dart:math';

import '../apl/apl_evaluator.dart';
import '../models/spec_definition.dart';
import '../specs/rotation_spec.dart';

/// One multiple-choice answer: the buttons to press, in order. Off-GCD
/// abilities come first and the GCD ability last.
class AnswerOption {
  const AnswerOption(this.spells, {required this.isCorrect});

  final List<SpellDefinition> spells;
  final bool isCorrect;

  String get name => spells.map((s) => s.name).join(' → ');
}

/// Picks the multiple-choice options for a quiz question: the APL's answer
/// plus plausible wrong answers.
///
/// When the answer has off-GCD abilities, the GCD ability on its own is one
/// wrong answer, and the others keep the same off-GCD start. The other wrong
/// answers come first from "near misses" (abilities on APL lines the evaluator
/// looked at before the winner, whose condition failed or which weren't
/// pressable), then from the rest of the action bar.
class PickAnswerOptions {
  PickAnswerOptions(this.spec, {Random? random}) : _random = random ?? Random();

  final RotationSpec spec;
  final Random _random;

  /// How many near misses to include before falling back to random
  /// abilities, so questions aren't all near misses.
  static const maxNearMisses = 2;

  /// Up to [count] distinct options built from [actionBar], in random order.
  /// One is correct when the answer is on the bar.
  List<AnswerOption> call(
    AplRecommendation answer,
    List<SpellDefinition> actionBar, {
    int count = 4,
  }) {
    final answerId = answer.selectedSpellId;
    final correct = actionBar.where((s) => s.id == answerId).firstOrNull;
    if (correct == null) {
      return [
        for (final spell in actionBar.take(count))
          AnswerOption([spell], isCorrect: false),
      ];
    }

    final offGcd = [
      for (final action in answer.offGcd) ?spec.spells[action.name],
    ];
    final nearMisses = <SpellDefinition>[];
    for (final entry in answer.trace) {
      if (entry.outcome != TraceOutcome.conditionFalse &&
          entry.outcome != TraceOutcome.unavailable) {
        continue;
      }
      final spell = actionBar
          .where((s) => s.id == entry.action.name)
          .firstOrNull;
      if (spell == null || spell.id == answerId) continue;
      if (!nearMisses.contains(spell)) nearMisses.add(spell);
    }
    nearMisses.shuffle(_random);
    final others = [
      for (final s in actionBar)
        if (s.id != answerId && !nearMisses.contains(s)) s,
    ]..shuffle(_random);

    final options = [
      AnswerOption([...offGcd, correct], isCorrect: true),
      if (offGcd.isNotEmpty) AnswerOption([correct], isCorrect: false),
    ];
    final wrong = [
      ...nearMisses.take(maxNearMisses),
      ...others,
      ...nearMisses.skip(maxNearMisses),
    ];
    for (final spell in wrong) {
      if (options.length >= count) break;
      options.add(AnswerOption([...offGcd, spell], isCorrect: false));
    }
    return options..shuffle(_random);
  }
}
