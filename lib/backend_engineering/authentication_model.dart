/// Authentication Model — Implementation Milestone R8. Deliberately
/// minimal and honest: `ArchitectureCandidate` (Vision Milestone V2)
/// carries no "does this app require end-user login" decision anywhere
/// upstream — `SecurityDecision`/`PermissionDecision` model CAPABILITY
/// access control (does a capability need a permission), not user
/// identity. Fabricating a rich identity-provider/session/role model
/// with no real source signal would violate this milestone's own
/// "never fabricate data" rule. What IS real and derivable:
/// `SecurityDecision.requiresCredentialVault` (does the backend need
/// externally-issued credentials at all, e.g. for an AI provider key).
/// `providerIndependent` is a static architectural fact (this codebase
/// never hardcodes an identity vendor anywhere), not a per-app decision.
library;

class AuthenticationModel {
  /// Real, from `SecurityDecision.requiresCredentialVault` — whether
  /// this application's architecture already requires externally-issued
  /// credentials of any kind.
  final bool requiresCredentials;

  /// Static architectural fact, not a per-app derivation: this
  /// specification never names a specific identity provider.
  final bool providerIndependent;

  const AuthenticationModel({
    required this.requiresCredentials,
    this.providerIndependent = true,
  });
}
