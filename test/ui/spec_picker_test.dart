import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/data/repositories/active_spec_repository.dart';
import 'package:rotational_quiz/data/services/local_store.dart';

import '../test_helpers.dart';

void main() {
  Future<TestRepositories> pump(
    WidgetTester tester, [
    LocalStore? store,
  ]) async {
    final repos = (await tester.runAsync(
      () => TestRepositories.create(store),
    ))!;
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(specApp(repos));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    return repos;
  }

  testWidgets('Restoration hides Sandbox, Quiz and APL; Elemental shows them', (
    tester,
  ) async {
    final repos = await pump(tester);
    for (final tab in ['Sandbox', 'Quiz', 'APL', 'Setup', 'Boss']) {
      expect(find.text(tab), findsWidgets, reason: tab);
    }

    await tester.tap(find.text('Setup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restoration Shaman').last);
    await tester.pumpAndSettle();

    for (final tab in ['Sandbox', 'Quiz', 'APL']) {
      expect(find.text(tab), findsNothing, reason: tab);
    }
    expect(find.text('Setup'), findsOneWidget);
    expect(find.text('Boss'), findsOneWidget);
    expect(
      repos.store.getString(ActiveSpecRepository.storeKey),
      'restoration_shaman',
    );

    await tester.tap(find.text('Setup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elemental Shaman').last);
    await tester.pumpAndSettle();
    for (final tab in ['Sandbox', 'Quiz', 'APL']) {
      expect(find.text(tab), findsOneWidget, reason: tab);
    }
  });

  testWidgets('the chosen spec survives a reload', (tester) async {
    final store = InMemoryStore({
      ActiveSpecRepository.storeKey: 'restoration_shaman',
    });
    await pump(tester, store);
    expect(find.text('Sandbox'), findsNothing);
    expect(find.text('Rotational Quiz · Restoration Shaman'), findsOneWidget);
  });
}
