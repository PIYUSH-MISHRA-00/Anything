/// Generated-Experience smoke validator — behavior, not mere presence (IS-P10).
library;

import 'experience_package.dart';
import 'semantic_completeness.dart';

/// One smoke finding.
class SmokeFinding {
  final String code;
  final String detail;

  const SmokeFinding(this.code, this.detail);

  @override
  String toString() => '$code: $detail';
}

/// Result of smoking a package for install readiness.
class ExperienceSmokeReport {
  final bool passed;
  final List<SmokeFinding> findings;

  const ExperienceSmokeReport({required this.passed, this.findings = const []});

  List<String> get messages => findings.map((f) => f.toString()).toList();
}

/// Validates identity, actions, bindings, and capability completeness.
class ExperienceSmokeValidator {
  const ExperienceSmokeValidator();

  ExperienceSmokeReport validate(
    ExperiencePackage package, {
    Set<String>? requiredCapabilities,
  }) {
    final findings = <SmokeFinding>[];

    if (package.manifest.name.trim().isEmpty) {
      findings.add(const SmokeFinding('identity', 'missing display name'));
    }
    if (RegExp(r'^experience[_-]').hasMatch(package.manifest.name) ||
        package.manifest.name == 'untitled') {
      findings.add(
        SmokeFinding(
          'identity',
          'non-human display name "${package.manifest.name}"',
        ),
      );
    }
    if (package.interface.screens.isEmpty) {
      findings.add(const SmokeFinding('structure', 'no screens'));
    }

    for (final screen in package.interface.screens) {
      for (final node in _walk(screen.children)) {
        final binding = node.actionBinding;
        if (binding == null) continue;
        if (!_actionResolves(package.behavior, binding.actionId)) {
          findings.add(
            SmokeFinding(
              'dead_action',
              'control "${node.id}" → "${binding.actionId}" has no behavior',
            ),
          );
        }
      }
    }

    final caps =
        requiredCapabilities ?? package.manifest.requiredCapabilities.toSet();
    if (caps.isNotEmpty) {
      final completeness = const SemanticCompletenessValidator().validate(
        package: package,
        requiredCapabilities: caps,
      );
      for (final gap in completeness.gaps) {
        findings.add(
          SmokeFinding('capability', '${gap.capabilityId}: ${gap.reason}'),
        );
      }
    }

    // Forms must have fields when present.
    for (final screen in package.interface.screens) {
      for (final node in _walk(screen.children)) {
        if (node.type == 'entityForm') {
          final fields = node.properties['fields'];
          if (fields is! List || fields.isEmpty) {
            findings.add(
              SmokeFinding('form', 'entityForm "${node.id}" has no fields'),
            );
          }
        }
        if (node.type == 'input' &&
            node.stateBinding == null &&
            node.actionBinding == null) {
          findings.add(
            SmokeFinding(
              'binding',
              'input "${node.id}" has no state or action binding',
            ),
          );
        }
      }
    }

    return ExperienceSmokeReport(passed: findings.isEmpty, findings: findings);
  }

  /// Mirrors [BehaviorInterpreter.execute] resolution so smoke does not
  /// reject packages the runtime can already execute.
  bool _actionResolves(BehaviorGraph graph, String actionId) {
    if (_runtimeKnown(actionId)) return true;
    for (final n in graph.nodes) {
      if (n.id == actionId || n.id == '${actionId}_event') return true;
      final configEventId = n.config['eventId'];
      if (configEventId == actionId || configEventId == '${actionId}_event') {
        return true;
      }
    }
    return false;
  }

  bool _runtimeKnown(String actionId) {
    const known = {
      'submitForm',
      'deleteRecord',
      'openDetail',
      'searchChanged',
      'refreshData',
      'calc.digit',
      'calc.operator',
      'calc.equals',
      'calc.clear',
      'calc.backspace',
      'numberPressed',
      'operationPressed',
      'equalsPressed',
      'clearPressed',
    };
    return known.contains(actionId) || actionId.startsWith('calc.');
  }

  Iterable<InterfaceNode> _walk(List<InterfaceNode> roots) sync* {
    for (final n in roots) {
      yield n;
      yield* _walk(n.children);
    }
  }
}
