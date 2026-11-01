import 'dart:math';

import '../apl/apl_evaluator.dart';
import '../models/spec_definition.dart';

/// Picks the multiple-choice options for a quiz question: the APL's answer
/// plus plausible distractors.
///
/// Distractors come first from "near misses" (abilities on APL lines the
/// evaluator looked at before the winner, whose condition failed or which
/// weren't pressable), then from the rest of the action bar.
class PickAnswerOptions {
  PickAnswerOptions({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// How many near misses to include before falling back to random
  /// abilities, so questions aren't all near misses.
  static const maxNearMisses = 2;

  /// Up to [count] distinct abilities from [actionBar], in random order,
  /// always including the answer when it is on the bar.
  List<SpellDefinition> call(
    AplRecommendation answer,
    List<SpellDefinition> actionBar, {
    int count = 4,
  }) {
    final answerId = answer.selectedSpellId;
    final correct = actionBar.where((s) => s.id == answerId).firstOrNull;
    if (correct == null) return actionBar.take(count).toList();

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

    final options = [correct, ...nearMisses.take(maxNearMisses)];
    for (final s in [...others, ...nearMisses.skip(maxNearMisses)]) {
      if (options.length >= count) break;
      options.add(s);
    }
    return options..shuffle(_random);
  }
}
