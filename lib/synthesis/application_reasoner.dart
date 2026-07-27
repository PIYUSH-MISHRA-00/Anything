/// Application Reasoner — structured reasoning about what application to build.
///
/// The reasoner takes user intent understanding and produces structured
/// semantic information sufficient to construct an AppBlueprint.
///
/// This is the intelligence layer between understanding and synthesis.
library;

import '../kernel/understanding/intent_understanding.dart';
import '../knowledge/knowledge_bundle.dart';
import 'app_blueprint.dart';

/// Result of application reasoning.
sealed class AppReasoningResult {
  const AppReasoningResult();
}

/// Reasoning succeeded — semantic information is complete.
class ReasoningReady extends AppReasoningResult {
  const ReasoningReady({required this.semanticApp});

  /// The semantic application description sufficient to build a blueprint.
  final SemanticApp semanticApp;
}

/// Reasoning needs clarification from the user.
class ReasoningClarificationRequired extends AppReasoningResult {
  const ReasoningClarificationRequired({required this.question});

  final String question;
}

/// Reasoning needs a model provider (not configured).
class ReasoningProviderRequired extends AppReasoningResult {
  const ReasoningProviderRequired();
}

/// Reasoning needs external knowledge to proceed.
class ReasoningKnowledgeRequired extends AppReasoningResult {
  const ReasoningKnowledgeRequired({required this.requirements});

  final List<SynthesisKnowledgeRequirement> requirements;
}

/// Reasoning determined the intent is unsupported or the domain is unclear
/// even after knowledge acquisition.
class ReasoningUnsupported extends AppReasoningResult {
  const ReasoningUnsupported({required this.reason});

  final String reason;
}

/// Reasoning failed.
class ReasoningFailed extends AppReasoningResult {
  const ReasoningFailed({required this.error});

  final String error;
}

/// Knowledge requirement from the reasoning layer.
class SynthesisKnowledgeRequirement {
  const SynthesisKnowledgeRequirement({
    required this.id,
    required this.purpose,
    required this.query,
    required this.required,
    this.resourceType = 'domainKnowledge',
    this.queryHints = const [],
  });

  /// Stable identifier for this requirement.
  final String id;

  /// Why this knowledge is needed.
  final String purpose;

  /// The query or intention for knowledge retrieval.
  final String query;

  /// Whether this knowledge is required (cannot proceed without) or optional.
  final bool required;

  /// Category hint: externalApi, protocol, dataFormat, algorithm,
  /// integrationDocumentation, domainKnowledge, technicalReference.
  final String resourceType;

  /// Additional query hints.
  final List<String> queryHints;
}

/// Context for application reasoning — carries structured information
/// the reasoner needs beyond the raw intent understanding.
class ApplicationReasoningContext {
  const ApplicationReasoningContext({
    required this.understanding,
    this.knowledge,
    this.availableCapabilities = const [],
    this.round = 0,
    this.maxRounds = 2,
  });

  /// The intent understanding from classification.
  final IntentUnderstanding understanding;

  /// Acquired knowledge bundle, if any.
  final KnowledgeBundle? knowledge;

  /// Capability IDs available to the application.
  final List<String> availableCapabilities;

  /// Current refinement round (0-based).
  final int round;

  /// Maximum allowed refinement rounds.
  final int maxRounds;
}

/// Semantic application description — the output of application reasoning.
///
/// Contains sufficient information to construct an AppBlueprint.
/// Domain knowledge comes from here, not from hardcoded templates.
class SemanticApp {
  const SemanticApp({
    required this.name,
    required this.purpose,
    required this.entities,
    this.actions = const [],
    this.derivedValues = const [],
    this.views = const [],
    this.tags = const [],
    this.archetypes = const [],
    this.requiredCapabilities = const [],
    this.networkConfig,
    this.knowledgeNeeds = const [],
  });

  final String name;
  final String purpose;
  final List<SemanticEntity> entities;
  final List<SemanticAction> actions;
  final List<SemanticDerivedValue> derivedValues;
  final List<SemanticView> views;
  final List<String> tags;
  final List<String> archetypes;
  final List<String> requiredCapabilities;
  final BlueprintNetworkConfig? networkConfig;
  final List<SynthesisKnowledgeRequirement> knowledgeNeeds;
}

/// A semantic entity in the application.
class SemanticEntity {
  const SemanticEntity({
    required this.id,
    required this.name,
    this.description = '',
    this.fields = const [],
    this.displayField = '',
  });

  final String id;
  final String name;
  final String description;
  final List<SemanticField> fields;
  final String displayField;
}

/// A semantic field within an entity.
class SemanticField {
  const SemanticField({
    required this.id,
    required this.name,
    required this.type,
    this.required = false,
    this.defaultValue,
    this.minimum,
    this.maximum,
    this.allowedValues = const [],
    this.referenceEntityId,
    this.description = '',
  });

  final String id;
  final String name;
  final BlueprintFieldType type;
  final bool required;
  final String? defaultValue;
  final num? minimum;
  final num? maximum;
  final List<String> allowedValues;
  final String? referenceEntityId;
  final String description;
}

/// A semantic action in the application.
class SemanticAction {
  const SemanticAction({
    required this.id,
    required this.name,
    required this.targetEntityId,
    this.actionType = BlueprintActionType.create,
    this.fields = const [],
    this.derivedEffect,
  });

  final String id;
  final String name;
  final String targetEntityId;
  final BlueprintActionType actionType;
  final List<String> fields;
  final String? derivedEffect;
}

/// A semantic derived value.
class SemanticDerivedValue {
  const SemanticDerivedValue({
    required this.id,
    required this.name,
    required this.sourceEntityId,
    required this.operation,
    this.fieldId,
    this.description = '',
  });

  final String id;
  final String name;
  final String sourceEntityId;
  final DerivedOperation operation;
  final String? fieldId;
  final String description;
}

/// A semantic view description.
class SemanticView {
  const SemanticView({
    required this.id,
    required this.name,
    required this.purpose,
    this.sourceEntityId,
    this.viewType = BlueprintViewType.list,
    this.sections = const [],
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String purpose;
  final String? sourceEntityId;
  final BlueprintViewType viewType;
  final List<SemanticViewSection> sections;
  final bool isDefault;
}

/// A semantic section within a view.
class SemanticViewSection {
  const SemanticViewSection({
    required this.id,
    required this.purpose,
    this.sourceEntityId,
    this.filter,
    this.limit,
    this.sectionType = BlueprintSectionType.list,
  });

  final String id;
  final String purpose;
  final String? sourceEntityId;
  final String? filter;
  final int? limit;
  final BlueprintSectionType sectionType;
}

/// Application reasoning contract.
///
/// Implementations analyze user intent and produce structured semantic
/// information sufficient to construct an AppBlueprint.
abstract class ApplicationReasoner {
  /// Reason about what application the user wants.
  ///
  /// Returns a typed result indicating success, clarification needed,
  /// provider needed, knowledge needed, unsupported, or failure.
  Future<AppReasoningResult> reason(ApplicationReasoningContext context);
}
