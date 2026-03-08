import 'tool_registry.dart';
import 'dart:math';

class CalculatorTool extends BaseTool {
  @override
  String get name => 'calculator_tool';

  @override
  Future<dynamic> execute(String contextPayload) async {
    // Extract mathematical expression from context
    final expression = _extractExpression(contextPayload);
    if (expression == null) {
      return {'error': 'No mathematical expression found'};
    }

    try {
      final result = _evaluate(expression);
      return {
        'expression': expression,
        'result': result,
        'formatted': _formatNumber(result),
      };
    } catch (e) {
      return {'error': 'Could not evaluate: $expression'};
    }
  }

  String? _extractExpression(String input) {
    // Extract numbers and operators
    final regex = RegExp(r'[\d\.\+\-\*\/\(\)\^\s]+');
    final match = regex.firstMatch(input);
    return match?.group(0)?.trim();
  }

  double _evaluate(String expr) {
    // Simple calculator: handle basic operations
    expr = expr.replaceAll(' ', '');

    // Handle power operator
    if (expr.contains('^')) {
      final parts = expr.split('^');
      return pow(double.parse(parts[0]), double.parse(parts[1])).toDouble();
    }

    // Handle multiplication/division first, then addition/subtraction
    if (expr.contains('*')) {
      final parts = expr.split('*');
      return parts.map(double.parse).reduce((a, b) => a * b);
    }
    if (expr.contains('/')) {
      final parts = expr.split('/');
      return parts.map(double.parse).reduce((a, b) => a / b);
    }
    if (expr.contains('+')) {
      final parts = expr.split('+');
      return parts.map(double.parse).reduce((a, b) => a + b);
    }
    if (expr.contains('-') && expr.indexOf('-') > 0) {
      final parts = expr.split('-');
      return parts.map(double.parse).reduce((a, b) => a - b);
    }

    return double.parse(expr);
  }

  String _formatNumber(double num) {
    if (num == num.toInt().toDouble()) {
      return num.toInt().toString();
    }
    return num.toStringAsFixed(4);
  }
}
