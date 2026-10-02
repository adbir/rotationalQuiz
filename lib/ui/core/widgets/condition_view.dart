import 'package:flutter/material.dart';

import '../../../domain/apl/apl_expression.dart';
import '../theme.dart';

/// Renders an APL condition with every evaluated clause coloured by its
/// result: green for true, red for false and grey for clauses skipped by
/// short-circuiting.
class ConditionView extends StatelessWidget {
  const ConditionView({
    super.key,
    required this.expression,
    required this.values,
    this.style,
  });

  final AplExpression expression;
  final Map<AplExpression, double> values;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = (style ?? theme.textTheme.bodySmall)!.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Courier New', 'Courier'],
    );
    return Text.rich(
      TextSpan(style: base, children: _spans(expression, theme)),
      softWrap: true,
    );
  }

  List<InlineSpan> _spans(AplExpression node, ThemeData theme) {
    switch (node) {
      case BinaryExpression(:final operator, :final left, :final right)
          when operator.isLogical:
        return [
          ..._spans(left, theme),
          TextSpan(
            text: operator.symbol,
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          ..._spans(right, theme),
        ];
      case UnaryExpression(operator: UnaryOperator.not, :final operand)
          when _isLogical(operand):
        return [
          TextSpan(text: '!', style: _clauseStyle(node, theme)),
          ..._spans(operand, theme),
        ];
      case GroupExpression(:final inner) when _isLogical(inner):
        return [
          TextSpan(text: '(', style: _clauseStyle(node, theme)),
          ..._spans(inner, theme),
          TextSpan(text: ')', style: _clauseStyle(node, theme)),
        ];
      default:
        final value = values[node];
        return [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Tooltip(
              message: value == null
                  ? 'Not evaluated (short-circuited)'
                  : '= ${_format(value)}',
              child: Text(
                node.toSource(),
                style: theme.textTheme.bodySmall
                    ?.copyWith(
                      fontFamily: 'monospace',
                      fontFamilyFallback: const ['Courier New', 'Courier'],
                    )
                    .merge(_clauseStyle(node, theme)),
              ),
            ),
          ),
        ];
    }
  }

  static bool _isLogical(AplExpression node) => switch (node) {
    BinaryExpression(:final operator) => operator.isLogical,
    GroupExpression(:final inner) => _isLogical(inner),
    UnaryExpression(operator: UnaryOperator.not, :final operand) => _isLogical(
      operand,
    ),
    _ => false,
  };

  TextStyle? _clauseStyle(AplExpression node, ThemeData theme) {
    final value = values[node];
    if (value == null) {
      return TextStyle(color: theme.colorScheme.outline);
    }
    final pass = value != 0;
    final color = pass ? AppTheme.passColor : AppTheme.failColor;
    return TextStyle(
      color: color,
      backgroundColor: color.withValues(alpha: 0.12),
      fontWeight: FontWeight.w600,
    );
  }

  static String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}
