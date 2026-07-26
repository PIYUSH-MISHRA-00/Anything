/// File capability — trusted file operations for Experiences.
library;

import '../platform/capability_platform.dart';

/// Safe file reference returned to Experiences.
class FileReference {
  final String id;
  final String displayName;
  final String? mimeType;
  final int? sizeBytes;
  final bool isAdopted;
  final String? adoptedPath;

  const FileReference({
    required this.id,
    required this.displayName,
    this.mimeType,
    this.sizeBytes,
    this.isAdopted = false,
    this.adoptedPath,
  });
}

/// File service abstraction.
abstract class FileService {
  Future<FileReference?> pickFile({
    List<String>? allowedExtensions,
    int? maxSizeBytes,
  });
  Future<FileReference?> pickImage({int? maxSizeBytes});
  Future<bool> adoptFile(String fileId, String experienceId);
  Future<bool> deleteAdoptedFile(String fileId, String experienceId);
}

/// Fake file service for testing with ownership enforcement.
class FakeFileService implements FileService {
  final List<FileReference> _files = [];
  final Map<String, String> _ownership = {}; // fileId -> experienceId

  void addFile(FileReference file) => _files.add(file);

  @override
  Future<FileReference?> pickFile({
    List<String>? allowedExtensions,
    int? maxSizeBytes,
  }) async {
    if (_files.isEmpty) return null;
    return _files.first;
  }

  @override
  Future<FileReference?> pickImage({int? maxSizeBytes}) async {
    return _files
        .where((f) => f.mimeType?.startsWith('image/') == true)
        .firstOrNull;
  }

  @override
  Future<bool> adoptFile(String fileId, String experienceId) async {
    _files.firstWhere(
      (f) => f.id == fileId,
      orElse: () => throw Exception('File not found'),
    );
    _ownership[fileId] = experienceId;
    return true;
  }

  @override
  Future<bool> deleteAdoptedFile(String fileId, String experienceId) async {
    // Ownership check: only the owning Experience can delete
    if (_ownership[fileId] != experienceId) return false;
    _ownership.remove(fileId);
    return true;
  }
}

/// Maximum file size (5MB default).
const int _defaultMaxFileSize = 5 * 1024 * 1024;

/// File capability for Experiences.
class FileCapability extends PlatformCapability {
  final FileService _service;
  final String _experienceId;
  final int _maxFileSize;

  FileCapability({
    required FileService service,
    required String experienceId,
    int maxFileSize = _defaultMaxFileSize,
  }) : _service = service,
       _experienceId = experienceId,
       _maxFileSize = maxFileSize,
       super(
         id: 'files',
         name: 'Files',
         description: 'File selection and management',
         supportedOperations: [
           'pickFile',
           'pickImage',
           'adoptFile',
           'deleteFile',
         ],
       );

  /// Compute effective max size: min(trusted max, requested max).
  int _effectiveMaxSize(int? requested) {
    if (requested == null || requested <= 0) return _maxFileSize;
    return requested < _maxFileSize ? requested : _maxFileSize;
  }

  /// Validate file size against effective maximum for this invocation.
  CapabilityInvocationResult? _validateSize(
    FileReference file,
    int effectiveMax,
  ) {
    if (file.sizeBytes != null && file.sizeBytes! > effectiveMax) {
      return const CapabilityInvocationResult(
        status: CapabilityResultStatus.policyDenied,
        error: 'File exceeds maximum allowed size',
      );
    }
    return null;
  }

  @override
  Future<CapabilityInvocationResult> execute(
    String operation,
    Map<String, dynamic> params,
  ) async {
    switch (operation) {
      case 'pickFile':
        final effectiveMax = _effectiveMaxSize(params['maxSizeBytes'] as int?);
        final result = await _service.pickFile(maxSizeBytes: effectiveMax);
        if (result == null) {
          return const CapabilityInvocationResult(
            status: CapabilityResultStatus.cancelled,
          );
        }
        final sizeError = _validateSize(result, effectiveMax);
        if (sizeError != null) return sizeError;
        return CapabilityInvocationResult.success(
          data: {
            'fileId': result.id,
            'displayName': result.displayName,
            'mimeType': result.mimeType,
            'sizeBytes': result.sizeBytes,
          },
        );

      case 'pickImage':
        final effectiveMax = _effectiveMaxSize(params['maxSizeBytes'] as int?);
        final result = await _service.pickImage(maxSizeBytes: effectiveMax);
        if (result == null) {
          return const CapabilityInvocationResult(
            status: CapabilityResultStatus.cancelled,
          );
        }
        final sizeError = _validateSize(result, effectiveMax);
        if (sizeError != null) return sizeError;
        return CapabilityInvocationResult.success(
          data: {
            'fileId': result.id,
            'displayName': result.displayName,
            'mimeType': result.mimeType,
            'sizeBytes': result.sizeBytes,
          },
        );

      case 'adoptFile':
        final fileId = params['fileId'] as String?;
        if (fileId == null) {
          return const CapabilityInvocationResult(
            status: CapabilityResultStatus.invalidArguments,
            error: 'fileId required',
          );
        }
        final adopted = await _service.adoptFile(fileId, _experienceId);
        return CapabilityInvocationResult.success(data: {'adopted': adopted});

      case 'deleteFile':
        final fileId = params['fileId'] as String?;
        if (fileId == null) {
          return const CapabilityInvocationResult(
            status: CapabilityResultStatus.invalidArguments,
            error: 'fileId required',
          );
        }
        final deleted = await _service.deleteAdoptedFile(fileId, _experienceId);
        return CapabilityInvocationResult.success(data: {'deleted': deleted});

      default:
        return CapabilityInvocationResult(
          status: CapabilityResultStatus.unsupported,
          error: 'Unknown file operation: $operation',
        );
    }
  }
}
