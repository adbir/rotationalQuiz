import 'dart:collection';

import '../models/combat_state.dart';
import '../models/spec_definition.dart';
import '../specs/rotation_spec.dart';
import 'apl_document.dart';
import 'apl_expression.dart';

/// What happened to an APL line during evaluation.
enum TraceOutcome {
  /// This is the ability to press on the next GCD.
  selected,

  /// An off-GCD ability to press alongside the next GCD.
  offGcd,

  /// A `run_action_list` / `call_action_list` whose condition passed.
  jumped,

  /// The `if=` condition was false.
  conditionFalse,

  /// The condition passed but the ability can't be pressed (cooldown,
  /// resources, talent...).
  unavailable,

  /// A `moving=1` line while standing still.
  notMoving,

  /// Racials, trinkets, potions and other actions the sandbox ignores.
  notModelled,

  /// The condition could not be parsed.
  error,
}

/// The evaluation of one APL line.
class AplTraceEntry {
  AplTraceEntry({
    required this.action,
    required this.outcome,
    this.reason,
    this.conditionPassed,
    Map<AplExpression, double>? nodeValues,
    Map<String, double>? identifierValues,
  }) : nodeValues = nodeValues ?? Map.identity(),
       identifierValues = identifierValues ?? const {};

  final AplAction action;
  final TraceOutcome outcome;

  /// Human readable explanation for [TraceOutcome.unavailable] and friends.
  final String? reason;

  /// Result of the `if=` condition; `null` when there is none or it was not
  /// evaluated.
  final bool? conditionPassed;

  /// Value of every expression node that was evaluated. Nodes skipped by
  /// short-circuiting are absent. Keyed by identity.
  final Map<AplExpression, double> nodeValues;

  /// Value of each state identifier read by the condition, in read order.
  final Map<String, double> identifierValues;
}

/// The result of evaluating an APL against a [CombatState].
class AplRecommendation {
  const AplRecommendation({
    required this.selected,
    required this.offGcd,
    required this.trace,
    required this.unknownIdentifiers,
  });

  /// The APL line that picked the next GCD ability, or `null` if nothing is
  /// castable.
  final AplAction? selected;

  /// Off-GCD abilities to press alongside [selected], in priority order.
  final List<AplAction> offGcd;

  /// Every line that was looked at, in evaluation order.
  final List<AplTraceEntry> trace;

  /// Identifiers the sandbox does not model; they evaluate to `0`.
  final Set<String> unknownIdentifiers;

  String? get selectedSpellId => selected?.name;
}

/// Walks an [AplDocument] the way SimC's action selection does: top to
/// bottom, the first line whose condition passes and whose ability is ready
/// wins.
class AplEvaluator {
  const AplEvaluator(this.spec);

  final RotationSpec spec;

  static const _maxDepth = 16;

  /// Recommends the next button(s) for [state].
  AplRecommendation recommend(AplDocument document, CombatState state) {
    final run = _Run(document, state);
    final selected = _runList(run, spec.entryList, 0);
    return AplRecommendation(
      selected: selected,
      offGcd: List.unmodifiable(run.offGcd),
      trace: List.unmodifiable(run.trace),
      unknownIdentifiers: UnmodifiableSetView(run.unknown),
    );
  }

  /// Evaluates a single expression against [state]; handy for tests and the
  /// APL viewer.
  double evaluate(AplExpression expression, CombatState state) {
    final context = _ExpressionContext(this, state);
    return context.eval(expression);
  }

  AplAction? _runList(_Run run, String listName, int depth) {
    final list = run.document[listName];
    if (list == null || depth > _maxDepth) return null;

    for (final action in list.actions) {
      if (action.name == 'variable' ||
          spec.unmodelledActions.contains(action.name)) {
        run.trace.add(
          AplTraceEntry(
            action: action,
            outcome: TraceOutcome.notModelled,
            reason: 'Not modelled by the sandbox',
          ),
        );
        continue;
      }
      if (action.onlyWhileMoving && !run.state.moving) {
        run.trace.add(
          AplTraceEntry(
            action: action,
            outcome: TraceOutcome.notMoving,
            reason: 'Only used while moving',
          ),
        );
        continue;
      }
      if (action.conditionError != null) {
        run.trace.add(
          AplTraceEntry(
            action: action,
            outcome: TraceOutcome.error,
            reason: 'Could not parse condition: ${action.conditionError}',
          ),
        );
        continue;
      }

      final context = _ExpressionContext(this, run.state);
      final condition = action.condition;
      final passed = condition == null || context.eval(condition) != 0;
      run.unknown.addAll(context.unknown);

      AplTraceEntry entry(TraceOutcome outcome, [String? reason]) =>
          AplTraceEntry(
            action: action,
            outcome: outcome,
            reason: reason,
            conditionPassed: condition == null ? null : passed,
            nodeValues: context.values,
            identifierValues: context.identifiers,
          );

      if (action.isListJump) {
        final target = action.targetListName;
        if (!passed) {
          run.trace.add(entry(TraceOutcome.conditionFalse));
          continue;
        }
        run.trace.add(entry(TraceOutcome.jumped, 'Go to "$target"'));
        if (target == null) continue;
        final result = _runList(run, target, depth + 1);
        // run_action_list never returns to the calling list.
        if (action.name == 'run_action_list' || result != null) return result;
        continue;
      }

      final availability = spec.availability(action.name, run.state);
      if (!passed) {
        run.trace.add(entry(TraceOutcome.conditionFalse, availability.reason));
        continue;
      }
      if (!availability.isAvailable) {
        run.trace.add(entry(TraceOutcome.unavailable, availability.reason));
        continue;
      }

      final SpellDefinition spell = spec.spells[action.name]!;
      if (spell.offGcd) {
        if (run.offGcd.any((a) => a.name == action.name)) continue;
        run.offGcd.add(action);
        run.state = spec.applyOffGcd(action.name, run.state);
        run.trace.add(entry(TraceOutcome.offGcd));
        continue;
      }

      run.trace.add(entry(TraceOutcome.selected));
      return action;
    }
    return null;
  }

  /// Resolves `buff.*`, `cooldown.*`, `talent.*` and friends, falling back
  /// to [RotationSpec.resolveScalar].
  double? _resolve(String identifier, CombatState state) {
    final parts = identifier.split('.');
    switch (parts) {
      case ['buff' || 'debuff' || 'dot', final name, final property]:
        final kind = switch (parts[0]) {
          'buff' => AuraKind.buff,
          'debuff' => AuraKind.debuff,
          _ => AuraKind.dot,
        };
        final aura = switch (kind) {
          AuraKind.buff => state.buff(name),
          AuraKind.debuff => state.debuff(name),
          AuraKind.dot => state.dot(name),
        };
        final definition = spec.auraDefinition(name, kind);
        return _auraProperty(aura, definition, property);
      case ['cooldown', final name, final property]:
        return _cooldownProperty(state, name, property);
      case ['talent', final name] || ['talent', final name, 'enabled']:
        return state.hasTalent(name) ? 1 : 0;
      case ['set_bonus', final name]:
        return state.setBonuses.contains(name) ? 1 : 0;
      case ['active_dot', final name]:
        return state.dot(name).isUp ? 1 : 0;
    }
    return spec.resolveScalar(identifier, state);
  }

  double? _auraProperty(
    AuraState aura,
    AuraDefinition? definition,
    String property,
  ) {
    final up = aura.isUp;
    final duration = definition?.duration ?? 15;
    return switch (property) {
      'up' || 'ticking' => up ? 1 : 0,
      'react' || 'stack' => up ? aura.stacks.toDouble() : 0,
      'down' => up ? 0 : 1,
      'remains' => up ? aura.remains : 0,
      'refreshable' => !up || aura.remains < duration * 0.3 ? 1 : 0,
      'duration' => duration,
      'max_stack' => (definition?.maxStacks ?? 1).toDouble(),
      _ => null,
    };
  }

  double? _cooldownProperty(CombatState state, String name, String property) {
    final definition = spec.cooldownDefinition(name);
    final cooldown = state.cooldown(name);
    final duration = definition?.duration ?? 0;
    final maxCharges = definition?.maxCharges;

    final double fractional;
    final double remains;
    if (maxCharges != null) {
      fractional = (cooldown.charges ?? maxCharges.toDouble()).clamp(
        0,
        maxCharges.toDouble(),
      );
      remains = fractional >= 1 ? 0 : (1 - fractional) * duration;
    } else {
      remains = cooldown.remains;
      fractional = remains <= 0
          ? 1
          : (duration <= 0 ? 0 : (1 - remains / duration).clamp(0, 1));
    }

    return switch (property) {
      'remains' => remains,
      'ready' || 'up' => remains <= 0 ? 1 : 0,
      'charges' => fractional.floorToDouble(),
      'charges_fractional' => fractional,
      'max_charges' => (maxCharges ?? 1).toDouble(),
      'duration' => duration,
      'full_recharge_time' =>
        ((maxCharges ?? 1) - fractional).clamp(0, double.infinity) * duration,
      _ => null,
    };
  }
}

class _Run {
  _Run(this.document, this.state);

  final AplDocument document;
  CombatState state;
  final trace = <AplTraceEntry>[];
  final offGcd = <AplAction>[];
  final unknown = <String>{};
}

class _ExpressionContext {
  _ExpressionContext(this.evaluator, this.state);

  final AplEvaluator evaluator;
  final CombatState state;
  final Map<AplExpression, double> values = Map.identity();
  final identifiers = <String, double>{};
  final unknown = <String>{};

  static const _epsilon = 1e-9;

  double eval(AplExpression node) {
    final value = _eval(node);
    values[node] = value;
    return value;
  }

  double _eval(AplExpression node) {
    switch (node) {
      case NumberLiteral(:final value):
        return value;
      case Identifier(:final name):
        final resolved = evaluator._resolve(name, state);
        if (resolved == null) unknown.add(name);
        final value = resolved ?? 0;
        identifiers[name] = value;
        return value;
      case GroupExpression(:final inner):
        return eval(inner);
      case UnaryExpression(:final operator, :final operand):
        final v = eval(operand);
        return switch (operator) {
          UnaryOperator.not => v == 0 ? 1 : 0,
          UnaryOperator.negate => -v,
          UnaryOperator.plus => v,
          UnaryOperator.abs => v.abs(),
        };
      case BinaryExpression(:final operator, :final left, :final right):
        switch (operator) {
          case BinaryOperator.and:
            if (eval(left) == 0) return 0;
            return eval(right) != 0 ? 1 : 0;
          case BinaryOperator.or:
            if (eval(left) != 0) return 1;
            return eval(right) != 0 ? 1 : 0;
          default:
        }
        final l = eval(left);
        final r = eval(right);
        bool eq() => (l - r).abs() < _epsilon;
        double b(bool v) => v ? 1 : 0;
        return switch (operator) {
          BinaryOperator.xor => b((l != 0) != (r != 0)),
          BinaryOperator.equal => b(eq()),
          BinaryOperator.notEqual => b(!eq()),
          BinaryOperator.less => b(l < r && !eq()),
          BinaryOperator.lessOrEqual => b(l < r || eq()),
          BinaryOperator.greater => b(l > r && !eq()),
          BinaryOperator.greaterOrEqual => b(l > r || eq()),
          BinaryOperator.max => l > r ? l : r,
          BinaryOperator.min => l < r ? l : r,
          BinaryOperator.add => l + r,
          BinaryOperator.subtract => l - r,
          BinaryOperator.multiply => l * r,
          BinaryOperator.divide => r == 0 ? 0 : l / r,
          BinaryOperator.modulus => r == 0 ? 0 : l % r,
          BinaryOperator.and ||
          BinaryOperator.or => throw StateError('unreachable'),
        };
    }
  }
}
