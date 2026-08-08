/// Canonical Experience Package codec — Implementation Specification IS-R60.
/// The ONE reader and the ONE writer for a transportable Experience package.
///
/// WHAT THE PHASE 1 AUDIT FOUND, AND WHAT IT CHANGED ABOUT THIS MILESTONE.
///
/// IS-R60 Phase 2 says "Create ONE canonical ExperienceManifest" and Phase 6
/// says "Implement package validator". BOTH ALREADY EXIST AND ARE CERTIFIED:
///
///     ExperienceManifest          lib/creation/experience_package.dart:137
///                                 certified exactly-one by I-60 (IS-R53)
///     ExperiencePackageValidator  lib/creation/package_validator.dart:31
///                                 the ONE structural validator, certified by
///                                 I-59 (R53) and I-65 (R54)
///     ExperienceDistributionManifest  the transport envelope that EMBEDS the
///                                 canonical manifest (IS-R53)
///     PackageIntegrity / computeIntegrityHash   checksums and fingerprints
///
/// Creating either under those names would produce a second manifest and a
/// second validator — which this same specification forbids in its ABSOLUTE
/// RULES and contradicts in its own success criteria ("Exactly one manifest",
/// "Exactly one validator"). So R60 creates NEITHER.
///
/// WHAT WAS GENUINELY MISSING, and is what this file adds:
///
///   * `ExperienceDistributionPackage` had `toJson()` and **NO `fromJson`**.
///     A package could be written and never read back — a one-way street that
///     has existed since IS-R53.
///   * There was no container format, no reader and no writer of any kind.
///     Nothing in `lib/` turned a package into bytes or bytes into a package.
///
/// That is the concrete reason R53's gap G-25 — "a user still cannot import an
/// Experience" — has stayed open through four milestones. The pipeline was
/// complete on package OBJECTS and had no way to obtain one.
///
/// OWNERSHIP. This file owns SERIALISATION and nothing else.
///
///     ExperiencePackageWriter     MODEL  -> BYTES
///     ExperiencePackageReader     BYTES  -> MODEL
///     ExperiencePackageValidator  VALIDATES STRUCTURE   (canonical, delegated to)
///     ExperienceDistributionFramework  MOVES            (R53)
///     ExperienceInstallationFramework  INSTALLS         (R54)
///     ExperienceCommitFramework        COMMITS          (R55)
///     ExperienceTrustClassifier        COMPUTES TRUST   (R52)
///
/// The reader NEVER installs, NEVER activates and NEVER computes trust. It
/// turns bytes into a model and stops. That is a safety property, not an
/// omission: parsing something must not run it, and a well-formed package must
/// not be able to argue itself into authority by being well-formed.
///
/// NO NETWORKING, NO MARKETPLACE, NO ENCRYPTION, NO NEW DEPENDENCY. The
/// container is canonical JSON because `archive`/zip is not a dependency of
/// this project and R60 is forbidden from adding one. A binary container can
/// replace the encoding later without touching the manifest, the validator or
/// any caller — which is why the format carries an explicit version.
library;

import 'dart:convert';

import 'experience_package.dart';
import 'package_validator.dart';

/// The on-the-wire format itself.
///
/// Deliberately tiny: a magic string, a version, and the rule that the payload
/// is canonical JSON. Everything else is the manifest's job.
class ExperiencePackageFormat {
  const ExperiencePackageFormat._();

  /// Identifies the container regardless of file extension, so a truncated or
  /// unrelated file fails loudly instead of half-parsing.
  static const String magic = 'ANYTHING-EXPERIENCE-PACKAGE';

  /// Container format version. Distinct from `experiencePackageVersion` (the
  /// package MODEL version) and from the R53 envelope version — a container
  /// can change encoding without the model changing, and vice versa.
  static const int version = 1;

  /// Conventional file extension. Nothing in this file performs file I/O;
  /// `RealFileService` (IS-R49) owns that.
  static const String extension = '.anything';

  static const String magicKey = 'format';
  static const String versionKey = 'formatVersion';
  static const String checksumKey = 'checksum';
  static const String payloadKey = 'payload';

  /// Reserved for a future signature block. Declared so adding signing does
  /// not require a container version bump, and READ BACK unchanged by the
  /// reader so a signed package written by a future build round-trips through
  /// this one without losing the block.
  static const String signatureKey = 'signature';

  /// Reserved for forward-compatible extension. Same rationale.
  static const String extensionsKey = 'extensions';
}

/// Why a package could not be read. A closed vocabulary, so a caller reacts to
/// a reason rather than parsing a message.
enum PackageReadFailure {
  /// Not JSON, or not an object.
  malformed,

  /// Missing or wrong magic — this is not an Experience package.
  notAPackage,

  /// The container format is newer than this build understands.
  unsupportedFormatVersion,

  /// The stored checksum does not match the payload.
  checksumMismatch,

  /// The payload is structurally invalid (delegated to the canonical
  /// validator).
  invalidPackage,
}

/// Outcome of a read. Either a package or a reason, never both.
class PackageReadResult {
  final ExperiencePackage? package;
  final ExperienceManifest? manifest;

  /// Signature block as read, unchanged. Null when absent. Nothing verifies
  /// it — see [ExperiencePackageReader].
  final Map<String, dynamic>? signature;

  /// Forward-compatible extension area as read, unchanged.
  final Map<String, dynamic>? extensions;

  final PackageReadFailure? failure;
  final List<String> messages;

  const PackageReadResult._({
    this.package,
    this.manifest,
    this.signature,
    this.extensions,
    this.failure,
    this.messages = const [],
  });

  bool get succeeded => package != null;

  factory PackageReadResult.success({
    required ExperiencePackage package,
    Map<String, dynamic>? signature,
    Map<String, dynamic>? extensions,
  }) => PackageReadResult._(
    package: package,
    manifest: package.manifest,
    signature: signature,
    extensions: extensions,
  );

  factory PackageReadResult.failed(
    PackageReadFailure failure,
    String message, {
    List<String> details = const [],
  }) => PackageReadResult._(failure: failure, messages: [message, ...details]);
}

/// THE package writer (IS-R60 Phase 5) — model to bytes.
///
/// DETERMINISTIC BY CONSTRUCTION. The same package always produces
/// byte-identical output: every map is emitted with its keys sorted, so the
/// result does not depend on insertion order, hash order, or the order a
/// caller happened to build a map in. That is what makes a checksum, and later
/// a signature, meaningful — a non-deterministic writer would produce a
/// different digest for the same Experience on every run.
///
/// It writes bytes and returns them. It performs NO file I/O — `RealFileService`
/// (IS-R49) owns that — and it never exports directly to a UI.
class ExperiencePackageWriter {
  const ExperiencePackageWriter();

  /// Serialises [package] into the canonical container.
  ///
  /// [signature] and [extensions] are carried through verbatim. This writer
  /// signs nothing and interprets neither; they exist so a future signing
  /// implementation does not need a format change.
  String write(
    ExperiencePackage package, {
    Map<String, dynamic>? signature,
    Map<String, dynamic>? extensions,
  }) {
    final payload = _canonical(package.toJson());
    final container = <String, dynamic>{
      ExperiencePackageFormat.magicKey: ExperiencePackageFormat.magic,
      ExperiencePackageFormat.versionKey: ExperiencePackageFormat.version,
      ExperiencePackageFormat.checksumKey:
          ExperiencePackage.computeIntegrityHash(package),
      ExperiencePackageFormat.payloadKey: payload,
      if (signature != null)
        ExperiencePackageFormat.signatureKey: _canonical(signature),
      if (extensions != null)
        ExperiencePackageFormat.extensionsKey: _canonical(extensions),
    };
    return jsonEncode(container);
  }

  /// Recursively rebuilds every map with sorted keys.
  ///
  /// Lists keep their order — element order is data, not formatting, and
  /// reordering it would change the Experience.
  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _canonical(value[k])};
    }
    if (value is List) return [for (final v in value) _canonical(v)];
    return value;
  }
}

/// THE package reader (IS-R60 Phase 4) — bytes to model.
///
/// It opens the container, checks the format, verifies the checksum, delegates
/// structural validation to the canonical `ExperiencePackageValidator`, and
/// returns a model.
///
/// IT NEVER INSTALLS, NEVER ACTIVATES AND NEVER COMPUTES TRUST.
///
/// The trust point is worth stating explicitly: this reader will happily parse
/// a package carrying a signature block and reports it **unread and
/// unverified**. Nothing here checks a signature, and the classifier (IS-R52)
/// deliberately refuses to treat a signature's mere presence as proof. A
/// well-formed package earns no authority by being well-formed.
class ExperiencePackageReader {
  const ExperiencePackageReader();

  /// The canonical structural validator. Injectable only so a test can observe
  /// delegation; it defaults to the one canonical validator and this reader
  /// re-implements no rule of its own.
  PackageValidationResult _validate(ExperiencePackage package) =>
      ExperiencePackageValidator.validate(package);

  PackageReadResult read(String bytes) {
    Object? decoded;
    try {
      decoded = jsonDecode(bytes);
    } catch (e) {
      return PackageReadResult.failed(
        PackageReadFailure.malformed,
        'not valid JSON: $e',
      );
    }
    if (decoded is! Map) {
      return PackageReadResult.failed(
        PackageReadFailure.malformed,
        'container is not an object',
      );
    }
    final container = Map<String, dynamic>.from(decoded);

    if (container[ExperiencePackageFormat.magicKey] !=
        ExperiencePackageFormat.magic) {
      return PackageReadResult.failed(
        PackageReadFailure.notAPackage,
        'missing or wrong format marker; this is not an Experience package',
      );
    }

    final formatVersion =
        (container[ExperiencePackageFormat.versionKey] as num?)?.toInt() ?? 0;
    if (formatVersion <= 0 || formatVersion > ExperiencePackageFormat.version) {
      return PackageReadResult.failed(
        PackageReadFailure.unsupportedFormatVersion,
        'container format v$formatVersion is not supported by this build '
        '(supported: v${ExperiencePackageFormat.version})',
      );
    }

    final payload = container[ExperiencePackageFormat.payloadKey];
    if (payload is! Map) {
      return PackageReadResult.failed(
        PackageReadFailure.malformed,
        'container has no package payload',
      );
    }

    ExperiencePackage package;
    try {
      package = ExperiencePackage.fromJson(Map<String, dynamic>.from(payload));
    } catch (e) {
      return PackageReadResult.failed(
        PackageReadFailure.malformed,
        'payload is not a readable Experience package: $e',
      );
    }

    // The checksum is verified against the REBUILT package, not against the
    // raw text. That catches a payload edited in transit even when the edit
    // leaves valid JSON behind.
    final claimed = container[ExperiencePackageFormat.checksumKey];
    if (claimed is String && claimed.isNotEmpty) {
      final actual = ExperiencePackage.computeIntegrityHash(package);
      if (actual != claimed) {
        return PackageReadResult.failed(
          PackageReadFailure.checksumMismatch,
          'package checksum does not match the container',
        );
      }
    }

    // Structure, size, references, limits and integrity — DELEGATED to the one
    // canonical validator, never re-implemented here.
    final validation = _validate(package);
    if (!validation.isValid) {
      return PackageReadResult.failed(
        PackageReadFailure.invalidPackage,
        'package failed structural validation',
        details: validation.errors,
      );
    }

    final signature = container[ExperiencePackageFormat.signatureKey];
    final extensions = container[ExperiencePackageFormat.extensionsKey];
    return PackageReadResult.success(
      package: package,
      signature: signature is Map ? Map<String, dynamic>.from(signature) : null,
      extensions: extensions is Map
          ? Map<String, dynamic>.from(extensions)
          : null,
    );
  }
}
