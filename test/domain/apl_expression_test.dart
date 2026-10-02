import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/apl/apl_evaluator.dart';
import 'package:rotational_quiz/domain/apl/apl_expression.dart';
import 'package:rotational_quiz/domain/models/combat_state.dart';
import 'package:rotational_quiz/domain/specs/elemental_shaman.dart';

void main() {
  const spec = ElementalShaman();
  const evaluator = AplEvaluator(spec);
  final state = spec
      .defaultState(spec.loadouts.first)
      .copyWith(resource: 40)
      .withBuff('stormkeeper', const AuraState.up(stacks: 2));

  double eval(String source) =>
      evaluator.evaluate(AplExpressionParser.parse(source), state);

  group('AplExpressionParser', () {
    test('round-trips source text', () {
      const source =
          '!buff.master_of_the_elements.up&(maelstrom>52-5*talent.x)|gcd<1';
      expect(AplExpressionParser.parse(source).toSource(), source);
    });

    test('and binds tighter than or', () {
      final tree = AplExpressionParser.parse('a|b&c');
      expect(tree, isA<BinaryExpression>());
      expect((tree as BinaryExpression).operator, BinaryOperator.or);
    });

    test('unary not binds tighter than and', () {
      final tree = AplExpressionParser.parse('!a&b') as BinaryExpression;
      expect(tree.operator, BinaryOperator.and);
      expect(tree.left, isA<UnaryExpression>());
    });

    test('rejects malformed input', () {
      expect(
        () => AplExpressionParser.parse('a&(b'),
        throwsA(isA<AplParseException>()),
      );
      expect(
        () => AplExpressionParser.parse('a&'),
        throwsA(isA<AplParseException>()),
      );
    });
  });

  group('evaluation', () {
    test('arithmetic follows precedence', () {
      expect(eval('2+3*4'), 14);
      expect(eval('(2+3)*4'), 20);
      expect(eval('52-5*2'), 42);
      expect(eval('10%4'), 2.5);
      expect(eval('-3+5'), 2);
    });

    test('max and min operators', () {
      expect(eval('3>?5'), 5);
      expect(eval('3<?5'), 3);
    });

    test('comparisons return 1 or 0', () {
      expect(eval('maelstrom>30'), 1);
      expect(eval('maelstrom.deficit<15'), 0);
      expect(eval('maelstrom=40'), 1);
      expect(eval('maelstrom!=40'), 0);
    });

    test('buff, cooldown and talent lookups', () {
      expect(eval('buff.stormkeeper.up'), 1);
      expect(eval('buff.stormkeeper.stack'), 2);
      expect(eval('buff.lava_surge.down'), 1);
      expect(eval('cooldown.ascendance.remains'), 60);
      expect(eval('cooldown.lava_burst.charges_fractional'), 1);
      expect(eval('talent.call_of_the_ancestors'), 1);
      expect(eval('talent.tempest'), 0);
      expect(eval('dot.flame_shock.refreshable'), 0);
    });

    test('flame shock is refreshable inside the pandemic window', () {
      final low = state.withDot('flame_shock', const AuraState.up(remains: 5));
      expect(
        evaluator.evaluate(
          AplExpressionParser.parse('dot.flame_shock.refreshable'),
          low,
        ),
        1,
      );
    });
  });
}
