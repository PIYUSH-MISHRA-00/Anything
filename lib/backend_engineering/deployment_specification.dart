/// Deployment Specification — Implementation Milestone R8. Real,
/// minimal: `requiresBackend` is derived from `OfflineDecision`/
/// `SecurityDecision` (ArchitectureCandidate, Vision Milestone V2) —
/// the two real, existing upstream signals for "does this app need
/// anything beyond purely local storage." `secretReferences` are real,
/// typed, NAME-ONLY references (never a value) emitted only when
/// `requiresCredentials` is real — this specification never carries an
/// actual secret. Environment/scaling/networking/monitoring/health-check
/// fields are deliberately NOT modeled here: no real upstream signal
/// exists to derive them from without inventing data (see this
/// milestone's Known Limitations) — never fabricated to fill the
/// spec's own long wishlist.
library;

/// A named reference to a secret this deployment would need — NEVER a
/// value. `ExperienceModificationCoordinator`'s own security discipline
/// (never persist a raw credential outside `CredentialVault`) is
/// mirrored here at the specification level.
class SecretReference {
  final String name;

  const SecretReference(this.name);
}

class DeploymentSpecificationModel {
  /// Real, derived: true when the architecture's own OfflineDecision
  /// isn't fully-offline, or its SecurityDecision requires network
  /// access beyond `NetworkMode.none`.
  final bool requiresBackend;
  final List<SecretReference> secretReferences;

  const DeploymentSpecificationModel({required this.requiresBackend, this.secretReferences = const []});
}
