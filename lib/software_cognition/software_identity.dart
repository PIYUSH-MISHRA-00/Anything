/// SoftwareIdentity / SoftwareFingerprint — stable, deterministic identity
/// for software artifacts, mirroring EntityIdentity's proven
/// "reuse an existing stable id, or build a deterministic structural
/// fingerprint" pattern (`lib/world_model/entity_identity.dart`) exactly,
/// so a SoftwareNode's identity can later unify with a World Graph
/// EntityIdentity without inventing a second identity scheme.
library;

import 'software_types.dart';

class SoftwareIdentity {
  final String value;

  const SoftwareIdentity._(this.value);

  /// Reuses an already-stable id (a package name, a repository URL) —
  /// never re-derived.
  factory SoftwareIdentity.stable(SoftwareNodeKind kind, String id) =>
      SoftwareIdentity._('${kind.name}:$id');

  /// Deterministic structural fingerprint for something with no existing
  /// stable id (a detected pattern, an inferred architecture layer). Two
  /// structurally-identical things always resolve to the same identity.
  factory SoftwareIdentity.structural(
    SoftwareNodeKind kind,
    List<String> signature,
  ) {
    final sorted = [...signature]..sort();
    return SoftwareIdentity._('${kind.name}:${sorted.join(',')}');
  }

  @override
  bool operator ==(Object other) =>
      other is SoftwareIdentity && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// A deterministic structural fingerprint used for similarity comparison
/// — the same sorted-signature approach as SoftwareIdentity.structural,
/// but kept as its own value type since similarity compares fingerprints
/// against each other rather than using them as graph identities.
class SoftwareFingerprint {
  final List<String> signature;

  SoftwareFingerprint(List<String> signature)
    : signature = ([...signature]..sort());

  /// Jaccard similarity (intersection / union) over the two fingerprints'
  /// signature sets — deterministic, symmetric, bounded [0.0, 1.0].
  double similarityTo(SoftwareFingerprint other) {
    final a = signature.toSet();
    final b = other.signature.toSet();
    if (a.isEmpty && b.isEmpty) return 1.0;
    final intersection = a.intersection(b).length;
    final union = a.union(b).length;
    if (union == 0) return 0.0;
    return intersection / union;
  }

  @override
  bool operator ==(Object other) =>
      other is SoftwareFingerprint &&
      other.signature.join(',') == signature.join(',');

  @override
  int get hashCode => signature.join(',').hashCode;
}
