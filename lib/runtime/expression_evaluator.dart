/// Deterministic math expression evaluator (no arbitrary eval).
///
/// Supports parentheses, precedence, unary minus, and common scientific
/// functions/constants used by CalculationSpec.
library;

import 'dart:math' as math;

/// Result of evaluating an expression.
class ExpressionResult {
  final double? value;
  final String? error;

  const ExpressionResult.value(this.value) : error = null;
  const ExpressionResult.error(this.error) : value = null;

  bool get ok => error == null && value != null;
}

/// Shunting-yard + RPN evaluator for calculator expressions.
class ExpressionEvaluator {
  ExpressionEvaluator._();

  static ExpressionResult evaluate(
    String input, {
    String angleMode = 'degrees',
  }) {
    final tokens = _tokenize(input);
    if (tokens == null) {
      return const ExpressionResult.error('Invalid expression');
    }
    try {
      final rpn = _toRpn(tokens);
      final value = _evalRpn(rpn, degrees: angleMode != 'radians');
      if (value.isNaN || value.isInfinite) {
        return const ExpressionResult.error('Invalid result');
      }
      return ExpressionResult.value(value);
    } on _EvalError catch (e) {
      return ExpressionResult.error(e.message);
    } catch (_) {
      return const ExpressionResult.error('Invalid expression');
    }
  }

  static List<_Tok>? _tokenize(String raw) {
    final s = raw
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-');
    final out = <_Tok>[];
    var i = 0;
    _Tok? prev;
    while (i < s.length) {
      final c = s[i];
      if (c == ' ' || c == '\t') {
        i++;
        continue;
      }
      if (_isDigit(c) || (c == '.' && i + 1 < s.length && _isDigit(s[i + 1]))) {
        final start = i;
        i++;
        while (i < s.length && (_isDigit(s[i]) || s[i] == '.')) {
          i++;
        }
        out.add(_Tok.num(double.parse(s.substring(start, i))));
        prev = out.last;
        continue;
      }
      if (c == '(') {
        out.add(_Tok.lparen());
        prev = out.last;
        i++;
        continue;
      }
      if (c == ')') {
        out.add(_Tok.rparen());
        prev = out.last;
        i++;
        continue;
      }
      // Multi-letter functions / constants
      if (_isLetter(c)) {
        final start = i;
        i++;
        while (i < s.length && _isLetter(s[i])) {
          i++;
        }
        final name = s.substring(start, i).toLowerCase();
        if (name == 'pi') {
          out.add(_Tok.num(math.pi));
        } else if (name == 'e' && (i >= s.length || s[i] != 'x')) {
          // bare e constant; exp handled as function below
          out.add(_Tok.num(math.e));
        } else if (const {
          'sin',
          'cos',
          'tan',
          'asin',
          'acos',
          'atan',
          'sqrt',
          'cbrt',
          'log',
          'ln',
          'exp',
          'abs',
        }.contains(name)) {
          out.add(_Tok.func(name));
        } else if (name == 'mod') {
          out.add(_Tok.op('mod', 2, true));
        } else {
          return null;
        }
        prev = out.last;
        continue;
      }
      if (c == 'π') {
        out.add(_Tok.num(math.pi));
        prev = out.last;
        i++;
        continue;
      }
      if (c == '!') {
        out.add(_Tok.func('factorial'));
        prev = out.last;
        i++;
        continue;
      }
      if (c == '^') {
        out.add(_Tok.op('^', 4, false));
        prev = out.last;
        i++;
        continue;
      }
      if ('+-*/%'.contains(c)) {
        // Unary minus
        final unaryMinus =
            prev == null ||
            prev.kind == _Kind.op ||
            prev.kind == _Kind.lparen ||
            prev.kind == _Kind.func;
        if (c == '-' && unaryMinus) {
          out.add(_Tok.func('neg'));
        } else {
          final prec = (c == '+' || c == '-') ? 1 : 2;
          out.add(_Tok.op(c, prec, true));
        }
        prev = out.last;
        i++;
        continue;
      }
      return null;
    }
    return out;
  }

  static List<_Tok> _toRpn(List<_Tok> tokens) {
    final output = <_Tok>[];
    final stack = <_Tok>[];
    for (final t in tokens) {
      switch (t.kind) {
        case _Kind.num:
          output.add(t);
        case _Kind.func:
          stack.add(t);
        case _Kind.op:
          while (stack.isNotEmpty) {
            final top = stack.last;
            if (top.kind == _Kind.func ||
                (top.kind == _Kind.op &&
                    ((t.leftAssoc && top.precedence >= t.precedence) ||
                        (!t.leftAssoc && top.precedence > t.precedence)))) {
              output.add(stack.removeLast());
            } else {
              break;
            }
          }
          stack.add(t);
        case _Kind.lparen:
          stack.add(t);
        case _Kind.rparen:
          while (stack.isNotEmpty && stack.last.kind != _Kind.lparen) {
            output.add(stack.removeLast());
          }
          if (stack.isEmpty) throw _EvalError('Mismatched parentheses');
          stack.removeLast();
          if (stack.isNotEmpty && stack.last.kind == _Kind.func) {
            output.add(stack.removeLast());
          }
      }
    }
    while (stack.isNotEmpty) {
      final t = stack.removeLast();
      if (t.kind == _Kind.lparen || t.kind == _Kind.rparen) {
        throw _EvalError('Mismatched parentheses');
      }
      output.add(t);
    }
    return output;
  }

  static double _evalRpn(List<_Tok> rpn, {required bool degrees}) {
    final stack = <double>[];
    for (final t in rpn) {
      switch (t.kind) {
        case _Kind.num:
          stack.add(t.value!);
        case _Kind.op:
          if (stack.length < 2) throw _EvalError('Invalid expression');
          final b = stack.removeLast();
          final a = stack.removeLast();
          stack.add(_bin(t.text, a, b));
        case _Kind.func:
          if (t.text == 'factorial') {
            // Postfix: n!
            if (stack.isEmpty) throw _EvalError('Invalid expression');
            stack.add(_unary('factorial', stack.removeLast(), degrees));
          } else if (t.text == 'neg') {
            if (stack.isEmpty) throw _EvalError('Invalid expression');
            stack.add(-stack.removeLast());
          } else {
            if (stack.isEmpty) throw _EvalError('Invalid expression');
            stack.add(_unary(t.text, stack.removeLast(), degrees));
          }
        case _Kind.lparen:
        case _Kind.rparen:
          throw _EvalError('Invalid expression');
      }
    }
    if (stack.length != 1) throw _EvalError('Invalid expression');
    return stack.single;
  }

  static double _bin(String op, double a, double b) {
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '*':
        return a * b;
      case '/':
        if (b == 0) throw _EvalError('Division by zero');
        return a / b;
      case '%':
      case 'mod':
        if (b == 0) throw _EvalError('Modulo by zero');
        return a % b;
      case '^':
        return math.pow(a, b).toDouble();
      default:
        throw _EvalError('Unknown operator: $op');
    }
  }

  static double _unary(String op, double x, bool degrees) {
    final rad = degrees ? x * math.pi / 180.0 : x;
    switch (op) {
      case 'sin':
        return math.sin(rad);
      case 'cos':
        return math.cos(rad);
      case 'tan':
        return math.tan(rad);
      case 'asin':
        if (x < -1 || x > 1) throw _EvalError('asin domain [-1,1]');
        final v = math.asin(x);
        return degrees ? v * 180.0 / math.pi : v;
      case 'acos':
        if (x < -1 || x > 1) throw _EvalError('acos domain [-1,1]');
        final v = math.acos(x);
        return degrees ? v * 180.0 / math.pi : v;
      case 'atan':
        final v = math.atan(x);
        return degrees ? v * 180.0 / math.pi : v;
      case 'sqrt':
        if (x < 0) throw _EvalError('sqrt of negative');
        return math.sqrt(x);
      case 'cbrt':
        return x < 0
            ? -math.pow(-x, 1 / 3).toDouble()
            : math.pow(x, 1 / 3).toDouble();
      case 'log':
        if (x <= 0) throw _EvalError('log requires > 0');
        return math.log(x) / math.ln10;
      case 'ln':
        if (x <= 0) throw _EvalError('ln requires > 0');
        return math.log(x);
      case 'exp':
        return math.exp(x);
      case 'abs':
        return x.abs();
      case 'factorial':
        if (x < 0 || x != x.roundToDouble() || x > 170) {
          throw _EvalError('factorial requires integer 0..170');
        }
        var r = 1.0;
        for (var i = 2; i <= x.round(); i++) {
          r *= i;
        }
        return r;
      default:
        throw _EvalError('Unknown function: $op');
    }
  }

  static bool _isDigit(String c) =>
      c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  static bool _isLetter(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || (u >= 97 && u <= 122);
  }
}

enum _Kind { num, op, func, lparen, rparen }

class _Tok {
  final _Kind kind;
  final String text;
  final double? value;
  final int precedence;
  final bool leftAssoc;

  const _Tok._(
    this.kind,
    this.text, {
    this.value,
    this.precedence = 0,
    this.leftAssoc = true,
  });

  factory _Tok.num(double v) => _Tok._(_Kind.num, '', value: v);
  factory _Tok.op(String op, int prec, bool left) =>
      _Tok._(_Kind.op, op, precedence: prec, leftAssoc: left);
  factory _Tok.func(String name) => _Tok._(_Kind.func, name);
  factory _Tok.lparen() => const _Tok._(_Kind.lparen, '(');
  factory _Tok.rparen() => const _Tok._(_Kind.rparen, ')');
}

class _EvalError implements Exception {
  final String message;
  _EvalError(this.message);
}
