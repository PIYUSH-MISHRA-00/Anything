/// Calculator Runtime — executes Calculator through the generic Runtime.
///
/// No Calculator-specific production screen.
/// The ExperiencePackage defines Calculator.
/// The Runtime interprets it.
library;

import '../anything_runtime.dart';
import '../experience_session.dart';
import 'calculator_package.dart';

/// Calculator Runtime controller.
///
/// Handles Calculator-specific behavior through the generic Runtime.
class CalculatorRuntime {
  final AnythingRuntime _runtime;

  CalculatorRuntime(this._runtime);

  /// Open and initialize Calculator.
  Future<ExperienceSession> open() async {
    final package = createCalculatorPackage();
    return await _runtime.openExperience(package);
  }

  /// Handle number button press.
  void onNumberPressed(int value) {
    final display = _runtime.getState('display')?.toString() ?? '0';
    final newInput = _runtime.getState('newInput') as bool? ?? true;

    if (newInput || display == '0') {
      _runtime.setState('display', value.toString());
    } else {
      _runtime.setState('display', '$display$value');
    }
    _runtime.setState('newInput', false);
  }

  /// Handle operation button press.
  void onOperationPressed(String op) {
    final display = _runtime.getState('display')?.toString() ?? '0';
    final currentOp = _runtime.getState('currentOperation')?.toString() ?? '';

    if (currentOp.isNotEmpty) {
      // Calculate intermediate result
      _calculate();
    }

    _runtime.setState('storedValue', double.tryParse(display) ?? 0.0);
    _runtime.setState('currentOperation', op);
    _runtime.setState('newInput', true);

    // Update expression display
    final opSymbol = _opToSymbol(op);
    _runtime.setState('expression', '$display $opSymbol');
  }

  /// Handle equals button press.
  void onEqualsPressed() {
    _calculate();
    _runtime.setState('currentOperation', '');
    _runtime.setState('expression', '');
    _runtime.setState('newInput', true);
  }

  /// Handle clear button press.
  void onClearPressed() {
    _runtime.setState('display', '0');
    _runtime.setState('expression', '');
    _runtime.setState('currentValue', 0.0);
    _runtime.setState('storedValue', 0.0);
    _runtime.setState('currentOperation', '');
    _runtime.setState('newInput', true);
  }

  void _calculate() {
    final stored = _runtime.getState('storedValue') as num? ?? 0;
    final display = _runtime.getState('display')?.toString() ?? '0';
    final current = double.tryParse(display) ?? 0;
    final op = _runtime.getState('currentOperation')?.toString() ?? '';

    num result;
    switch (op) {
      case '+':
        result = stored + current;
      case '-':
        result = stored - current;
      case '*':
        result = stored * current;
      case '/':
        if (current == 0) {
          _runtime.setState('display', 'Error');
          return;
        }
        result = stored / current;
      default:
        result = current;
    }

    // Format result
    final displayValue = result == result.toInt().toDouble()
        ? result.toInt().toString()
        : result
              .toStringAsFixed(10)
              .replaceAll(RegExp(r'0+$'), '')
              .replaceAll(RegExp(r'\.$'), '');

    _runtime.setState('display', displayValue);
    _runtime.setState('storedValue', result);
  }

  String _opToSymbol(String op) {
    switch (op) {
      case '+':
        return '+';
      case '-':
        return '−';
      case '*':
        return '×';
      case '/':
        return '÷';
      default:
        return op;
    }
  }

  /// Get current display value.
  String get display => _runtime.getState('display')?.toString() ?? '0';

  /// Get current expression.
  String get expression => _runtime.getState('expression')?.toString() ?? '';
}
