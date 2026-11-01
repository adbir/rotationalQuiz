import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rotational_quiz/app.dart';

import '../test_helpers.dart';

void main() {
  testWidgets('navigates between sandbox, quiz and setup', (tester) async {
    final repos = await tester.runAsync(TestRepositories.create);
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: repos!.apl),
          ChangeNotifierProvider.value(value: repos.talentBuilds),
          ChangeNotifierProvider.value(value: repos.keybinds),
          ChangeNotifierProvider.value(value: repos.warcraftLogs),
        ],
        child: const RotationalQuizApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Press next'), findsOneWidget);
    expect(find.text('APL trace'), findsOneWidget);

    await tester.tap(find.text('Quiz'));
    await tester.pumpAndSettle();
    expect(find.text('Single target. What do you press next?'), findsOneWidget);

    await tester.tap(find.text('Multiple choice'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsWidgets);

    await tester.tap(find.text('Setup'));
    await tester.pumpAndSettle();
    expect(find.text('Your talent build'), findsOneWidget);
    expect(find.text('Keybinds'), findsOneWidget);
  });
}
