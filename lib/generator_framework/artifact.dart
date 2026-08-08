/// Artifact Model — Implementation Milestone R10. A real, typed,
/// language-independent representation of what a generator produces:
/// files, directories, metadata, assets, dependencies, generated
/// sources, configuration, manifests, build instructions. Content is
/// real DATA (a `String` body, a real path) — never anything this
/// framework itself interprets or executes (no `Process.run`, no
/// `eval`, no dynamic loading anywhere in this package).
library;

/// What kind of thing an [Artifact] represents — real, closed vocabulary,
/// never tied to one language's own file-type conventions.
enum ArtifactKind {
  file,
  directory,
  metadata,
  asset,
  dependency,
  generatedSource,
  configuration,
  manifest,
  buildInstruction,
}

/// One real, inspectable, generated artifact. [path] is a real,
/// generator-supplied relative path (this framework never writes to
/// disk itself — producing `Artifact` DATA is the whole contract; actual
/// disk I/O, if ever wanted, is a separate, future, explicit caller
/// action, never implicit here). [content] is `null` for
/// [ArtifactKind.directory] (a real directory has no body).
class Artifact {
  final String id;
  final String path;
  final ArtifactKind kind;
  final String? content;

  const Artifact({
    required this.id,
    required this.path,
    required this.kind,
    this.content,
  });
}

/// A real, named grouping of related [Artifact]s (e.g. "everything for
/// one entity") — never a language-specific project-structure concept
/// (no "lib folder", no "src folder" baked in here; a real future
/// generator decides its own real paths when it builds its `Artifact`s).
class ArtifactGroup {
  final String id;
  final List<Artifact> artifacts;

  const ArtifactGroup({required this.id, this.artifacts = const []});
}
