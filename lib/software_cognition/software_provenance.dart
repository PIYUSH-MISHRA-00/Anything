/// SoftwareProvenance — the record every acquired software artifact
/// carries so origin is never lost (Vision Milestone V11's License /
/// Attribution / Copyright requirements). Extends the existing knowledge
/// provenance pattern (`ResourceProvenance`/`LicenseMetadata` in
/// `lib/knowledge/knowledge_resource.dart`) with the additional fields
/// software specifically requires (author, repository, commit, version)
/// rather than bloating the generic knowledge-resource type with
/// software-only fields it doesn't need.
library;

import '../knowledge/knowledge_resource.dart' show LicenseMetadata;

export '../knowledge/knowledge_resource.dart' show LicenseMetadata, LicensePolicy;

class SoftwareProvenance {
  final String sourceUrl;
  final String? author;
  final String? repositoryUrl;
  final String? commit;
  final String? version;
  final DateTime retrievedAt;
  final String provider;
  final LicenseMetadata license;

  const SoftwareProvenance({
    required this.sourceUrl,
    this.author,
    this.repositoryUrl,
    this.commit,
    this.version,
    required this.retrievedAt,
    required this.provider,
    required this.license,
  });
}
