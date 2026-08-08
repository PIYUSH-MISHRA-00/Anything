/// Implementation Specification IS-R51 — Canonical Operating System
/// Governance Framework.
///
/// REALITY before R51, from the Task 1 audit: governance decisions were real
/// but scattered across the files that happened to need them — and the most
/// important one did not exist at all.
///
///     HTTP allowed hosts     AppComposition._defaultHttpAllowedHosts
///     Invocation budget      CapabilityPlatform._maxInvocationsPerCapability
///     File size ceiling      FileCapability._maxFileSize
///     Knowledge ceiling      RuntimeSecurityLimits.maxKnowledgeBytes
///     Capability declaration CapabilityPlatform.invoke()
///     Protection             ExperienceProtectionService (opt-in)
///     EXPERIENCE TRUST       *** did not exist anywhere ***
///
/// Every Experience — however it arrived — was treated identically by the
/// capability platform, because there was no notion of trust to treat it by.
///
/// GOVERNANCE DECIDES; EXISTING OWNERS ENFORCE. These tests exercise both
/// halves: the engine's decisions in isolation, and the real
/// `CapabilityPlatform` obeying them.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/app/governance_engine.dart';
import 'package:anything/capabilities/platform/capability_platform.dart';

class _EchoCapability extends PlatformCapability {
  int executions = 0;

  _EchoCapability(String id)
    : super(
        id: id,
        name: id,
        description: 'test',
        supportedOperations: const ['run', 'background', 'restore'],
      );

  @override
  Future<CapabilityInvocationResult> execute(
    String operation,
    Map<String, dynamic> params,
  ) async {
    executions++;
    return CapabilityInvocationResult.success(data: {'ok': true});
  }
}

void main() {
  const engine = OperatingSystemGovernanceEngine();

  group('Trust model (R51 Task 6) — the thing that did not exist before', () {
    test(
      'trust levels are ordered least-to-most privileged, so comparisons are meaningful',
      () {
        expect(
          ExperienceTrustLevel.untrusted.atLeast(ExperienceTrustLevel.local),
          isFalse,
        );
        expect(
          ExperienceTrustLevel.local.atLeast(ExperienceTrustLevel.local),
          isTrue,
        );
        expect(
          ExperienceTrustLevel.trusted.atLeast(ExperienceTrustLevel.imported),
          isTrue,
        );
        expect(
          ExperienceTrustLevel.imported.atLeast(ExperienceTrustLevel.verified),
          isFalse,
        );
        expect(ExperienceTrustLevel.values.map((t) => t.name), [
          'untrusted',
          'experimental',
          'imported',
          'local',
          'verified',
          'trusted',
        ]);
      },
    );

    test(
      'an untrusted Experience is DENIED a capability its trust level does not reach',
      () {
        final evaluation = engine.authorizeCapability(
          capabilityId: 'http',
          trustLevel: ExperienceTrustLevel.untrusted,
        );
        expect(evaluation.isAllowed, isFalse);
        expect(evaluation.outcome, GovernanceOutcome.deny);
        expect(evaluation.reason, contains('http'));
      },
    );

    test('a local Experience is ALLOWED the same capability', () {
      final evaluation = engine.authorizeCapability(
        capabilityId: 'http',
        trustLevel: ExperienceTrustLevel.local,
      );
      expect(evaluation.isAllowed, isTrue);
    });

    test(
      'a capability with no trust floor is available at every level — the clock reveals and consumes nothing',
      () {
        for (final level in ExperienceTrustLevel.values) {
          expect(
            engine
                .authorizeCapability(capabilityId: 'clock', trustLevel: level)
                .isAllowed,
            isTrue,
          );
        }
      },
    );
  });

  group('Domain rules (R51 Task 4)', () {
    test(
      'PRIVACY mode denies every capability that would send data off the device',
      () {
        for (final capability in ['http', 'ai', 'knowledge']) {
          final evaluation = engine.authorizeCapability(
            capabilityId: capability,
            privacyMode: true,
          );
          expect(
            evaluation.outcome,
            GovernanceOutcome.deny,
            reason: '$capability must be denied in privacy mode',
          );
          expect(evaluation.reason, contains('privacy mode'));
        }
        // Local-only capabilities are unaffected.
        expect(
          engine
              .authorizeCapability(capabilityId: 'files', privacyMode: true)
              .isAllowed,
          isTrue,
        );
        expect(
          engine
              .authorizeCapability(capabilityId: 'clock', privacyMode: true)
              .isAllowed,
          isTrue,
        );
      },
    );

    test(
      'OFFLINE denies network-dependent capabilities but not local ones',
      () {
        expect(
          engine
              .authorizeCapability(capabilityId: 'http', isOffline: true)
              .isAllowed,
          isFalse,
        );
        expect(
          engine
              .authorizeCapability(capabilityId: 'knowledge', isOffline: true)
              .isAllowed,
          isFalse,
        );
        expect(
          engine
              .authorizeCapability(capabilityId: 'files', isOffline: true)
              .isAllowed,
          isTrue,
        );
        expect(
          engine
              .authorizeCapability(
                capabilityId: 'notifications',
                isOffline: true,
              )
              .isAllowed,
          isTrue,
        );
      },
    );

    test(
      'MODEL ACCESS requires explicit approval for a low-trust Experience — not a silent denial',
      () {
        final evaluation = engine.authorizeCapability(
          capabilityId: 'ai',
          trustLevel: ExperienceTrustLevel.experimental,
        );
        // The trust floor denies outright; approval is the weaker verdict, so
        // deny wins. This asserts the precedence explicitly.
        expect(evaluation.outcome, GovernanceOutcome.deny);

        // With the floor removed from consideration, approval is the outcome.
        const modelOnly = OperatingSystemGovernanceEngine(
          rules: [ModelAccessRule()],
        );
        final approval = modelOnly.authorizeCapability(
          capabilityId: 'ai',
          trustLevel: ExperienceTrustLevel.experimental,
        );
        expect(approval.outcome, GovernanceOutcome.requireApproval);
        expect(approval.reason, contains('approval'));
      },
    );

    test(
      'NETWORK host allowlist decides reachability; an unlisted host is denied',
      () {
        const networked = OperatingSystemGovernanceEngine(
          rules: [
            NetworkHostAllowlistRule(allowedHosts: ['api.example.com']),
          ],
        );
        expect(
          networked
              .evaluate(const GovernanceContext(host: 'api.example.com'))
              .isAllowed,
          isTrue,
        );
        final denied = networked.evaluate(
          const GovernanceContext(host: 'evil.example.net'),
        );
        expect(denied.isAllowed, isFalse);
        expect(denied.reason, contains('not allowlisted'));
      },
    );

    test(
      'RESOURCE ceiling denies an oversized request and is silent about a reasonable one',
      () {
        const sized = OperatingSystemGovernanceEngine(
          rules: [ResourceCeilingRule(maxRequestBytes: 1000)],
        );
        expect(
          sized
              .evaluate(const GovernanceContext(requestedBytes: 2000))
              .isAllowed,
          isFalse,
        );
        final ok = sized.evaluate(const GovernanceContext(requestedBytes: 500));
        expect(ok.isAllowed, isTrue);
        expect(
          ok.decisions,
          isEmpty,
          reason:
              'a rule with no objection stays silent rather than voting allow',
        );
      },
    );

    test('BACKGROUND EXECUTION requires local trust or above', () {
      expect(
        engine
            .evaluate(
              const GovernanceContext(
                operation: 'background',
                trustLevel: ExperienceTrustLevel.local,
              ),
            )
            .isAllowed,
        isTrue,
      );
      expect(
        engine
            .evaluate(
              const GovernanceContext(
                operation: 'background',
                trustLevel: ExperienceTrustLevel.imported,
              ),
            )
            .isAllowed,
        isFalse,
      );
    });

    test(
      'RECOVERY quarantines an untrusted Experience from automatic restore',
      () {
        expect(
          engine
              .evaluate(
                const GovernanceContext(
                  operation: 'restore',
                  trustLevel: ExperienceTrustLevel.untrusted,
                ),
              )
              .isAllowed,
          isFalse,
        );
        expect(
          engine
              .evaluate(
                const GovernanceContext(
                  operation: 'restore',
                  trustLevel: ExperienceTrustLevel.local,
                ),
              )
              .isAllowed,
          isTrue,
        );
      },
    );
  });

  group('Evaluation semantics (R51 Task 3)', () {
    test(
      'DENY WINS over allow — fail-closed on conflict, regardless of how many rules permitted',
      () {
        // Trust floor allows (local meets it); privacy mode denies.
        final evaluation = engine.authorizeCapability(
          capabilityId: 'http',
          trustLevel: ExperienceTrustLevel.trusted,
          privacyMode: true,
        );
        expect(
          evaluation.decisions.any((d) => d.isAllowed),
          isTrue,
          reason: 'at least one rule permitted it',
        );
        expect(
          evaluation.outcome,
          GovernanceOutcome.deny,
          reason: 'and yet the request is refused',
        );
      },
    );

    test('deny outranks requireApproval', () {
      const both = OperatingSystemGovernanceEngine(
        rules: [PrivacyModeRule(), ModelAccessRule()],
      );
      final evaluation = both.authorizeCapability(
        capabilityId: 'ai',
        trustLevel: ExperienceTrustLevel.experimental,
        privacyMode: true,
      );
      expect(evaluation.outcome, GovernanceOutcome.deny);
    });

    test(
      'a silent rule is NOT an approving rule — silence and approval are distinguishable',
      () {
        // No rule has an opinion about an unknown capability with no context.
        final evaluation = engine.authorizeCapability(
          capabilityId: 'totally-unknown',
        );
        expect(evaluation.decisions, isEmpty);
        expect(evaluation.isAllowed, isTrue, reason: 'nothing objected');
        expect(evaluation.reason, 'no rule applied');
      },
    );

    test('every decision carries a reason and the rule that produced it', () {
      final evaluation = engine.authorizeCapability(
        capabilityId: 'http',
        trustLevel: ExperienceTrustLevel.untrusted,
      );
      for (final decision in evaluation.decisions) {
        expect(decision.reason, isNotEmpty);
        expect(decision.ruleId, isNotEmpty);
      }
      expect(
        evaluation.decisive,
        isNotEmpty,
        reason:
            'the decisions responsible for the outcome must be identifiable',
      );
    });

    test('rulesFor() and policyFor() scope to one domain', () {
      expect(
        engine.rulesFor(GovernanceDomain.privacy).single.id,
        'privacy.no_egress',
      );
      expect(
        engine.policyFor(GovernanceDomain.offline).domain,
        GovernanceDomain.offline,
      );
      expect(
        engine.rulesFor(GovernanceDomain.backup),
        isEmpty,
        reason: 'a domain with no rules yet is empty, not fabricated',
      );
    });

    test('all fourteen canonical domains exist', () {
      expect(GovernanceDomain.values.length, 14);
      for (final required in [
        GovernanceDomain.security,
        GovernanceDomain.privacy,
        GovernanceDomain.permissions,
        GovernanceDomain.resourceManagement,
        GovernanceDomain.backgroundExecution,
        GovernanceDomain.network,
        GovernanceDomain.offline,
        GovernanceDomain.modelAccess,
        GovernanceDomain.workspace,
        GovernanceDomain.experienceTrust,
        GovernanceDomain.dataGovernance,
        GovernanceDomain.recovery,
        GovernanceDomain.backup,
        GovernanceDomain.sync,
      ]) {
        expect(GovernanceDomain.values, contains(required));
      }
    });
  });

  group(
    'Capability authorization end-to-end (R51 Task 5) — governance decides, the platform enforces',
    () {
      test(
        'the real CapabilityPlatform REFUSES to execute a governance-denied request',
        () async {
          final capability = _EchoCapability('http');
          final platform = CapabilityPlatform(governance: engine)
            ..register(capability);

          final result = await platform.invoke(
            'http',
            'run',
            const {},
            trustLevel: ExperienceTrustLevel.untrusted,
          );

          expect(result.status, CapabilityResultStatus.permissionDenied);
          expect(
            capability.executions,
            0,
            reason:
                'a denied capability must not run — enforcement, not advice',
          );
        },
      );

      test(
        'the same request from a trusted Experience executes normally',
        () async {
          final capability = _EchoCapability('http');
          final platform = CapabilityPlatform(governance: engine)
            ..register(capability);

          final result = await platform.invoke(
            'http',
            'run',
            const {},
            trustLevel: ExperienceTrustLevel.trusted,
          );

          expect(result.status, CapabilityResultStatus.success);
          expect(capability.executions, 1);
        },
      );

      test('privacy mode blocks execution through the real platform', () async {
        final capability = _EchoCapability('ai');
        final platform = CapabilityPlatform(governance: engine)
          ..register(capability);

        final result = await platform.invoke(
          'ai',
          'run',
          const {},
          privacyMode: true,
        );

        expect(result.status, CapabilityResultStatus.permissionDenied);
        expect(capability.executions, 0);
      });

      test(
        'an approval requirement maps to policyDenied, NOT permissionDenied — the distinction is preserved',
        () async {
          final capability = _EchoCapability('ai');
          const modelOnly = OperatingSystemGovernanceEngine(
            rules: [ModelAccessRule()],
          );
          final platform = CapabilityPlatform(governance: modelOnly)
            ..register(capability);

          final result = await platform.invoke(
            'ai',
            'run',
            const {},
            trustLevel: ExperienceTrustLevel.experimental,
          );

          expect(result.status, CapabilityResultStatus.policyDenied);
          expect(capability.executions, 0);
        },
      );

      test(
        'governance is asked AFTER the structural checks, so the most specific reason wins',
        () async {
          final capability = _EchoCapability('http');
          final platform = CapabilityPlatform(governance: engine)
            ..register(capability);

          // Unsupported operation AND an untrusted Experience: the caller should
          // learn the operation is unsupported, not be told about trust.
          final result = await platform.invoke(
            'http',
            'no-such-operation',
            const {},
            trustLevel: ExperienceTrustLevel.untrusted,
          );
          expect(result.status, CapabilityResultStatus.unsupported);

          // An undeclared capability is still reported as such.
          final undeclared = await platform.invoke(
            'http',
            'run',
            const {},
            declaredCapabilities: const ['files'],
            trustLevel: ExperienceTrustLevel.untrusted,
          );
          expect(undeclared.status, CapabilityResultStatus.policyDenied);
          expect(undeclared.error, contains('not declared'));
        },
      );

      test(
        'the platform still enforces its own session budget — governance did not replace it',
        () async {
          final capability = _EchoCapability('files');
          final platform = CapabilityPlatform(governance: engine)
            ..register(capability);

          for (var i = 0; i < 100; i++) {
            await platform.invoke('files', 'run', const {}, sessionId: 's1');
          }
          final overBudget = await platform.invoke(
            'files',
            'run',
            const {},
            sessionId: 's1',
          );

          expect(overBudget.status, CapabilityResultStatus.policyDenied);
          expect(overBudget.error, contains('Invocation limit'));
          expect(capability.executions, 100);
        },
      );
    },
  );

  group('Backward compatibility (R51 Task 13)', () {
    test(
      'a CapabilityPlatform with NO governance behaves exactly as before',
      () async {
        final capability = _EchoCapability('http');
        final platform = CapabilityPlatform()..register(capability);
        expect(platform.governance, isNull);

        // Even an untrusted Experience executes, because no governance was
        // supplied — identical to pre-R51 behaviour.
        final result = await platform.invoke(
          'http',
          'run',
          const {},
          trustLevel: ExperienceTrustLevel.untrusted,
        );
        expect(result.status, CapabilityResultStatus.success);
        expect(capability.executions, 1);
      },
    );

    test(
      'invoke() defaults to local trust, so existing callers that pass no trust level are unaffected',
      () async {
        final capability = _EchoCapability('http');
        final platform = CapabilityPlatform(governance: engine)
          ..register(capability);

        final result = await platform.invoke('http', 'run', const {});
        expect(
          result.status,
          CapabilityResultStatus.success,
          reason:
              'the default trust level must be one that works for ordinary Experiences',
        );
      },
    );

    test(
      'no new CapabilityResultStatus value was introduced — no caller switch became incomplete',
      () {
        expect(CapabilityResultStatus.values.map((s) => s.name), [
          'success',
          'unavailable',
          'permissionDenied',
          'unsupported',
          'cancelled',
          'invalidArguments',
          'policyDenied',
          'timeout',
          'failed',
        ]);
      },
    );
  });

  group('Governance owns policy ONLY (R51 Task 2)', () {
    test(
      'the engine is pure — evaluation is synchronous and returns a verdict, nothing else',
      () {
        final evaluation = engine.authorizeCapability(capabilityId: 'http');
        expect(evaluation, isA<GovernanceEvaluation>());
        expect(evaluation.context.capabilityId, 'http');
      },
    );

    test(
      'a caller may supply an entirely different rule set — policy is configurable, not compiled in',
      () {
        const permissive = OperatingSystemGovernanceEngine(rules: []);
        expect(
          permissive
              .authorizeCapability(
                capabilityId: 'http',
                trustLevel: ExperienceTrustLevel.untrusted,
              )
              .isAllowed,
          isTrue,
          reason: 'with no rules, nothing objects',
        );
      },
    );
  });
}
