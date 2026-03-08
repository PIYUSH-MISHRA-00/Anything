import 'package:flutter_riverpod/flutter_riverpod.dart';

final workflowExecutorProvider = Provider<WorkflowExecutor>((ref) {
  return WorkflowExecutor();
});

/// Executes individual workflow steps and tracks progress.
class WorkflowExecutor {
  final List<String> _log = [];

  List<String> get log => List.unmodifiable(_log);

  void logStep(String step) {
    _log.add('[${DateTime.now().toIso8601String()}] $step');
  }

  void clear() {
    _log.clear();
  }
}
