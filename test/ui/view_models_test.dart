import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/models/keybind.dart';
import 'package:rotational_quiz/domain/specs/elemental_shaman_data.dart';
import 'package:rotational_quiz/ui/features/quiz/view_models/quiz_view_model.dart';
import 'package:rotational_quiz/ui/features/sandbox/view_models/sandbox_view_model.dart';

import '../test_helpers.dart';

void main() {
  late TestRepositories repos;

  setUp(() async {
    repos = await TestRepositories.create();
  });

  SandboxViewModel sandbox() =>
      SandboxViewModel(repository: repos.apl, talentBuilds: repos.talentBuilds);

  QuizViewModel quiz([int seed = 7]) => QuizViewModel(
    aplRepository: repos.apl,
    talentBuilds: repos.talentBuilds,
    keybinds: repos.keybinds,
    random: Random(seed),
  );

  group('SandboxViewModel', () {
    test('recommends as soon as the APL is loaded', () {
      final vm = sandbox();
      expect(vm.recommendation, isNotNull);
      expect(vm.recommendation!.selectedSpellId, 'lightning_bolt');
    });

    test('re-evaluates when the scenario changes', () {
      final vm = sandbox();
      final flameShock = vm.spec.auras.firstWhere((a) => a.id == 'flame_shock');
      vm.setAura(flameShock, vm.auraState(flameShock).copyWith(remains: 2));
      expect(vm.recommendation!.selectedSpellId, 'flame_shock');
    });

    test('choice-node talents are mutually exclusive', () {
      final vm = sandbox();
      final tempest = vm.spec.talents.firstWhere(
        (t) => t.id == ElementalTalents.tempestTalent,
      );
      vm.setTalent(tempest, true);
      expect(vm.state.hasTalent(ElementalTalents.tempestTalent), isTrue);
      expect(vm.state.hasTalent(ElementalTalents.callOfTheAncestors), isFalse);
      expect(vm.talentsEdited, isTrue);
    });

    test('follows the active talent build', () async {
      final vm = sandbox();
      await repos.talentBuilds.setActive(repos.talentBuilds.loadouts[1]);
      expect(vm.state.hasTalent(ElementalTalents.tempestTalent), isTrue);
      // Stormbringer takes Swelling Maelstrom.
      expect(vm.state.maxResource, 150);
    });

    test('saving edited talents creates and activates a build', () async {
      final vm = sandbox();
      final eotS = vm.spec.talents.firstWhere(
        (t) => t.id == ElementalTalents.eyeOfTheStorm,
      );
      vm.setTalent(eotS, true);
      await vm.saveTalentsAs('With EotS');
      expect(repos.talentBuilds.active.name, 'With EotS');
      expect(vm.talentsEdited, isFalse);
    });
  });

  group('QuizViewModel', () {
    test('scores guesses against the APL', () {
      final vm = quiz();
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
      expect(vm.outcome, QuizOutcome.wrong);
      expect(vm.answered, 2);
      expect(vm.streak, 0);
      expect(vm.bestStreak, 1);
    });

    test('the answer is always on the action bar', () {
      final vm = quiz(1);
      for (final loadout in repos.talentBuilds.loadouts) {
        vm.selectLoadout(loadout);
        for (var i = 0; i < 150; i++) {
          vm.nextQuestion();
          final ids = vm.actionBar.map((s) => s.id);
          expect(ids, contains(vm.answer!.selectedSpellId), reason: 'run $i');
        }
      }
    });

    test('multiple choice offers four distinct options with the answer', () {
      final vm = quiz(3)..setMode(QuizMode.multipleChoice);
      for (var i = 0; i < 100; i++) {
        vm.nextQuestion();
        final ids = vm.options.map((s) => s.id).toList();
        expect(ids.toSet().length, 4, reason: 'run $i');
        expect(ids, contains(vm.answer!.selectedSpellId));
      }
    });

    test('hot keys: the bound key answers the question', () async {
      final vm = quiz()..setMode(QuizMode.hotkeys);
      final answer = vm.answer!.selectedSpellId!;
      const key = Keybind(code: 0x0007001e, keyLabel: '1', shift: true);
      await repos.keybinds.bind(answer, key);
      expect(
        vm.pressKeybind(const Keybind(code: 0x0007001e, keyLabel: '1')),
        isFalse,
        reason: 'modifiers must match',
      );
      expect(vm.pressKeybind(key), isTrue);
      expect(vm.isCorrect, isTrue);
      expect(vm.reactionTime, isNotNull);
    });

    test('hot keys: off-GCD abilities can be woven first', () {
      final vm = quiz()..setMode(QuizMode.hotkeys);
      while (vm.answer!.offGcd.isEmpty) {
        vm.nextQuestion();
      }
      vm.guessSpell(vm.answer!.offGcd.first.name);
      expect(vm.isAnswered, isFalse);
      expect(vm.offGcdPressed, isNotEmpty);
      vm.guessSpell(vm.answer!.selectedSpellId!);
      expect(vm.isCorrect, isTrue);
    });

    test(
      'hot keys: skipping the off-GCD ability still counts, with a hint',
      () {
        final vm = quiz()..setMode(QuizMode.hotkeys);
        while (vm.answer!.offGcd.isEmpty) {
          vm.nextQuestion();
        }
        final offGcd = vm.answer!.offGcd.map((a) => a.name).toList();
        vm.guessSpell(vm.answer!.selectedSpellId!);
        expect(vm.isCorrect, isTrue);
        expect(vm.skippedOffGcd, offGcd);

        vm.nextQuestion();
        while (vm.answer!.offGcd.isEmpty) {
          vm.nextQuestion();
        }
        for (final action in vm.answer!.offGcd) {
          vm.guessSpell(action.name);
        }
        vm.guessSpell(vm.answer!.selectedSpellId!);
        expect(vm.isCorrect, isTrue);
        expect(vm.skippedOffGcd, isEmpty);
        vm.dispose();
      },
    );

    test('hot keys: time runs out, correct answers auto-advance', () {
      fakeAsync((async) {
        final vm = quiz()..setMode(QuizMode.hotkeys);
        vm.setTimeLimit(const Duration(seconds: 2));
        vm.nextQuestion();
        async.elapse(const Duration(milliseconds: 1900));
        expect(vm.isAnswered, isFalse);
        async.elapse(const Duration(milliseconds: 200));
        expect(vm.outcome, QuizOutcome.timedOut);

        vm.nextQuestion();
        final question = vm.questionNumber;
        vm.guessSpell(vm.answer!.selectedSpellId!);
        async.elapse(QuizViewModel.autoAdvanceDelay);
        expect(vm.questionNumber, question + 1);
        expect(vm.isAnswered, isFalse);
        vm.dispose();
      });
    });
  });
}
