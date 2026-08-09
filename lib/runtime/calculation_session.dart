/// Generic calculation session — digit/operator/equals/clear/backspace.
///
/// Capability runtime for [AppCapabilityIds.calculation]. Not a Calculator
/// product module: any Experience that emits `calc.*` actions uses this.
library;

import 'state_engine.dart';

/// Applies calculation protocol events to session state.
class CalculationSession {
  CalculationSession._();

  static const digit = 'calc.digit';
  static const operator_ = 'calc.operator';
  static const equals = 'calc.equals';
  static const clear = 'calc.clear';
  static const backspace = 'calc.backspace';

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
        id == backspace;
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
    _calculate(state);
    state.write('currentOperation', '');
    state.write('expression', '');
    state.write('newInput', true);
  }

  static void _onClear(ExperienceStateEngine state) {
    state.write('display', '0');
    state.write('expression', '');
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
      default:
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
      default:
        return op;
    }
  }

  static String _format(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    var s = value.toStringAsFixed(8);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }
}
