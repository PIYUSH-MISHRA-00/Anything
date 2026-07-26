/// App Blueprint — technology-independent semantic description of a synthesized application.
///
/// The Blueprint describes WHAT the requested application fundamentally IS,
/// without specifying HOW it's implemented in Flutter/Dart/SQLite.
///
/// Between Intent Understanding and ExperienceSpec, the Blueprint serves as
/// the structured intermediate representation that synthesis patterns operate on.
library;

import 'app_archetype.dart';

/// Technology-independent semantic description of a synthesized application.
///
/// The Blueprint is the central synthesis artifact. It describes:
/// - What entities the app manages
/// - What fields each entity has
/// - What actions users can perform
/// - What views the app needs
/// - What derived values it computes
/// - What persistence/network/capabilities it requires
class AppBlueprint {
  const AppBlueprint({
    required this.id,
    required this.name,
    required this.description,
    this.archetypes = const [],
    this.domain = AppDomain.custom,
    this.entities = const [],
    this.views = const [],
    this.actions = const [],
    this.derivedValues = const [],
    this.offlinePolicy = OfflinePolicy.full,
    this.requiredCapabilities = const [],
    this.networkConfig,
  });

  final String id;
  final String name;
  final String description;
  final List<AppArchetype> archetypes;
  final AppDomain domain;
  final List<BlueprintEntity> entities;
  final List<BlueprintView> views;
  final List<BlueprintAction> actions;
  final List<BlueprintDerivedValue> derivedValues;
  final OfflinePolicy offlinePolicy;
  final List<String> requiredCapabilities;
  final BlueprintNetworkConfig? networkConfig;

  AppBlueprint copyWith({
    String? id,
    String? name,
    String? description,
    List<AppArchetype>? archetypes,
    AppDomain? domain,
    List<BlueprintEntity>? entities,
    List<BlueprintView>? views,
    List<BlueprintAction>? actions,
    List<BlueprintDerivedValue>? derivedValues,
    OfflinePolicy? offlinePolicy,
    List<String>? requiredCapabilities,
    BlueprintNetworkConfig? networkConfig,
  }) {
    return AppBlueprint(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      archetypes: archetypes ?? this.archetypes,
      domain: domain ?? this.domain,
      entities: entities ?? this.entities,
      views: views ?? this.views,
      actions: actions ?? this.actions,
      derivedValues: derivedValues ?? this.derivedValues,
      offlinePolicy: offlinePolicy ?? this.offlinePolicy,
      requiredCapabilities: requiredCapabilities ?? this.requiredCapabilities,
      networkConfig: networkConfig ?? this.networkConfig,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'archetypes': archetypes.map((a) => a.name).toList(),
    'domain': domain.name,
    'entities': entities.map((e) => e.toJson()).toList(),
    'views': views.map((v) => v.toJson()).toList(),
    'actions': actions.map((a) => a.toJson()).toList(),
    'derivedValues': derivedValues.map((d) => d.toJson()).toList(),
    'offlinePolicy': offlinePolicy.name,
    'requiredCapabilities': requiredCapabilities,
    'networkConfig': networkConfig?.toJson(),
  };

  factory AppBlueprint.fromJson(Map<String, dynamic> json) {
    return AppBlueprint(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      archetypes: (json['archetypes'] as List)
          .map((a) => AppArchetype.values.firstWhere((e) => e.name == a))
          .toList(),
      domain: AppDomain.values.firstWhere((e) => e.name == json['domain']),
      entities: (json['entities'] as List)
          .map((e) => BlueprintEntity.fromJson(e as Map<String, dynamic>))
          .toList(),
      views: (json['views'] as List)
          .map((v) => BlueprintView.fromJson(v as Map<String, dynamic>))
          .toList(),
      actions: (json['actions'] as List)
          .map((a) => BlueprintAction.fromJson(a as Map<String, dynamic>))
          .toList(),
      derivedValues: (json['derivedValues'] as List)
          .map((d) => BlueprintDerivedValue.fromJson(d as Map<String, dynamic>))
          .toList(),
      offlinePolicy: OfflinePolicy.values.firstWhere(
        (e) => e.name == json['offlinePolicy'],
      ),
      requiredCapabilities: (json['requiredCapabilities'] as List)
          .cast<String>(),
      networkConfig: json['networkConfig'] != null
          ? BlueprintNetworkConfig.fromJson(
              json['networkConfig'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// A semantic entity in the blueprint (e.g. "Expense", "Habit", "Note").
class BlueprintEntity {
  const BlueprintEntity({
    required this.id,
    required this.name,
    this.description = '',
    this.fields = const [],
    this.displayField = '',
  });

  final String id;
  final String name;
  final String description;
  final List<BlueprintField> fields;
  final String displayField;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'fields': fields.map((f) => f.toJson()).toList(),
    'displayField': displayField,
  };

  factory BlueprintEntity.fromJson(Map<String, dynamic> json) {
    return BlueprintEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      fields: (json['fields'] as List)
          .map((f) => BlueprintField.fromJson(f as Map<String, dynamic>))
          .toList(),
      displayField: json['displayField'] as String? ?? '',
    );
  }
}

/// Supported semantic field types for blueprint entities.
enum BlueprintFieldType {
  text,
  multilineText,
  integer,
  decimal,
  boolean,
  date,
  dateTime,
  time,
  category,
  url,
  reference,
  derived,
}

/// A field within a blueprint entity.
class BlueprintField {
  const BlueprintField({
    required this.id,
    required this.name,
    required this.type,
    this.required = false,
    this.defaultValue,
    this.minimum,
    this.maximum,
    this.maxLength,
    this.allowedValues = const [],
    this.description = '',
    this.referenceEntityId,
  });

  final String id;
  final String name;
  final BlueprintFieldType type;
  final bool required;
  final String? defaultValue;
  final num? minimum;
  final num? maximum;
  final int? maxLength;
  final List<String> allowedValues;
  final String description;
  final String? referenceEntityId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'required': required,
    if (defaultValue != null) 'defaultValue': defaultValue,
    if (minimum != null) 'minimum': minimum,
    if (maximum != null) 'maximum': maximum,
    if (maxLength != null) 'maxLength': maxLength,
    if (allowedValues.isNotEmpty) 'allowedValues': allowedValues,
    'description': description,
    if (referenceEntityId != null) 'referenceEntityId': referenceEntityId,
  };

  factory BlueprintField.fromJson(Map<String, dynamic> json) {
    return BlueprintField(
      id: json['id'] as String,
      name: json['name'] as String,
      type: BlueprintFieldType.values.firstWhere((e) => e.name == json['type']),
      required: json['required'] as bool? ?? false,
      defaultValue: json['defaultValue'] as String?,
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      maxLength: json['maxLength'] as int?,
      allowedValues: (json['allowedValues'] as List?)?.cast<String>() ?? [],
      description: json['description'] as String? ?? '',
      referenceEntityId: json['referenceEntityId'] as String?,
    );
  }
}

/// A semantic view in the blueprint (e.g. "Overview", "Add Expense").
class BlueprintView {
  const BlueprintView({
    required this.id,
    required this.name,
    required this.purpose,
    this.entityId,
    this.viewType = BlueprintViewType.list,
    this.sourceEntityId,
    this.primaryActionId,
    this.sections = const [],
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String purpose;
  final String? entityId;
  final BlueprintViewType viewType;
  final String? sourceEntityId;
  final String? primaryActionId;
  final List<BlueprintViewSection> sections;
  final bool isDefault;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'purpose': purpose,
    if (entityId != null) 'entityId': entityId,
    'viewType': viewType.name,
    if (sourceEntityId != null) 'sourceEntityId': sourceEntityId,
    if (primaryActionId != null) 'primaryActionId': primaryActionId,
    'sections': sections.map((s) => s.toJson()).toList(),
    'isDefault': isDefault,
  };

  factory BlueprintView.fromJson(Map<String, dynamic> json) {
    return BlueprintView(
      id: json['id'] as String,
      name: json['name'] as String,
      purpose: json['purpose'] as String? ?? '',
      entityId: json['entityId'] as String?,
      viewType: BlueprintViewType.values.firstWhere(
        (e) => e.name == json['viewType'],
      ),
      sourceEntityId: json['sourceEntityId'] as String?,
      primaryActionId: json['primaryActionId'] as String?,
      sections:
          (json['sections'] as List?)
              ?.map(
                (s) => BlueprintViewSection.fromJson(s as Map<String, dynamic>),
              )
              .toList() ??
          [],
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

/// View type classification.
enum BlueprintViewType {
  list,
  detail,
  form,
  dashboard,
  calendar,
  settings,
  empty,
  summary,
}

/// A content section within a view.
class BlueprintViewSection {
  const BlueprintViewSection({
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'purpose': purpose,
    if (sourceEntityId != null) 'sourceEntityId': sourceEntityId,
    if (filter != null) 'filter': filter,
    if (limit != null) 'limit': limit,
    'sectionType': sectionType.name,
  };

  factory BlueprintViewSection.fromJson(Map<String, dynamic> json) {
    return BlueprintViewSection(
      id: json['id'] as String,
      purpose: json['purpose'] as String? ?? '',
      sourceEntityId: json['sourceEntityId'] as String?,
      filter: json['filter'] as String?,
      limit: json['limit'] as int?,
      sectionType: BlueprintSectionType.values.firstWhere(
        (e) => e.name == json['sectionType'],
      ),
    );
  }
}

/// Section type classification.
enum BlueprintSectionType { list, summary, form, detail, chart }

/// A semantic action in the blueprint (e.g. "add expense", "toggle habit").
class BlueprintAction {
  const BlueprintAction({
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'targetEntityId': targetEntityId,
    'actionType': actionType.name,
    'fields': fields,
    if (derivedEffect != null) 'derivedEffect': derivedEffect,
  };

  factory BlueprintAction.fromJson(Map<String, dynamic> json) {
    return BlueprintAction(
      id: json['id'] as String,
      name: json['name'] as String,
      targetEntityId: json['targetEntityId'] as String,
      actionType: BlueprintActionType.values.firstWhere(
        (e) => e.name == json['actionType'],
      ),
      fields: (json['fields'] as List?)?.cast<String>() ?? [],
      derivedEffect: json['derivedEffect'] as String?,
    );
  }
}

/// Action type classification.
enum BlueprintActionType {
  create,
  update,
  delete,
  toggle,
  increment,
  decrement,
  setValue,
  clearValue,
  changeStatus,
  navigate,
}

/// A derived/computed value in the blueprint (e.g. "total expenses", "streak").
class BlueprintDerivedValue {
  const BlueprintDerivedValue({
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sourceEntityId': sourceEntityId,
    'operation': operation.name,
    if (fieldId != null) 'fieldId': fieldId,
    'description': description,
  };

  factory BlueprintDerivedValue.fromJson(Map<String, dynamic> json) {
    return BlueprintDerivedValue(
      id: json['id'] as String,
      name: json['name'] as String,
      sourceEntityId: json['sourceEntityId'] as String,
      operation: DerivedOperation.values.firstWhere(
        (e) => e.name == json['operation'],
      ),
      fieldId: json['fieldId'] as String?,
      description: json['description'] as String? ?? '',
    );
  }
}

/// Supported derived value operations.
enum DerivedOperation {
  count,
  sum,
  average,
  minimum,
  maximum,
  consecutiveDateCount,
  percentage,
  daysRemaining,
  difference,
}

/// Network configuration for apps that require external data.
class BlueprintNetworkConfig {
  const BlueprintNetworkConfig({
    required this.purpose,
    this.allowedHosts = const [],
    this.refreshInterval,
    this.cacheStrategy = BlueprintCacheStrategy.cacheFirst,
  });

  final String purpose;
  final List<String> allowedHosts;
  final Duration? refreshInterval;
  final BlueprintCacheStrategy cacheStrategy;

  Map<String, dynamic> toJson() => {
    'purpose': purpose,
    'allowedHosts': allowedHosts,
    if (refreshInterval != null)
      'refreshInterval': refreshInterval!.inMilliseconds,
    'cacheStrategy': cacheStrategy.name,
  };

  factory BlueprintNetworkConfig.fromJson(Map<String, dynamic> json) {
    return BlueprintNetworkConfig(
      purpose: json['purpose'] as String,
      allowedHosts: (json['allowedHosts'] as List?)?.cast<String>() ?? [],
      refreshInterval: json['refreshInterval'] != null
          ? Duration(milliseconds: json['refreshInterval'] as int)
          : null,
      cacheStrategy: BlueprintCacheStrategy.values.firstWhere(
        (e) => e.name == json['cacheStrategy'],
      ),
    );
  }
}

/// Cache strategy for network-backed apps.
enum BlueprintCacheStrategy { cacheFirst, networkFirst, cacheOnly }
