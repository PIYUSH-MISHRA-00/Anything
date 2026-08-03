/// Generator Framework — Implementation Milestone R10. The ONE canonical,
/// LANGUAGE-INDEPENDENT interface every future language generator must
/// implement, mirroring this codebase's established pluggable-interface
/// convention (`ModelProvider`, `KnowledgeProvider`, `SearchProvider` —
/// `lib/core/contracts/`): a real Dart `abstract interface class`, real
/// typed request/response objects, contracts never depending on a
/// specific implementation.
///
/// Investigation (Rule 3) confirmed no generic, multi-language generator
/// abstraction exists anywhere in this codebase before this milestone.
/// `GenericPackageBuilder` (`lib/synthesis/generic_package_builder.dart`)
/// is the closest candidate — its own doc comment states plainly "This is
/// NOT part of the production pipeline... test-only... DO NOT use this in
/// production code" — a single-purpose, Anything-internal, Flutter-
/// `ExperiencePackage`-specific test helper, categorically different from
/// a pluggable, language-neutral generator interface. No duplication
/// exists; this is genuinely new, sanctioned work.
///
/// Consumes `CanonicalImplementationModel` (Implementation Milestone R9)
/// exclusively — zero knowledge of Flutter/Dart/React/Angular/Vue/Node/
/// Python/Java/Go/Swift/Kotlin/C# anywhere in this file.
library;

import '../implementation_model/canonical_implementation_model.dart';
import 'generation_result.dart';

/// Semantic version for a generator implementation — real, small, never
/// tied to any specific target language's own versioning scheme.
class GeneratorVersion {
  final int major;
  final int minor;
  final int patch;

  const GeneratorVersion({required this.major, required this.minor, required this.patch});

  @override
  String toString() => '$major.$minor.$patch';
}

/// A real, checkable declaration of what an [Artifact] kind a generator
/// can produce — mirrors `CapabilityDescriptor`'s own
/// declare-before-invoke pattern (`lib/capabilities/registry/`), never a
/// parallel capability taxonomy (this is a DIFFERENT concern —
/// "what artifact kinds can this generator emit" — not an Anything
/// runtime capability).
enum GeneratorCapability { sourceFiles, configuration, manifests, buildInstructions, documentation }

/// Real, small identity for a generator — id/name/version/declared
/// capabilities. Never a language-specific type (e.g. no `dartVersion`,
/// no `flutterSdkConstraint` — those belong to a FUTURE, real language
/// generator's own implementation, never to this canonical metadata
/// shape).
class GeneratorMetadata {
  final String id;
  final String name;
  final GeneratorVersion version;
  final List<GeneratorCapability> capabilities;

  const GeneratorMetadata({required this.id, required this.name, required this.version, this.capabilities = const []});
}

/// Identifies WHAT is being generated for — a real, opaque, language-
/// neutral identifier (e.g. `'reference-summary'`), never a language/
/// framework enum (`flutter`/`react`/... are explicitly forbidden by this
/// milestone's own spec).
class GeneratorTarget {
  final String id;
  final String name;

  const GeneratorTarget({required this.id, required this.name});
}

/// Real, minimal generation options — a caller-supplied, generator-
/// interpreted key/value set (e.g. output-path preferences). Never
/// interpreted by the framework itself, only passed through.
class GeneratorOptions {
  final Map<String, String> values;

  const GeneratorOptions({this.values = const {}});

  static const GeneratorOptions empty = GeneratorOptions();
}

/// Everything one [Generator.generate] call needs — the real,
/// already-computed `CanonicalImplementationModel` (R9), the target
/// being generated for, and real options. Never carries anything
/// language-specific.
class GeneratorContext {
  final CanonicalImplementationModel model;
  final GeneratorTarget target;
  final GeneratorOptions options;

  const GeneratorContext({required this.model, required this.target, this.options = GeneratorOptions.empty});
}

/// The ONE canonical interface. Every real, future language generator
/// (a Flutter generator, a backend-service generator, a web generator...)
/// implements this SAME interface — never a separate, per-language API.
/// Deterministic by contract (Rule 7): the same [GeneratorContext] must
/// always produce a structurally identical [GenerationResult] — verified
/// directly by this milestone's own determinism test, not merely assumed
/// of future implementations.
abstract interface class Generator {
  GeneratorMetadata get metadata;

  GenerationResult generate(GeneratorContext context);
}
