class AUILSchema {
  final String layout;
  final List<AUILComponent> components;

  AUILSchema({required this.layout, required this.components});

  factory AUILSchema.fromJson(Map<String, dynamic> json) {
    var componentList = json['components'] as List? ?? [];
    List<AUILComponent> components = componentList.map((c) => AUILComponent.fromJson(c)).toList();
    
    return AUILSchema(
      layout: json['layout'] ?? 'dashboard',
      components: components,
    );
  }
}

class AUILComponent {
  final String type;
  final dynamic data;
  final String? content;

  AUILComponent({required this.type, this.data, this.content});

  factory AUILComponent.fromJson(Map<String, dynamic> json) {
    return AUILComponent(
      type: json['type'] ?? 'text_block',
      data: json['data'],
      content: json['content']?.toString(),
    );
  }
}
