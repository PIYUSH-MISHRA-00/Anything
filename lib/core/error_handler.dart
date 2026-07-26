import 'package:flutter/material.dart';

class ErrorInfo {
  final IconData icon;
  final String title;
  final String description;
  final bool canRetry;

  const ErrorInfo({
    required this.icon,
    required this.title,
    required this.description,
    this.canRetry = true,
  });
}

class ErrorHandler {
  static ErrorInfo classify(dynamic error) {
    final message = error.toString().toLowerCase();

    if (message.contains('socketexception') ||
        message.contains('network') ||
        message.contains('failed host lookup')) {
      return const ErrorInfo(
        icon: Icons.wifi_off,
        title: 'No Internet Connection',
        description: 'Please check your network and try again.',
      );
    }

    if (message.contains('timeout') || message.contains('timed out')) {
      return const ErrorInfo(
        icon: Icons.timer_off,
        title: 'Request Timed Out',
        description: 'The AI took too long to respond. Please try again.',
      );
    }

    if (message.contains('api key') ||
        message.contains('401') ||
        message.contains('unauthorized') ||
        message.contains('not configured')) {
      return const ErrorInfo(
        icon: Icons.key_off,
        title: 'API Key Issue',
        description: 'Your Groq API key is missing or invalid. Check Settings.',
        canRetry: false,
      );
    }

    if (message.contains('file') || message.contains('upload')) {
      return const ErrorInfo(
        icon: Icons.file_copy_outlined,
        title: 'File Error',
        description: 'There was a problem processing the attached file.',
      );
    }

    if (message.contains('permission')) {
      return const ErrorInfo(
        icon: Icons.block,
        title: 'Permission Denied',
        description: 'The required permission was not granted.',
        canRetry: false,
      );
    }

    return ErrorInfo(
      icon: Icons.error_outline,
      title: 'Something Went Wrong',
      description: error.toString().replaceAll('Exception: ', ''),
    );
  }

  static Widget buildErrorWidget(dynamic error, {VoidCallback? onRetry}) {
    final info = classify(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(info.icon, color: Colors.redAccent, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              info.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              info.description,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (info.canRetry && onRetry != null) ...[
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try Again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  side: const BorderSide(color: Colors.blueAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
