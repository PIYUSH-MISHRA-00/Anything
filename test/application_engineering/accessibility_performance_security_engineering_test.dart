/// Vision V3 AEE — Accessibility/Performance/Security Engineering. Every
/// decision must be grounded in real, direct source inspection; the key
/// regression this guards is honesty: virtualization must stay reported as
/// NOT real (generated lists use Column + List.generate, not
/// ListView.builder — see lib/runtime/experience_renderer.dart).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/accessibility_performance_security_engineering.dart';

void main() {
  group('AccessibilityEngineering', () {
    const accessibilityEngineering = AccessibilityEngineering();

    test('produces one decision per accessibility aspect, all grounded in Flutter defaults', () {
      final result = accessibilityEngineering.plan();
      expect(result.decisions, hasLength(AccessibilityAspect.values.length));
      for (final d in result.decisions) {
        expect(d.rationale, isNotEmpty);
      }
    });
  });

  group('PerformanceEngineering', () {
    const performanceEngineering = PerformanceEngineering();

    test('virtualization is honestly reported as NOT implemented', () {
      final result = performanceEngineering.plan();
      final virtualization = result.decisions.firstWhere(
        (d) => d.subjectId == PerformanceAspect.virtualization.name,
      );
      expect(virtualization.decision, contains('not implemented'));
      expect(virtualization.confidence.score, 0.0);
      expect(virtualization.rationale, contains('ListView.builder'));
    });

    test('lazyLoading/caching/memory/database are reported real', () {
      final result = performanceEngineering.plan();
      for (final aspect in [
        PerformanceAspect.lazyLoading,
        PerformanceAspect.caching,
        PerformanceAspect.memory,
        PerformanceAspect.database,
      ]) {
        final d = result.decisions.firstWhere((d) => d.subjectId == aspect.name);
        expect(d.decision, contains('is real today'));
      }
    });
  });

  group('SecurityEngineering', () {
    const securityEngineering = SecurityEngineering();

    test('records Kaalka as the sole canonical protection mechanism', () {
      final result = securityEngineering.plan();
      final kaalka = result.decisions.firstWhere((d) => d.subjectId == SecurityAspect.kaalka.name);
      expect(kaalka.rationale, contains('package:kaalka'));
      expect(kaalka.rationale, contains('canonical'));
    });

    test('records that CredentialVault exists but is unused, not fabricated as wired up', () {
      final result = securityEngineering.plan();
      final credentialFlow = result.decisions.firstWhere(
        (d) => d.subjectId == SecurityAspect.credentialFlow.name,
      );
      expect(credentialFlow.rationale, contains('unused'));
    });
  });
}
