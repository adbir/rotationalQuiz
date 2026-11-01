import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/apl/apl_document.dart';
import 'package:rotational_quiz/domain/apl/apl_evaluator.dart';
import 'package:rotational_quiz/ui/core/widgets/recommendation_card.dart';

import '../test_helpers.dart';

void main() {
  testWidgets('off-GCD abilities are shown before the GCD ability', (
    tester,
  ) async {
    final document = AplDocument.parse(
      File(spec.aplAssetPath).readAsStringSync(),
    );
    // The Farseer default state: Ancestral Swiftness + Lightning Bolt.
    final recommendation = const AplEvaluator(spec)
        .recommend(document, spec.defaultState(spec.loadouts.first));
    expect(recommendation.offGcd.map((a) => a.name), ['ancestral_swiftness']);

    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecommendationCard(spec: spec, recommendation: recommendation),
        ),
      ),
    );

    final swiftness = tester.getCenter(find.text('AS'));
    final bolt = tester.getCenter(find.text('LB'));
    expect(swiftness.dx, lessThan(bolt.dx));
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });
}
