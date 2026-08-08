/// Experience portability — Implementation Specification IS-P02 Phase 9.
/// The wire between machinery that already existed and a user who can finally
/// reach it.
///
/// WHAT THE AUDIT FOUND. Every component below was already built, tested and
/// certified. None of it had a single production caller:
///
///     ExperiencePackageWriter / Reader   IS-R60   ZERO `lib/` importers
///     ExperiencePackageValidator         IS-R53   canonical, delegated to
///     ExperienceInstallationFramework    IS-R54   read only by tests
///     SqliteExperienceRepository         canonical
///     RealFileService                    IS-R49   real file I/O
///
/// Gap G-25 -- "a user still cannot import an Experience" -- has been open
/// since IS-R53, was the recommended next milestone in the R61, R62 and
/// Master Audit reports, and was deferred three times because every
/// specification from R53 onward forbade touching the subsystems where a
/// consumer would have to live.
///
/// THIS FILE IS THAT CONSUMER, AND IT IS ONLY A CONSUMER. It creates no
/// format, no validator, no installer and no repository. It owns exactly one
/// thing: the ORDER in which the existing pieces are called, and the honest
/// reporting of where the sequence stopped.
///
///     export:  repository -> writer          -> file
///     import:  file       -> reader          -> installer -> repository
///
/// NOT A SECOND INSTALLER. `ExperienceInstallationFramework` (R54) installs;
/// this asks it to. NOT A SECOND VALIDATOR. `ExperiencePackageReader` (R60)
/// already delegates structural validation to the canonical validator; this
/// re-checks nothing. NOT FILE I/O. `RealFileService` (R49) owns that.
library;

import '../capabilities/adapters/file_service_adapter.dart';
import '../creation/experience_package.dart';
import '../creation/experience_package_codec.dart';
import '../storage/sqlite_experience_repository.dart';
import 'experience_installation.dart';

/// Why a portability operation stopped. A closed vocabulary, so the UI reacts
/// to a reason rather than parsing a message.
enum PortabilityFailure {
  /// No Experience with that id is stored.
  notFound,

  /// The user dismissed the file picker. Not an error.
  cancelled,

  /// The chosen file could not be read from disk.
  unreadable,

  /// The bytes are not a usable Experience package. The reader's own
  /// `PackageReadFailure` is carried through in [PortabilityResult.readFailure]
  /// rather than being flattened into one reason.
  invalidPackage,

  /// The package was read and refused by the installer -- incompatible
  /// runtime, missing dependency, or a failed commit.
  installationRefused,

  /// The file could not be written.
  writeFailed,
}

/// Outcome of an export or an import.
class PortabilityResult {
  final bool succeeded;
  final PortabilityFailure? failure;

  /// The reader's own failure reason, when [failure] is [invalidPackage].
  /// Surfaced verbatim -- the codec's vocabulary is already exhaustive and
  /// re-wording it would lose information the UI can use.
  final PackageReadFailure? readFailure;

  /// Where an exported file landed.
  final String? path;

  final ExperienceManifest? manifest;

  /// The installer's own messages, when it refused. Never re-worded.
  final List<String> messages;

  const PortabilityResult._({
    required this.succeeded,
    this.failure,
    this.readFailure,
    this.path,
    this.manifest,
    this.messages = const [],
  });

  factory PortabilityResult.exported(
    String path,
    ExperienceManifest manifest,
  ) => PortabilityResult._(succeeded: true, path: path, manifest: manifest);

  factory PortabilityResult.imported(ExperienceManifest manifest) =>
      PortabilityResult._(succeeded: true, manifest: manifest);

  factory PortabilityResult.failed(
    PortabilityFailure failure, {
    PackageReadFailure? readFailure,
    List<String> messages = const [],
  }) => PortabilityResult._(
    succeeded: false,
    failure: failure,
    readFailure: readFailure,
    messages: messages,
  );

  /// A sentence fit to show a person. Deliberately lives here rather than in
  /// the UI, so both entry points say the same thing about the same failure.
  String get description {
    if (succeeded) {
      return path == null
          ? 'Imported "${manifest?.name ?? 'Experience'}".'
          : 'Exported "${manifest?.name ?? 'Experience'}".';
    }
    switch (failure!) {
      case PortabilityFailure.notFound:
        return 'That Experience is no longer stored on this device.';
      case PortabilityFailure.cancelled:
        return 'Cancelled.';
      case PortabilityFailure.unreadable:
        return 'That file could not be read.';
      case PortabilityFailure.invalidPackage:
        switch (readFailure) {
          case PackageReadFailure.notAPackage:
            return 'That file is not an Anything Experience.';
          case PackageReadFailure.checksumMismatch:
            return 'That Experience was modified after it was exported, so it '
                'was not imported.';
          case PackageReadFailure.unsupportedFormatVersion:
            return 'That Experience was made by a newer version of Anything.';
          case PackageReadFailure.invalidPackage:
            return 'That Experience is damaged and cannot be opened.';
          case PackageReadFailure.malformed:
          case null:
            return 'That file is not a readable Experience.';
        }
      case PortabilityFailure.installationRefused:
        return messages.isEmpty
            ? 'That Experience could not be installed here.'
            : messages.first;
      case PortabilityFailure.writeFailed:
        return 'The Experience could not be saved to a file.';
    }
  }
}

/// Moves Experiences between this device and a file.
///
/// Every collaborator is injected and every one already existed. This class
/// adds no capability of its own -- it decides only the ORDER of calls and how
/// to report where the sequence stopped.
class ExperiencePortability {
  final SqliteExperienceRepository repository;
  final ExperienceInstallationFramework installer;
  final RealFileService files;

  /// The canonical codec (IS-R60). Both are `const` and stateless.
  final ExperiencePackageWriter writer;
  final ExperiencePackageReader reader;

  const ExperiencePortability({
    required this.repository,
    required this.installer,
    required this.files,
    this.writer = const ExperiencePackageWriter(),
    this.reader = const ExperiencePackageReader(),
  });

  /// A filename a person will recognise a week later.
  ///
  /// Slugged rather than raw, because an Experience name is user-supplied text
  /// and can contain path separators. `RealFileService` refuses to escape its
  /// sandbox anyway, but producing a name that cannot escape is better than
  /// relying on something downstream to refuse it.
  static String fileNameFor(ExperienceManifest manifest) {
    final slug = manifest.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final safe = slug.isEmpty ? manifest.experienceId : slug;
    return '$safe-v${manifest.version}${ExperiencePackageFormat.extension}';
  }

  /// EXPORT — a stored Experience becomes a shareable file.
  Future<PortabilityResult> export(String experienceId) async {
    final package = await repository.getPackage(experienceId);
    if (package == null) {
      return PortabilityResult.failed(PortabilityFailure.notFound);
    }

    // The writer is deterministic: the same Experience always produces
    // byte-identical output, which is what makes the embedded checksum -- and
    // later a signature -- mean anything.
    final bytes = writer.write(package);

    final file = await files.writeExport(fileNameFor(package.manifest), bytes);
    if (file == null) {
      return PortabilityResult.failed(PortabilityFailure.writeFailed);
    }
    return PortabilityResult.exported(file.path, package.manifest);
  }

  /// IMPORT — a file becomes an installed Experience.
  ///
  /// The sequence matters and is the whole reason this class exists: READ,
  /// then INSTALL. The reader deliberately never installs (I-88), because
  /// parsing something must not run it, and a well-formed package must not
  /// earn authority by being well-formed.
  Future<PortabilityResult> import({
    Set<String> availableCapabilities = const {},
  }) async {
    final picked = await files.pickFile(
      allowedExtensions: const ['anything', 'json'],
    );
    if (picked == null) {
      return PortabilityResult.failed(PortabilityFailure.cancelled);
    }

    final bytes = await files.readPickedText(picked.id);
    if (bytes == null) {
      return PortabilityResult.failed(PortabilityFailure.unreadable);
    }

    return importBytes(bytes, availableCapabilities: availableCapabilities);
  }

  /// The half of [import] that has no file picker in it.
  ///
  /// Separated so the whole read-and-install path is testable without an OS
  /// dialog, and so a future source -- a share intent, a deep link -- has a
  /// real integration point rather than needing this class reorganised.
  Future<PortabilityResult> importBytes(
    String bytes, {
    Set<String> availableCapabilities = const {},
  }) async {
    // Structural validation, checksum verification and format-version
    // checking all happen here, inside the canonical reader. Nothing is
    // re-checked afterwards.
    final read = reader.read(bytes);
    if (!read.succeeded) {
      return PortabilityResult.failed(
        PortabilityFailure.invalidPackage,
        readFailure: read.failure,
        messages: read.messages,
      );
    }

    // An imported package is UNTRUSTED INPUT and is installed as such: the
    // installer evaluates compatibility, plans dependencies and commits
    // transactionally. This class does none of that and must not.
    final result = await installer.install(
      package: read.package!,
      availableCapabilities: availableCapabilities,
    );
    if (!result.succeeded) {
      return PortabilityResult.failed(
        PortabilityFailure.installationRefused,
        messages: result.messages,
      );
    }
    return PortabilityResult.imported(read.package!.manifest);
  }
}
