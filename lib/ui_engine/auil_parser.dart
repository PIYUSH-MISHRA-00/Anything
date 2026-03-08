import 'dart:convert';
import '../models/auil_schema_model.dart';

class AUILParser {
  static AUILSchema parse(String jsonString) {
    try {
      // Find JSON block if AI added markdown wrappers natively
      final startIndex = jsonString.indexOf('{');
      final endIndex = jsonString.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1) {
        final cleanJson = jsonString.substring(startIndex, endIndex + 1);
        final Map<String, dynamic> decoded = jsonDecode(cleanJson);
        return AUILSchema.fromJson(decoded);
      }
      throw FormatException('No JSON found in string');
    } catch (e) {
      // Fallback schema on error
      return AUILSchema(
        layout: 'dashboard',
        components: [
          AUILComponent(type: 'text_block', content: 'Failed to parse AI response: $e')
        ]
      );
    }
  }
}
