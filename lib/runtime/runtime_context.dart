/// Runtime Component Context — bounded event/action interface for component builders.
///
/// Provides trusted callbacks from component builders to the runtime.
/// Never grants arbitrary code execution authority.
library;

import '../creation/experience_package.dart';
import 'data_runtime.dart';
import 'experience_router.dart';
import 'form_controller.dart';
import 'state_engine.dart';

/// Bounded runtime actions that component builders can invoke.
enum RuntimeActionType {
  dispatch,
  navigate,
  updateFormField,
  toggleState,
  refreshQuery,
  submitForm,
  cancelForm,
  showDialog,
  showBottomSheet,
  confirmDelete,
  selectRecord,
}

/// A bounded runtime action request.
class RuntimeAction {
  final RuntimeActionType type;
  final Map<String, dynamic> parameters;

  const RuntimeAction({required this.type, this.parameters = const {}});
}

/// Result of a runtime action.
sealed class ActionResult {
  const ActionResult();
}

class ActionSucceeded extends ActionResult {
  final dynamic result;
  const ActionSucceeded([this.result]);
}

class ActionFailed extends ActionResult {
  final String reason;
  const ActionFailed(this.reason);
}

class ActionRejected extends ActionResult {
  final String reason;
  const ActionRejected(this.reason);
}

/// RuntimeComponentContext — trusted runtime callbacks for component builders.
///
/// Components receive this context to dispatch actions. All methods are
/// bounded to specific trusted operations — no arbitrary code execution.
class RuntimeComponentContext {
  final ExperienceStateEngine stateEngine;
  final ExperienceDataRuntime dataRuntime;
  final ExperienceRouter router;
  final String experienceId;

  final void Function(String eventId, {Map<String, dynamic>? data}) _onEvent;
  final ExperienceFormController? _currentForm;
  final String? _currentEntityId;
  final String? _currentRecordId;
  final DataSchema? _dataSchema;

  RuntimeComponentContext({
    required this.stateEngine,
    required this.dataRuntime,
    required this.router,
    required this.experienceId,
    required void Function(String eventId, {Map<String, dynamic>? data})
    onEvent,
    ExperienceFormController? currentForm,
    String? currentEntityId,
    String? currentRecordId,
    DataSchema? dataSchema,
  }) : _onEvent = onEvent,
       _currentForm = currentForm,
       _currentEntityId = currentEntityId,
       _currentRecordId = currentRecordId,
       _dataSchema = dataSchema;

  ExperienceFormController? get currentForm => _currentForm;
  String? get currentEntityId => _currentEntityId;
  String? get currentRecordId => _currentRecordId;
  DataSchema? get dataSchema => _dataSchema;

  /// Dispatch an action through the behavior interpreter.
  Future<void> dispatchAction(
    String actionId, {
    Map<String, dynamic>? data,
  }) async {
    _onEvent(actionId, data: data);
  }

  /// Navigate to a screen.
  void navigate(String screenId, {Map<String, dynamic>? arguments}) {
    router.navigate(
      NavigationRequest(
        action: NavigationAction.push,
        targetScreenId: screenId,
        arguments: arguments,
      ),
    );
  }

  /// Navigate back.
  void navigateBack() {
    router.navigate(const NavigationRequest(action: NavigationAction.pop));
  }

  /// Navigate to root.
  void navigateToRoot() {
    router.navigate(
      const NavigationRequest(action: NavigationAction.popToRoot),
    );
  }

  /// Switch to a tab.
  void switchTab(String screenId) {
    router.navigate(
      NavigationRequest(
        action: NavigationAction.switchTab,
        targetScreenId: screenId,
      ),
    );
  }

  /// Toggle a boolean state value.
  void toggleState(String stateId) {
    final current = stateEngine.read(stateId);
    if (current is bool) {
      stateEngine.write(stateId, !current);
    }
  }

  /// Update a state value.
  void updateState(String stateId, dynamic value) {
    stateEngine.write(stateId, value);
  }

  /// Read a state value.
  dynamic readState(String stateId) {
    return stateEngine.read(stateId);
  }

  /// Update a form field value.
  void updateFormField(String fieldId, dynamic value) {
    _currentForm?.setValue(fieldId, value);
  }

  /// Get a form field value.
  dynamic getFormField(String fieldId) {
    return _currentForm?.getValue(fieldId);
  }

  /// Get form error for a field.
  String? getFormFieldError(String fieldId) {
    return _currentForm?.getFieldError(fieldId);
  }

  /// Check if form is valid.
  bool isFormValid() {
    return _currentForm?.isValid ?? false;
  }

  /// Check if form is dirty.
  bool isFormDirty() {
    return _currentForm?.isDirty ?? false;
  }

  /// Insert a record into an entity.
  Future<void> createRecord(String entity, Map<String, dynamic> record) async {
    await dataRuntime.insert(entity, record);
  }

  /// Update a record.
  Future<void> updateRecord(
    String entity,
    String id,
    Map<String, dynamic> updates,
  ) async {
    await dataRuntime.update(entity, id, updates);
  }

  /// Delete a record with relationship safety check.
  Future<ActionResult> deleteRecord(String entity, String id) async {
    final safetyError = await checkDeleteSafety(entity, id);
    if (safetyError != null) {
      return ActionRejected(safetyError);
    }
    await dataRuntime.delete(entity, id);
    return const ActionSucceeded();
  }

  /// Check if a record can be safely deleted (no inbound references).
  Future<String?> checkDeleteSafety(String entity, String id) async {
    if (_dataSchema == null) return null;

    for (final otherEntity in _dataSchema.entities) {
      final records = await dataRuntime.query(otherEntity.id);
      for (final record in records) {
        for (final field in otherEntity.fields) {
          if (field.type == 'reference' &&
              field.id.endsWith('Id') &&
              record[field.id] == id) {
            return 'Cannot delete: referenced by ${otherEntity.name}';
          }
        }
      }
    }
    return null;
  }

  /// Query records from an entity.
  Future<List<Map<String, dynamic>>> queryRecords(String entity) async {
    return await dataRuntime.query(entity);
  }

  /// Read a single record.
  Future<Map<String, dynamic>?> readRecord(String entity, String id) async {
    return await dataRuntime.readById(entity, id);
  }

  /// Get entity schema by id.
  DataEntitySchema? getEntitySchema(String entityId) {
    if (_dataSchema == null) return null;
    try {
      return _dataSchema.entities.firstWhere((e) => e.id == entityId);
    } catch (_) {
      return null;
    }
  }

  /// Get display label for a record using schema metadata.
  String getRecordLabel(Map<String, dynamic> record, {String? entityId}) {
    final entity = entityId != null ? getEntitySchema(entityId) : null;
    if (entity != null) {
      final displayField = entity.fields
          .where((f) => f.id == 'name' || f.id == 'title' || f.id == 'label')
          .firstOrNull;
      if (displayField != null && record[displayField.id] != null) {
        return record[displayField.id].toString();
      }
    }
    if (record['name'] != null) return record['name'].toString();
    if (record['title'] != null) return record['title'].toString();
    if (record['label'] != null) return record['label'].toString();
    return record['id']?.toString() ?? 'Unknown';
  }

  /// Create a child context with form binding.
  RuntimeComponentContext withForm(
    ExperienceFormController form,
    String entityId,
  ) {
    return RuntimeComponentContext(
      stateEngine: stateEngine,
      dataRuntime: dataRuntime,
      router: router,
      experienceId: experienceId,
      onEvent: _onEvent,
      currentForm: form,
      currentEntityId: entityId,
      currentRecordId: _currentRecordId,
      dataSchema: _dataSchema,
    );
  }

  /// Create a child context with record binding.
  RuntimeComponentContext withRecord(String entityId, String recordId) {
    return RuntimeComponentContext(
      stateEngine: stateEngine,
      dataRuntime: dataRuntime,
      router: router,
      experienceId: experienceId,
      onEvent: _onEvent,
      currentForm: _currentForm,
      currentEntityId: entityId,
      currentRecordId: recordId,
      dataSchema: _dataSchema,
    );
  }
}
