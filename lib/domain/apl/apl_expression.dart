/// Abstract syntax tree and parser for SimulationCraft conditional
/// expressions, e.g. the text after `if=` in an action line.
///
/// Operator semantics follow the SimC wiki (ActionLists > Conditional
/// expressions):
///
/// | Precedence | Operators                            |
/// | ---------- | ------------------------------------ |
/// | lowest     | `\|` (or), `^` (xor)                 |
/// |            | `&` (and)                            |
/// |            | `=` `!=` `<` `<=` `>` `>=`           |
/// |            | `>?` (max), `<?` (min)               |
/// |            | `+` `-`                              |
/// |            | `*` `%` (division) `%%` (modulus)    |
/// | highest    | unary `!` `-` `+` `@` (abs)          |
///
/// All values are doubles; booleans are `1` (true) and `0` (false).
library;

/// Base class for all expression nodes.
sealed class AplExpression {
  const AplExpression();

  /// Renders the node back to SimC syntax.
  String toSource();

  @override
  String toString() => toSource();
}

/// A numeric literal such as `52` or `1.8`.
final class NumberLiteral extends AplExpression {
  const NumberLiteral(this.value, this.source);

  final double value;
  final String source;

  @override
  String toSource() => source;
}

/// A state lookup such as `buff.stormkeeper.up` or `maelstrom.deficit`.
final class Identifier extends AplExpression {
  const Identifier(this.name);

  final String name;

  /// The dotted path, e.g. `['buff', 'stormkeeper', 'up']`.
  List<String> get parts => name.split('.');

  @override
  String toSource() => name;
}

/// Unary operator kinds.
enum UnaryOperator {
  not('!'),
  negate('-'),
  plus('+'),
  abs('@');

  const UnaryOperator(this.symbol);

  final String symbol;
}

/// A unary operation such as `!buff.ascendance.up`.
final class UnaryExpression extends AplExpression {
  const UnaryExpression(this.operator, this.operand);

  final UnaryOperator operator;
  final AplExpression operand;

  @override
  String toSource() => '${operator.symbol}${operand.toSource()}';
}

/// Binary operator kinds, ordered loosely by precedence group.
enum BinaryOperator {
  or('|', 1),
  xor('^', 1),
  and('&', 2),
  equal('=', 3),
  notEqual('!=', 3),
  less('<', 3),
  lessOrEqual('<=', 3),
  greater('>', 3),
  greaterOrEqual('>=', 3),
  max('>?', 4),
  min('<?', 4),
  add('+', 5),
  subtract('-', 5),
  multiply('*', 6),
  divide('%', 6),
  modulus('%%', 6);

  const BinaryOperator(this.symbol, this.precedence);

  final String symbol;
  final int precedence;

  bool get isLogical => this == or || this == xor || this == and;
}

/// A binary operation such as `maelstrom.deficit>15`.
final class BinaryExpression extends AplExpression {
  const BinaryExpression(this.operator, this.left, this.right);

  final BinaryOperator operator;
  final AplExpression left;
  final AplExpression right;

  @override
  String toSource() =>
      '${left.toSource()}${operator.symbol}${right.toSource()}';
}

/// A parenthesised sub-expression. Kept in the tree so that [toSource]
/// round-trips the original text.
final class GroupExpression extends AplExpression {
  const GroupExpression(this.inner);

  final AplExpression inner;

  @override
  String toSource() => '(${inner.toSource()})';
}

/// Thrown when an expression cannot be parsed.
class AplParseException implements Exception {
  AplParseException(this.message, this.source, this.offset);

  final String message;
  final String source;
  final int offset;

  @override
  String toString() => 'AplParseException: $message at $offset in "$source"';
}

enum _TokenType { number, identifier, operator, leftParen, rightParen, end }

class _Token {
  const _Token(this.type, this.text, this.offset);

  final _TokenType type;
  final String text;
  final int offset;
}

/// Longest operators first so that e.g. `>=` wins over `>`.
const _operators = [
  '>?', '<?', '<=', '>=', '!=', '%%', //
  '=', '<', '>', '!', '+', '-', '*', '%', '/', '&', '|', '^', '@',
];

List<_Token> _tokenize(String source) {
  final tokens = <_Token>[];
  var i = 0;
  bool isDigit(String c) => c.compareTo('0') >= 0 && c.compareTo('9') <= 0;
  bool isIdentStart(String c) => RegExp(r'[A-Za-z_]').hasMatch(c);
  bool isIdentPart(String c) => RegExp(r'[A-Za-z0-9_.]').hasMatch(c);

  while (i < source.length) {
    final c = source[i];
    if (c.trim().isEmpty) {
      i++;
      continue;
    }
    if (c == '(') {
      tokens.add(_Token(_TokenType.leftParen, c, i++));
      continue;
    }
    if (c == ')') {
      tokens.add(_Token(_TokenType.rightParen, c, i++));
      continue;
    }
    if (isDigit(c) ||
        (c == '.' && i + 1 < source.length && isDigit(source[i + 1]))) {
      final start = i;
      while (i < source.length && (isDigit(source[i]) || source[i] == '.')) {
        i++;
      }
      // Identifiers such as `trinket.1.has_use_buff` never start with a digit,
      // but guard against `1abc` style garbage.
      if (i < source.length && isIdentStart(source[i])) {
        throw AplParseException('Unexpected character', source, i);
      }
      tokens.add(_Token(_TokenType.number, source.substring(start, i), start));
      continue;
    }
    if (isIdentStart(c)) {
      final start = i;
      while (i < source.length && isIdentPart(source[i])) {
        i++;
      }
      tokens.add(
        _Token(_TokenType.identifier, source.substring(start, i), start),
      );
      continue;
    }
    final op = _operators.firstWhere(
      (o) => source.startsWith(o, i),
      orElse: () => throw AplParseException('Unexpected character', source, i),
    );
    tokens.add(_Token(_TokenType.operator, op, i));
    i += op.length;
  }
  tokens.add(_Token(_TokenType.end, '', source.length));
  return tokens;
}

/// Parses SimC conditional expressions with a Pratt (precedence climbing)
/// parser.
class AplExpressionParser {
  AplExpressionParser._(this._source) : _tokens = _tokenize(_source);

  final String _source;
  final List<_Token> _tokens;
  var _position = 0;

  /// Parses [source] into an expression tree.
  ///
  /// Throws an [AplParseException] if [source] is not a valid expression.
  static AplExpression parse(String source) {
    final parser = AplExpressionParser._(source);
    final expression = parser._parseBinary(0);
    final trailing = parser._peek;
    if (trailing.type != _TokenType.end) {
      throw AplParseException(
        'Unexpected "${trailing.text}"',
        source,
        trailing.offset,
      );
    }
    return expression;
  }

  _Token get _peek => _tokens[_position];

  _Token _advance() => _tokens[_position++];

  static final _binaryBySymbol = {
    for (final op in BinaryOperator.values) op.symbol: op,
    '/': BinaryOperator.divide,
  };

  static final _unaryBySymbol = {
    for (final op in UnaryOperator.values) op.symbol: op,
  };

  AplExpression _parseBinary(int minPrecedence) {
    var left = _parseUnary();
    while (true) {
      final token = _peek;
      if (token.type != _TokenType.operator) break;
      final op = _binaryBySymbol[token.text];
      if (op == null || op.precedence <= minPrecedence) break;
      _advance();
      final right = _parseBinary(op.precedence);
      left = BinaryExpression(op, left, right);
    }
    return left;
  }

  AplExpression _parseUnary() {
    final token = _peek;
    if (token.type == _TokenType.operator) {
      final op = _unaryBySymbol[token.text];
      if (op == null) {
        throw AplParseException(
          'Unexpected operator "${token.text}"',
          _source,
          token.offset,
        );
      }
      _advance();
      return UnaryExpression(op, _parseUnary());
    }
    return _parsePrimary();
  }

  AplExpression _parsePrimary() {
    final token = _advance();
    switch (token.type) {
      case _TokenType.number:
        return NumberLiteral(double.parse(token.text), token.text);
      case _TokenType.identifier:
        return Identifier(token.text);
      case _TokenType.leftParen:
        final inner = _parseBinary(0);
        final closing = _advance();
        if (closing.type != _TokenType.rightParen) {
          throw AplParseException('Expected ")"', _source, closing.offset);
        }
        return GroupExpression(inner);
      case _TokenType.operator:
      case _TokenType.rightParen:
      case _TokenType.end:
        throw AplParseException(
          token.type == _TokenType.end
              ? 'Unexpected end of expression'
              : 'Unexpected "${token.text}"',
          _source,
          token.offset,
        );
    }
  }
}
