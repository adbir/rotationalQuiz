import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rotational_quiz/app.dart';

import '../test_helpers.dart';

void main() {
  testWidgets('sandbox shows the next button and the quiz is reachable', (
    tester,
  ) async {
    final repository = await tester.runAsync(loadedRepository);
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: repository!,
        child: const RotationalQuizApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Press next'), findsOneWidget);
    expect(find.text('APL trace'), findsOneWidget);

    await tester.tap(find.text('Quiz'));
    await tester.pumpAndSettle();
    expect(find.text('Single target. What do you press next?'), findsOneWidget);
  });
}
