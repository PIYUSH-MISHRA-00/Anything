/// Model Application Reasoner — uses ModelProvider for structured application reasoning.
///
/// The LLM receives the user's normalized objective, relevant context,
/// available trusted capabilities, and a supported semantic vocabulary.
/// It returns structured JSON matching a strict schema.
///
/// It does NOT return Dart, Flutter code, JavaScript, SQL, or shell commands.
library;

import 'dart:convert';

import '../core/contracts/model_provider.dart';
import '../kernel/understanding/intent_understanding.dart';
import '../kernel/specification/experience_spec.dart' show NetworkNeed;
import 'app_blueprint.dart';
import 'application_reasoner.dart';

/// Model-backed application reasoner.
///
/// Uses a configured ModelProvider to reason about complex or novel
/// application requests that cannot be handled deterministically.
class ModelApplicationReasoner implements ApplicationReasoner {
  final ModelProvider _provider;

  const ModelApplicationReasoner(this._provider);

  @override
  Future<AppReasoningResult> reason(IntentUnderstanding understanding) async {
    final prompt = _buildPrompt(understanding);

    try {
      final response = await _provider.generate(
        ModelRequest(
          messages: [
            ModelMessage.system(_systemPrompt),
            ModelMessage.user(prompt),
          ],
          maxTokens: 2000,
          temperature: 0.3,
        ),
      );

      return _parseResponse(response.text);
    } catch (e) {
      return ReasoningFailed(error: 'Model reasoning failed: $e');
    }
  }

  String _buildPrompt(IntentUnderstanding understanding) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Analyze the following user intent and describe the application to build.',
    );
    buffer.writeln();
    buffer.writeln('User objective: "${understanding.objective}"');
    if (understanding.desiredOutcome.isNotEmpty) {
      buffer.writeln('Desired outcome: "${understanding.desiredOutcome}"');
    }
    if (understanding.networkNeed != NetworkNeed.none) {
      buffer.writeln('Network need: ${understanding.networkNeed.name}');
    }
    buffer.writeln();
    buffer.writeln('Return a JSON object with this exact structure:');
    buffer.writeln(_jsonSchema);
    return buffer.toString();
  }

  AppReasoningResult _parseResponse(String responseText) {
    try {
      // Extract JSON from the response
      final json = _extractJson(responseText);
      if (json == null) {
        return const ReasoningFailed(
          error: 'Could not parse model response as JSON',
        );
      }

      return ReasoningReady(semanticApp: _parseSemanticApp(json));
    } catch (e) {
      return ReasoningFailed(error: 'Failed to parse model output: $e');
    }
  }

  Map<String, dynamic>? _extractJson(String text) {
    // Try to find JSON in the response
    final jsonPattern = RegExp(r'\{[\s\S]*\}', dotAll: true);
    final match = jsonPattern.firstMatch(text);
    if (match == null) return null;

    try {
      return jsonDecode(match.group(0)!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  SemanticApp _parseSemanticApp(Map<String, dynamic> json) {
    final entities = (json['entities'] as List? ?? []).map((e) {
      final entity = e as Map<String, dynamic>;
      final fields = (entity['fields'] as List? ?? []).map((f) {
        final field = f as Map<String, dynamic>;
        return SemanticField(
          id: _normalizeId(field['id'] as String? ?? field['name'] as String),
          name: field['name'] as String,
          type: _parseFieldType(field['type'] as String? ?? 'text'),
          required: field['required'] as bool? ?? false,
          defaultValue: field['defaultValue'] as String?,
          minimum: field['minimum'] as num?,
          maximum: field['maximum'] as num?,
          allowedValues:
              (field['allowedValues'] as List?)?.cast<String>() ?? [],
          referenceEntityId: field['referenceEntityId'] as String?,
          description: field['description'] as String? ?? '',
        );
      }).toList();

      return SemanticEntity(
        id: _normalizeId(entity['id'] as String? ?? entity['name'] as String),
        name: entity['name'] as String,
        description: entity['description'] as String? ?? '',
        fields: fields,
        displayField: entity['displayField'] as String? ?? '',
      );
    }).toList();

    final actions = (json['actions'] as List? ?? []).map((a) {
      final action = a as Map<String, dynamic>;
      return SemanticAction(
        id: _normalizeId(action['id'] as String? ?? action['name'] as String),
        name: action['name'] as String,
        targetEntityId: _normalizeId(action['targetEntity'] as String),
        actionType: _parseActionType(action['type'] as String? ?? 'create'),
        derivedEffect: action['derivedEffect'] as String?,
      );
    }).toList();

    final derivedValues = (json['derivedValues'] as List? ?? []).map((d) {
      final dv = d as Map<String, dynamic>;
      return SemanticDerivedValue(
        id: _normalizeId(dv['id'] as String? ?? dv['name'] as String),
        name: dv['name'] as String,
        sourceEntityId: _normalizeId(dv['sourceEntity'] as String),
        operation: _parseOperation(dv['operation'] as String? ?? 'count'),
        fieldId: dv['fieldId'] as String?,
        description: dv['description'] as String? ?? '',
      );
    }).toList();

    final views = (json['views'] as List? ?? []).map((v) {
      final view = v as Map<String, dynamic>;
      final sections = (view['sections'] as List? ?? []).map((s) {
        final section = s as Map<String, dynamic>;
        return SemanticViewSection(
          id: _normalizeId(
            section['id'] as String? ?? section['purpose'] as String,
          ),
          purpose: section['purpose'] as String,
          sourceEntityId: section['sourceEntity'] != null
              ? _normalizeId(section['sourceEntity'] as String)
              : null,
          sectionType: _parseSectionType(section['type'] as String? ?? 'list'),
        );
      }).toList();

      return SemanticView(
        id: _normalizeId(view['id'] as String? ?? view['name'] as String),
        name: view['name'] as String,
        purpose: view['purpose'] as String,
        sourceEntityId: view['sourceEntity'] != null
            ? _normalizeId(view['sourceEntity'] as String)
            : null,
        viewType: _parseViewType(view['type'] as String? ?? 'list'),
        sections: sections,
        isDefault: view['isDefault'] as bool? ?? false,
      );
    }).toList();

    return SemanticApp(
      name: json['name'] as String,
      purpose: json['purpose'] as String,
      entities: entities,
      actions: actions,
      derivedValues: derivedValues,
      views: views,
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      archetypes: (json['archetypes'] as List?)?.cast<String>() ?? [],
      requiredCapabilities:
          (json['requiredCapabilities'] as List?)?.cast<String>() ?? [],
      knowledgeNeeds: (json['knowledgeNeeds'] as List? ?? []).map((k) {
        final kr = k as Map<String, dynamic>;
        return SynthesisKnowledgeRequirement(
          objective: kr['objective'] as String,
          resourceType: kr['resourceType'] as String,
          queryHints: (kr['queryHints'] as List?)?.cast<String>() ?? [],
        );
      }).toList(),
    );
  }

  String _normalizeId(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  BlueprintFieldType _parseFieldType(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return BlueprintFieldType.text;
      case 'multiline':
      case 'multilineText':
        return BlueprintFieldType.multilineText;
      case 'integer':
      case 'int':
      case 'number':
        return BlueprintFieldType.integer;
      case 'decimal':
      case 'double':
      case 'float':
        return BlueprintFieldType.decimal;
      case 'boolean':
      case 'bool':
        return BlueprintFieldType.boolean;
      case 'date':
        return BlueprintFieldType.date;
      case 'datetime':
        return BlueprintFieldType.dateTime;
      case 'time':
        return BlueprintFieldType.time;
      case 'category':
      case 'enum':
        return BlueprintFieldType.category;
      case 'url':
        return BlueprintFieldType.url;
      case 'reference':
        return BlueprintFieldType.reference;
      default:
        return BlueprintFieldType.text;
    }
  }

  BlueprintActionType _parseActionType(String type) {
    switch (type.toLowerCase()) {
      case 'create':
        return BlueprintActionType.create;
      case 'update':
        return BlueprintActionType.update;
      case 'delete':
        return BlueprintActionType.delete;
      case 'toggle':
        return BlueprintActionType.toggle;
      case 'increment':
        return BlueprintActionType.increment;
      case 'decrement':
        return BlueprintActionType.decrement;
      case 'setvalue':
      case 'set_value':
        return BlueprintActionType.setValue;
      case 'clearvalue':
      case 'clear_value':
        return BlueprintActionType.clearValue;
      case 'changestatus':
      case 'change_status':
        return BlueprintActionType.changeStatus;
      default:
        return BlueprintActionType.create;
    }
  }

  DerivedOperation _parseOperation(String op) {
    switch (op.toLowerCase()) {
      case 'count':
        return DerivedOperation.count;
      case 'sum':
        return DerivedOperation.sum;
      case 'average':
      case 'avg':
        return DerivedOperation.average;
      case 'min':
      case 'minimum':
        return DerivedOperation.minimum;
      case 'max':
      case 'maximum':
        return DerivedOperation.maximum;
      case 'streak':
      case 'consecutivedatecount':
      case 'consecutive_date_count':
        return DerivedOperation.consecutiveDateCount;
      case 'percentage':
        return DerivedOperation.percentage;
      case 'daysremaining':
      case 'days_remaining':
        return DerivedOperation.daysRemaining;
      case 'difference':
      case 'diff':
        return DerivedOperation.difference;
      default:
        return DerivedOperation.count;
    }
  }

  BlueprintViewType _parseViewType(String type) {
    switch (type.toLowerCase()) {
      case 'list':
        return BlueprintViewType.list;
      case 'detail':
        return BlueprintViewType.detail;
      case 'form':
        return BlueprintViewType.form;
      case 'dashboard':
        return BlueprintViewType.dashboard;
      case 'calendar':
        return BlueprintViewType.calendar;
      case 'settings':
        return BlueprintViewType.settings;
      case 'summary':
        return BlueprintViewType.summary;
      default:
        return BlueprintViewType.list;
    }
  }

  BlueprintSectionType _parseSectionType(String type) {
    switch (type.toLowerCase()) {
      case 'list':
        return BlueprintSectionType.list;
      case 'summary':
        return BlueprintSectionType.summary;
      case 'form':
        return BlueprintSectionType.form;
      case 'detail':
        return BlueprintSectionType.detail;
      case 'chart':
        return BlueprintSectionType.chart;
      default:
        return BlueprintSectionType.list;
    }
  }

  static const String _systemPrompt = '''You are an application architect.
You analyze user intent and describe what application should be built.
You return structured JSON describing entities, fields, actions, views, and computed values.
You NEVER return code (Dart, Flutter, JavaScript, SQL, shell commands).
You describe WHAT the application IS, not HOW it is implemented.
You use generic semantic descriptions. Domain knowledge belongs in your response, not in source code.
All IDs must be lowercase_snake_case.
Field types: text, multilineText, integer, decimal, boolean, date, dateTime, time, category, url, reference.
Action types: create, update, delete, toggle, increment, decrement, setValue, clearValue, changeStatus.
Operations: count, sum, average, minimum, maximum, consecutiveDateCount, percentage, daysRemaining, difference.
View types: list, detail, form, dashboard, calendar, settings, summary.
Section types: list, summary, form, detail, chart.''';

  static const String _jsonSchema = '''{
  "name": "App Name",
  "purpose": "What this app does",
  "entities": [
    {
      "name": "EntityName",
      "description": "What this entity represents",
      "fields": [
        {
          "name": "fieldName",
          "type": "text",
          "required": true,
          "description": "What this field stores"
        }
      ]
    }
  ],
  "actions": [
    {
      "name": "actionName",
      "type": "create",
      "targetEntity": "entityName"
    }
  ],
  "derivedValues": [
    {
      "name": "valueName",
      "sourceEntity": "entityName",
      "operation": "count",
      "fieldId": "fieldName"
    }
  ],
  "views": [
    {
      "name": "viewName",
      "purpose": "What this view shows",
      "type": "list",
      "sourceEntity": "entityName",
      "sections": [
        {
          "purpose": "section purpose",
          "sourceEntity": "entityName",
          "type": "list"
        }
      ],
      "isDefault": true
    }
  ],
  "tags": ["tag1", "tag2"],
  "archetypes": ["collection"],
  "requiredCapabilities": [],
  "knowledgeNeeds": []
}''';
}
