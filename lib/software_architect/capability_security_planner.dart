/// Capability / Permission / Security / Offline / Synchronization
/// planners.
///
/// CapabilityPlanner's metadata table describes exactly what is really
/// implemented in this codebase today (see
/// docs/security/CAPABILITY_SECURITY_MATRIX.md) — it does not pretend
/// unimplemented capabilities (camera, OAuth, bluetooth, ...) exist. A
/// request for one is honestly reported as not-yet-available, at real
/// confidence, not fabricated as working.
library;

import 'architecture_types.dart';
import 'confidence.dart';

class _KnownCapability {
  final String why;
  final List<String> requiredPermissions;
  final String securityImplication;
  final String offlineImplication;
  final List<String> alternatives;

  const _KnownCapability({
    required this.why,
    this.requiredPermissions = const [],
    required this.securityImplication,
    required this.offlineImplication,
    this.alternatives = const [],
  });
}

/// Real, implemented capabilities only (see
/// docs/security/CAPABILITY_SECURITY_MATRIX.md for the full account of
/// each). Not wired into the live runtime yet (see
/// docs/security/TRUST_BOUNDARIES.md) — CapabilityPlanner still reports
/// them as available at the *planning* level since that's a distinct,
/// tracked runtime-integration gap, not a planning concern.
const Map<String, _KnownCapability> _knownCapabilities = {
  'clock': _KnownCapability(
    why:
        'Time-based logic (timestamps, streak/date calculations) needs a trusted time source.',
    securityImplication:
        'No filesystem/network side effects; read-only time queries.',
    offlineImplication: 'Fully local; unaffected by connectivity.',
  ),
  'notifications': _KnownCapability(
    why: 'Reminders/scheduled alerts for time-sensitive data.',
    requiredPermissions: ['notifications'],
    securityImplication:
        'Scoped per-Experience; cannot cancel another Experience\'s notifications.',
    offlineImplication: 'Local scheduling; no network required.',
    alternatives: ['In-app badge/indicator (no OS permission required)'],
  ),
  'http': _KnownCapability(
    why:
        'Declared network purpose requires fetching or sending data to a remote host.',
    requiredPermissions: ['internet'],
    securityImplication:
        'HTTPS-only, private/loopback ranges blocked, declared-host allow-list enforced, response/request size bounded (see docs/security/RUNTIME_LIMITS.md).',
    offlineImplication:
        'Unavailable offline; app must degrade gracefully without it.',
    alternatives: ['Manual data entry', 'Bundled static reference data'],
  ),
  'ai': _KnownCapability(
    why: 'On-demand generation/summarization beyond static templates.',
    securityImplication:
        'Prompt/response size bounded; no credential resolution implemented yet.',
    offlineImplication: 'Requires network to reach a model provider.',
    alternatives: ['Deterministic computation', 'Static content'],
  ),
  'knowledge': _KnownCapability(
    why: 'Reference lookups against external knowledge.',
    securityImplication:
        'Retrieved content is treated as untrusted data, never instructions (see docs/security/TRUST_BOUNDARIES.md).',
    offlineImplication:
        'Requires network; cached results can be reused offline once acquired.',
    alternatives: ['Bundled static reference data'],
  ),
  'files': _KnownCapability(
    why: 'User needs to attach/import/export a file.',
    requiredPermissions: ['storage'],
    securityImplication:
        'Sandboxed via FileService; trusted max size = min(requested, trusted).',
    offlineImplication: 'Fully local; unaffected by connectivity.',
  ),
};

class CapabilityPlanner {
  const CapabilityPlanner();

  List<CapabilityDecision> plan(List<String> requiredCapabilityIds) {
    return requiredCapabilityIds.map((id) {
      final known = _knownCapabilities[id];
      final resolved = known != null;
      return CapabilityDecision(
        capabilityId: id,
        resolved: resolved,
        decision: ArchitectureDecision(
          id: 'capability:$id',
          category: ArchitectureDecisionCategory.capability,
          subjectId: id,
          decision: resolved
              ? 'Use the "$id" capability'
              : '"$id" is not yet implemented in this platform',
          rationale: resolved
              ? known.why
              : 'No CapabilityDescriptor/PlatformCapability exists for '
                    '"$id" in the current codebase — reported honestly '
                    'rather than assumed to work.',
          confidence: Confidence(
            score: resolved ? 0.9 : 0.0,
            reason: resolved
                ? 'Matches a real, implemented, tested capability.'
                : 'No implementation exists to plan against.',
            risk: resolved ? RiskLevel.low : RiskLevel.high,
            alternatives: resolved ? known.alternatives : const [],
          ),
          alternatives: resolved ? known.alternatives : const [],
          securityImplication: resolved ? known.securityImplication : null,
          offlineImplication: resolved ? known.offlineImplication : null,
        ),
      );
    }).toList();
  }
}

class PermissionPlanner {
  const PermissionPlanner();

  List<PermissionDecision> plan(List<CapabilityDecision> capabilities) {
    final decisions = <PermissionDecision>[];
    for (final cap in capabilities) {
      final known = _knownCapabilities[cap.capabilityId];
      if (known == null) continue;
      for (final permission in known.requiredPermissions) {
        decisions.add(
          PermissionDecision(
            permission: permission,
            requiredByCapabilityId: cap.capabilityId,
            decision: ArchitectureDecision(
              id: 'permission:$permission:${cap.capabilityId}',
              category: ArchitectureDecisionCategory.permission,
              subjectId: permission,
              decision: 'Request "$permission" permission',
              rationale:
                  'Required by the "${cap.capabilityId}" capability; a '
                  'declaration in the package is a request, the trusted '
                  'runtime platform decides whether it is granted.',
              confidence: Confidence.full,
            ),
          ),
        );
      }
    }
    return decisions;
  }
}

class SecurityPlanner {
  const SecurityPlanner();

  ArchitectureDecision _decision(NetworkMode mode, bool vault) =>
      ArchitectureDecision(
        id: 'security:network-mode',
        category: ArchitectureDecisionCategory.security,
        subjectId: 'network',
        decision: mode == NetworkMode.none
            ? 'No network access'
            : 'Restricted HTTPS-only network access',
        rationale: mode == NetworkMode.none
            ? 'No network-requiring capability was planned.'
            : 'A network-requiring capability was planned; HTTPS-only, '
                  'private-range-blocked access applies (see '
                  'docs/security/RUNTIME_LIMITS.md).',
        confidence: Confidence.full,
        securityImplication: vault
            ? 'Any credential this app needs is resolved from the '
                  'CredentialVault by purpose, never embedded in the package.'
            : null,
      );

  SecurityDecision plan(List<CapabilityDecision> capabilities) {
    final needsNetwork = capabilities.any(
      (c) =>
          c.capabilityId == 'http' ||
          c.capabilityId == 'ai' ||
          c.capabilityId == 'knowledge',
    );
    final mode = needsNetwork ? NetworkMode.restrictedHttps : NetworkMode.none;
    // Vault is only meaningful once a real credential-consuming capability
    // exists; today none do (see docs/security/TRUST_BOUNDARIES.md), so
    // this is always false — honestly reflecting current wiring, not
    // aspirational.
    const requiresVault = false;
    return SecurityDecision(
      networkMode: mode,
      requiresCredentialVault: requiresVault,
      decision: _decision(mode, requiresVault),
    );
  }
}

class OfflinePlanner {
  const OfflinePlanner();

  OfflineDecision plan(List<CapabilityDecision> capabilities) {
    final needsNetwork = capabilities.any(
      (c) =>
          c.capabilityId == 'http' ||
          c.capabilityId == 'ai' ||
          c.capabilityId == 'knowledge',
    );
    final capability = needsNetwork
        ? OfflineCapability.cacheThenOnline
        : OfflineCapability.fullyOffline;
    return OfflineDecision(
      capability: capability,
      decision: ArchitectureDecision(
        id: 'offline:policy',
        category: ArchitectureDecisionCategory.offline,
        subjectId: 'offline',
        decision: capability == OfflineCapability.fullyOffline
            ? 'App works fully offline'
            : 'App works offline for cached data; network-dependent '
                  'features degrade gracefully',
        rationale: needsNetwork
            ? 'At least one network-requiring capability was planned; '
                  'core CRUD/data remains SQLite-backed and fully local '
                  'regardless.'
            : 'No network-requiring capability was planned; the entire '
                  'app is local-data-only.',
        confidence: Confidence.full,
      ),
    );
  }
}

class SynchronizationPlanner {
  const SynchronizationPlanner();

  SynchronizationDecision plan(OfflineDecision offline) {
    final strategy = switch (offline.capability) {
      OfflineCapability.fullyOffline => SyncStrategy.none,
      OfflineCapability.cacheThenOnline => SyncStrategy.cacheFirst,
      OfflineCapability.onlineRequired => SyncStrategy.networkFirst,
    };
    return SynchronizationDecision(
      strategy: strategy,
      decision: ArchitectureDecision(
        id: 'synchronization:strategy',
        category: ArchitectureDecisionCategory.synchronization,
        subjectId: 'sync',
        decision: 'Synchronization strategy: ${strategy.name}',
        rationale:
            'Derived directly from the offline decision — no separate '
            'sync requirement exists apart from how the app already '
            'handles being offline.',
        confidence: Confidence.full,
      ),
    );
  }
}
