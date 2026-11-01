import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/data/services/local_store.dart';
import 'package:rotational_quiz/domain/specs/restoration_shaman.dart';
import 'package:rotational_quiz/ui/features/boss_evaluation/view_models/boss_evaluation_view_model.dart';
import 'package:rotational_quiz/ui/features/boss_evaluation/views/boss_evaluation_screen.dart';
import 'package:rotational_quiz/ui/features/boss_evaluation/views/widgets/fight_bar.dart';
import 'package:rotational_quiz/ui/features/boss_evaluation/views/widgets/finding_card.dart';

import '../fake_warcraft_logs_repository.dart';
import '../test_helpers.dart';

const _url = 'https://www.warcraftlogs.com/reports/mine?fight=18&source=278';

void main() {
  var openedSetup = 0;

  Future<void> show(
    WidgetTester tester,
    FakeWarcraftLogsRepository fake, {
    bool signedIn = true,
    InMemoryStore? store,
  }) async {
    final repos = (await tester.runAsync(
      () => TestRepositories.create(store),
    ))!;
    if (signedIn) await tester.runAsync(repos.signInWithCode);
    tester.view.physicalSize = const Size(1000, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final viewModel = BossEvaluationViewModel(
      repository: fake,
      signIn: repos.warcraftLogs,
      store: repos.store,
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
    await tester.tap(find.text('All numbers'));
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
    expect(
      find.text('Maelstrom at each Spawn of Vexhul arrival'),
      findsOneWidget,
    );
    // The pooling header and the fight bar's wave label.
    expect(find.text('28 s'), findsNWidgets(2));
  });

  testWidgets('offers an NSRT note built from the result', (tester) async {
    await show(tester, FakeWarcraftLogsRepository());
    await load(tester);
    await tester.pumpAndSettle();

    expect(find.text('Copy NSRT note'), findsOneWidget);
    expect(find.text('All add waves'), findsOneWidget);
    final viewModel = tester
        .widget<BossEvaluationScreen>(find.byType(BossEvaluationScreen))
        .viewModel;
    expect(viewModel.nsrtNote, startsWith('EncounterID:'));
    expect(viewModel.nsrtNote, contains('Difficulty:Mythic;Name:'));
    expect(viewModel.nsrtNote, contains('ph:1;time:'));
    expect(
      viewModel.nsrtNote,
      'EncounterID:3421;Difficulty:Mythic;Name:The Twin Fangs;\n'
      'ph:1;time:13.2;tag:Pool for Spawn of Vexhul;spellid:462620;\n'
      'ph:1;time:27.4;tag:Stormkeeper;spellid:191634;\n'
      'ph:1;time:30.7;tag:Earthquake;spellid:462620;',
    );

    await tester.tap(find.byType(Checkbox));
    expect(viewModel.allWaves, isTrue);
  });

  testWidgets('leads with up to three findings and folds the tables', (
    tester,
  ) async {
    await show(tester, FakeWarcraftLogsRepository());
    await load(tester);
    await tester.pumpAndSettle();

    expect(find.byType(FindingCard), findsWidgets);
    expect(find.byType(FindingCard).evaluate().length, lessThanOrEqualTo(3));
    expect(find.textContaining('You pressed'), findsOneWidget);
    expect(find.textContaining('Where:'), findsWidgets);
    expect(find.textContaining('Try:'), findsWidgets);
    expect(find.text('Show the numbers'), findsWidgets);
    expect(find.text('All numbers'), findsOneWidget);
    expect(find.text('Metrics'), findsNothing);
    expect(find.byType(FightBar), findsOneWidget);
    expect(find.text('28 s'), findsOneWidget);
    expect(find.textContaining('Darker amber'), findsOneWidget);
  });

  testWidgets('remembers whether All numbers is open', (tester) async {
    final store = InMemoryStore();
    await show(tester, FakeWarcraftLogsRepository(), store: store);
    await load(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All numbers'));
    await tester.pumpAndSettle();
    expect(find.text('Metrics'), findsOneWidget);
    expect(store.getString('boss_evaluation.show_all'), 'true');

    await tester.pumpWidget(const SizedBox());
    await show(tester, FakeWarcraftLogsRepository(), store: store);
    await load(tester);
    await tester.pumpAndSettle();
    expect(find.text('Metrics'), findsOneWidget);
  });

  testWidgets(
    'says Same as rank 1 and shows no findings when nothing differs',
    (tester) async {
      await show(tester, FakeWarcraftLogsRepository(matchRank1: true));
      await load(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('Same as rank 1'), findsOneWidget);
      expect(find.byType(FindingCard), findsNothing);
    },
  );

  group('Restoration', () {
    Future<void> loadResto(WidgetTester tester) async {
      await show(
        tester,
        FakeWarcraftLogsRepository(spec: const RestorationShaman()),
      );
      await load(tester);
      await tester.pumpAndSettle();
    }

    testWidgets('shows HPS in the header and raid support', (tester) async {
      await loadResto(tester);
      await tester.tap(find.text('All numbers'));
      await tester.pumpAndSettle();

      expect(find.text('HPS'), findsOneWidget);
      expect(find.text('DPS'), findsNothing);
      // Rank 1's amount from the rankings, scaled for a healer.
      expect(find.text('437,706'), findsOneWidget);
      expect(find.textContaining('Innervate'), findsWidgets);
      expect(find.textContaining('not by measured HPS'), findsOneWidget);
    });

    testWidgets('leads with a healer finding and its evidence', (tester) async {
      await loadResto(tester);

      expect(find.byType(FindingCard), findsWidgets);
      expect(
        find.textContaining('You cast Surging Totem 0.0% of the times'),
        findsOneWidget,
      );
      expect(find.textContaining('0 of 4 possible casts'), findsOneWidget);
      expect(find.textContaining('Cast Surging Totem each time'), findsWidgets);

      await tester.tap(find.text('Show the numbers').first);
      await tester.pumpAndSettle();
      expect(find.text('Surging Totem casts of possible'), findsOneWidget);
    });

    testWidgets('has no Maelstrom, pooling or NSRT content', (tester) async {
      await loadResto(tester);
      await tester.tap(find.text('All numbers'));
      await tester.pumpAndSettle();

      expect(find.text('Copy NSRT note'), findsNothing);
      expect(find.textContaining('NSRT'), findsNothing);
      expect(find.textContaining('Maelstrom'), findsNothing);
      expect(find.textContaining('Free spenders'), findsNothing);
      expect(find.textContaining('Spawn of Vexhul'), findsNothing);
      expect(find.textContaining('wasted'), findsNothing);
      // The healer rows the metrics table adds.
      expect(find.text('Healing Rain uptime'), findsOneWidget);
      expect(find.text('Mana at the end'), findsOneWidget);
      expect(find.text('Stormstream Totem, procs · average hold'), findsOne);
    });
  });
}
