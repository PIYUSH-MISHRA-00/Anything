class IntentModel {
  final String action;
  final String category;
  final List<String> toolsNeeded;
  final double confidence;
  final String? entitySubject;

  IntentModel({
    required this.action,
    required this.category,
    required this.toolsNeeded,
    required this.confidence,
    this.entitySubject,
  });

  factory IntentModel.fromJson(Map<String, dynamic> json) {
    return IntentModel(
      action: json['action'] ?? 'unknown',
      category: json['category'] ?? 'general',
      toolsNeeded: List<String>.from(json['tools_needed'] ?? []),
      confidence: (json['confidence'] ?? 0.5).toDouble(),
      entitySubject: json['entity_subject'],
    );
  }

  Map<String, dynamic> toJson() => {
    'action': action,
    'category': category,
    'tools_needed': toolsNeeded,
    'confidence': confidence,
    'entity_subject': entitySubject,
  };

  bool get requiresTools => toolsNeeded.isNotEmpty;
  bool get isHighConfidence => confidence > 0.7;
}
