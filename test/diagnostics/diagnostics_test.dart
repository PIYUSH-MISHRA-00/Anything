/// Vision V10 RC — StructuredLogger, ErrorReport, and Diagnostics
/// (HealthReport family): the first real, typed, categorized logging and
/// diagnostics infrastructure in this codebase (repository audit
/// confirmed none existed before this milestone).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/design_review/review_types.dart';
import 'package:anything/diagnostics/error_report.dart';
import 'package:anything/diagnostics/health_report.dart';
import 'package:anything/diagnostics/log_entry.dart';
import 'package:anything/diagnostics/structured_logger.dart';
import 'package:anything/runtime_intelligence/automation_history.dart';
import 'package:anything/runtime_intelligence/learning_memory.dart';
import 'package:anything/runtime_intelligence/observation_memory.dart';
import 'package:anything/runtime_intelligence/observation_record.dart';
import 'package:anything/runtime_intelligence/ril_types.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/world_model/entity_identity.dart';
import 'package:anything/world_model/world_edge.dart';
import 'package:anything/world_model/world_graph.dart';
import 'package:anything/world_model/world_node.dart';
import 'package:anything/world_model/world_types.dart';

void main() {
  group('StructuredLogger', () {
    test('categorizes every entry and keeps a bounded in-memory buffer', () {
      final logger = StructuredLogger(maxBuffer: 2);
      logger.info(LogCategory.kernel, 'first');
      logger.warning(LogCategory.worldModel, 'second');
      logger.error(LogCategory.security, 'third');

      expect(logger.recent, hasLength(2)); // bounded — oldest evicted
      expect(logger.recent.map((e) => e.message), ['second', 'third']);
      expect(logger.recentOfCategory(LogCategory.security), hasLength(1));
    });

    test(
      'redact() strips email-shaped and token-shaped content — never exposes it verbatim',
      () {
        final redacted = StructuredLogger.redact(
          'contact user@example.com with token: abcdef1234567890',
        );
        expect(redacted, isNot(contains('user@example.com')));
        expect(redacted, contains('[redacted-email]'));
        expect(redacted, contains('[redacted-token]'));
      },
    );

    test('log() applies redaction before storing/emitting', () {
      final logger = StructuredLogger();
      logger.info(LogCategory.security, 'leaked user@example.com');
      expect(logger.recent.single.message, isNot(contains('user@example.com')));
    });
  });

  group('ErrorReport', () {
    test(
      'never exposes the raw exception — only the caller-supplied safe message',
      () {
        final report = ErrorReport.from(
          StateError('some internal detail that must never reach the user'),
          category: LogCategory.storage,
          userFacingMessage: "Couldn't save your changes. Please try again.",
        );
        expect(report.safeMessage, isNot(contains('internal detail')));
        expect(
          report.safeMessage,
          "Couldn't save your changes. Please try again.",
        );
        expect(report.recoverable, isTrue);
      },
    );

    test(
      'logs the real exception type for developers via the provided logger',
      () {
        final logger = StructuredLogger();
        ErrorReport.from(
          ArgumentError('bad value'),
          category: LogCategory.kernel,
          userFacingMessage: 'Something went wrong.',
          logger: logger,
        );
        expect(
          logger.recent.any(
            (e) =>
                e.category == LogCategory.kernel &&
                e.severity == LogSeverity.error,
          ),
          isTrue,
        );
      },
    );
  });

  group('HealthReport', () {
    test(
      'WorldGraphDiagnostics honestly reports dangling edges from a real WorldGraph',
      () {
        final a = EntityIdentity.stable(WorldNodeKind.entity, 'a');
        final ghost = EntityIdentity.stable(WorldNodeKind.entity, 'ghost');
        final graph = WorldGraph(
          nodes: [
            WorldNode(identity: a, kind: WorldNodeKind.entity, label: 'a'),
          ],
          edges: [
            WorldEdge(
              fromId: a,
              toId: ghost,
              kind: RelationshipKind.relatesTo,
              evidence: const GraphEvidence(
                sourceGraph: 'g',
                sourceNodeId: 'n',
              ),
            ),
          ],
        );
        final diagnostics = WorldGraphDiagnostics.of(graph);
        expect(diagnostics.isConsistent, isFalse);
        expect(diagnostics.danglingEdgeCount, 1);
        expect(diagnostics.nodesByKind[WorldNodeKind.entity], 1);
      },
    );

    test('a consistent graph reports healthy', () {
      final diagnostics = WorldGraphDiagnostics.of(const WorldGraph());
      expect(diagnostics.isConsistent, isTrue);
    });

    test(
      'RuntimeIntelligenceDiagnostics summarizes real memory counts, never fabricated',
      () {
        final observationMemory = ObservationMemory();
        observationMemory.record(
          ObservationRecord(
            id: 'r1',
            category: ObservationCategory.navigation,
            timestamp: DateTime.now(),
          ),
        );
        final diagnostics = RuntimeIntelligenceDiagnostics.of(
          observationMemory: observationMemory,
          learningMemory: LearningMemory(),
          automationHistory: AutomationHistory(),
        );
        expect(diagnostics.observationCount, 1);
        expect(diagnostics.learningRecordCount, 0);
      },
    );

    test(
      'SecurityDiagnostics reuses real SCARE ReviewIssues, never a second security checker',
      () {
        final issues = [
          ReviewIssue(
            id: 'security:x',
            category: ReviewCategory.security,
            severity: ReviewSeverity.critical,
            reason: 'test',
            evidence: const ReviewEvidence(
              affectedGraph: 'g',
              affectedNodeId: 'n',
            ),
            recommendation: const ReviewRecommendation(description: 'fix'),
            confidence: Confidence.full,
          ),
        ];
        final diagnostics = SecurityDiagnostics.fromReviewIssues(issues);
        expect(diagnostics.securityIssueCount, 1);
        expect(diagnostics.criticalSecurityIssueCount, 1);
      },
    );

    test(
      'HealthReport.isHealthy reflects both graph consistency and zero critical security issues',
      () {
        final healthy = HealthReport(
          worldGraph: const WorldGraphDiagnostics(
            nodeCount: 1,
            edgeCount: 0,
            danglingEdgeCount: 0,
            nodesByKind: {},
          ),
          runtimeIntelligence: const RuntimeIntelligenceDiagnostics(
            observationCount: 0,
            learningRecordCount: 0,
            automationRecordCount: 0,
          ),
          security: const SecurityDiagnostics(
            securityIssueCount: 0,
            criticalSecurityIssueCount: 0,
          ),
          storage: const StorageDiagnostics(
            experienceCount: 0,
            protectedExperienceCount: 0,
          ),
        );
        expect(healthy.isHealthy, isTrue);

        final unhealthy = HealthReport(
          worldGraph: const WorldGraphDiagnostics(
            nodeCount: 1,
            edgeCount: 1,
            danglingEdgeCount: 1,
            nodesByKind: {},
          ),
          runtimeIntelligence: const RuntimeIntelligenceDiagnostics(
            observationCount: 0,
            learningRecordCount: 0,
            automationRecordCount: 0,
          ),
          security: const SecurityDiagnostics(
            securityIssueCount: 0,
            criticalSecurityIssueCount: 0,
          ),
          storage: const StorageDiagnostics(
            experienceCount: 0,
            protectedExperienceCount: 0,
          ),
        );
        expect(unhealthy.isHealthy, isFalse);
      },
    );
  });
}
