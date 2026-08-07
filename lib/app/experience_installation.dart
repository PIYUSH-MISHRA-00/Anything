/// Experience Installation Framework — Implementation Specification IS-R54.
/// The ONE owner of COMMITTING an Experience to this device: install, upgrade,
/// downgrade, repair, rollback, dependency preparation and compatibility
/// validation.
///
/// WHERE THIS SITS. R53 gave the system a producer that MOVES experiences but
/// left it also doing the committing. R54 takes the commit back:
///
///     ExperienceDistributionFramework  MOVES      (import/export)   R53
///     ExperienceInstallationFramework  COMMITS    (this file)       R54
///     SqliteExperienceRepository       STORES     (canonical)
///     ExperienceTrustClassifier        COMPUTES trust               R52
///     OperatingSystemGovernanceEngine  DECIDES                      R51
///     CapabilityPlatform               ENFORCES                     R49/R51
///     ExperienceEntryPipeline          ACTIVATES                    R45
///     ExperienceProtectionService      PROTECTS                     (Kaalka)
///
/// THE THREE THINGS THIS FILE DELIBERATELY DOES NOT DO.
///
///   * It never ACTIVATES. `install()` returns a committed Experience and
///     stops. Installing something must not run it — the same safety property
///     R53 established for import, now enforced one layer lower (certified
///     I-64: this file may not name `ExperienceEntryPipeline`,
///     `ExperienceHostScreen`, `Navigator` or `AnythingRuntime`).
///
///   * It never COMPUTES TRUST and never ENFORCES POLICY. It receives an
///     `ExperienceProvenance` and stores it. Whether that provenance earns any
///     authority is R52's answer, and what to do about it is R51's.
///
///   * It never ENCRYPTS. Task 7 has the installer REQUEST protection after a
///     successful commit; `ExperienceProtectionService` performs it. There is
///     still exactly one crypto importer in `lib/` (I-21a, unchanged).
///
/// WHAT ALREADY EXISTED, AND WAS NOT DUPLICATED.
///
/// IS-R54's ABSOLUTE RULES forbid a "Second migration engine". One already
/// exists and is canonical:
///
///     DataMigrationPlan / MigrationValidator  lib/storage/migration.dart
///     MigrationExecutor                       lib/storage/migration_executor.dart
///
/// `MigrationExecutor` runs typed, transactional `ALTER TABLE`/`CREATE TABLE`
/// operations against a real per-Experience SQLite database. So Task 6
/// ("migration preparation … architecture only") is implemented as exactly
/// that: [MigrationRequirement] RECORDS that an upgrade crosses a data-schema
/// boundary and names the from/to versions. It plans no operations and
/// executes nothing. Building operations here would mean inventing a schema
/// diff this milestone cannot honestly compute, and running them would make
/// this a second migration engine.
///
/// Likewise `ExperiencePackageValidator` (lib/creation/package_validator.dart)
/// is the ONE structural validator: [InstallationTransaction.validate]
/// delegates to it and re-implements no rule (certified I-65).
library;

import '../creation/experience_package.dart';
import '../creation/package_validator.dart';
import '../security/protection_service.dart';
import '../storage/sqlite_experience_repository.dart';
import 'experience_commit.dart';
import 'experience_provenance.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TASK 3 — COMPATIBILITY. Evaluate only. Never install.
// ─────────────────────────────────────────────────────────────────────────────

/// Why an Experience is not installable here. A closed vocabulary so a caller
/// can react to a reason instead of parsing a message.
enum IncompatibilityReason {
  /// The package needs a newer runtime than this build provides.
  runtimeTooOld,

  /// `minimumRuntimeVersion` / `version` is not a parseable version string.
  malformedVersion,

  /// The manifest is missing something installation depends on.
  manifestIncomplete,

  /// A required capability is not registered on this platform.
  capabilityUnavailable,

  /// The package declares a network or storage mode this device disallows.
  platformUnsupported,

  /// The package format itself is newer than this build understands.
  packageFormatTooNew,
}

class CompatibilityFinding {
  final IncompatibilityReason reason;
  final String detail;

  /// A blocking finding stops installation; a non-blocking one is recorded and
  /// surfaced. An unavailable OPTIONAL capability is the motivating case: it
  /// degrades the Experience, it does not make it uninstallable.
  final bool blocking;

  const CompatibilityFinding(this.reason, this.detail, {this.blocking = true});

  @override
  String toString() => '${reason.name}: $detail';
}

class CompatibilityEvaluation {
  final List<CompatibilityFinding> findings;

  const CompatibilityEvaluation(this.findings);

  static const CompatibilityEvaluation compatible = CompatibilityEvaluation([]);

  /// Installable when nothing BLOCKING was found. Warnings do not stop an
  /// install; they travel with the result so the caller can show them.
  bool get isCompatible => !findings.any((f) => f.blocking);

  List<CompatibilityFinding> get blockers => findings.where((f) => f.blocking).toList();
  List<CompatibilityFinding> get warnings => findings.where((f) => !f.blocking).toList();
}

/// THE compatibility evaluator (IS-R54 Task 3).
///
/// PURE. It reads a manifest and answers a question. It has no repository, no
/// platform, no protection service and no I/O, so it CANNOT install even by
/// accident — the type system enforces "only evaluate" before certification
/// does (certified I-63).
///
/// This is the first consumer of `ExperienceManifest.minimumRuntimeVersion`.
/// That field has been declared and serialised since the manifest existed and,
/// until now, NOTHING read it — a compatibility promise the system made in its
/// data model and never kept.
class ExperienceCompatibilityEvaluator {
  /// The runtime version this build provides.
  ///
  /// Hand-maintained, and honestly so: `pubspec.yaml` cannot be read at
  /// runtime without adding a dependency (`package_info_plus`), and IS-R54
  /// adds none. It is declared in exactly ONE place so a drift is a one-line
  /// fix rather than a hunt, and every entry point below takes an override so
  /// tests and future callers never need to mutate it.
  ///
  /// Known gap: nothing mechanically ties this to `pubspec.yaml` (which still
  /// reads `1.0.0+1` while the branch is v2.0.0). Recorded rather than papered
  /// over.
  static const String currentRuntimeVersion = '2.0.0';

  const ExperienceCompatibilityEvaluator();

  /// Compares two dotted version strings. Returns <0, 0 or >0.
  ///
  /// THE one version comparator in `lib/`. A repository-wide search before
  /// writing it found exactly one version-arithmetic site,
  /// `ModificationEngine._bumpVersion`, which PRODUCES a version and is
  /// private — no comparator existed to reuse.
  ///
  /// Returns null when either side is not parseable, so a caller must decide
  /// what an unreadable version means rather than silently receiving "equal".
  static int? compareVersions(String a, String b) {
    final left = _parse(a);
    final right = _parse(b);
    if (left == null || right == null) return null;
    for (var i = 0; i < 3; i++) {
      if (left[i] != right[i]) return left[i].compareTo(right[i]);
    }
    return 0;
  }

  /// Parses `major.minor.patch`, tolerating a shorter form (`2`, `2.1`) and a
  /// `+build` / `-prerelease` suffix, which are ignored for ordering.
  static List<int>? _parse(String version) {
    final core = version.trim().split(RegExp(r'[+\-]')).first;
    if (core.isEmpty) return null;
    final parts = core.split('.');
    if (parts.length > 3) return null;
    final out = <int>[0, 0, 0];
    for (var i = 0; i < parts.length; i++) {
      final value = int.tryParse(parts[i]);
      if (value == null || value < 0) return null;
      out[i] = value;
    }
    return out;
  }

  /// Evaluates a package against this device.
  ///
  /// [availableCapabilities] is supplied by the caller rather than read from
  /// `CapabilityPlatform` directly — that keeps this evaluator pure and stops
  /// it importing the enforcement layer, which it must never touch.
  CompatibilityEvaluation evaluate(
    ExperiencePackage package, {
    String runtimeVersion = currentRuntimeVersion,
    Set<String> availableCapabilities = const {},
    bool enforceCapabilities = true,
  }) {
    final findings = <CompatibilityFinding>[];
    final manifest = package.manifest;

    // ── Manifest compatibility ──
    if (manifest.experienceId.isEmpty) {
      findings.add(const CompatibilityFinding(
          IncompatibilityReason.manifestIncomplete, 'manifest has no experienceId'));
    }
    if (manifest.entryPoint.isEmpty) {
      findings.add(const CompatibilityFinding(
          IncompatibilityReason.manifestIncomplete, 'manifest has no entryPoint'));
    }
    if (_parse(manifest.version) == null) {
      findings.add(CompatibilityFinding(
          IncompatibilityReason.malformedVersion, 'package version "${manifest.version}" is unparseable'));
    }

    // ── Runtime version compatibility — the first real consumer of this field ──
    final minimum = manifest.minimumRuntimeVersion;
    if (minimum != null && minimum.isNotEmpty) {
      final comparison = compareVersions(minimum, runtimeVersion);
      if (comparison == null) {
        findings.add(CompatibilityFinding(IncompatibilityReason.malformedVersion,
            'minimumRuntimeVersion "$minimum" is unparseable'));
      } else if (comparison > 0) {
        findings.add(CompatibilityFinding(IncompatibilityReason.runtimeTooOld,
            'needs runtime $minimum, this build is $runtimeVersion'));
      }
    }

    // ── Package format compatibility ──
    if (package.packageVersion > experiencePackageVersion) {
      findings.add(CompatibilityFinding(IncompatibilityReason.packageFormatTooNew,
          'package format v${package.packageVersion} exceeds supported v$experiencePackageVersion'));
    }

    // ── Capability compatibility ──
    //
    // Skipped entirely unless the caller supplies a capability set. An EMPTY
    // set means "I did not tell you what is available", not "nothing is
    // available" — treating those the same would block every install on a
    // caller's omission.
    if (enforceCapabilities && availableCapabilities.isNotEmpty) {
      for (final required in manifest.requiredCapabilities) {
        if (!availableCapabilities.contains(required)) {
          findings.add(CompatibilityFinding(IncompatibilityReason.capabilityUnavailable,
              'required capability "$required" is not registered'));
        }
      }
      for (final optional in manifest.optionalCapabilities) {
        if (!availableCapabilities.contains(optional)) {
          // Not blocking: the Experience degrades, it does not fail to install.
          findings.add(CompatibilityFinding(IncompatibilityReason.capabilityUnavailable,
              'optional capability "$optional" is not registered', blocking: false));
        }
      }
    }

    return CompatibilityEvaluation(findings);
  }

  /// FUTURE SDK COMPATIBILITY (Task 3) — architecture only.
  ///
  /// Deliberately expressed as the existing format check rather than a new
  /// "SDK version" concept: `experiencePackageVersion` IS this system's
  /// package-format SDK level, and inventing a second version axis that
  /// nothing sets would be a speculative field pretending to be a check.
  bool supportsPackageFormat(int packageFormatVersion) =>
      packageFormatVersion <= experiencePackageVersion;
}

// ─────────────────────────────────────────────────────────────────────────────
// TASK 4 — DEPENDENCY PREPARATION. No downloading. No networking.
// ─────────────────────────────────────────────────────────────────────────────

/// What must happen to a single dependency before an install can proceed.
enum DependencyStatus {
  /// Already installed on this device.
  satisfied,

  /// Not installed, and nothing here can fetch it.
  missing,

  /// Names the Experience being installed. A self-dependency is always a
  /// defect in the package, never something to resolve.
  circular,
}

class DependencyNodePlan {
  final String experienceId;
  final DependencyStatus status;

  const DependencyNodePlan(this.experienceId, this.status);
}

class DependencyPlan {
  /// Dependencies in the order they would have to be present, nearest-first.
  final List<DependencyNodePlan> nodes;

  const DependencyPlan(this.nodes);

  static const DependencyPlan empty = DependencyPlan([]);

  List<String> get missing =>
      nodes.where((n) => n.status == DependencyStatus.missing).map((n) => n.experienceId).toList();

  List<String> get circular =>
      nodes.where((n) => n.status == DependencyStatus.circular).map((n) => n.experienceId).toList();

  /// Satisfiable when nothing is missing and nothing is circular.
  bool get isSatisfied => missing.isEmpty && circular.isEmpty;
}

/// THE dependency planner (IS-R54 Task 4).
///
/// ARCHITECTURE ONLY, as instructed. It PLANS: given the dependency ids a
/// package declares and the ids already installed, it says which are satisfied,
/// which are missing and which are self-referential. It downloads nothing,
/// opens no socket and installs nothing — there is no transport for a
/// dependency to arrive on, and R53's `dependencies` field has never had a
/// producer.
///
/// NOT a second `DependencyResolver`. The five resolvers in
/// `lib/feature_discovery/` expand a FEATURE CANDIDATE into capability,
/// permission, storage and navigation primitives during design. This plans
/// EXPERIENCE-TO-EXPERIENCE package dependencies at install time. Different
/// inputs, different outputs, different lifecycle stage; certification pins
/// both sets so the distinction stays deliberate (I-63).
class ExperienceDependencyPlanner {
  const ExperienceDependencyPlanner();

  /// [dependencies] comes from the R53 distribution envelope, whose
  /// `dependencies` list has been transported since R53 and resolved by
  /// nothing (gap G-27). This is its first reader.
  DependencyPlan plan({
    required String experienceId,
    required List<String> dependencies,
    required Set<String> installedIds,
  }) {
    final nodes = <DependencyNodePlan>[];
    final seen = <String>{};

    for (final raw in dependencies) {
      final id = raw.trim();
      if (id.isEmpty || !seen.add(id)) continue;

      if (id == experienceId) {
        nodes.add(DependencyNodePlan(id, DependencyStatus.circular));
      } else if (installedIds.contains(id)) {
        nodes.add(DependencyNodePlan(id, DependencyStatus.satisfied));
      } else {
        nodes.add(DependencyNodePlan(id, DependencyStatus.missing));
      }
    }

    return DependencyPlan(nodes);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TASK 6 — MIGRATION PREPARATION. Records a requirement. Executes nothing.
// ─────────────────────────────────────────────────────────────────────────────

/// What kind of boundary an upgrade crosses.
enum MigrationKind {
  /// The Experience's own data schema version changed.
  dataSchema,

  /// The package format version changed.
  packageFormat,

  /// The minimum runtime version changed.
  runtime,
}

/// A RECORD that an install crosses a migration boundary (IS-R54 Task 6).
///
/// NOT a migration engine, and deliberately not a `DataMigrationPlan`. The
/// canonical migration engine already exists — `MigrationExecutor` with
/// `DataMigrationPlan`/`MigrationValidator` in `lib/storage/` — and it runs
/// real transactional operations against a real database. This type carries
/// only the FACT that a boundary was crossed and the versions on either side.
///
/// It plans no operations, because computing a genuine schema diff is beyond
/// what this milestone can honestly derive, and fabricating one would be worse
/// than recording nothing. Executing any would make this a second migration
/// engine, which IS-R54's ABSOLUTE RULES forbid.
class MigrationRequirement {
  final MigrationKind kind;
  final String experienceId;
  final String fromVersion;
  final String toVersion;

  const MigrationRequirement({
    required this.kind,
    required this.experienceId,
    required this.fromVersion,
    required this.toVersion,
  });

  @override
  String toString() => '${kind.name} $fromVersion -> $toVersion';
}

/// Derives migration requirements by comparing what is installed with what is
/// arriving. Pure comparison over data that genuinely exists on both packages.
List<MigrationRequirement> migrationRequirements({
  required ExperiencePackage installed,
  required ExperiencePackage incoming,
}) {
  final requirements = <MigrationRequirement>[];
  final id = incoming.manifest.experienceId;

  final from = installed.data?.schemaVersion;
  final to = incoming.data?.schemaVersion;
  if (from != null && to != null && from != to) {
    requirements.add(MigrationRequirement(
      kind: MigrationKind.dataSchema,
      experienceId: id,
      fromVersion: '$from',
      toVersion: '$to',
    ));
  }

  if (installed.packageVersion != incoming.packageVersion) {
    requirements.add(MigrationRequirement(
      kind: MigrationKind.packageFormat,
      experienceId: id,
      fromVersion: '${installed.packageVersion}',
      toVersion: '${incoming.packageVersion}',
    ));
  }

  final fromRuntime = installed.manifest.minimumRuntimeVersion;
  final toRuntime = incoming.manifest.minimumRuntimeVersion;
  if (fromRuntime != toRuntime && toRuntime != null) {
    requirements.add(MigrationRequirement(
      kind: MigrationKind.runtime,
      experienceId: id,
      fromVersion: fromRuntime ?? 'unspecified',
      toVersion: toRuntime,
    ));
  }

  return requirements;
}

// ─────────────────────────────────────────────────────────────────────────────
// TASK 5 — INSTALLATION TRANSACTION.
// ─────────────────────────────────────────────────────────────────────────────

enum TransactionState { open, prepared, committed, rolledBack, cancelled }

/// The install-side transaction (IS-R54 Task 5), now DELEGATING every write to
/// the ONE commit framework (IS-R55 Task 6).
///
/// WHAT CHANGED IN R55, AND WHY IT MATTERS.
///
/// R54 built this as a COMPENSATING transaction — snapshot, write, restore on
/// failure — because `savePackage` and `saveMetadata` each resolved their own
/// `Database` and sqflite's `db.transaction` was unreachable through them. R54
/// recorded the residual crash window as gap G-28: a process death between the
/// two writes stranded torn state with no snapshot left to undo it.
///
/// R55 closes that. `ExperienceCommitFramework` writes both rows inside ONE
/// real SQLite transaction (see `RepositoryTransactionCoordinator`), so there
/// is no longer a window in which one row has landed and the other has not.
/// Either the whole commit is durable or none of it is.
///
/// This class keeps its public shape — prepare / validate / commit / rollback /
/// cancel, and the prior-state accessors — because R54's suite and the
/// installer are written against it, and IS-R55 forbids an API break. What it
/// no longer has is a repository write of its own: it holds a commit framework
/// and asks.
///
/// The prior-state snapshot survives for a DIFFERENT reason than before. It is
/// no longer a crash-recovery mechanism; it is what a caller needs to undo a
/// SUCCESSFUL install later, because the repository keeps no version history
/// and "the version before this one" cannot be looked up after the fact.
class InstallationTransaction {
  final SqliteExperienceRepository repository;
  final ExperienceCommitFramework commitFramework;
  final String experienceId;

  TransactionState _state = TransactionState.open;
  ExperiencePackage? _priorPackage;
  ExperienceMetadataRecord? _priorMetadata;
  bool _existed = false;

  InstallationTransaction({
    required this.repository,
    required this.experienceId,
    ExperienceCommitFramework? commitFramework,
  }) : commitFramework = commitFramework ?? ExperienceCommitFramework(repository: repository);

  TransactionState get state => _state;

  /// True when [prepare] found an existing installation — i.e. this is an
  /// upgrade/downgrade/reinstall rather than a fresh install.
  bool get replacesExisting => _existed;

  ExperiencePackage? get priorPackage => _priorPackage;
  ExperienceMetadataRecord? get priorMetadata => _priorMetadata;

  /// Captures the state a later [rollback] would have to restore.
  Future<void> prepare() async {
    _require(TransactionState.open, 'prepare');
    final prior = await commitFramework.currentState(experienceId);
    _priorPackage = prior.package;
    _priorMetadata = prior.metadata;
    _existed = _priorPackage != null || _priorMetadata != null;
    _state = TransactionState.prepared;
  }

  /// Structural validation — DELEGATED to the canonical validator, never
  /// re-implemented (certified I-65).
  PackageValidationResult validate(ExperiencePackage package) =>
      ExperiencePackageValidator.validate(package);

  /// Writes both rows through the ONE commit owner, atomically.
  Future<void> commit({
    required ExperiencePackage package,
    required ExperienceMetadataRecord metadata,
  }) async {
    _require(TransactionState.prepared, 'commit');
    final result = await commitFramework.commit(
      experienceId: experienceId,
      origin: CommitOrigin.installation,
      package: package,
      metadata: metadata,
    );
    if (!result.succeeded) {
      // SQLite rolled the whole transaction back; nothing partial survived, so
      // there is nothing to compensate for. Surface the failure unchanged.
      _state = TransactionState.rolledBack;
      throw StateError('commit failed: ${result.error}');
    }
    _state = TransactionState.committed;
  }

  /// Undoes a committed transaction by restoring the prepared snapshot —
  /// through the ONE rollback owner (IS-R55 Task 9).
  Future<void> rollback() async {
    if (_state != TransactionState.committed && _state != TransactionState.prepared) {
      throw StateError('cannot roll back a transaction in state ${_state.name}');
    }
    await commitFramework.rollback(
      experienceId: experienceId,
      previousPackage: _priorPackage,
      previousMetadata: _priorMetadata,
    );
    _state = TransactionState.rolledBack;
  }

  /// Abandons a transaction that never committed. Touches no storage.
  void cancel() {
    _require(TransactionState.prepared, 'cancel', alsoAllow: TransactionState.open);
    _state = TransactionState.cancelled;
  }

  void _require(TransactionState expected, String action, {TransactionState? alsoAllow}) {
    if (_state != expected && _state != alsoAllow) {
      throw StateError('cannot $action a transaction in state ${_state.name}');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TASK 2 — THE INSTALLATION FRAMEWORK.
// ─────────────────────────────────────────────────────────────────────────────

/// What an install turned out to be, decided from the versions rather than
/// asserted by the caller.
enum InstallationKind { freshInstall, upgrade, downgrade, reinstall, repair }

/// Why an installation did not happen.
enum InstallationFailure {
  incompatible,
  invalidPackage,
  dependenciesUnsatisfied,
  notInstalled,
  storageFailure,
}

class InstallationResult {
  final bool succeeded;
  final InstallationKind? kind;
  final String? experienceId;
  final InstallationFailure? failure;
  final CompatibilityEvaluation? compatibility;
  final DependencyPlan? dependencies;
  final List<MigrationRequirement> migrations;
  final List<String> messages;

  /// The package this install replaced, when it replaced one. A caller that
  /// wants to undo LATER — after this framework has returned and the
  /// transaction is gone — must hold this, for the same reason
  /// `ExperienceModificationCoordinator.rollback` requires it: the repository
  /// keeps no version history.
  final ExperiencePackage? previousPackage;

  /// Whether protection was requested AND succeeded. False when it was not
  /// requested, and false — with a message — when it was requested and failed.
  final bool protected;

  const InstallationResult._({
    required this.succeeded,
    this.kind,
    this.experienceId,
    this.failure,
    this.compatibility,
    this.dependencies,
    this.migrations = const [],
    this.messages = const [],
    this.previousPackage,
    this.protected = false,
  });

  factory InstallationResult.success({
    required InstallationKind kind,
    required String experienceId,
    CompatibilityEvaluation? compatibility,
    DependencyPlan? dependencies,
    List<MigrationRequirement> migrations = const [],
    List<String> messages = const [],
    ExperiencePackage? previousPackage,
    bool protected = false,
  }) =>
      InstallationResult._(
        succeeded: true,
        kind: kind,
        experienceId: experienceId,
        compatibility: compatibility,
        dependencies: dependencies,
        migrations: migrations,
        messages: messages,
        previousPackage: previousPackage,
        protected: protected,
      );

  factory InstallationResult.rejected(
    InstallationFailure failure,
    List<String> messages, {
    CompatibilityEvaluation? compatibility,
    DependencyPlan? dependencies,
  }) =>
      InstallationResult._(
        succeeded: false,
        failure: failure,
        messages: messages,
        compatibility: compatibility,
        dependencies: dependencies,
      );
}

/// THE one owner of committing an Experience (IS-R54 Task 2).
///
/// Install, upgrade, downgrade, repair, rollback, dependency preparation,
/// compatibility validation, commit. It NEVER activates, NEVER classifies
/// trust, NEVER enforces policy, NEVER encrypts and NEVER distributes.
class ExperienceInstallationFramework {
  final SqliteExperienceRepository repository;
  final ExperienceCompatibilityEvaluator compatibility;
  final ExperienceDependencyPlanner dependencyPlanner;

  /// Optional. When absent, `protect: true` is reported as unfulfilled rather
  /// than silently ignored — an install that quietly did not protect what it
  /// was asked to protect is exactly the kind of invisible gap this codebase
  /// records instead of shipping.
  final ExperienceProtectionService? protectionService;

  /// The ONE commit owner (IS-R55). The installer PREPARES — evaluates
  /// compatibility, plans dependencies, derives migrations, decides what kind
  /// of install this is — and this commits. It is optional so no existing
  /// caller breaks; when absent one is built over the same repository, so the
  /// write still goes through a commit framework and never through a second
  /// path in this file.
  final ExperienceCommitFramework? commitFramework;

  const ExperienceInstallationFramework({
    required this.repository,
    this.compatibility = const ExperienceCompatibilityEvaluator(),
    this.dependencyPlanner = const ExperienceDependencyPlanner(),
    this.protectionService,
    this.commitFramework,
  });

  /// The commit owner this installer writes through.
  ExperienceCommitFramework get commits =>
      commitFramework ?? ExperienceCommitFramework(repository: repository);

  /// INSTALL — the single commit path (Tasks 2, 5, 7, 8).
  ///
  /// Order matters and is deliberate:
  ///   evaluate compatibility -> plan dependencies -> prepare (snapshot)
  ///   -> validate -> derive migrations -> commit -> request protection
  ///
  /// Nothing is written until every check has passed, and NOTHING IS
  /// ACTIVATED afterwards. The Experience is installed and idle until a user
  /// opens it through `ExperienceEntryPipeline` (R45).
  Future<InstallationResult> install({
    required ExperiencePackage package,
    ExperienceProvenance provenance = const ExperienceProvenance(),
    List<String> dependencies = const [],
    Set<String> availableCapabilities = const {},
    String runtimeVersion = ExperienceCompatibilityEvaluator.currentRuntimeVersion,
    bool protect = false,
    DateTime? at,
  }) async {
    final id = package.manifest.experienceId;
    final now = at ?? DateTime.now();

    final evaluation = compatibility.evaluate(
      package,
      runtimeVersion: runtimeVersion,
      availableCapabilities: availableCapabilities,
    );
    if (!evaluation.isCompatible) {
      return InstallationResult.rejected(
        InstallationFailure.incompatible,
        evaluation.blockers.map((f) => f.toString()).toList(),
        compatibility: evaluation,
      );
    }

    final installedIds = (await repository.listAll()).map((m) => m.id).toSet();
    final plan = dependencyPlanner.plan(
      experienceId: id,
      dependencies: dependencies,
      installedIds: installedIds,
    );
    if (!plan.isSatisfied) {
      return InstallationResult.rejected(
        InstallationFailure.dependenciesUnsatisfied,
        [
          if (plan.missing.isNotEmpty) 'missing dependencies: ${plan.missing.join(", ")}',
          if (plan.circular.isNotEmpty) 'circular dependency: ${plan.circular.join(", ")}',
        ],
        compatibility: evaluation,
        dependencies: plan,
      );
    }

    final transaction = InstallationTransaction(
      repository: repository,
      experienceId: id,
      commitFramework: commits,
    );
    await transaction.prepare();

    final validation = transaction.validate(package);
    if (!validation.isValid) {
      transaction.cancel();
      return InstallationResult.rejected(
        InstallationFailure.invalidPackage,
        validation.errors,
        compatibility: evaluation,
        dependencies: plan,
      );
    }

    final previous = transaction.priorPackage;
    final kind = _kindFor(previous, package);
    final migrations = previous == null
        ? const <MigrationRequirement>[]
        : migrationRequirements(installed: previous, incoming: package);

    final priorMetadata = transaction.priorMetadata;
    try {
      await transaction.commit(
        package: package,
        metadata: ExperienceMetadataRecord(
          id: id,
          name: package.manifest.name,
          description: package.manifest.description,
          category: package.manifest.category,
          // An upgrade keeps the original creation date — the Experience was
          // not created again, a newer version of it arrived.
          createdAt: priorMetadata?.createdAt ?? package.manifest.createdAt,
          updatedAt: now,
          lastUsedAt: priorMetadata?.lastUsedAt,
          packageVersion: package.manifest.version,
          provenance: provenance,
          // Protection is REQUESTED below, after the commit, and only
          // `ExperienceProtectionService` can make this true. Never asserted
          // here — claiming a protected state this framework did not produce
          // is exactly the fabrication R52/R53 removed elsewhere.
          isProtected: false,
        ),
      );
    } catch (e) {
      return InstallationResult.rejected(
        InstallationFailure.storageFailure,
        ['commit failed and was rolled back: $e'],
        compatibility: evaluation,
        dependencies: plan,
      );
    }

    // TASK 7 — request protection AFTER a successful commit. This framework
    // does not encrypt: it asks the service that owns protection to do it.
    final messages = <String>[];
    var protectedNow = false;
    if (protect) {
      if (protectionService == null) {
        messages.add('protection was requested but no ExperienceProtectionService is wired');
      } else {
        final result = await protectionService!.protectWithCurrentTime(
          package: package,
          experienceId: id,
        );
        protectedNow = result is ProtectionSucceeded;
        if (!protectedNow) {
          messages.add('protection was requested but did not succeed');
        }
      }
    }

    return InstallationResult.success(
      kind: kind,
      experienceId: id,
      compatibility: evaluation,
      dependencies: plan,
      migrations: migrations,
      messages: [...messages, ...evaluation.warnings.map((w) => w.toString())],
      previousPackage: previous,
      protected: protectedNow,
    );
  }

  /// UPGRADE / DOWNGRADE (Task 2).
  ///
  /// Both are [install] — the version comparison decides which it was, so
  /// there is ONE commit path rather than three that could drift. These exist
  /// because the specification names them, and because a caller asserting
  /// "this is an upgrade" should be told when it is not.
  Future<InstallationResult> upgrade({
    required ExperiencePackage package,
    ExperienceProvenance provenance = const ExperienceProvenance(),
    List<String> dependencies = const [],
    Set<String> availableCapabilities = const {},
    String runtimeVersion = ExperienceCompatibilityEvaluator.currentRuntimeVersion,
    bool protect = false,
    DateTime? at,
  }) =>
      install(
        package: package,
        provenance: provenance,
        dependencies: dependencies,
        availableCapabilities: availableCapabilities,
        runtimeVersion: runtimeVersion,
        protect: protect,
        at: at,
      );

  /// See [upgrade] — the same one path. A downgrade is not blocked: it is a
  /// legitimate recovery action, and the result reports
  /// [InstallationKind.downgrade] so a caller can warn about it honestly.
  Future<InstallationResult> downgrade({
    required ExperiencePackage package,
    ExperienceProvenance provenance = const ExperienceProvenance(),
    Set<String> availableCapabilities = const {},
    String runtimeVersion = ExperienceCompatibilityEvaluator.currentRuntimeVersion,
    DateTime? at,
  }) =>
      install(
        package: package,
        provenance: provenance,
        availableCapabilities: availableCapabilities,
        runtimeVersion: runtimeVersion,
        at: at,
      );

  /// ROLLBACK — restores a package the caller still holds (IS-R54 Task 2),
  /// terminating inside the ONE rollback owner (IS-R55 Task 9).
  ///
  /// Takes [previousPackage] rather than looking up "the version before this
  /// one" because the repository keeps no version history.
  ///
  /// It rolls back by RE-INSTALLING, which is deliberate and worth keeping:
  /// the prior package is re-validated and re-checked for compatibility on the
  /// way back in, so a rollback cannot restore something this build can no
  /// longer run. The write itself still lands in
  /// `ExperienceCommitFramework.commit` — the installer performs no write of
  /// its own here or anywhere else.
  Future<InstallationResult> rollback({
    required String experienceId,
    required ExperiencePackage previousPackage,
    ExperienceProvenance provenance = const ExperienceProvenance(),
    DateTime? at,
  }) async {
    final existing = await repository.getMetadata(experienceId);
    if (existing == null) {
      return InstallationResult.rejected(
        InstallationFailure.notInstalled,
        ['$experienceId is not installed'],
      );
    }
    return install(
      package: previousPackage,
      provenance: provenance,
      at: at,
    );
  }

  /// REPAIR — the installer REQUESTS; the commit framework COORDINATES
  /// (IS-R55 Task 8).
  ///
  /// R54 implemented the reconciliation here. R55 moves it to
  /// `ExperienceCommitFramework.repair`, because repair is entirely a
  /// persistence-consistency operation: it looks at what is on disk and
  /// reconciles rows. The installer still decides WHEN to repair and how to
  /// report it in installation vocabulary; it no longer decides what repairing
  /// means, and it no longer writes.
  ///
  /// Behaviour is unchanged — package-without-metadata is rebuilt from the
  /// manifest with provenance recorded as unknown, metadata-without-package is
  /// reported unrepairable rather than faked.
  Future<InstallationResult> repair(String experienceId, {DateTime? at}) async {
    final result = await commits.repair(experienceId, at: at);

    switch (result.outcome) {
      case RepairOutcome.notInstalled:
        return InstallationResult.rejected(
          InstallationFailure.notInstalled,
          ['$experienceId is not installed'],
        );
      case RepairOutcome.unrepairable:
        return InstallationResult.rejected(
          InstallationFailure.notInstalled,
          ['$experienceId ${result.message}'],
        );
      case RepairOutcome.healthy:
      case RepairOutcome.repaired:
        return InstallationResult.success(
          kind: InstallationKind.repair,
          experienceId: experienceId,
          messages: [result.message],
        );
    }
  }

  /// Decides what this install IS from the versions, rather than trusting a
  /// caller's label. An unparseable version on either side yields
  /// [InstallationKind.reinstall] — the safe, non-claiming answer.
  static InstallationKind _kindFor(ExperiencePackage? previous, ExperiencePackage incoming) {
    if (previous == null) return InstallationKind.freshInstall;
    final comparison = ExperienceCompatibilityEvaluator.compareVersions(
      incoming.manifest.version,
      previous.manifest.version,
    );
    if (comparison == null || comparison == 0) return InstallationKind.reinstall;
    return comparison > 0 ? InstallationKind.upgrade : InstallationKind.downgrade;
  }
}
