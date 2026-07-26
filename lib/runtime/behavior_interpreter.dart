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

    if (operation == null || stateId == null) return;

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
