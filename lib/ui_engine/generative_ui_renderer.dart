import 'package:flutter/material.dart';

import 'layout_engine.dart';
import 'auil_parser.dart';

class GenerativeUIRenderer extends StatelessWidget {
  final String rawAuilJson;

  const GenerativeUIRenderer({super.key, required this.rawAuilJson});

  @override
  Widget build(BuildContext context) {
    try {
      final schema = AUILParser.parse(rawAuilJson);
      return LayoutEngine.buildLayout(schema);
    } catch (e) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Failed to render Generative UI: $e',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }
  }
}
