import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/data/repositories/spell_icon_repository.dart';
import 'package:rotational_quiz/data/services/local_store.dart';
import 'package:rotational_quiz/data/services/spell_icon_service.dart';
import 'package:rotational_quiz/ui/core/widgets/spell_button.dart';
import 'package:rotational_quiz/ui/core/widgets/spell_icon.dart';

import '../test_helpers.dart';

void main() {
  final lavaBurst = spec.spells['lava_burst']!;

  Widget app(Widget child, {SpellIconRepository? icons}) => MaterialApp(
    home: Scaffold(
      body: icons == null
          ? child
          : SpellIconScope(repository: icons, child: child),
    ),
  );

  testWidgets('without an icon scope the button shows its abbreviation', (
    tester,
  ) async {
    await tester.pumpWidget(app(SpellButton(spell: lavaBurst)));
    expect(find.text('LvB'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a known icon is loaded, with the text fallback on failure', (
    tester,
  ) async {
    final icons = SpellIconRepository(
      service: SpellIconService(),
      store: InMemoryStore({
        'spell_icons': '{"${lavaBurst.spellId}":"spell_shaman_lavaburst"}',
      }),
    );
    await tester.pumpWidget(app(SpellButton(spell: lavaBurst), icons: icons));

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).url,
      endsWith('/icons/large/spell_shaman_lavaburst.jpg'),
    );
    // Tests have no network, so the image fails and the fallback shows.
    await tester.pumpAndSettle();
    expect(find.text('LvB'), findsOneWidget);
  });
}
