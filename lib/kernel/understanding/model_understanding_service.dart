/// Model-assisted Intent Understanding service.
///
/// Uses the configured ModelProvider to produce structured understanding.
/// Falls back to heuristic understanding when no provider is available.
library;

import 'dart:convert';

import '../../core/contracts/intent.dart';
import '../../core/contracts/model_provider.dart';
import '../classification/intent_category.dart';
import '../specification/experience_spec.dart';
import 'intent_understanding.dart';

/// Service that produces structured Intent Understanding.
class ModelUnderstandingService {
  final ModelProviderRegistry _providerRegistry;

  ModelUnderstandingService(this._providerRegistry);

  /// Produce a structured understanding of the intent.
  Future<IntentUnderstanding> understand({
    required Intent intent,
    required IntentCategory category,
    required ExistingExperienceResolution existingResolution,
    required List availableCapabilities,
  }) async {
    final provider = _providerRegistry.activeProvider;

    if (provider == null || !provider.isConfigured) {
      // No provider — use heuristic understanding
      return _heuristicUnderstanding(
        intent: intent,
        category: category,
        existingResolution: existingResolution,
      );
    }

    // Try model-assisted understanding
    try {
      return await _modelUnderstanding(
        intent: intent,
        category: category,
        provider: provider,
      );
    } catch (e) {
      // Fall back to heuristic on model failure
      return _heuristicUnderstanding(
        intent: intent,
        category: category,
        existingResolution: existingResolution,
      );
    }
  }

  /// Model-assisted understanding using structured output.
  Future<IntentUnderstanding> _modelUnderstanding({
    required Intent intent,
    required IntentCategory category,
    required ModelProvider provider,
  }) async {
    final prompt = _buildUnderstandingPrompt(intent, category);

    final response = await provider.generate(
      ModelRequest(
        messages: [
          ModelMessage.system(_systemPrompt),
          ModelMessage.user(prompt),
        ],
        temperature: 0.3,
        maxTokens: 1000,
      ),
    );

    return _parseUnderstandingResponse(
      intentId: intent.id,
      responseText: response.text,
      category: category,
    );
  }

  /// Parse structured model output into IntentUnderstanding.
  IntentUnderstanding _parseUnderstandingResponse({
    required String intentId,
    required String responseText,
    required IntentCategory category,
  }) {
    try {
      // Try to extract JSON from the response
      final jsonStr = _extractJson(responseText);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      return IntentUnderstanding(
        intentId: intentId,
        objective: data['objective'] as String? ?? 'Unknown objective',
        category: _parseCategory(data['category'] as String?),
        existingExperience: ExistingExperienceResolution.notChecked(),
        desiredOutcome: data['desiredOutcome'] as String? ?? '',
        constraints: List<String>.from(data['constraints'] ?? []),
        requiredInputs: List<String>.from(data['requiredInputs'] ?? []),
        assumptions: List<String>.from(data['assumptions'] ?? []),
        confidence: (data['confidence'] as num?)?.toDouble() ?? 0.5,
        networkNeed: _parseNetworkNeed(data['networkNeed'] as String?),
        creationNeed: _parseCreationNeed(data['creationNeed'] as String?),
        modificationNeed: _parseModificationNeed(
          data['modificationNeed'] as String?,
        ),
      );
    } catch (e) {
      // If parsing fails, return heuristic understanding
      return _heuristicFromExpression(
        intentId: intentId,
        expression: responseText,
        category: category,
      );
    }
  }

  /// Heuristic understanding without a model.
  IntentUnderstanding _heuristicUnderstanding({
    required Intent intent,
    required IntentCategory category,
    required ExistingExperienceResolution existingResolution,
  }) {
    final expression = intent.expression.toLowerCase();

    // Determine creation need
    CreationNeed creationNeed = CreationNeed.likelyNeeded;
    if (category == IntentCategory.open) {
      creationNeed = CreationNeed.notNeeded;
    }

    // Determine network need
    NetworkNeed networkNeed = NetworkNeed.none;
    if (expression.contains('weather') ||
        expression.contains('news') ||
        expression.contains('stock') ||
        expression.contains('api')) {
      networkNeed = NetworkNeed.required;
    } else if (expression.contains('search') || expression.contains('web')) {
      networkNeed = NetworkNeed.optional;
    }

    // Determine modification need
    ModificationNeed modNeed = ModificationNeed.notNeeded;
    if (category == IntentCategory.modify) {
      modNeed = CreationNeed.likelyNeeded as ModificationNeed;
    }

    return IntentUnderstanding(
      intentId: intent.id,
      objective: intent.expression,
      category: category,
      existingExperience: existingResolution,
      desiredOutcome: intent.expression,
      assumptions: ['Using safe defaults for unspecified requirements'],
      confidence: 0.7,
      networkNeed: networkNeed,
      creationNeed: creationNeed,
      modificationNeed: modNeed,
    );
  }

  IntentUnderstanding _heuristicFromExpression({
    required String intentId,
    required String expression,
    required IntentCategory category,
  }) {
    return IntentUnderstanding(
      intentId: intentId,
      objective: expression,
      category: category,
      existingExperience: ExistingExperienceResolution.notChecked(),
      desiredOutcome: expression,
      confidence: 0.6,
      networkNeed: NetworkNeed.none,
      creationNeed: CreationNeed.likelyNeeded,
      modificationNeed: ModificationNeed.notNeeded,
    );
  }

  String _buildUnderstandingPrompt(Intent intent, IntentCategory category) {
    return '''
Analyze this user intent and return a JSON object with these fields:
{
  "objective": "normalized description of what the user wants",
  "category": "create|open|modify|ask|research|transform|automate",
  "desiredOutcome": "what success looks like",
  "constraints": ["list of constraints"],
  "requiredInputs": ["information needed from user"],
  "assumptions": ["safe assumptions being made"],
  "confidence": 0.0-1.0,
  "networkNeed": "none|optional|required|conditional",
  "creationNeed": "notNeeded|likelyNeeded|definitelyNeeded",
  "modificationNeed": "notNeeded|likelyNeeded|definitelyNeeded"
}

User intent: "${intent.expression}"
Preliminary category: ${category.name}

Return ONLY valid JSON. No markdown.
''';
  }

  String _extractJson(String text) {
    // Try to find JSON in the response
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (jsonMatch != null) {
      return jsonMatch.group(0)!;
    }
    return text;
  }

  IntentCategory _parseCategory(String? value) {
    switch (value) {
      case 'create':
        return IntentCategory.create;
      case 'open':
        return IntentCategory.open;
      case 'modify':
        return IntentCategory.modify;
      case 'ask':
        return IntentCategory.ask;
      case 'research':
        return IntentCategory.research;
      case 'transform':
        return IntentCategory.transform;
      case 'automate':
        return IntentCategory.automate;
      default:
        return IntentCategory.create;
    }
  }

  NetworkNeed _parseNetworkNeed(String? value) {
    switch (value) {
      case 'none':
        return NetworkNeed.none;
      case 'optional':
        return NetworkNeed.optional;
      case 'required':
        return NetworkNeed.required;
      case 'conditional':
        return NetworkNeed.conditional;
      default:
        return NetworkNeed.none;
    }
  }

  CreationNeed _parseCreationNeed(String? value) {
    switch (value) {
      case 'notNeeded':
        return CreationNeed.notNeeded;
      case 'likelyNeeded':
        return CreationNeed.likelyNeeded;
      case 'definitelyNeeded':
        return CreationNeed.definitelyNeeded;
      default:
        return CreationNeed.likelyNeeded;
    }
  }

  ModificationNeed _parseModificationNeed(String? value) {
    switch (value) {
      case 'notNeeded':
        return ModificationNeed.notNeeded;
      case 'likelyNeeded':
        return ModificationNeed.likelyNeeded;
      case 'definitelyNeeded':
        return ModificationNeed.definitelyNeeded;
      default:
        return ModificationNeed.notNeeded;
    }
  }

  static const String _systemPrompt = '''
You are the Intent Understanding engine for Anything, an AI operating environment.

Your job is to analyze user intents and return structured JSON describing:
- What the user wants (objective)
- The category of intent
- Desired outcome
- Constraints
- Required user inputs
- Safe assumptions
- Confidence level
- Network requirements
- Creation/modification needs

Be concise. Return only valid JSON. No markdown code blocks.
''';
}
