// Renders the main screens to PNGs so the UI can be checked without a
// browser or display (e.g. in a cloud container). Skipped unless
// SCREENSHOT_DIR is set:
//
//   SCREENSHOT_DIR=/tmp/shots flutter test test/screenshots --update-goldens
//
// Optional: SCREENSHOT_WIDTH / SCREENSHOT_HEIGHT (default 1440x1100; use
// e.g. 420x900 for the phone layout).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rotational_quiz/app.dart';
import 'package:rotational_quiz/domain/models/keybind.dart';

import '../test_helpers.dart';

final _outDir = Platform.environment['SCREENSHOT_DIR'];

/// Tests render text with a box font unless real fonts are loaded. Flutter
/// ships Roboto and the Material icons in `bin/cache/artifacts/material_fonts`,
/// three levels above the `flutter_tester` binary running this test.
Future<void> _loadRealFonts() async {
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final fonts = '${artifacts.path}/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('$fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  const roboto = [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Italic.ttf',
  ];
  await load('Roboto', roboto);
  await load('monospace', roboto);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

void main() {
  testWidgets('screenshots', skip: _outDir == null, (tester) async {
    await tester.runAsync(_loadRealFonts);
    final repos = (await tester.runAsync(TestRepositories.create))!;
    // A few binds so the hot-key bar shows labels.
    const digits = [
      'lightning_bolt',
      'lava_burst',
      'flame_shock',
      'elemental_blast',
      'earthquake',
    ];
    for (final (i, id) in digits.indexed) {
      await tester.runAsync(
        () => repos.keybinds.bind(
          id,
          Keybind(code: 0x0007001e + i, keyLabel: '${i + 1}'),
        ),
      );
    }

    final env = Platform.environment;
    tester.view.physicalSize = Size(
      double.parse(env['SCREENSHOT_WIDTH'] ?? '1440'),
      double.parse(env['SCREENSHOT_HEIGHT'] ?? '1100'),
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: repos.apl),
          ChangeNotifierProvider.value(value: repos.talentBuilds),
          ChangeNotifierProvider.value(value: repos.keybinds),
        ],
        child: const RotationalQuizApp(),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> shot(String name) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_outDir/$name.png'),
    );

    await shot('sandbox');
    for (final (tab, name) in [
      ('Quiz', 'quiz_action_bar'),
      ('Multiple choice', 'quiz_multiple_choice'),
      ('Hot keys', 'quiz_hot_keys'),
      ('APL', 'apl'),
      ('Setup', 'setup'),
    ]) {
      await tester.tap(find.text(tab).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await shot(name);
    }

    // Let the hot-key countdown expire so no timers are left pending.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
