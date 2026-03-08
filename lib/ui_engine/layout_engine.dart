import 'package:flutter/material.dart';
import '../models/auil_schema_model.dart';
import 'component_registry.dart';

class LayoutEngine {
  static Widget buildLayout(AUILSchema schema) {
    switch (schema.layout) {
      case 'dashboard':
        return DashboardLayout(components: schema.components);
      case 'list':
      default:
        return ListLayout(components: schema.components); 
    }
  }
}

class DashboardLayout extends StatelessWidget {
  final List<AUILComponent> components;
  const DashboardLayout({super.key, required this.components});

  @override
  Widget build(BuildContext context) {
    // A dashboard is often a grid; for simplicity we use a list view here 
    // but in a production app this would use a Wrap or GridView
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: components.length,
      itemBuilder: (context, index) {
        return ComponentRegistry.buildComponent(components[index]);
      },
    );
  }
}

class ListLayout extends StatelessWidget {
  final List<AUILComponent> components;
  const ListLayout({super.key, required this.components});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: components.length,
      itemBuilder: (context, index) {
        return ComponentRegistry.buildComponent(components[index]);
      },
    );
  }
}
