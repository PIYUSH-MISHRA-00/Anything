/// Capability Platform — manages and executes trusted capabilities.
library;

import 'dart:async';

import '../../app/experience_provenance.dart';
import '../../app/governance_engine.dart';

/// Status of a capability invocation.
enum CapabilityResultStatus {
  success,
  unavailable,
  permissionDenied,
  unsupported,
  cancelled,
  invalidArguments,
  policyDenied,
  timeout,
  failed,
}

/// Result of a capability invocation.
class CapabilityInvocationResult {
  final CapabilityResultStatus status;
  final Map<String, dynamic> data;
  final String? error;
  const CapabilityInvocationResult({
    required this.status,
    this.data = const {},
    this.error,
  });
  factory CapabilityInvocationResult.success({
    Map<String, dynamic> data = const {},
  }) => CapabilityInvocationResult(
    status: CapabilityResultStatus.success,
    data: data,
  );
  factory CapabilityInvocationResult.failure(String error) =>
      CapabilityInvocationResult(
        status: CapabilityResultStatus.failed,
        error: error,
      );
}

/// A registered capability in the platform.
abstract class PlatformCapability {
  final String id;
  final String name;
  final String description;
  final List<String> supportedOperations;
  const PlatformCapability({
    required this.id,
    required this.name,
    required this.description,
    required this.supportedOperations,
  });
  Future<CapabilityInvocationResult> execute(
    String operation,
    Map<String, dynamic> params,
  );
}

/// The Capability Platform.
///
/// IS-R51: the platform now ASKS governance and ENFORCES the answer. It gains
/// no permission manager, no second registry and no authorization path of its
/// own — `governance.authorizeCapability()` returns a verdict, and `invoke()`
/// obeys it. Every check that was already here (declaration, registration,
/// session budget, supported operation) is unchanged and stays exactly where
/// it was: those are enforcement, and moving them would have broken both
/// ownership and backward compatibility.
///
/// With no governance engine supplied — the default — behaviour is identical
/// to pre-R51, which is what keeps every existing caller and test intact.
class CapabilityPlatform {
  final Map<String, PlatformCapability> _capabilities = {};
  final Map<String, Map<String, int>> _sessionCounts =
      {}; // sessionId -> capId -> count
  static const int _maxInvocationsPerCapability = 100;

  /// THE governance decision-maker (IS-R51). Optional so the platform stays
  /// usable standalone; the production composition supplies the canonical
  /// engine.
  final OperatingSystemGovernanceEngine? governance;

  /// THE trust classifier (IS-R52). Supplied so a caller may hand in an
  /// Experience's PROVENANCE and have trust COMPUTED, rather than passing a
  /// trust level it decided for itself — which would put classification back
  /// in the caller and defeat R52 entirely.
  ///
  /// This platform never classifies and never decides: it asks the classifier
  /// for a level, asks governance for a verdict, and enforces the answer.
  final ExperienceTrustClassifier? trustClassifier;

  CapabilityPlatform({this.governance, this.trustClassifier});

  /// Computes the trust level for [provenance] using THE canonical classifier
  /// (IS-R52 Task 5). Falls back to the default when no classifier is
  /// configured, so a platform built without one behaves exactly as pre-R52.
  ExperienceTrustLevel trustFor(ExperienceProvenance provenance) {
    final classifier = trustClassifier;
    if (classifier == null) return ExperienceTrustLevel.local;
    return classifier.classify(provenance);
  }

  void register(PlatformCapability capability) {
    _capabilities[capability.id] = capability;
  }

  bool isRegistered(String capabilityId) =>
      _capabilities.containsKey(capabilityId);

  PlatformCapability? getCapability(String capabilityId) =>
      _capabilities[capabilityId];

  /// Invoke a capability operation with session-scoped budget.
  Future<CapabilityInvocationResult> invoke(
    String capabilityId,
    String operation,
    Map<String, dynamic> params, {
    List<String>? declaredCapabilities,
    String? sessionId,
    ExperienceTrustLevel trustLevel = ExperienceTrustLevel.local,
    /// IS-R52: hand in PROVENANCE and trust is COMPUTED by the canonical
    /// classifier. Takes precedence over [trustLevel], which remains only so
    /// pre-R52 callers and tests keep working unchanged.
    ExperienceProvenance? provenance,
    String? experienceId,
    bool isOffline = false,
    bool privacyMode = false,
  }) async {
    if (declaredCapabilities != null &&
        !declaredCapabilities.contains(capabilityId)) {
      return CapabilityInvocationResult(
        status: CapabilityResultStatus.policyDenied,
        error: 'Capability not declared: $capabilityId',
      );
    }
    final cap = _capabilities[capabilityId];
    if (cap == null) {
      return CapabilityInvocationResult(
        status: CapabilityResultStatus.unsupported,
        error: 'Unknown capability: $capabilityId',
      );
    }

    // Session-scoped budget check
    final sid = sessionId ?? 'default';
    _sessionCounts.putIfAbsent(sid, () => {});
    final count = _sessionCounts[sid]![capabilityId] ?? 0;
    if (count >= _maxInvocationsPerCapability) {
      return CapabilityInvocationResult(
        status: CapabilityResultStatus.policyDenied,
        error: 'Invocation limit exceeded',
      );
    }
    if (!cap.supportedOperations.contains(operation)) {
      return CapabilityInvocationResult(
        status: CapabilityResultStatus.unsupported,
        error: 'Unsupported operation: $operation',
      );
    }

    // IS-R51: GOVERNANCE DECIDES, THIS PLATFORM ENFORCES.
    //
    // Asked last, after the cheap structural checks, so a governance denial is
    // never reported for a request that was malformed anyway — the caller gets
    // the most specific reason available.
    //
    // A denial maps to the EXISTING `permissionDenied` status and an approval
    // requirement to the EXISTING `policyDenied`; no new status was added, so
    // no caller's switch became incomplete.
    final governanceEngine = governance;
    if (governanceEngine != null) {
      // Provenance wins when supplied: trust must be COMPUTED, not asserted
      // by whoever happens to be calling.
      final effectiveTrust = provenance == null ? trustLevel : trustFor(provenance);
      final evaluation = governanceEngine.authorizeCapability(
        capabilityId: capabilityId,
        operation: operation,
        trustLevel: effectiveTrust,
        experienceId: experienceId,
        sessionId: sessionId,
        isOffline: isOffline,
        privacyMode: privacyMode,
      );
      if (!evaluation.isAllowed) {
        return CapabilityInvocationResult(
          status: evaluation.outcome == GovernanceOutcome.deny
              ? CapabilityResultStatus.permissionDenied
              : CapabilityResultStatus.policyDenied,
          error: evaluation.reason,
        );
      }
    }

    try {
      _sessionCounts[sid]![capabilityId] = count + 1;
      return await cap.execute(operation, params);
    } catch (e) {
      return CapabilityInvocationResult.failure(e.toString());
    }
  }

  /// Reset counts for a specific session.
  void resetSession(String sessionId) => _sessionCounts.remove(sessionId);

  /// Reset all counts.
  void resetCounts() => _sessionCounts.clear();
  List<PlatformCapability> get all => _capabilities.values.toList();
}
