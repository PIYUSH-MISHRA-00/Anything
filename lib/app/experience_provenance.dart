/// Experience Identity, Provenance and Trust Classification —
/// Implementation Specification IS-R52.
///
/// R51 built a governance framework whose trust model was dormant: every
/// Experience defaulted to `local` because nothing computed anything else.
/// R52 supplies the missing layer — **trust is now COMPUTED, not assumed**.
///
/// THE OWNERSHIP SPLIT THIS MILESTONE EXISTS TO ESTABLISH:
///
///     ExperienceTrustClassifier   COMPUTES trust from provenance
///     OperatingSystemGovernanceEngine  CONSUMES trust, decides policy
///     CapabilityPlatform          ENFORCES the decision
///     SqliteExperienceRepository  STORES provenance
///
/// Each of those four verbs belongs to exactly one owner, and the
/// certification checks all four boundaries (I-52..I-55). In particular the
/// governance engine must never compute trust — if it did, "governance
/// consumes trust" would collapse into "governance decides everything", and
/// the clean R51 split would be gone in one commit.
///
/// DEPENDENCY DIRECTION IS ONE-WAY AND DELIBERATE. This library imports
/// `governance_engine.dart` for `ExperienceTrustLevel`; governance imports
/// nothing at all and does not know this file exists. R51's invariant I-49
/// (the governance engine's import list must be EMPTY) therefore still holds
/// unchanged — the classifier depends on the vocabulary, never the reverse.
///
/// NOT THE SAME THING AS `lib/experience_identity/` (R22). That library owns
/// `ScreenIdentity`/`ActionIdentity` — the identity of screens and actions
/// *inside* an Experience, used by the compiler equivalence comparator. This
/// file owns the identity of an *Experience itself*: where it came from, who
/// authored it, and how much it is trusted. Two genuinely different subjects
/// that happen to share the word "identity"; both are pinned in certification
/// so the distinction is visible rather than rediscovered.
library;

import 'governance_engine.dart';

/// Where an Experience came from. The single source of truth for
/// classification — everything else in provenance is corroborating detail.
enum ExperienceOrigin {
  /// Authored on this device by this user, through the normal creation flow.
  createdLocally,

  /// Shipped with Anything.
  firstParty,

  /// Brought in from outside this device.
  imported,

  /// Obtained from a marketplace (future).
  marketplace,

  /// Provenance is genuinely not known — a record predating R52, or one whose
  /// origin could not be established. Deliberately NOT merged with
  /// `imported`: "we do not know" and "we know it came from elsewhere" are
  /// different facts and must classify differently.
  unknown,
}

/// How far verification has progressed. Orthogonal to origin: a marketplace
/// Experience can be unverified, and a locally-created one can be quarantined.
enum VerificationState {
  unverified,
  verified,

  /// Verification was withdrawn after the fact.
  revoked,

  /// Explicitly held back by a user or by policy.
  quarantined,
}

/// A deterministic content fingerprint.
///
/// Deliberately a wrapper over a caller-supplied digest rather than a hashing
/// implementation: hashing already exists (`KnowledgeResource.computeHash`,
/// `ExperiencePackage.computeIntegrityHash`) and R52 introduces no second
/// one. This type exists to give that digest a *name* and a *type*, so a
/// fingerprint cannot be silently confused with an id.
class ExperienceFingerprint {
  final String value;

  const ExperienceFingerprint(this.value);

  /// Absent fingerprint — a record that predates fingerprinting. Distinct
  /// from an empty digest.
  static const ExperienceFingerprint none = ExperienceFingerprint('');

  bool get isPresent => value.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is ExperienceFingerprint && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ExperienceFingerprint($value)';
}

/// Everything known about where an Experience came from.
///
/// Immutable. Transitions ([verified], [revoked], [quarantined], [promoted],
/// [demoted]) return a NEW provenance rather than mutating — so a trust change
/// is always an explicit, traceable replacement rather than a silent field
/// write somewhere in a call stack (IS-R52 Task 8).
class ExperienceProvenance {
  final ExperienceOrigin origin;
  final DateTime? createdAt;
  final DateTime? importedAt;

  /// Free-text description of where an import came from (a file path, a
  /// share sheet, a future sync peer). Recorded, never parsed for authority.
  final String? installationSource;

  final String? author;

  /// Signature placeholder (IS-R52 Task 2). R52 records it; nothing verifies
  /// it yet, and `verificationState` is NOT derived from it — a stored
  /// signature is a claim, not proof, until something checks it.
  final String? signature;

  final VerificationState verificationState;

  /// Future marketplace / cloud identifiers. Recorded so the schema does not
  /// need another migration when those arrive.
  final String? marketplaceId;
  final String? cloudId;

  final ExperienceFingerprint fingerprint;

  const ExperienceProvenance({
    this.origin = ExperienceOrigin.unknown,
    this.createdAt,
    this.importedAt,
    this.installationSource,
    this.author,
    this.signature,
    this.verificationState = VerificationState.unverified,
    this.marketplaceId,
    this.cloudId,
    this.fingerprint = ExperienceFingerprint.none,
  });

  /// Provenance for an Experience authored locally through the normal flow.
  factory ExperienceProvenance.createdLocally({
    DateTime? at,
    String? author,
    ExperienceFingerprint? fingerprint,
  }) {
    return ExperienceProvenance(
      origin: ExperienceOrigin.createdLocally,
      createdAt: at,
      author: author,
      fingerprint: fingerprint ?? ExperienceFingerprint.none,
    );
  }

  /// Provenance for an Experience brought in from outside this device.
  factory ExperienceProvenance.imported({
    DateTime? at,
    String? source,
    String? author,
    String? signature,
    ExperienceFingerprint? fingerprint,
  }) {
    return ExperienceProvenance(
      origin: ExperienceOrigin.imported,
      importedAt: at,
      installationSource: source,
      author: author,
      signature: signature,
      fingerprint: fingerprint ?? ExperienceFingerprint.none,
    );
  }

  /// Provenance for an Experience shipped with Anything.
  factory ExperienceProvenance.firstParty({String? author}) {
    return ExperienceProvenance(
      origin: ExperienceOrigin.firstParty,
      author: author,
      verificationState: VerificationState.verified,
    );
  }

  ExperienceProvenance copyWith({
    ExperienceOrigin? origin,
    DateTime? createdAt,
    DateTime? importedAt,
    String? installationSource,
    String? author,
    String? signature,
    VerificationState? verificationState,
    String? marketplaceId,
    String? cloudId,
    ExperienceFingerprint? fingerprint,
  }) {
    return ExperienceProvenance(
      origin: origin ?? this.origin,
      createdAt: createdAt ?? this.createdAt,
      importedAt: importedAt ?? this.importedAt,
      installationSource: installationSource ?? this.installationSource,
      author: author ?? this.author,
      signature: signature ?? this.signature,
      verificationState: verificationState ?? this.verificationState,
      marketplaceId: marketplaceId ?? this.marketplaceId,
      cloudId: cloudId ?? this.cloudId,
      fingerprint: fingerprint ?? this.fingerprint,
    );
  }

  // ── Transitions (Task 8) ────────────────────────────────────────────────

  ExperienceProvenance verified() =>
      copyWith(verificationState: VerificationState.verified);
  ExperienceProvenance revoked() =>
      copyWith(verificationState: VerificationState.revoked);
  ExperienceProvenance quarantined() =>
      copyWith(verificationState: VerificationState.quarantined);

  /// Lift a quarantine or revocation back to plain unverified. Deliberately
  /// does NOT jump straight to `verified`: promotion restores eligibility,
  /// it does not manufacture proof.
  ExperienceProvenance promoted() =>
      copyWith(verificationState: VerificationState.unverified);

  ExperienceProvenance demoted() => quarantined();

  Map<String, dynamic> toJson() => {
    'origin': origin.name,
    'createdAt': createdAt?.toIso8601String(),
    'importedAt': importedAt?.toIso8601String(),
    'installationSource': installationSource,
    'author': author,
    'signature': signature,
    'verificationState': verificationState.name,
    'marketplaceId': marketplaceId,
    'cloudId': cloudId,
    'fingerprint': fingerprint.value,
  };

  /// Tolerant of missing and unrecognised values, because it must read rows
  /// written before R52 existed. An unreadable origin becomes `unknown`
  /// rather than throwing or guessing.
  factory ExperienceProvenance.fromJson(Map<String, dynamic> json) {
    return ExperienceProvenance(
      origin: ExperienceOrigin.values.firstWhere(
        (o) => o.name == json['origin'],
        orElse: () => ExperienceOrigin.unknown,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      importedAt: DateTime.tryParse(json['importedAt'] as String? ?? ''),
      installationSource: json['installationSource'] as String?,
      author: json['author'] as String?,
      signature: json['signature'] as String?,
      verificationState: VerificationState.values.firstWhere(
        (v) => v.name == json['verificationState'],
        orElse: () => VerificationState.unverified,
      ),
      marketplaceId: json['marketplaceId'] as String?,
      cloudId: json['cloudId'] as String?,
      fingerprint: ExperienceFingerprint(json['fingerprint'] as String? ?? ''),
    );
  }
}

/// The canonical identity of an Experience: which one it is, what it contains,
/// and where it came from.
class ExperienceIdentity {
  final String experienceId;
  final ExperienceProvenance provenance;

  const ExperienceIdentity({
    required this.experienceId,
    required this.provenance,
  });

  ExperienceFingerprint get fingerprint => provenance.fingerprint;
  ExperienceOrigin get origin => provenance.origin;
}

/// THE one thing that computes trust (IS-R52 Task 4).
///
/// Pure and deterministic: provenance in, trust level out. It holds no
/// storage, performs no I/O, and — critically — **enforces nothing**. It does
/// not know what a capability is, cannot deny anything, and has no opinion
/// about policy. Governance consumes what it returns; `CapabilityPlatform`
/// enforces what governance decides.
///
/// That separation is the whole design. A classifier that could also enforce
/// would be a second governance engine; a governance engine that could also
/// classify would make provenance decorative. Both directions are certified
/// (I-52, I-53).
class ExperienceTrustClassifier {
  const ExperienceTrustClassifier();

  /// Computes the trust level for [provenance].
  ///
  /// VERIFICATION STATE OUTRANKS ORIGIN, in one direction only: it can lower
  /// trust but never raise it. A quarantined or revoked Experience is
  /// untrusted no matter how it arrived — that is what quarantine means. But
  /// a `verified` state does not promote an imported Experience to
  /// `verified` trust on its own, because R52 verifies nothing yet: the
  /// signature field is a recorded claim, and treating an unchecked claim as
  /// proof would be the exact "assumed rather than computed" failure this
  /// milestone exists to remove.
  ExperienceTrustLevel classify(ExperienceProvenance provenance) {
    switch (provenance.verificationState) {
      case VerificationState.quarantined:
      case VerificationState.revoked:
        return ExperienceTrustLevel.untrusted;
      case VerificationState.unverified:
      case VerificationState.verified:
        break;
    }

    switch (provenance.origin) {
      case ExperienceOrigin.firstParty:
        return ExperienceTrustLevel.trusted;

      case ExperienceOrigin.marketplace:
        // Only a marketplace Experience whose verification really succeeded
        // reaches `verified`; an unverified one is treated as merely
        // imported.
        return provenance.verificationState == VerificationState.verified
            ? ExperienceTrustLevel.verified
            : ExperienceTrustLevel.imported;

      case ExperienceOrigin.createdLocally:
        return ExperienceTrustLevel.local;

      case ExperienceOrigin.imported:
        return ExperienceTrustLevel.imported;

      case ExperienceOrigin.unknown:
        // "We do not know where this came from" is a weaker position than
        // "we know it was imported", so it classifies lower — but not
        // `untrusted`, which is reserved for an explicit human or policy
        // decision rather than an absence of information.
        return ExperienceTrustLevel.experimental;
    }
  }

  /// Convenience for callers holding a full identity.
  ExperienceTrustLevel classifyIdentity(ExperienceIdentity identity) =>
      classify(identity.provenance);
}
