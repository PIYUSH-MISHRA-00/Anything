/// Behavior Interpreter — executes declarative BehaviorGraph nodes.
///
/// No arbitrary eval. Only trusted operation types.
library;

import '../creation/experience_package.dart';
import 'experience_session.dart';
import 'state_engine.dart';
import 'data_runtime.dart';
import 'service_resolver.dart';

/// Execution context for behavior nodes.
class BehaviorExecutionContext {
  final ExperienceSession session;
  final ExperienceStateEngine stateEngine;
  final ExperienceDataRuntime dataRuntime;
  final ExperienceServiceResolver serviceResolver;

  const BehaviorExecutionContext({
    required this.session,
    required this.stateEngine,
    required this.dataRuntime,
    required this.serviceResolver,
  });
}

/// Interprets BehaviorGraph nodes.
class BehaviorInterpreter {
  static const int _maxNodesPerExecution = 100;

  /// Execute behavior for a given event.
  Future<void> execute(
    BehaviorGraph graph,
    String eventId,
    BehaviorExecutionContext context,
  ) async {
    // Find the node matching the event
    final startNode = graph.nodes.where((n) => n.id == eventId).firstOrNull;
    if (startNode == null) return;

    // Execute the graph starting from this node
    await _executeNode(startNode, graph, context, <String>{});
  }

  Future<void> _executeNode(
    BehaviorNode node,
    BehaviorGraph graph,
    BehaviorExecutionContext context,
    Set<String> visited,
  ) async {
    // Check execution budget
    if (visited.length >= _maxNodesPerExecution) {
      return; // Stop execution
    }

    // Prevent cycles
    if (!visited.add(node.id)) {
      return;
    }

    // Execute the node based on its type
    await _executeByType(node, context);

    // Find and execute connected nodes
    final outgoingEdges = graph.edges.where((e) => e.from == node.id);
    for (final edge in outgoingEdges) {
      final nextNode = graph.nodes.where((n) => n.id == edge.to).firstOrNull;
      if (nextNode != null) {
        await _executeNode(nextNode, graph, context, visited);
      }
    }
  }

  Future<void> _executeByType(
    BehaviorNode node,
    BehaviorExecutionContext context,
  ) async {
    switch (node.type) {
      case 'event':
        // Event node — just marks the entry point
        break;

      case 'stateRead':
        // State read — already handled by UI bindings
        break;

      case 'stateWrite':
        final stateId = node.config['stateId'] as String?;
        final value = node.config['value'];
        if (stateId != null) {
          context.stateEngine.write(stateId, value);
        }
        break;

      case 'calculation':
        await _executeCalculation(node, context);
        break;

      case 'validation':
        // Validation — check conditions
        break;

      case 'transform':
        // Transform data
        break;

      case 'branch':
        // Branching — handled by edges with conditions
        break;

      case 'dataQuery':
        await _executeDataQuery(node, context);
        break;

      case 'dataMutation':
        await _executeDataMutation(node, context);
        break;

      case 'serviceInvocation':
        await _executeServiceCall(node, context);
        break;

      case 'capabilityInvocation':
        // Capability invocation — check declaration
        break;

      case 'navigation':
        // Navigation — handled by renderer
        break;

      case 'errorHandling':
        // Error handling
        break;

      case 'return':
        // Output/return
        break;

      default:
        // Unknown node type — skip
        break;
    }
  }

  Future<void> _executeCalculation(
    BehaviorNode node,
    BehaviorExecutionContext context,
  ) async {
    final operation = node.config['operation'] as String?;
    final stateId = node.config['stateId'] as String?;
    final operand = node.config['operand'];

    // Aggregate operations use sourceStateId + fieldId → targetStateId
    final sourceStateId = node.config['sourceStateId'] as String?;
    final targetStateId = node.config['targetStateId'] as String?;
    final fieldId = node.config['fieldId'] as String?;

    if (operation == null) return;

    // Handle aggregate operations
    if (_isAggregateOperation(operation)) {
      _executeAggregate(
        operation,
        sourceStateId,
        fieldId,
        targetStateId,
        context,
      );
      return;
    }

    if (stateId == null) return;

    final currentValue = context.stateEngine.read(stateId);
    final numericCurrent = (currentValue is num)
        ? currentValue.toDouble()
        : 0.0;
    final numericOperand = (operand is num) ? operand.toDouble() : 0.0;

    dynamic result;
    switch (operation) {
      case 'add':
        result = numericCurrent + numericOperand;
      case 'subtract':
        result = numericCurrent - numericOperand;
      case 'multiply':
        result = numericCurrent * numericOperand;
      case 'divide':
        if (numericOperand == 0) {
          result = 'Error: Division by zero';
        } else {
          result = numericCurrent / numericOperand;
        }
      case 'set':
        result = numericOperand;
      case 'clear':
        result = 0.0;
      default:
        return;
    }

    context.stateEngine.write(stateId, result);
  }

  bool _isAggregateOperation(String operation) {
    return operation == 'sum' ||
        operation == 'count' ||
        operation == 'average' ||
        operation == 'min' ||
        operation == 'max' ||
        operation == 'consecutiveDateCount';
  }

  void _executeAggregate(
    String operation,
    String? sourceStateId,
    String? fieldId,
    String? targetStateId,
    BehaviorExecutionContext context,
  ) {
    if (sourceStateId == null || targetStateId == null) return;

    final rawData = context.stateEngine.read(sourceStateId);
    if (rawData is! List) return;

    final records = rawData.cast<Map<String, dynamic>>();
    dynamic result;

    switch (operation) {
      case 'count':
        result = records.length;
        break;
      case 'sum':
        if (fieldId == null) {
          result = records.length;
          break;
        }
        double total = 0;
        for (final record in records) {
          final value = record[fieldId];
          if (value is num) {
            total += value.toDouble();
          } else if (value is String) {
            total += double.tryParse(value) ?? 0;
          }
        }
        result = total;
        break;
      case 'average':
        if (fieldId == null || records.isEmpty) {
          result = 0.0;
          break;
        }
        double total = 0;
        int count = 0;
        for (final record in records) {
          final value = record[fieldId];
          if (value is num) {
            total += value.toDouble();
            count++;
          } else if (value is String) {
            final parsed = double.tryParse(value);
            if (parsed != null) {
              total += parsed;
              count++;
            }
          }
        }
        result = count > 0 ? total / count : 0.0;
        break;
      case 'min':
        if (fieldId == null || records.isEmpty) {
          result = 0.0;
          break;
        }
        double minVal = double.infinity;
        for (final record in records) {
          final value = record[fieldId];
          if (value is num && value.toDouble() < minVal) {
            minVal = value.toDouble();
          } else if (value is String) {
            final parsed = double.tryParse(value);
            if (parsed != null && parsed < minVal) {
              minVal = parsed;
            }
          }
        }
        result = minVal == double.infinity ? 0.0 : minVal;
        break;
      case 'max':
        if (fieldId == null || records.isEmpty) {
          result = 0.0;
          break;
        }
        double maxVal = double.negativeInfinity;
        for (final record in records) {
          final value = record[fieldId];
          if (value is num && value.toDouble() > maxVal) {
            maxVal = value.toDouble();
          } else if (value is String) {
            final parsed = double.tryParse(value);
            if (parsed != null && parsed > maxVal) {
              maxVal = parsed;
            }
          }
        }
        result = maxVal == double.negativeInfinity ? 0.0 : maxVal;
        break;
      case 'consecutiveDateCount':
        if (records.isEmpty) {
          result = 0;
          break;
        }
        // Count consecutive dates from today backwards
        final dates =
            records
                .map(
                  (r) =>
                      r['date'] as String? ??
                      r['completion_date'] as String? ??
                      '',
                )
                .where((d) => d.isNotEmpty)
                .toList()
              ..sort((a, b) => b.compareTo(a)); // Most recent first

        int streak = 0;
        DateTime? expectedDate = DateTime.now();
        for (final dateStr in dates) {
          final date = DateTime.tryParse(dateStr);
          if (date == null) continue;
          final expected = expectedDate;
          if (expected != null &&
              date.year == expected.year &&
              date.month == expected.month &&
              date.day == expected.day) {
            streak++;
            expectedDate = expected.subtract(const Duration(days: 1));
          } else {
            break;
          }
        }
        result = streak;
        break;
    }

    context.stateEngine.write(targetStateId, result);
  }

  Future<void> _executeDataQuery(
    BehaviorNode node,
    BehaviorExecutionContext context,
  ) async {
    final entity = node.config['entity'] as String?;
    final resultStateId = node.config['resultStateId'] as String?;
    if (entity == null || resultStateId == null) return;

    final results = context.dataRuntime.query(entity);
    context.stateEngine.write(resultStateId, results);
  }

  Future<void> _executeDataMutation(
    BehaviorNode node,
    BehaviorExecutionContext context,
  ) async {
    final operation = node.config['operation'] as String?;
    final entity = node.config['entity'] as String?;
    final data = node.config['data'] as Map<String, dynamic>?;

    if (operation == null || entity == null) return;

    switch (operation) {
      case 'insert':
        if (data != null) {
          context.dataRuntime.insert(entity, data);
        }
      case 'update':
        final id = node.config['id'] as String?;
        if (id != null && data != null) {
          context.dataRuntime.update(entity, id, data);
        }
      case 'delete':
        final id = node.config['id'] as String?;
        if (id != null) {
          context.dataRuntime.delete(entity, id);
        }
    }
  }

  Future<void> _executeServiceCall(
    BehaviorNode node,
    BehaviorExecutionContext context,
  ) async {
    final serviceId = node.config['serviceId'] as String?;
    final operation = node.config['operation'] as String?;
    if (serviceId == null || operation == null) return;

    // Check if service is available
    if (!context.serviceResolver.isAvailable(serviceId)) {
      return;
    }

    // Execute through trusted service resolver
    await context.serviceResolver.execute(serviceId, operation, node.config);
  }
}
