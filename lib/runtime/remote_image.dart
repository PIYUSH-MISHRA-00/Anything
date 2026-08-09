/// Generic remote image URL validation for Experience rendering.
///
/// Not news-specific — any InterfaceNode of type `remoteImage` / `image`
/// uses this.
library;

/// Validates and normalizes a remote image URL for safe display.
class RemoteImageUrl {
  RemoteImageUrl._();

  static const maxUrlLength = 2048;

  /// Returns a sanitized https/http URL, or null if unsuitable.
  static String? sanitize(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty || t.length > maxUrlLength) return null;
    Uri uri;
    try {
      uri = Uri.parse(t);
    } catch (_) {
      return null;
    }
    if (!uri.hasScheme || !uri.hasAuthority) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return null;
    if (uri.host.isEmpty) return null;
    return uri.toString();
  }

  static bool isValid(String? raw) => sanitize(raw) != null;
}
