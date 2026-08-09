/// Structured calculation requirements — mode + operations, not product names.
///
/// The planner/model may emit a mode; lexical cues are only a fallback when
/// the structured plan under-specifies calculation mode.
library;

/// Calculation product mode (capability configuration, not an app template).
enum CalculationMode {
  basic,
  scientific,
  financial,
  statistics,
  custom,
}

/// Declarative calculation surface specification.
class CalculationSpec {
  final CalculationMode mode;
  final List<String> operations;
  final String angleMode;
  final bool memorySupport;
  final bool historySupport;

  const CalculationSpec({
    required this.mode,
    required this.operations,
    this.angleMode = 'degrees',
    this.memorySupport = false,
    this.historySupport = false,
  });

  static const basicOps = <String>[
    'digit',
    'add',
    'sub',
    'mul',
    'div',
    'equals',
    'clear',
    'backspace',
    'decimal',
  ];

  static const scientificOps = <String>[
    ...basicOps,
    'sin',
    'cos',
    'tan',
    'asin',
    'acos',
    'atan',
    'sqrt',
    'cbrt',
    'pow',
    'log',
    'ln',
    'exp',
    'factorial',
    'mod',
    'abs',
    'pi',
    'e',
    'percent',
    'paren',
    'neg',
  ];

  static const statisticsOps = <String>[
    ...basicOps,
    'sqrt',
    'pow',
    'abs',
    'percent',
    'mean',
  ];

  static const financialOps = <String>[
    ...basicOps,
    'percent',
    'pow',
    'abs',
  ];

  bool get isScientific =>
      mode == CalculationMode.scientific ||
      operations.any(
        (o) => const {
          'sin',
          'cos',
          'tan',
          'log',
          'ln',
          'sqrt',
          'pow',
          'factorial',
          'pi',
          'e',
        }.contains(o),
      );

  /// Build from structured capability ids and optional blueprint hints.
  factory CalculationSpec.resolve({
    required Set<String> capabilityIds,
    Map<String, dynamic>? blueprintHints,
    String? intentExpression,
  }) {
    final hintMode = blueprintHints?['calculationMode']?.toString();
    final hintOps = blueprintHints?['calculationOperations'];
    if (hintOps is List && hintOps.isNotEmpty) {
      final ops = hintOps.map((e) => e.toString()).toList();
      return CalculationSpec(
        mode: _modeFromString(hintMode) ??
            (ops.any((o) => scientificOps.contains(o) && !basicOps.contains(o))
                ? CalculationMode.scientific
                : CalculationMode.custom),
        operations: ops,
        angleMode: blueprintHints?['angleMode']?.toString() ?? 'degrees',
        memorySupport: blueprintHints?['memorySupport'] == true,
        historySupport: blueprintHints?['historySupport'] == true,
      );
    }

    if (capabilityIds.contains('scientificCalculation') ||
        capabilityIds.contains('calculation:scientific')) {
      return const CalculationSpec(
        mode: CalculationMode.scientific,
        operations: scientificOps,
        memorySupport: true,
        historySupport: true,
      );
    }
    if (capabilityIds.contains('statisticsCalculation') ||
        capabilityIds.contains('calculation:statistics')) {
      return const CalculationSpec(
        mode: CalculationMode.statistics,
        operations: statisticsOps,
      );
    }
    if (capabilityIds.contains('financialCalculation') ||
        capabilityIds.contains('calculation:financial')) {
      return const CalculationSpec(
        mode: CalculationMode.financial,
        operations: financialOps,
      );
    }

    final fromHint = _modeFromString(hintMode);
    if (fromHint != null) {
      return CalculationSpec(
        mode: fromHint,
        operations: _opsFor(fromHint),
        angleMode: blueprintHints?['angleMode']?.toString() ?? 'degrees',
      );
    }

    // Fallback only when the structured plan omitted mode: infer from
    // expression shape so "scientific calculator" ≠ "calculator".
    final expr = (intentExpression ?? '').toLowerCase();
    if (expr.contains('scientific') ||
        expr.contains('trig') ||
        expr.contains('engineering')) {
      return const CalculationSpec(
        mode: CalculationMode.scientific,
        operations: scientificOps,
        memorySupport: true,
        historySupport: true,
      );
    }
    if (expr.contains('statistic') || expr.contains('stats')) {
      return const CalculationSpec(
        mode: CalculationMode.statistics,
        operations: statisticsOps,
      );
    }
    if (expr.contains('financ') ||
        expr.contains('tax') ||
        expr.contains('percent')) {
      return const CalculationSpec(
        mode: CalculationMode.financial,
        operations: financialOps,
      );
    }

    return const CalculationSpec(
      mode: CalculationMode.basic,
      operations: basicOps,
    );
  }

  static CalculationMode? _modeFromString(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'basic':
        return CalculationMode.basic;
      case 'scientific':
        return CalculationMode.scientific;
      case 'financial':
        return CalculationMode.financial;
      case 'statistics':
      case 'stats':
        return CalculationMode.statistics;
      case 'custom':
        return CalculationMode.custom;
      default:
        return null;
    }
  }

  static List<String> _opsFor(CalculationMode mode) {
    switch (mode) {
      case CalculationMode.scientific:
        return scientificOps;
      case CalculationMode.statistics:
        return statisticsOps;
      case CalculationMode.financial:
        return financialOps;
      case CalculationMode.basic:
      case CalculationMode.custom:
        return basicOps;
    }
  }
}
