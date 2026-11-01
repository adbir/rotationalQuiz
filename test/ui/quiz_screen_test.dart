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

  testWidgets('multiple choice shows off-GCD sequences in order', (
    tester,
  ) async {
    final repos = await tester.runAsync(TestRepositories.create);
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final vm = QuizViewModel(
      aplRepository: repos!.apl,
      talentBuilds: repos.talentBuilds,
      keybinds: repos.keybinds,
      random: Random(4),
    )..setMode(QuizMode.multipleChoice);
    addTearDown(vm.dispose);
    while (vm.answer!.offGcd.length != 1 ||
        vm.answer!.offGcd.single.name != 'ancestral_swiftness') {
      vm.nextQuestion();
    }

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

    final correct = vm.options.singleWhere((o) => o.isCorrect);
    expect(correct.spells.first.id, 'ancestral_swiftness');
    expect(find.text(correct.name), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsWidgets);
    expect(
      tester.takeException(),
      isNull,
      reason: 'no overflow at phone width',
    );
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

    final index = vm.options.indexWhere((o) => o.isCorrect);
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
