/// Generic calculation session driven by [CalculationSpec] operations.
///
/// Capability runtime for calculation — not a product-specific Calculator
/// module. Unary scientific ops apply to the current display value.
library;

import 'dart:math' as math;

import 'expression_evaluator.dart';
import 'state_engine.dart';

/// Applies calculation protocol events to session state.
class CalculationSession {
  CalculationSession._();

  static const digit = 'calc.digit';
  static const operator_ = 'calc.operator';
  static const equals = 'calc.equals';
  static const clear = 'calc.clear';
  static const backspace = 'calc.backspace';
  static const unary = 'calc.unary';
  static const constant = 'calc.constant';
  static const paren = 'calc.paren';
  static const evaluateExpression = 'calc.evaluateExpression';

  /// Legacy golden-path aliases still accepted.
  static const legacyAliases = {
    'numberPressed': digit,
    'operationPressed': operator_,
    'equalsPressed': equals,
    'clearPressed': clear,
  };

  static bool handles(String eventId) {
    final id = legacyAliases[eventId] ?? eventId;
    return id == digit ||
        id == operator_ ||
        id == equals ||
        id == clear ||
        id == backspace ||
        id == unary ||
        id == constant ||
        id == paren ||
        id == evaluateExpression;
  }

  static void apply(
    ExperienceStateEngine state, {
    required String eventId,
    Map<String, dynamic>? data,
  }) {
    final id = legacyAliases[eventId] ?? eventId;
    switch (id) {
      case digit:
        _onDigit(state, data?['value']);
      case operator_:
        _onOperator(state, (data?['op'] ?? data?['value'] ?? '').toString());
      case equals:
        _onEquals(state);
      case clear:
        _onClear(state);
      case backspace:
        _onBackspace(state);
      case unary:
        _onUnary(state, (data?['op'] ?? data?['value'] ?? '').toString());
      case constant:
        _onConstant(state, (data?['name'] ?? data?['value'] ?? '').toString());
      case paren:
        _onParen(state, (data?['value'] ?? data?['op'] ?? '').toString());
      case evaluateExpression:
        _onEvaluateExpression(state, data?['expression']?.toString());
    }
  }

  static void _onDigit(ExperienceStateEngine state, dynamic value) {
    state.write('error', '');
    final display = state.read('display')?.toString() ?? '0';
    final newInput = state.read('newInput') as bool? ?? true;
    final digitStr = value?.toString() ?? '';
    if (digitStr.isEmpty) return;

    if (digitStr == '.') {
      if (newInput) {
        state.write('display', '0.');
        state.write('newInput', false);
        return;
      }
      if (display.contains('.')) return;
      state.write('display', '$display.');
      return;
    }

    if (newInput || display == '0') {
      state.write('display', digitStr);
    } else {
      state.write('display', '$display$digitStr');
    }
    state.write('newInput', false);
  }

  static void _onOperator(ExperienceStateEngine state, String op) {
    state.write('error', '');
    if (op.isEmpty) return;
    final normalized = _normalizeOp(op);
    final display = state.read('display')?.toString() ?? '0';
    final currentOp = state.read('currentOperation')?.toString() ?? '';

    if (currentOp.isNotEmpty && !(state.read('newInput') as bool? ?? true)) {
      _calculate(state);
    }

    final after = state.read('display')?.toString() ?? display;
    state.write('storedValue', double.tryParse(after) ?? 0.0);
    state.write('currentOperation', normalized);
    state.write('newInput', true);
    state.write('expression', '$after ${_opSymbol(normalized)}');
  }

  static void _onEquals(ExperienceStateEngine state) {
    final exprBuf = state.read('expressionBuffer')?.toString() ?? '';
    final display = state.read('display')?.toString() ?? '0';
    final pendingOp = state.read('currentOperation')?.toString() ?? '';
    // Prefer full expression evaluation when parentheses / buffer present.
    if (exprBuf.contains('(') || exprBuf.contains(')')) {
      final combined = '$exprBuf$display'.trim();
      _onEvaluateExpression(state, combined);
      return;
    }
    if (pendingOp.isEmpty &&
        (exprBuf.contains('+') ||
            exprBuf.contains('-') ||
            exprBuf.contains('*') ||
            exprBuf.contains('/') ||
            exprBuf.contains('^'))) {
      _onEvaluateExpression(state, '$exprBuf$display'.trim());
      return;
    }
    _calculate(state);
    state.write('currentOperation', '');
    state.write('expression', '');
    state.write('expressionBuffer', '');
    state.write('newInput', true);
  }

  static void _onParen(ExperienceStateEngine state, String value) {
    state.write('error', '');
    final buf = state.read('expressionBuffer')?.toString() ?? '';
    final display = state.read('display')?.toString() ?? '0';
    final newInput = state.read('newInput') as bool? ?? true;
    if (value == '(') {
      state.write('expressionBuffer', '$buf(');
      state.write('expression', '$buf(');
      state.write('newInput', true);
      return;
    }
    if (value == ')') {
      final piece = newInput ? '' : display;
      final next = '$buf$piece)';
      state.write('expressionBuffer', next);
      state.write('expression', next);
      state.write('display', '0');
      state.write('newInput', true);
    }
  }

  static void _onEvaluateExpression(ExperienceStateEngine state, String? raw) {
    final angle = state.read('angleMode')?.toString() ?? 'degrees';
    final input = (raw ?? '').trim();
    if (input.isEmpty) return;
    final result = ExpressionEvaluator.evaluate(input, angleMode: angle);
    if (!result.ok) {
      state.write('display', 'Error');
      state.write('error', result.error ?? 'Invalid expression');
      state.write('newInput', true);
      return;
    }
    state.write('display', _format(result.value!));
    state.write('expression', input);
    state.write('expressionBuffer', '');
    state.write('currentOperation', '');
    state.write('storedValue', result.value);
    state.write('error', '');
    state.write('newInput', true);
  }

  static void _onClear(ExperienceStateEngine state) {
    state.write('display', '0');
    state.write('expression', '');
    state.write('expressionBuffer', '');
    state.write('storedValue', 0.0);
    state.write('currentOperation', '');
    state.write('newInput', true);
    state.write('error', '');
  }

  static void _onBackspace(ExperienceStateEngine state) {
    state.write('error', '');
    final display = state.read('display')?.toString() ?? '0';
    final newInput = state.read('newInput') as bool? ?? true;
    if (newInput || display.length <= 1) {
      state.write('display', '0');
      state.write('newInput', true);
      return;
    }
    state.write('display', display.substring(0, display.length - 1));
  }

  static void _onConstant(ExperienceStateEngine state, String name) {
    state.write('error', '');
    final v = switch (name.toLowerCase()) {
      'pi' || 'π' => math.pi,
      'e' => math.e,
      _ => null,
    };
    if (v == null) return;
    state.write('display', _format(v));
    state.write('newInput', true);
  }

  static void _onUnary(ExperienceStateEngine state, String op) {
    state.write('error', '');
    final display = state.read('display')?.toString() ?? '0';
    final x = double.tryParse(display);
    if (x == null) {
      state.write('error', 'Invalid number');
      return;
    }
    final degrees =
        (state.read('angleMode')?.toString() ?? 'degrees') != 'radians';
    final rad = degrees ? x * math.pi / 180.0 : x;

    late final double result;
    try {
      switch (op.toLowerCase()) {
        case 'sin':
          result = math.sin(rad);
        case 'cos':
          result = math.cos(rad);
        case 'tan':
          result = math.tan(rad);
        case 'asin':
          if (x < -1 || x > 1) {
            state.write('error', 'asin domain [-1,1]');
            return;
          }
          result = degrees ? math.asin(x) * 180.0 / math.pi : math.asin(x);
        case 'acos':
          if (x < -1 || x > 1) {
            state.write('error', 'acos domain [-1,1]');
            return;
          }
          result = degrees ? math.acos(x) * 180.0 / math.pi : math.acos(x);
        case 'atan':
          result = degrees ? math.atan(x) * 180.0 / math.pi : math.atan(x);
        case 'sqrt':
          if (x < 0) {
            state.write('error', 'sqrt of negative');
            return;
          }
          result = math.sqrt(x);
        case 'cbrt':
          result = x < 0
              ? -math.pow(-x, 1 / 3).toDouble()
              : math.pow(x, 1 / 3).toDouble();
        case 'log':
          if (x <= 0) {
            state.write('error', 'log requires > 0');
            return;
          }
          result = math.log(x) / math.ln10;
        case 'ln':
          if (x <= 0) {
            state.write('error', 'ln requires > 0');
            return;
          }
          result = math.log(x);
        case 'exp':
          result = math.exp(x);
        case 'abs':
          result = x.abs();
        case 'neg':
        case '±':
          result = -x;
        case 'percent':
        case '%':
          result = x / 100.0;
        case 'factorial':
        case '!':
          if (x < 0 || x != x.roundToDouble() || x > 170) {
            state.write('error', 'factorial requires integer 0..170');
            return;
          }
          result = _factorial(x.round());
        case 'pow':
          // Binary pow via pending operator x^y
          _onOperator(state, '^');
          return;
        default:
          state.write('error', 'Unsupported op: $op');
          return;
      }
    } catch (e) {
      state.write('error', e.toString());
      return;
    }

    if (result.isNaN || result.isInfinite) {
      state.write('display', 'Error');
      state.write('error', 'Invalid result');
      state.write('newInput', true);
      return;
    }
    state.write('display', _format(result));
    state.write('expression', '$op($display)');
    state.write('newInput', true);
  }

  static double _factorial(int n) {
    var r = 1.0;
    for (var i = 2; i <= n; i++) {
      r *= i;
    }
    return r;
  }

  static void _calculate(ExperienceStateEngine state) {
    final stored = (state.read('storedValue') as num?)?.toDouble() ?? 0.0;
    final display = state.read('display')?.toString() ?? '0';
    final current = double.tryParse(display) ?? 0.0;
    final op = state.read('currentOperation')?.toString() ?? '';
    if (op.isEmpty) return;

    double? result;
    switch (op) {
      case '+':
        result = stored + current;
      case '-':
        result = stored - current;
      case '*':
        result = stored * current;
      case '/':
        if (current == 0) {
          state.write('display', 'Error');
          state.write('error', 'Division by zero');
          state.write('newInput', true);
          return;
        }
        result = stored / current;
      case '^':
      case 'pow':
        result = math.pow(stored, current).toDouble();
      case 'mod':
      case '%':
        if (current == 0) {
          state.write('display', 'Error');
          state.write('error', 'Modulo by zero');
          state.write('newInput', true);
          return;
        }
        result = stored % current;
      default:
        return;
    }

    if (result.isNaN || result.isInfinite) {
      state.write('display', 'Error');
      state.write('error', 'Invalid result');
      state.write('newInput', true);
      return;
    }

    final text = _format(result);
    state.write('display', text);
    state.write('storedValue', result);
    state.write('error', '');
  }

  static String _normalizeOp(String op) {
    switch (op) {
      case '×':
      case 'x':
      case 'X':
      case '*':
        return '*';
      case '÷':
      case '/':
        return '/';
      case '−':
      case '-':
        return '-';
      case '+':
        return '+';
      case '^':
      case 'pow':
        return '^';
      case 'mod':
      case '%':
        return 'mod';
      default:
        return op;
    }
  }

  static String _opSymbol(String op) {
    switch (op) {
      case '*':
        return '×';
      case '/':
        return '÷';
      case '^':
        return '^';
      case 'mod':
        return 'mod';
      default:
        return op;
    }
  }

  static String _format(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.round().toString();
    }
    var s = value.toStringAsFixed(10);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }
}
