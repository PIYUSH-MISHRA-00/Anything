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
  Map<String, dynamic>? _eventData;

  /// Execute behavior for a given event.
  Future<void> execute(
    BehaviorGraph graph,
    String eventId, {
    BehaviorExecutionContext? context,
    Map<String, dynamic>? data,
  }) async {
    _eventData = data;

    // Find the node matching the event (prefer exact id).
    var startNode = graph.nodes.where((n) => n.id == eventId).firstOrNull;

    // Generic SearchAction aliases → data refresh entry points when the
    // Experience shell exposes refreshData but the UI fires search.
    if (startNode == null) {
      final aliased = switch (eventId) {
        'search' || 'SearchAction' || 'searchAction' => 'refreshData',
        _ => null,
      };
      if (aliased != null) {
        startNode = graph.nodes.where((n) => n.id == aliased).firstOrNull;
      }
    }

    // If no direct match, try the _event suffix convention used by generated
    // behavior graphs (e.g., button fires 'add_person', graph has 'add_person_event').
    startNode ??= graph.nodes
        .where((n) => n.id == '${eventId}_event')
        .firstOrNull;

    // If no direct match, resolve generic renderer events to behavior graph nodes.
    // The renderer sends generic IDs (submitForm, deleteRecord) but the graph
    // uses action-specific IDs (create_person_event, delete_person_event).
    startNode ??= _resolveGenericEvent(graph, eventId, data);

    if (startNode == null) return;

    // Execute the graph starting from this node
    await _executeNode(startNode, graph, context!, <String>{});
    _eventData = null;
  }

  /// Maps generic renderer event IDs to behavior graph event nodes.
  ///
  /// The renderer dispatches generic events (submitForm, deleteRecord, etc.)
  /// but the generated behavior graph uses action-specific IDs
  /// (create_person_event, delete_person_event, etc.). This method resolves
  /// the mapping by inspecting event node configs and matching entity/action type.
  BehaviorNode? _resolveGenericEvent(
    BehaviorGraph graph,
    String eventId,
    Map<String, dynamic>? data,
  ) {
    final entityId = data?['entityId'] as String?;
    if (entityId == null) return null;

    // Map generic renderer events to expected action types
    String? actionType;
    if (eventId == 'submitForm') {
      final mode = data?['mode'] as String?;
      actionType = mode == 'edit' ? 'update' : 'create';
    } else if (eventId == 'deleteRecord') {
      actionType = 'delete';
    }
    if (actionType == null) return null;

    // Find event node that targets this entity with matching action type
    for (final node in graph.nodes) {
      if (node.type != 'event') continue;
      final config = node.config;
      final configEventId = config['eventId'] as String?;
      if (configEventId == null) continue;

      // Match by entity ID in the action ID
      if (!configEventId.contains(entityId)) continue;

      // Also match by action type prefix
      if (actionType == 'create' &&
          (configEventId.startsWith('create_') ||
              configEventId.startsWith('add_'))) {
        return node;
      } else if (actionType == 'update' &&
          (configEventId.startsWith('update_') ||
              configEventId.startsWith('edit_'))) {
        return node;
      } else if (actionType == 'delete' &&
          (configEventId.startsWith('delete_') ||
              configEventId.startsWith('remove_'))) {
        return node;
      }
    }
    return null;
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
    // Prefer data from the event (form values), fall back to node config
    final data =
        _eventData?['values'] as Map<String, dynamic>? ??
        node.config['data'] as Map<String, dynamic>?;

    if (operation == null || entity == null) return;

    // If the event data has a recordId (edit mode), always update.
    final eventRecordId = _eventData?['recordId'] as String?;
    final eventMode = _eventData?['mode'] as String?;
    if (eventMode == 'edit' && eventRecordId != null && data != null) {
      await context.dataRuntime.update(entity, eventRecordId, data);
      return;
    }

    switch (operation) {
      case 'insert':
      case 'create':
        if (data != null) {
          await context.dataRuntime.insert(entity, data);
        }
      case 'update':
        final id = node.config['id'] as String? ?? eventRecordId;
        if (id != null && data != null) {
          await context.dataRuntime.update(entity, id, data);
        }
      case 'delete':
        final id = node.config['id'] as String? ?? eventRecordId;
        if (id != null) {
          await context.dataRuntime.delete(entity, id);
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

    final loadingStateId = node.config['loadingStateId'] as String?;
    final loadingLabelStateId = node.config['loadingLabelStateId'] as String?;
    final errorStateId = node.config['errorStateId'] as String?;
    final resultStateId = node.config['resultStateId'] as String?;
    final titleStateId = node.config['titleStateId'] as String?;
    final cacheStateId = node.config['cacheStateId'] as String?;
    final queryStateId = node.config['queryStateId'] as String?;

    if (loadingStateId != null) {
      context.stateEngine.write(loadingStateId, true);
    }
    if (loadingLabelStateId != null) {
      context.stateEngine.write(loadingLabelStateId, 'Loading…');
    }
    if (errorStateId != null) {
      context.stateEngine.write(errorStateId, '');
    }

    if (!context.serviceResolver.isAvailable(serviceId)) {
      if (errorStateId != null) {
        context.stateEngine.write(
          errorStateId,
          'Data service is not available.',
        );
      }
      if (loadingStateId != null) {
        context.stateEngine.write(loadingStateId, false);
      }
      if (loadingLabelStateId != null) {
        context.stateEngine.write(loadingLabelStateId, '');
      }
      return;
    }

    // Prefer explicit event payload query (SearchAction), then state, then config.
    final eventQuery = _eventData?['query']?.toString();
    final stateQuery = queryStateId != null
        ? (context.stateEngine.read(queryStateId)?.toString() ?? '')
        : '';
    final configQuery = node.config['query'] as String? ?? '';
    final query = (eventQuery != null && eventQuery.trim().isNotEmpty)
        ? eventQuery.trim()
        : (stateQuery.trim().isNotEmpty
              ? stateQuery.trim()
              : configQuery.trim());

    if (query.isEmpty) {
      if (errorStateId != null) {
        context.stateEngine.write(errorStateId, 'Enter a query first.');
      }
      if (loadingStateId != null) {
        context.stateEngine.write(loadingStateId, false);
      }
      if (loadingLabelStateId != null) {
        context.stateEngine.write(loadingLabelStateId, '');
      }
      return;
    }

    // Keep state aligned with the query actually sent to the provider.
    if (queryStateId != null) {
      context.stateEngine.write(queryStateId, query);
    }

    final requestId =
        '${DateTime.now().microsecondsSinceEpoch}-$serviceId-$operation';
    // Write when the Experience declares activeRequestId (news/weather shells).
    context.stateEngine.write('activeRequestId', requestId);

    final params = <String, dynamic>{
      'query': query,
      'location': query,
      'requestId': requestId,
    };
    final result = await context.serviceResolver.execute(
      serviceId,
      operation,
      params,
    );

    // Drop stale responses when a newer search superseded this one.
    final active = context.stateEngine.read('activeRequestId')?.toString();
    if (active != null && active.isNotEmpty && active != requestId) {
      return;
    }

    if (loadingStateId != null) {
      context.stateEngine.write(loadingStateId, false);
    }
    if (loadingLabelStateId != null) {
      context.stateEngine.write(loadingLabelStateId, '');
    }

    if (result['error'] != null) {
      if (errorStateId != null) {
        context.stateEngine.write(errorStateId, result['error'].toString());
      }
      if (cacheStateId != null && resultStateId != null) {
        final cached = context.stateEngine.read(cacheStateId)?.toString() ?? '';
        if (cached.isNotEmpty) {
          context.stateEngine.write(resultStateId, cached);
          if (errorStateId != null) {
            context.stateEngine.write(
              errorStateId,
              '${result['error']} Showing last known data.',
            );
          }
        }
      }
      return;
    }

    final results = result['results'] as List? ?? const [];
    if (results.isEmpty) {
      if (resultStateId != null) {
        context.stateEngine.write(resultStateId, 'No data found for "$query".');
      }
      if (titleStateId != null) {
        context.stateEngine.write(titleStateId, query);
      }
      return;
    }

    final expectedSourceType =
        node.config['expectedSourceType']?.toString() ?? '';
    final provenanceStateId = node.config['provenanceStateId'] as String?;
    final sourceTypeStateId = node.config['sourceTypeStateId'] as String?;
    final aggregate = node.config['aggregateResults'] == true;

    final first = results.first;
    String title = query;
    String body = '';
    String sourceType = '';
    String provider = '';
    if (first is Map) {
      title = (first['title'] ?? query).toString();
      sourceType = (first['sourceType'] ?? '').toString();
      provider = (first['provider'] ?? '').toString();
      if (aggregate) {
        final chunks = <String>[];
        for (final item in results) {
          if (item is Map) {
            chunks.add((item['content'] ?? item['title'] ?? '').toString());
          } else {
            chunks.add(item.toString());
          }
        }
        body = chunks.where((c) => c.trim().isNotEmpty).join('\n\n——\n\n');
      } else {
        body = (first['content'] ?? first['sourceUri'] ?? '').toString();
        if (results.length > 1) {
          body =
              '$body\n\n(+${results.length - 1} more source'
              '${results.length - 1 == 1 ? '' : 's'})';
        }
      }
    } else {
      body = first.toString();
    }

    // IS-P13: never accept Wikipedia/generic knowledge as weather/news.
    if (expectedSourceType.isNotEmpty) {
      final uri = first is Map ? (first['sourceUri'] ?? '').toString() : '';
      final looksWiki =
          uri.contains('wikipedia.org') ||
          body.toLowerCase().contains('wikipedia') ||
          sourceType == 'genericKnowledge' ||
          sourceType.isEmpty &&
              (expectedSourceType == 'structuredWeather' ||
                  expectedSourceType == 'structuredNews');
      if (sourceType != expectedSourceType || looksWiki) {
        if (errorStateId != null) {
          context.stateEngine.write(
            errorStateId,
            'Expected $expectedSourceType data, but received '
            '${sourceType.isEmpty ? 'generic knowledge' : sourceType}. '
            'Retry or re-create this app.',
          );
        }
        return;
      }
    }

    if (titleStateId != null) {
      context.stateEngine.write(titleStateId, title);
    }
    if (resultStateId != null) {
      context.stateEngine.write(resultStateId, body);
    }
    if (cacheStateId != null) {
      context.stateEngine.write(cacheStateId, body);
    }
    final imageStateId = node.config['imageStateId'] as String?;
    if (imageStateId != null) {
      String? imageUrl;
      if (first is Map) {
        imageUrl = (first['imageUrl'] ?? first['image'] ?? '').toString();
        if (imageUrl.isEmpty) {
          for (final item in results) {
            if (item is Map) {
              final candidate =
                  (item['imageUrl'] ?? item['image'] ?? '').toString();
              if (candidate.isNotEmpty) {
                imageUrl = candidate;
                break;
              }
            }
          }
        }
      }
      context.stateEngine.write(imageStateId, imageUrl ?? '');
    }
    final linkStateId = node.config['linkStateId'] as String?;
    if (linkStateId != null && first is Map) {
      context.stateEngine.write(
        linkStateId,
        (first['sourceUri'] ?? first['url'] ?? '').toString(),
      );
    }
    if (sourceTypeStateId != null && sourceType.isNotEmpty) {
      context.stateEngine.write(sourceTypeStateId, sourceType);
    }
    if (provenanceStateId != null) {
      final prov = result['provenance'];
      final label = prov is Map
          ? '${prov['sourceType'] ?? sourceType} via '
              '${prov['provider'] ?? provider}'
          : (provider.isEmpty
              ? sourceType
              : '$sourceType via $provider');
      context.stateEngine.write(provenanceStateId, label);
    }
  }
}
