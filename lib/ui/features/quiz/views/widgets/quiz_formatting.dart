import '../../../../core/widgets/spell_button.dart';
import '../../view_models/quiz_view_model.dart';

/// How [id] is marked on the bar or option list for the current question.
SpellButtonMark markSpell(QuizViewModel vm, String id) {
  if (vm.mode == QuizMode.hotkeys && vm.offGcdPressed.contains(id)) {
    return SpellButtonMark.correct;
  }
  if (!vm.isAnswered) return SpellButtonMark.none;
  if (id == vm.answer?.selectedSpellId) return SpellButtonMark.correct;
  if (id == vm.guess) return SpellButtonMark.wrong;
  return SpellButtonMark.none;
}

/// Formats [d] as seconds with two decimals, e.g. `1.24s`.
String formatSeconds(Duration d) =>
    '${(d.inMilliseconds / 1000).toStringAsFixed(2)}s';
