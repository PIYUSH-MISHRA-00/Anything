/// Intent Composer — manages the state of intent creation.
///
/// Separates visual input from business logic.
library;

import 'package:flutter/material.dart';

import 'package:anything/core/contracts/intent.dart' as core;
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';

/// Callback for voice state changes.
typedef VoiceStateChangedCallback = void Function(bool isListening);

/// Intent Composer manages the lifecycle of intent creation.
class IntentComposer extends ChangeNotifier {
  final AnythingKernel _kernel;
  String _expression = '';
  core.InputModality _modality = core.InputModality.text;
  final List<core.IntentAttachment> _attachments = [];
  bool _isSubmitting = false;
  String? _error;
  KernelOutcome? _lastOutcome;

  IntentComposer(this._kernel);

  String get expression => _expression;
  core.InputModality get modality => _modality;
  List<core.IntentAttachment> get attachments =>
      List.unmodifiable(_attachments);
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;
  KernelOutcome? get lastOutcome => _lastOutcome;
  bool get canSubmit => _expression.trim().isNotEmpty && !_isSubmitting;

  /// Update the expression text.
  void setExpression(String text) {
    _expression = text;
    _error = null;
    notifyListeners();
  }

  /// Set the input modality.
  void setModality(core.InputModality modality) {
    _modality = modality;
    notifyListeners();
  }

  /// Add an attachment.
  void addAttachment(core.IntentAttachment attachment) {
    _attachments.add(attachment);
    notifyListeners();
  }

  /// Remove an attachment.
  void removeAttachment(String id) {
    _attachments.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  /// Clear all attachments.
  void clearAttachments() {
    _attachments.clear();
    notifyListeners();
  }

  /// Create a canonical Intent from current expression without submitting.
  core.Intent createIntent() {
    return core.Intent.create(
      expression: _expression.trim(),
      modality: _modality,
      attachments: _attachments,
    );
  }

  /// Submit the current intent to the kernel.
  Future<KernelOutcome?> submit() async {
    if (!canSubmit) return null;

    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final intent = core.Intent.create(
        expression: _expression.trim(),
        modality: _modality,
        attachments: _attachments,
      );

      final outcome = await _kernel.processIntent(intent);
      _lastOutcome = outcome;

      if (outcome is PlanningFailed) {
        // IS-P10: prefer the structured error (real cause) over a shrug message.
        _error = outcome.error.isNotEmpty ? outcome.error : outcome.message;
      } else if (outcome is UnsupportedIntent) {
        _error = outcome.message;
      }

      _isSubmitting = false;
      notifyListeners();
      return outcome;
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
      _isSubmitting = false;
      notifyListeners();
      return null;
    }
  }

  /// Clear the composer state.
  void clear() {
    _expression = '';
    _modality = core.InputModality.text;
    _attachments.clear();
    _error = null;
    _lastOutcome = null;
    notifyListeners();
  }

  /// Clear only the error state.
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
