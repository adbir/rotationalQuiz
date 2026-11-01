import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/apl/apl_document.dart';
import 'package:rotational_quiz/domain/apl/apl_expression.dart';
import 'package:rotational_quiz/domain/apl/apl_state_resolver.dart';
import 'package:rotational_quiz/domain/models/spec_definition.dart';
import 'package:rotational_quiz/domain/specs/elemental_shaman.dart';

/// Lists the sandbox evaluates for a single target.
const _singleTargetLists = ['default', 'single_target'];

Iterable<Identifier> _identifiers(AplExpression node) sync* {
  switch (node) {
    case Identifier():
      yield node;
    case GroupExpression(:final inner):
      yield* _identifiers(inner);
    case UnaryExpression(:final operand):
      yield* _identifiers(operand);
    case BinaryExpression(:final left, :final right):
      yield* _identifiers(left);
      yield* _identifiers(right);
    case NumberLiteral():
      break;
  }
}

void main() {
  const spec = ElementalShaman();
  final document = AplDocument.parse(
    File(spec.aplAssetPath).readAsStringSync(),
  );
  final modelled = [
    for (final listName in _singleTargetLists)
      for (final action in document[listName]!.actions)
        if (action.name != 'variable' &&
            !spec.unmodelledActions.contains(action.name))
          action,
  ];
  final identifiers = {
    for (final action in modelled)
      if (action.condition case final condition?)
        for (final id in _identifiers(condition)) id.name,
  };

  // Static check: unlike evaluating one state, this also covers clauses that
  // `&` / `|` short-circuit past.
  test('every identifier on the single-target path resolves', () {
    const resolver = AplStateResolver(spec);
    final state = spec.defaultState(spec.loadouts.first);
    final unknown = [
      for (final id in identifiers)
        if (resolver.resolve(id, state) == null) id,
    ];
    expect(unknown, isEmpty);
  });

  // The evaluator treats any unknown buff as "down", so a missing
  // AuraDefinition would silently hide a proc from the editor and the quiz.
  test('every aura on the single-target path has an AuraDefinition', () {
    final missing = <String>[];
    for (final id in identifiers) {
      final parts = id.split('.');
      final kind = switch (parts.first) {
        'buff' => AuraKind.buff,
        'dot' || 'active_dot' => AuraKind.dot,
        'debuff' => AuraKind.debuff,
        _ => null,
      };
      if (kind == null) continue;
      if (spec.auraDefinition(parts[1], kind) == null) missing.add(id);
    }
    expect(missing, isEmpty);
  });

  test('every ability on the single-target path is in the spell book', () {
    final missing = {
      for (final action in modelled)
        if (!action.isListJump && !spec.spells.containsKey(action.name))
          action.name,
    };
    expect(missing, isEmpty);
  });

  test('every ability and aura has a spell id for its icon', () {
    final missing = [
      for (final spell in spec.spells.values)
        if (spell.spellId == null) 'spell ${spell.id}',
      for (final aura in spec.auras)
        if (aura.spellId == null) 'aura ${aura.id}',
    ];
    expect(missing, isEmpty);
  });
}
