import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fileContextServiceProvider = Provider<FileContextService>((ref) {
  return FileContextService();
});

class FileContextService {
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5MB limit

  /// Picks a file and returns a tuple of (fileName, fileContent).
  Future<({String name, String context})?> pickAndProcessFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'txt',
        'csv',
        'md',
        'json',
        'pdf',
        'png',
        'jpg',
        'jpeg',
      ],
      withData: false,
      withReadStream: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final pickedFile = result.files.first;
    if (pickedFile.path == null) return null;

    final file = File(pickedFile.path!);
    final fileSize = await file.length();

    if (fileSize > _maxFileSizeBytes) {
      throw Exception('File too large (max 5MB). Please use a smaller file.');
    }

    final extension = pickedFile.extension?.toLowerCase() ?? '';
    final fileName = pickedFile.name;

    switch (extension) {
      case 'txt':
      case 'md':
      case 'json':
      case 'csv':
        final content = await file.readAsString();
        final label = extension == 'csv' ? 'CSV Dataset' : 'Text Document';
        return (name: fileName, context: '[$label: $fileName]\n$content');

      case 'pdf':
        // PDF text extraction requires external packages; provide the file path context
        return (
          name: fileName,
          context:
              '[PDF Document: $fileName] (PDF attached — summarize or analyze this document)',
        );

      case 'png':
      case 'jpg':
      case 'jpeg':
        // For images, we note the file for vision context
        return (
          name: fileName,
          context:
              '[Image: $fileName] (Image attached — describe or analyze this image)',
        );

      default:
        throw Exception('Unsupported file type: .$extension');
    }
  }
}
