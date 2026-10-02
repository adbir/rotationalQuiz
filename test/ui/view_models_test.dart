import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/data/repositories/apl_repository.dart';
import 'package:rotational_quiz/domain/specs/elemental_shaman.dart';
import 'package:rotational_quiz/ui/features/quiz/view_models/quiz_view_model.dart';
import 'package:rotational_quiz/ui/features/sandbox/view_models/sandbox_view_model.dart';

import '../test_helpers.dart';

void main() {
  late AplRepository repository;

  setUp(() async {
    repository = await loadedRepository();
  });

  group('SandboxViewModel', () {
    test('recommends as soon as the APL is loaded', () {
      final vm = SandboxViewModel(repository: repository);
      expect(vm.recommendation, isNotNull);
      expect(vm.recommendation!.selectedSpellId, 'lightning_bolt');
    });

    test('re-evaluates when the scenario changes', () {
      final vm = SandboxViewModel(repository: repository);
      final flameShock = vm.spec.auras.firstWhere((a) => a.id == 'flame_shock');
      vm.setAura(flameShock, vm.auraState(flameShock).copyWith(remains: 2));
      expect(vm.recommendation!.selectedSpellId, 'flame_shock');
    });

    test('choice-node talents are mutually exclusive', () {
      final vm = SandboxViewModel(repository: repository);
      final tempest = vm.spec.talents.firstWhere(
        (t) => t.id == ElementalShaman.tempestTalent,
      );
      vm.setTalent(tempest, true);
      expect(vm.state.hasTalent(ElementalShaman.tempestTalent), isTrue);
      expect(vm.state.hasTalent(ElementalShaman.callOfTheAncestors), isFalse);
    });
  });

  group('QuizViewModel', () {
    test('scores guesses against the APL', () {
      final vm = QuizViewModel(repository: repository, random: Random(7));
      expect(vm.state, isNotNull);
      final answer = vm.answer!.selectedSpellId!;
      vm.guessSpell(answer);
      expect(vm.isCorrect, isTrue);
      expect(vm.correct, 1);
      expect(vm.streak, 1);

      vm.nextQuestion();
      final wrong = vm.actionBar.firstWhere(
        (s) => s.id != vm.answer!.selectedSpellId,
      );
      vm.guessSpell(wrong.id);
      expect(vm.isCorrect, isFalse);
      expect(vm.answered, 2);
      expect(vm.streak, 0);
    });

    test('the answer is always on the action bar', () {
      final vm = QuizViewModel(repository: repository, random: Random(1));
      for (var i = 0; i < 200; i++) {
        vm.nextQuestion();
        final ids = vm.actionBar.map((s) => s.id);
        expect(ids, contains(vm.answer!.selectedSpellId), reason: 'run $i');
      }
    });
  });
}
