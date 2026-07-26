class WorkspaceModel {
  final String id;
  final String title;
  final String description;
  final String auilJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkspaceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.auilJson,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkspaceModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled',
      description: json['description'] ?? '',
      auilJson: json['auil_json'] ?? '{}',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'auil_json': auilJson,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
