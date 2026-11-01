import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/ui/features/boss_evaluation/view_models/boss_evaluation_view_model.dart';
import 'package:rotational_quiz/ui/features/boss_evaluation/views/boss_evaluation_screen.dart';

import '../fake_warcraft_logs_repository.dart';
import '../test_helpers.dart';

const _url = 'https://www.warcraftlogs.com/reports/mine?fight=18&source=278';

void main() {
  var openedSetup = 0;

  Future<void> show(
    WidgetTester tester,
    FakeWarcraftLogsRepository fake, {
    bool signedIn = true,
  }) async {
    final repos = (await tester.runAsync(TestRepositories.create))!;
    if (signedIn) await tester.runAsync(repos.signInWithCode);
    tester.view.physicalSize = const Size(1000, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final viewModel = BossEvaluationViewModel(
      repository: fake,
      signIn: repos.warcraftLogs,
    );
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BossEvaluationScreen(
            viewModel: viewModel,
            onOpenSetup: () => openedSetup++,
          ),
        ),
      ),
    );
  }

  Future<void> load(WidgetTester tester, [String url = _url]) async {
    await tester.enterText(find.byType(TextField), url);
    await tester.tap(find.text('Load'));
  }

  testWidgets('signed out points at Setup and has no Load button', (
    tester,
  ) async {
    await show(tester, FakeWarcraftLogsRepository(), signedIn: false);
    expect(
      find.textContaining('Sign in to Warcraft Logs on Setup'),
      findsOneWidget,
    );
    expect(find.text('Load'), findsNothing);
    await tester.tap(find.text('Open Setup'));
    expect(openedSetup, 1);
  });

  testWidgets('shows progress while loading', (tester) async {
    final hold = Completer<void>();
    await show(tester, FakeWarcraftLogsRepository(hold: hold.future));
    await load(tester);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading your fight...'), findsOneWidget);
    hold.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows the error from a failed load', (tester) async {
    await show(
      tester,
      FakeWarcraftLogsRepository(error: Exception('Sign in again.')),
    );
    await load(tester);
    await tester.pumpAndSettle();
    expect(find.text('Sign in again.'), findsOneWidget);
    expect(find.text('Metrics'), findsNothing);
  });

  testWidgets('explains a link without a fight and player', (tester) async {
    await show(tester, FakeWarcraftLogsRepository());
    await load(tester, 'https://www.warcraftlogs.com/reports/mine');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('needs a report, a fight and a player'),
      findsOneWidget,
    );
  });

  testWidgets('shows the three tables for you, the closest log and rank 1', (
    tester,
  ) async {
    await show(tester, FakeWarcraftLogsRepository());
    await load(tester);
    await tester.pumpAndSettle();

    // Header: you have no DPS or item level, the rankings do.
    expect(find.text('You'), findsWidgets);
    expect(find.text('Rank 53'), findsWidgets);
    expect(find.text('Rank 1'), findsWidgets);
    expect(find.text('75 s wipe'), findsOneWidget);
    expect(find.text('75 s kill'), findsNWidgets(2));
    expect(find.text('302,100'), findsOneWidget);
    expect(find.text('336,697'), findsOneWidget);
    expect(find.text('333'), findsNWidgets(2));

    expect(find.text('Metrics'), findsOneWidget);
    expect(find.text('Casts per minute'), findsOneWidget);
    expect(find.text('Casts per minute by stretch'), findsOneWidget);
    expect(find.text('0-28 s'), findsOneWidget);
    expect(find.text('Maelstrom before each wave'), findsOneWidget);
    expect(find.text('28 s'), findsOneWidget);
  });
}
