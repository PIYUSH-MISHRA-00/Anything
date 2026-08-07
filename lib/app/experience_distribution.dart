/// Experience Distribution Framework — Implementation Specification IS-R53.
/// The ONE owner of Experience MOVEMENT: import, export, packaging,
/// preparation and verification.
///
/// THE DECISION THAT SHAPED THIS MILESTONE — read this first.
///
/// IS-R53 Task 3 says "Introduce ExperienceManifest" and Task 6 says
/// "Introduce ExperiencePackageVerifier". Both already exist and are
/// canonical:
///
///     ExperienceManifest          lib/creation/experience_package.dart:137
///                                 identity, version, minimumRuntimeVersion,
///                                 created/updated, entryPoint, required and
///                                 optional capabilities, network/storage
///                                 mode, category, tags
///     ExperiencePackageValidator  lib/creation/package_validator.dart:31
///                                 size, version, manifest, structure,
///                                 references, limits, integrity
///
/// Introducing either by that name would have produced a SECOND manifest and
/// a SECOND verifier — which the same specification's ABSOLUTE RULES forbid
/// ("DO NOT create … Second verifier … Second package manager"), whose
/// success criteria contradict ("Exactly one Experience Manifest"), and whose
/// own context section rules out ("Treat every implementation already present
/// as canonical. Do NOT replace architecture.").
///
/// So this milestone EXTENDS both instead:
///
///   * [ExperienceDistributionManifest] EMBEDS the canonical
///     `ExperienceManifest` unchanged and adds ONLY fields that exist nowhere
///     else — provenance, package fingerprint, protection state, and
///     marketplace/enterprise/dependency metadata. It re-declares not one
///     canonical field. It is a TRANSPORT ENVELOPE, exactly as Task 3
///     specifies ("Manifest is transport metadata"), never a second identity
///     record.
///
///   * [ExperiencePackageVerifier] DELEGATES all structural and integrity
///     validation to `ExperiencePackageValidator` and adds only what genuinely
///     did not exist: fingerprint agreement and envelope/manifest consistency.
///     It re-implements nothing.
///
/// Both choices are certified (I-57…I-62), so neither can silently become a
/// duplicate later.
///
/// WHAT DISTRIBUTION OWNS, AND WHAT IT MUST NOT TOUCH.
///
///     ExperienceDistributionFramework  MOVES experiences (import/export)
///     ExperiencePackageVerifier        VERIFIES packages
///     ExperienceTrustClassifier        COMPUTES trust        (R52)
///     OperatingSystemGovernanceEngine  CONSUMES trust        (R51)
///     CapabilityPlatform               ENFORCES              (R49/R51)
///     SqliteExperienceRepository       STORES                (canonical)
///     ExperienceEntryPipeline          ACTIVATES             (R45)
///
/// Distribution NEVER classifies trust, NEVER enforces policy and NEVER
/// activates a runtime. Import produces a persisted, provenance-bearing
/// Experience that is READY for activation — the user still has to open it.
/// That is a deliberate safety property: importing something must not run it.
library;

import '../creation/experience_package.dart';
import '../creation/package_validator.dart';
import '../storage/sqlite_experience_repository.dart';
import 'experience_provenance.dart';

/// Where a distributed Experience came from, as a TRANSPORT fact.
///
/// Distinct from `ExperienceOrigin` (R52), which is the PROVENANCE fact the
/// trust classifier consumes. This enum describes the channel; that one
/// describes the resulting authority. Distribution maps channel -> origin in
/// exactly one place ([provenanceFor]) so the mapping is reviewable rather
/// than scattered across import call sites.
enum DistributionSource {
  /// A file the user chose on this device.
  localFile,

  /// Received from another device or app (share sheet, AirDrop, etc.).
  sharedTransfer,

  /// Future marketplace (IS-R53 Task 7 — architecture only).
  marketplace,

  /// Future enterprise deployment (IS-R53 Task 8 — architecture only).
  enterprise,

  /// Future cloud sync.
  cloudSync,
}

/// Future marketplace metadata (Task 7). Recorded and transported; NOTHING
/// consumes it yet, and no marketplace, UI, networking or cloud exists.
/// Architecture only, as instructed.
class MarketplaceMetadata {
  final String? listingId;
  final String? publisherId;
  final String? publisherName;

  /// Signature placeholder. Like R52's, this is a recorded CLAIM — nothing
  /// verifies it, and the verifier deliberately refuses to treat it as proof.
  final String? publisherSignature;

  const MarketplaceMetadata({
    this.listingId,
    this.publisherId,
    this.publisherName,
    this.publisherSignature,
  });

  Map<String, dynamic> toJson() => {
    'listingId': listingId,
    'publisherId': publisherId,
    'publisherName': publisherName,
    'publisherSignature': publisherSignature,
  };

  factory MarketplaceMetadata.fromJson(Map<String, dynamic> json) => MarketplaceMetadata(
    listingId: json['listingId'] as String?,
    publisherId: json['publisherId'] as String?,
    publisherName: json['publisherName'] as String?,
    publisherSignature: json['publisherSignature'] as String?,
  );
}

/// Future enterprise deployment metadata (Task 8). Architecture only.
class EnterpriseDistributionMetadata {
  final String? organizationId;
  final String? deploymentId;

  /// The name of a policy the organisation expects to apply. Recorded ONLY —
  /// governance (R51) remains the sole owner of policy decisions, and nothing
  /// here evaluates or enforces anything.
  final String? policyId;

  const EnterpriseDistributionMetadata({this.organizationId, this.deploymentId, this.policyId});

  Map<String, dynamic> toJson() => {
    'organizationId': organizationId,
    'deploymentId': deploymentId,
    'policyId': policyId,
  };

  factory EnterpriseDistributionMetadata.fromJson(Map<String, dynamic> json) =>
      EnterpriseDistributionMetadata(
        organizationId: json['organizationId'] as String?,
        deploymentId: json['deploymentId'] as String?,
        policyId: json['policyId'] as String?,
      );
}

/// THE transport envelope (IS-R53 Task 3).
///
/// EMBEDS the canonical `ExperienceManifest` rather than re-declaring its
/// fields, and adds only transport metadata that exists nowhere else. This is
/// what keeps "exactly one Experience Manifest" true: there is still exactly
/// one, and this carries it.
class ExperienceDistributionManifest {
  /// The canonical manifest, embedded unchanged.
  final ExperienceManifest manifest;

  /// Envelope format version, so a future format change is detectable rather
  /// than a mysterious parse failure.
  final int envelopeVersion;

  /// R52 provenance, transported with the package.
  final ExperienceProvenance provenance;

  /// Digest of the transported package, recomputed and compared on import.
  final ExperienceFingerprint fingerprint;

  /// Whether the source Experience was Kaalka-protected. Transport metadata
  /// ONLY — `ExperienceProtectionService` remains the sole owner of
  /// protection, and distribution neither protects nor unprotects anything.
  final bool wasProtected;

  final MarketplaceMetadata? marketplace;
  final EnterpriseDistributionMetadata? enterprise;

  /// Future dependency metadata. Declared so the envelope format does not
  /// need a version bump when dependencies arrive; nothing resolves them.
  final List<String> dependencies;

  const ExperienceDistributionManifest({
    required this.manifest,
    this.envelopeVersion = currentEnvelopeVersion,
    this.provenance = const ExperienceProvenance(),
    this.fingerprint = ExperienceFingerprint.none,
    this.wasProtected = false,
    this.marketplace,
    this.enterprise,
    this.dependencies = const [],
  });

  static const int currentEnvelopeVersion = 1;

  String get experienceId => manifest.experienceId;

  Map<String, dynamic> toJson() => {
    'envelopeVersion': envelopeVersion,
    'manifest': manifest.toJson(),
    'provenance': provenance.toJson(),
    'fingerprint': fingerprint.value,
    'wasProtected': wasProtected,
    'marketplace': marketplace?.toJson(),
    'enterprise': enterprise?.toJson(),
    'dependencies': dependencies,
  };

  factory ExperienceDistributionManifest.fromJson(Map<String, dynamic> json) {
    return ExperienceDistributionManifest(
      envelopeVersion: (json['envelopeVersion'] as num?)?.toInt() ?? 0,
      manifest: ExperienceManifest.fromJson(Map<String, dynamic>.from(json['manifest'] as Map)),
      provenance: json['provenance'] == null
          ? const ExperienceProvenance()
          : ExperienceProvenance.fromJson(Map<String, dynamic>.from(json['provenance'] as Map)),
      fingerprint: ExperienceFingerprint(json['fingerprint'] as String? ?? ''),
      wasProtected: json['wasProtected'] == true,
      marketplace: json['marketplace'] == null
          ? null
          : MarketplaceMetadata.fromJson(Map<String, dynamic>.from(json['marketplace'] as Map)),
      enterprise: json['enterprise'] == null
          ? null
          : EnterpriseDistributionMetadata.fromJson(Map<String, dynamic>.from(json['enterprise'] as Map)),
      dependencies: [for (final d in (json['dependencies'] as List? ?? [])) d as String],
    );
  }
}

/// A complete transportable Experience: envelope + package.
class ExperienceDistributionPackage {
  final ExperienceDistributionManifest envelope;
  final ExperiencePackage package;

  const ExperienceDistributionPackage({required this.envelope, required this.package});

  Map<String, dynamic> toJson() => {
    'envelope': envelope.toJson(),
    'package': package.toJson(),
  };
}

/// Why a verification failed. A closed vocabulary so a caller can react to a
/// reason rather than parse a message.
enum VerificationFailure {
  malformed,
  unsupportedEnvelopeVersion,
  invalidPackage,
  fingerprintMismatch,
  identityMismatch,
}

class PackageVerificationResult {
  final bool isValid;
  final List<VerificationFailure> failures;
  final List<String> messages;

  const PackageVerificationResult({required this.isValid, this.failures = const [], this.messages = const []});

  static const PackageVerificationResult valid = PackageVerificationResult(isValid: true);

  factory PackageVerificationResult.invalid(VerificationFailure failure, String message) =>
      PackageVerificationResult(isValid: false, failures: [failure], messages: [message]);
}

/// THE package verifier (IS-R53 Task 6).
///
/// DELEGATES every structural and integrity check to the pre-existing
/// `ExperiencePackageValidator` and adds ONLY what did not exist: fingerprint
/// agreement, envelope version support, and envelope/manifest identity
/// consistency. It re-implements no validation rule.
///
/// It NEVER computes trust and NEVER enforces policy. Verification answers
/// "is this package intact and internally consistent"; trust answers "how much
/// authority does its origin earn". Conflating them would let a well-formed
/// package argue itself into privileges — which is precisely why R52 kept
/// classification separate, and why the verifier is forbidden from touching it
/// (certified I-59).
class ExperiencePackageVerifier {
  const ExperiencePackageVerifier();

  PackageVerificationResult verify(ExperienceDistributionPackage distribution) {
    final envelope = distribution.envelope;

    if (envelope.envelopeVersion <= 0 ||
        envelope.envelopeVersion > ExperienceDistributionManifest.currentEnvelopeVersion) {
      return PackageVerificationResult.invalid(
        VerificationFailure.unsupportedEnvelopeVersion,
        'unsupported envelope version ${envelope.envelopeVersion}',
      );
    }

    if (envelope.experienceId.isEmpty || distribution.package.manifest.experienceId.isEmpty) {
      return PackageVerificationResult.invalid(
        VerificationFailure.malformed,
        'envelope or package is missing an experienceId',
      );
    }

    if (envelope.experienceId != distribution.package.manifest.experienceId) {
      return PackageVerificationResult.invalid(
        VerificationFailure.identityMismatch,
        'envelope identity "${envelope.experienceId}" does not match package '
        '"${distribution.package.manifest.experienceId}"',
      );
    }

    // Structure, size, references, limits and integrity — delegated, never
    // re-implemented.
    final validation = ExperiencePackageValidator.validate(distribution.package);
    if (!validation.isValid) {
      return PackageVerificationResult(
        isValid: false,
        failures: const [VerificationFailure.invalidPackage],
        messages: validation.errors,
      );
    }

    // The one genuinely new check: does the transported package still hash to
    // what the envelope claims? An absent fingerprint is not a failure —
    // older envelopes may not carry one — but a PRESENT and WRONG one is.
    if (envelope.fingerprint.isPresent) {
      final actual = ExperiencePackage.computeIntegrityHash(distribution.package);
      if (actual != envelope.fingerprint.value) {
        return PackageVerificationResult.invalid(
          VerificationFailure.fingerprintMismatch,
          'package fingerprint does not match the envelope',
        );
      }
    }

    return PackageVerificationResult.valid;
  }
}

/// Outcome of an import.
class ImportResult {
  final bool succeeded;
  final String? experienceId;
  final ExperienceProvenance? provenance;
  final PackageVerificationResult? verification;
  final String? error;

  const ImportResult._({
    required this.succeeded,
    this.experienceId,
    this.provenance,
    this.verification,
    this.error,
  });

  factory ImportResult.success({required String experienceId, required ExperienceProvenance provenance}) =>
      ImportResult._(succeeded: true, experienceId: experienceId, provenance: provenance);

  factory ImportResult.rejected(PackageVerificationResult verification) =>
      ImportResult._(succeeded: false, verification: verification, error: verification.messages.join('; '));

  factory ImportResult.failed(String error) => ImportResult._(succeeded: false, error: error);
}

/// THE one owner of Experience movement (IS-R53 Task 2).
///
/// Import, export, packaging and preparation. It does NOT classify trust, does
/// NOT enforce policy, and does NOT activate runtimes — each of those has an
/// owner already, and distribution calls none of them.
class ExperienceDistributionFramework {
  final SqliteExperienceRepository repository;
  final ExperiencePackageVerifier verifier;

  const ExperienceDistributionFramework({
    required this.repository,
    this.verifier = const ExperiencePackageVerifier(),
  });

  /// Maps a transport CHANNEL to the R52 PROVENANCE it earns.
  ///
  /// The single place this mapping exists, so it is reviewable rather than
  /// scattered across import call sites. Note what it does NOT do: it assigns
  /// an ORIGIN, never a trust level. `ExperienceTrustClassifier` derives trust
  /// from this, and distribution never calls it (certified I-58).
  static ExperienceProvenance provenanceFor(
    DistributionSource source, {
    DateTime? at,
    String? installationSource,
    String? author,
    ExperienceFingerprint? fingerprint,
    MarketplaceMetadata? marketplace,
  }) {
    switch (source) {
      case DistributionSource.marketplace:
        return ExperienceProvenance(
          origin: ExperienceOrigin.marketplace,
          importedAt: at,
          installationSource: installationSource,
          author: author ?? marketplace?.publisherName,
          signature: marketplace?.publisherSignature,
          marketplaceId: marketplace?.listingId,
          fingerprint: fingerprint ?? ExperienceFingerprint.none,
          // Deliberately NOT `verified`: nothing has checked the publisher
          // signature. R52's classifier treats an unverified marketplace
          // origin as merely `imported`, which is the honest position until a
          // real verifier exists.
        );
      case DistributionSource.enterprise:
      case DistributionSource.localFile:
      case DistributionSource.sharedTransfer:
      case DistributionSource.cloudSync:
        return ExperienceProvenance.imported(
          at: at,
          source: installationSource ?? source.name,
          author: author,
          fingerprint: fingerprint,
        );
    }
  }

  /// EXPORT (Task 5) — packages an already-persisted Experience for transport.
  ///
  /// Reads current metadata, provenance, fingerprint and protection state from
  /// the repository. Changes no persistence and mutates nothing.
  Future<ExperienceDistributionPackage?> export(String experienceId, {ExperiencePackage? package}) async {
    final metadata = await repository.getMetadata(experienceId);
    if (metadata == null) return null;

    final resolved = package ?? await repository.getPackage(experienceId);
    if (resolved == null) return null;

    return ExperienceDistributionPackage(
      envelope: ExperienceDistributionManifest(
        manifest: resolved.manifest,
        provenance: metadata.provenance,
        fingerprint: ExperienceFingerprint(ExperiencePackage.computeIntegrityHash(resolved)),
        wasProtected: metadata.isProtected,
      ),
      package: resolved,
    );
  }

  /// IMPORT (Task 4) — verify, assign provenance, persist. Ready for
  /// activation.
  ///
  /// IMPORT NEVER ACTIVATES A RUNTIME. It returns a persisted, provenance-
  /// bearing Experience and stops. Importing something must not run it —
  /// activation stays with `ExperienceEntryPipeline` (R45) and requires a
  /// deliberate user action.
  ///
  /// Trust is NOT computed here. The provenance this assigns is what
  /// `ExperienceTrustClassifier` (R52) will later classify, and what
  /// governance (R51) will consume — distribution starts that chain and does
  /// not participate in the rest of it.
  Future<ImportResult> import(
    ExperienceDistributionPackage distribution, {
    DistributionSource source = DistributionSource.localFile,
    String? installationSource,
    DateTime? at,
  }) async {
    final verification = verifier.verify(distribution);
    if (!verification.isValid) return ImportResult.rejected(verification);

    final provenance = provenanceFor(
      source,
      at: at ?? DateTime.now(),
      installationSource: installationSource,
      author: distribution.envelope.provenance.author,
      fingerprint: distribution.envelope.fingerprint.isPresent
          ? distribution.envelope.fingerprint
          : ExperienceFingerprint(ExperiencePackage.computeIntegrityHash(distribution.package)),
      marketplace: distribution.envelope.marketplace,
    );

    final manifest = distribution.package.manifest;
    final now = at ?? DateTime.now();

    try {
      await repository.savePackage(distribution.package);
      await repository.saveMetadata(
        ExperienceMetadataRecord(
          id: manifest.experienceId,
          name: manifest.name,
          description: manifest.description,
          category: manifest.category,
          createdAt: manifest.createdAt,
          updatedAt: now,
          packageVersion: manifest.version,
          provenance: provenance,
          // Protection state is NOT carried across: an imported package is
          // not protected on this device until this device protects it.
          // `ExperienceProtectionService` owns that, and distribution must not
          // fabricate a protected state it cannot honour.
          isProtected: false,
        ),
      );
    } catch (e) {
      return ImportResult.failed(e.toString());
    }

    return ImportResult.success(experienceId: manifest.experienceId, provenance: provenance);
  }
}
