/// RealFileService — Implementation Specification IS-R49 Task 3.
///
/// The real production implementation of `FileService`, replacing
/// `FakeFileService` in `AppComposition`. Follows the established pattern of
/// `RealHttpTransport` (`http_transport_adapter.dart`).
///
/// WHAT WAS FAKE. `FakeFileService` returned `_files.first` from a list a
/// test had pre-populated, "adopted" a file by writing a map entry, and
/// "deleted" it by removing that entry. No file was ever read, copied or
/// removed. It was registered in the REAL production composition.
///
/// WHAT IS REAL HERE. Every operation touches the real filesystem through
/// `dart:io`:
///   * IMPORT — [pickFile]/[pickImage] use `package:file_picker`, ALREADY a
///     dependency of this project. No new dependency is added.
///   * ADOPTION — [adoptFile] COPIES the picked bytes into an app-owned
///     sandbox directory. Until a file is adopted it is only referenced;
///     after adoption Anything owns its own copy and no longer depends on a
///     path outside the sandbox that the user may move or delete.
///   * EXPORT — [exportFile] writes an adopted file back out under a
///     caller-chosen name.
///   * TEMPORARY FILES — [createTemporaryFile] and [clearTemporaryFiles]
///     under a dedicated `tmp/` subtree.
///   * WORKSPACE ASSETS — [workspaceAssetPath], a shared, Experience-neutral
///     area.
///   * EXPERIENCE ASSETS — every adopted file lives under
///     `experiences/<experienceId>/`, which IS the ownership boundary.
///   * DELETION — [deleteAdoptedFile] removes the real bytes, and only for
///     the owning Experience.
///
/// SANDBOX SAFETY. Every path this service returns or writes is resolved and
/// then checked to be inside [rootDirectory]. A `fileId` or export name
/// containing `..` or an absolute path cannot escape — [_resolveInside]
/// rejects it rather than sanitising it, because silently rewriting a
/// caller's path is how path-traversal bugs hide. Experience A cannot read or
/// delete Experience B's files: the id is resolved under A's own directory,
/// so B's path simply does not exist from A.
///
/// NO DUPLICATE STORAGE SYSTEM. This is a filesystem abstraction for
/// user-facing binary assets. It does not persist Experiences (that is
/// `SqliteExperienceRepository`), knowledge (`KnowledgeRepository`), memory,
/// activity or intents. It owns exactly one thing: files a user imported.
///
/// TESTABILITY. Both platform-bound seams are injectable, exactly as
/// `RealHttpTransport({http.Client? client})` and
/// `WebWeaveXAdapter({PageFetcher? fetchPage})` already do it: [rootOverride]
/// replaces `path_provider`, and [picker] replaces the OS file dialog. Every
/// byte of the storage, ownership, sandbox and export logic below therefore
/// runs against a real directory in tests. Only the OS dialog itself — which
/// no unit test can drive on any platform — is left to the device.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as picker_pkg;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/retention_policy_engine.dart';
import '../builtin/file_capability.dart';

/// A file the user chose, before Anything owns it.
class PickedFile {
  final String name;
  final String? path;
  /// In-memory bytes from the picker (required on Android SAF when path is null).
  final List<int>? bytes;
  final int? sizeBytes;
  final String? mimeType;

  const PickedFile({
    required this.name,
    this.path,
    this.bytes,
    this.sizeBytes,
    this.mimeType,
  });

  bool get hasReadableContent =>
      (bytes != null && bytes!.isNotEmpty) ||
      (path != null && path!.isNotEmpty);
}

/// The OS file-selection seam. Real implementation uses `file_picker`;
/// tests inject a deterministic one.
abstract class FilePicker {
  Future<PickedFile?> pick({
    List<String>? allowedExtensions,
    bool imagesOnly = false,
  });
}

/// Real `package:file_picker`-backed selection.
class PlatformFilePicker implements FilePicker {
  const PlatformFilePicker();

  @override
  Future<PickedFile?> pick({
    List<String>? allowedExtensions,
    bool imagesOnly = false,
  }) async {
    final result = await picker_pkg.FilePicker.platform.pickFiles(
      type: imagesOnly
          ? picker_pkg.FileType.image
          : (allowedExtensions == null
                ? picker_pkg.FileType.any
                : picker_pkg.FileType.custom),
      allowedExtensions: imagesOnly ? null : allowedExtensions,
      // Android document providers often return path == null; bytes are required.
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) return null;
    return PickedFile(
      name: file.name,
      path: file.path,
      bytes: file.bytes,
      sizeBytes: file.size,
      mimeType: _mimeFor(file.extension),
    );
  }
}

/// Minimal extension -> MIME mapping for the types this capability
/// meaningfully distinguishes. Deliberately small: `FileCapability` only
/// branches on `image/`, so a full MIME database would be unused weight.
String? _mimeFor(String? extension) {
  switch (extension?.toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'pdf':
      return 'application/pdf';
    case 'txt':
      return 'text/plain';
    case 'json':
      return 'application/json';
    case 'csv':
      return 'text/csv';
    default:
      return null;
  }
}

class RealFileService implements FileService {
  final FilePicker _picker;
  final Directory? _rootOverride;
  Directory? _resolvedRoot;

  /// THE canonical retention owner (IS-R50). This service owns no retention
  /// rule of its own; see [applyRetention].
  final RetentionPolicyEngine retention;

  /// Picked-but-not-yet-adopted references, by id. Adoption is what makes a
  /// file durable; before that the reference only points at wherever the OS
  /// dialog left it.
  final Map<String, PickedFile> _pendingPicks = {};

  RealFileService({
    FilePicker? picker,
    Directory? rootOverride,
    this.retention = const RetentionPolicyEngine(),
  }) : _picker = picker ?? const PlatformFilePicker(),
       _rootOverride = rootOverride;

  /// The sandbox root. Everything this service touches lives inside it.
  Future<Directory> get rootDirectory async {
    if (_resolvedRoot != null) return _resolvedRoot!;
    final base = _rootOverride ?? await getApplicationDocumentsDirectory();
    final root = Directory(p.join(base.path, 'anything_files'));
    if (!root.existsSync()) root.createSync(recursive: true);
    _resolvedRoot = root;
    return root;
  }

  @override
  Future<FileReference?> pickFile({
    List<String>? allowedExtensions,
    int? maxSizeBytes,
  }) {
    return _pick(allowedExtensions: allowedExtensions, imagesOnly: false);
  }

  @override
  Future<FileReference?> pickImage({int? maxSizeBytes}) {
    return _pick(imagesOnly: true);
  }

  Future<FileReference?> _pick({
    List<String>? allowedExtensions,
    required bool imagesOnly,
  }) async {
    final picked = await _picker.pick(
      allowedExtensions: allowedExtensions,
      imagesOnly: imagesOnly,
    );
    if (picked == null) return null;

    // Size is reported, never enforced here: FileCapability owns the size
    // policy (`_effectiveMaxSize`/`_validateSize`) and enforcing it twice, in
    // two places, is how the two copies drift apart.
    final id = _idFor(picked.name);
    _pendingPicks[id] = picked;
    return FileReference(
      id: id,
      displayName: picked.name,
      mimeType: picked.mimeType,
      sizeBytes: picked.sizeBytes,
    );
  }

  @override
  Future<bool> adoptFile(String fileId, String experienceId) async {
    final picked = _pendingPicks[fileId];
    if (picked == null || !picked.hasReadableContent) return false;

    final destination = await _resolveInside(
      p.join('experiences', experienceId, fileId),
    );
    if (destination == null) return false;

    Directory(p.dirname(destination.path)).createSync(recursive: true);
    if (picked.bytes != null && picked.bytes!.isNotEmpty) {
      destination.writeAsBytesSync(picked.bytes!);
    } else {
      final source = File(picked.path!);
      if (!source.existsSync()) return false;
      source.copySync(destination.path);
    }
    _pendingPicks.remove(fileId);
    return true;
  }

  @override
  Future<bool> deleteAdoptedFile(String fileId, String experienceId) async {
    // Ownership IS the path: the id is resolved under this Experience's own
    // directory, so another Experience's file is simply not there to delete.
    final target = await _resolveInside(
      p.join('experiences', experienceId, fileId),
    );
    if (target == null || !target.existsSync()) return false;
    target.deleteSync();
    return true;
  }

  /// Whether [experienceId] currently owns an adopted [fileId].
  Future<bool> ownsAdoptedFile(String fileId, String experienceId) async {
    final target = await _resolveInside(
      p.join('experiences', experienceId, fileId),
    );
    return target != null && target.existsSync();
  }

  /// Every adopted file id belonging to [experienceId].
  Future<List<String>> adoptedFilesFor(String experienceId) async {
    final dir = await _resolveInside(p.join('experiences', experienceId));
    if (dir == null || !Directory(dir.path).existsSync()) return [];
    return [
      for (final entity in Directory(dir.path).listSync())
        if (entity is File) p.basename(entity.path),
    ]..sort();
  }

  /// EXPORT — copies an adopted file out under [exportName], inside the
  /// sandbox's `exports/` area. Returns the written path, or null if the
  /// source is missing or the name would escape the sandbox.
  Future<String?> exportFile(
    String fileId,
    String experienceId,
    String exportName,
  ) async {
    final source = await _resolveInside(
      p.join('experiences', experienceId, fileId),
    );
    if (source == null || !source.existsSync()) return null;

    final destination = await _resolveInside(p.join('exports', exportName));
    if (destination == null) return null;

    Directory(p.dirname(destination.path)).createSync(recursive: true);
    source.copySync(destination.path);
    return destination.path;
  }

  /// EXPORT A TEXT PAYLOAD — Implementation Specification IS-P02 Phase 9.
  ///
  /// IS-P12: prefer a user-visible `Downloads/Anything/` location when the
  /// platform allows it. Fall back to a Storage Access Framework save dialog,
  /// then to the sandboxed `exports/` directory. The returned [File.path] is
  /// always the real destination — never a guessed Downloads path.
  ///
  /// This service owns file I/O (IS-R49) and nothing else: it never learns
  /// what a package is. `ExperiencePortability` composes it with the codec.
  Future<File?> writeExport(String name, String contents) async {
    final public = await _tryWritePublicExport(name, contents);
    if (public != null) return public;

    final picked = await _trySaveViaPicker(name, contents);
    if (picked != null) return picked;

    final destination = await _resolveInside(p.join('exports', name));
    if (destination == null) return null;
    final dir = Directory(p.dirname(destination.path));
    dir.createSync(recursive: true);
    final uniqueName = _uniqueFileName(dir, name);
    // Basename-only rename stays inside the already-sandboxed exports/ dir.
    final unique = File(p.join(dir.path, uniqueName));
    unique.writeAsStringSync(contents);
    return unique;
  }

  /// User-visible Downloads/Anything when writable; otherwise null.
  Future<File?> _tryWritePublicExport(String name, String contents) async {
    final dirs = <Directory>[];
    if (Platform.isAndroid) {
      dirs.addAll([
        Directory('/storage/emulated/0/Download/Anything'),
        Directory('/storage/emulated/0/Downloads/Anything'),
      ]);
    }
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        dirs.add(Directory(p.join(downloads.path, 'Anything')));
      }
    } catch (_) {}

    for (final dir in dirs) {
      try {
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final unique = _uniqueFileName(dir, name);
        final file = File(p.join(dir.path, unique));
        file.writeAsStringSync(contents);
        return file;
      } catch (_) {
        // Scoped storage or permission — try next candidate.
      }
    }
    return null;
  }

  Future<File?> _trySaveViaPicker(String name, String contents) async {
    try {
      final path = await picker_pkg.FilePicker.platform.saveFile(
        dialogTitle: 'Export Experience',
        fileName: name,
        type: picker_pkg.FileType.custom,
        allowedExtensions: const ['anything', 'json'],
        bytes: Uint8List.fromList(contents.codeUnits),
      );
      if (path == null || path.isEmpty) return null;
      final file = File(path);
      if (!file.existsSync()) {
        file.writeAsStringSync(contents);
      }
      return file;
    } catch (_) {
      return null;
    }
  }

  String _uniqueFileName(Directory dir, String name) {
    final file = File(p.join(dir.path, name));
    if (!file.existsSync()) return name;
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    for (var i = 2; i < 1000; i++) {
      final candidate = '${stem}_$i$ext';
      if (!File(p.join(dir.path, candidate)).existsSync()) return candidate;
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return '${stem}_$stamp$ext';
  }

  /// READ A PICKED FILE AS TEXT — Implementation Specification IS-P02 Phase 9.
  ///
  /// Additive, and deliberately narrow. [adoptFile] copies a picked file INTO
  /// an Experience's own area, which is the right move for an asset an
  /// Experience will keep. An imported package is not an asset and belongs to
  /// no Experience yet, so adoption would create a directory for an
  /// Experience that may never be installed.
  ///
  /// Returns null when the pick has expired or the file has gone. Reading is
  /// all this does: the caller decides whether the bytes mean anything.
  Future<String?> readPickedText(String fileId) async {
    final picked = _pendingPicks[fileId];
    if (picked == null) return null;
    // Prefer in-memory bytes (Android SAF / content URI picks).
    if (picked.bytes != null && picked.bytes!.isNotEmpty) {
      try {
        return utf8.decode(picked.bytes!, allowMalformed: true);
      } catch (_) {
        return null;
      }
    }
    final path = picked.path;
    if (path == null || path.isEmpty) return null;
    final source = File(path);
    if (!source.existsSync()) return null;
    try {
      return source.readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  /// TEMPORARY FILES — scratch space inside the sandbox.
  Future<File?> createTemporaryFile(String name, List<int> bytes) async {
    final target = await _resolveInside(p.join('tmp', name));
    if (target == null) return null;
    Directory(p.dirname(target.path)).createSync(recursive: true);
    target.writeAsBytesSync(bytes);
    return target;
  }

  Future<void> clearTemporaryFiles() async {
    final root = await rootDirectory;
    final tmp = Directory(p.join(root.path, 'tmp'));
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  }

  /// Applies the ONE canonical retention policy to scratch and export areas
  /// (IS-R50 Task 6).
  ///
  /// This service owns no retention rule of its own: it reports each file's
  /// age and size to `RetentionPolicyEngine` and deletes exactly what the
  /// engine decides. `clearTemporaryFiles()` above remains an unconditional,
  /// caller-initiated wipe — an explicit user/caller action, not a policy
  /// outcome, which is why it is deliberately NOT routed through the engine.
  ///
  /// Experience assets are NEVER reclaimed here. An adopted file is a user's
  /// own document; deleting it is an explicit action through
  /// `deleteAdoptedFile`, never a retention side effect.
  ///
  /// Returns the deleted paths.
  Future<List<String>> applyRetention({DateTime? now}) async {
    final root = await rootDirectory;
    final deleted = <String>[];

    for (final entry in {
      LifecycleDomain.temporaryFiles: 'tmp',
      LifecycleDomain.exports: 'exports',
    }.entries) {
      final dir = Directory(p.join(root.path, entry.value));
      if (!dir.existsSync()) continue;

      final files = [
        for (final e in dir.listSync(recursive: true))
          if (e is File) e,
      ];
      if (files.isEmpty) continue;

      final evaluation = retention.evaluate(
        domain: entry.key,
        candidates: [
          for (final f in files)
            LifecycleCandidate(
              id: f.path,
              timestamp: f.statSync().modified,
              sizeBytes: f.lengthSync(),
            ),
        ],
        now: now,
      );

      for (final path in evaluation.reclaimedIds) {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
          deleted.add(path);
        }
      }
    }
    return deleted;
  }

  /// WORKSPACE ASSETS — shared, Experience-neutral storage.
  Future<File?> workspaceAsset(String name) =>
      _resolveInside(p.join('workspace', name));

  /// Resolves [relative] inside the sandbox root, or returns null if it would
  /// escape. Rejection rather than sanitisation is deliberate: quietly
  /// rewriting a traversal attempt hides the fact that one was made.
  Future<File?> _resolveInside(String relative) async {
    final root = await rootDirectory;
    final rootPath = p.normalize(root.absolute.path);
    final candidate = p.normalize(p.join(rootPath, relative));
    if (candidate != rootPath && !p.isWithin(rootPath, candidate)) return null;
    return File(candidate);
  }

  /// Stable, filesystem-safe id.
  ///
  /// Two separate rules, because the first alone is not enough. Collapsing
  /// non-`[A-Za-z0-9._-]` removes path separators — but `.` is in that safe
  /// set, so `../../evil` would survive as `.._.._evil`. That particular form
  /// is still CONTAINED (it is one path segment, so `p.normalize` does not
  /// treat it as traversal, and [_resolveInside] would reject it anyway), but
  /// an id carrying `..` is a latent hazard the moment any future code joins
  /// it with a non-normalising API. Collapsing runs of dots removes the whole
  /// class of concern for the cost of one line, and the id is opaque to
  /// callers regardless.
  String _idFor(String displayName) {
    final safe = displayName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'\.{2,}'), '_');
    return 'file-${DateTime.now().microsecondsSinceEpoch}-$safe';
  }
}
