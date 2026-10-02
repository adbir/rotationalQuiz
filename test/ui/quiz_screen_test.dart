import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/models/keybind.dart';
import 'package:rotational_quiz/ui/features/quiz/view_models/quiz_view_model.dart';
import 'package:rotational_quiz/ui/features/quiz/views/quiz_screen.dart';

import '../test_helpers.dart';

void main() {
  testWidgets('hot keys: pressing your keybind answers', (tester) async {
    final repos = await tester.runAsync(TestRepositories.create);
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final vm = QuizViewModel(
      aplRepository: repos!.apl,
      talentBuilds: repos.talentBuilds,
      keybinds: repos.keybinds,
      random: Random(5),
    )..setMode(QuizMode.hotkeys);
    vm.setTimeLimit(const Duration(seconds: 6));
    vm.nextQuestion();

    await repos.keybinds.bind(
      vm.answer!.selectedSpellId!,
      const Keybind(code: 0x00070014, keyLabel: 'Q', shift: true),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuizScreen(
            viewModel: vm,
            onOpenInSandbox: (_) {},
            onOpenSetup: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(vm.isCorrect, isTrue);
    expect(find.textContaining('Correct!'), findsOneWidget);
    await tester.pump(QuizViewModel.autoAdvanceDelay);
    expect(vm.isAnswered, isFalse);
    vm.dispose(); // Cancels the next question's countdown.
  });

  testWidgets('multiple choice: number keys pick an option', (tester) async {
    final repos = await tester.runAsync(TestRepositories.create);
    final vm = QuizViewModel(
      aplRepository: repos!.apl,
      talentBuilds: repos.talentBuilds,
      keybinds: repos.keybinds,
      random: Random(2),
    )..setMode(QuizMode.multipleChoice);
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuizScreen(
            viewModel: vm,
            onOpenInSandbox: (_) {},
            onOpenSetup: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final index = vm.options.indexWhere(
      (s) => s.id == vm.answer!.selectedSpellId,
    );
    await tester.sendKeyEvent(
      [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
      ][index],
    );
    await tester.pump();
    expect(vm.isCorrect, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(vm.isAnswered, isFalse);
  });
}
