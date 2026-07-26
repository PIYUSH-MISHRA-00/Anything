/// Capability descriptor for the Anything Capability Registry.
///
/// Describes a capability without implementing it.
/// The registry uses these descriptors for capability resolution.
library;

/// Metadata describing a registered capability.
class CapabilityDescriptor {
  /// Stable identifier.
  final String id;

  /// Version string.
  final String version;

  /// Human-readable name.
  final String name;

  /// Description of what this capability provides.
  final String description;

  /// Category of capability.
  final CapabilityCategory category;

  /// Input contract description.
  final String inputContract;

  /// Output contract description.
  final String outputContract;

  /// Permissions needed.
  final List<String> requiredPermissions;

  /// Whether network is needed.
  final bool networkRequired;

  /// Whether the capability is currently available.
  final bool isAvailable;

  /// Runtime requirements.
  final Map<String, dynamic> runtimeRequirements;

  const CapabilityDescriptor({
    required this.id,
    required this.version,
    required this.name,
    required this.description,
    required this.category,
    required this.inputContract,
    required this.outputContract,
    this.requiredPermissions = const [],
    this.networkRequired = false,
    this.isAvailable = true,
    this.runtimeRequirements = const {},
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CapabilityDescriptor &&
          id == other.id &&
          version == other.version;

  @override
  int get hashCode => Object.hash(id, version);
}

/// Categories of capabilities.
enum CapabilityCategory {
  ui,
  computation,
  data,
  integration,
  security,
  knowledge,
  multimodal,
  storage,
  background,
}
