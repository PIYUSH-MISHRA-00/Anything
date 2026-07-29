/// Experience Form Controller — generic form state management.
///
/// Handles initial values, dirty state, validation, submit, cancel.
/// No domain-specific logic.
library;

import 'dart:async';

/// Validation result for a single field.
class FieldValidation {
  final String fieldId;
  final bool isValid;
  final String? error;

  const FieldValidation({
    required this.fieldId,
    required this.isValid,
    this.error,
  });
}

/// Form mode.
enum FormMode { create, edit }

/// A generic form controller for Experience forms.
class ExperienceFormController {
  final String entityId;
  final FormMode mode;
  final Map<String, dynamic> _initialValues;
  final Map<String, dynamic> _currentValues;
  final Map<String, String> _fieldErrors;
  final List<FormFieldDefinition> _fieldDefinitions;

  /// Stream that emits when form state changes.
  final StreamController<FormState> _stateController =
      StreamController<FormState>.broadcast();
  Stream<FormState> get stateStream => _stateController.stream;

  ExperienceFormController({
    required this.entityId,
    this.mode = FormMode.create,
    Map<String, dynamic>? initialValues,
    List<FormFieldDefinition>? fieldDefinitions,
  }) : _initialValues = Map<String, dynamic>.from(initialValues ?? {}),
       _currentValues = Map<String, dynamic>.from(initialValues ?? {}),
       _fieldErrors = {},
       _fieldDefinitions = fieldDefinitions ?? [] {
    _validateSilent();
  }

  /// Get current field value.
  dynamic getValue(String fieldId) => _currentValues[fieldId];

  /// Set a field value.
  void setValue(String fieldId, dynamic value) {
    _currentValues[fieldId] = value;
    _fieldErrors.remove(fieldId);
    _notifyChanged();
  }

  /// Get all current values.
  Map<String, dynamic> get values => Map<String, dynamic>.from(_currentValues);

  /// Check if form has been modified.
  bool get isDirty {
    for (final key in _currentValues.keys) {
      if (_currentValues[key] != _initialValues[key]) return true;
    }
    for (final key in _initialValues.keys) {
      if (!_currentValues.containsKey(key)) return true;
    }
    return false;
  }

  /// Validate without notifying listeners (for initial setup).
  void _validateSilent() {
    _fieldErrors.clear();
    for (final field in _fieldDefinitions) {
      final value = _currentValues[field.id];
      final error = _validateField(field, value);
      if (error != null) {
        _fieldErrors[field.id] = error;
      }
    }
  }

  /// Get field error message.
  String? getFieldError(String fieldId) => _fieldErrors[fieldId];

  /// Check if a specific field is valid.
  bool isFieldValid(String fieldId) => !_fieldErrors.containsKey(fieldId);

  /// Check if entire form is valid.
  bool get isValid => _fieldErrors.isEmpty;

  /// Validate all fields. Returns true if valid.
  bool validate() {
    _fieldErrors.clear();
    bool valid = true;

    for (final field in _fieldDefinitions) {
      final value = _currentValues[field.id];
      final error = _validateField(field, value);
      if (error != null) {
        _fieldErrors[field.id] = error;
        valid = false;
      }
    }

    _notifyChanged();
    return valid;
  }

  /// Validate a single field.
  String? _validateField(FormFieldDefinition field, dynamic value) {
    if (field.required && (value == null || value.toString().isEmpty)) {
      return '${field.name} is required';
    }

    if (value == null) return null;

    if (value is String) {
      if (field.minLength != null && value.length < field.minLength!) {
        return '${field.name} must be at least ${field.minLength} characters';
      }
      if (field.maxLength != null && value.length > field.maxLength!) {
        return '${field.name} must be at most ${field.maxLength} characters';
      }
    }

    if (value is num) {
      if (field.minimum != null && value < field.minimum!) {
        return '${field.name} must be at least ${field.minimum}';
      }
      if (field.maximum != null && value > field.maximum!) {
        return '${field.name} must be at most ${field.maximum}';
      }
    }

    if (field.allowedValues != null && field.allowedValues!.isNotEmpty) {
      if (!field.allowedValues!.contains(value.toString())) {
        return '${field.name} must be one of: ${field.allowedValues!.join(", ")}';
      }
    }

    return null;
  }

  /// Reset form to initial values.
  void reset() {
    _currentValues.clear();
    _currentValues.addAll(_initialValues);
    _fieldErrors.clear();
    _notifyChanged();
  }

  /// Clear all values.
  void clear() {
    _currentValues.clear();
    _fieldErrors.clear();
    _notifyChanged();
  }

  /// Set multiple values at once.
  void setValues(Map<String, dynamic> values) {
    _currentValues.addAll(values);
    _notifyChanged();
  }

  void _notifyChanged() {
    if (!_stateController.isClosed) {
      _stateController.add(
        FormState(
          isDirty: isDirty,
          isValid: isValid,
          values: Map<String, dynamic>.from(_currentValues),
          errors: Map<String, String>.from(_fieldErrors),
        ),
      );
    }
  }

  /// Dispose resources.
  void dispose() {
    _stateController.close();
  }
}

/// Form state snapshot.
class FormState {
  final bool isDirty;
  final bool isValid;
  final Map<String, dynamic> values;
  final Map<String, String> errors;

  const FormState({
    required this.isDirty,
    required this.isValid,
    required this.values,
    required this.errors,
  });
}

/// Form field definition for validation and rendering.
class FormFieldDefinition {
  final String id;
  final String name;
  final String type;
  final bool required;
  final int? minLength;
  final int? maxLength;
  final num? minimum;
  final num? maximum;
  final List<String>? allowedValues;
  final dynamic defaultValue;
  final String? referenceEntityId;
  final String? hint;

  const FormFieldDefinition({
    required this.id,
    required this.name,
    required this.type,
    this.required = false,
    this.minLength,
    this.maxLength,
    this.minimum,
    this.maximum,
    this.allowedValues,
    this.defaultValue,
    this.referenceEntityId,
    this.hint,
  });
}
