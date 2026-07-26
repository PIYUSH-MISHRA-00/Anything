/// Capability Registry for Anything.
///
/// Manages registered capabilities and resolves requirements.
library;

import 'capability_descriptor.dart';

/// The central capability registry.
class CapabilityRegistry {
  final Map<String, CapabilityDescriptor> _capabilities = {};

  /// Register a capability.
  void register(CapabilityDescriptor capability) {
    _capabilities[capability.id] = capability;
  }

  /// Unregister a capability.
  void unregister(String capabilityId) {
    _capabilities.remove(capabilityId);
  }

  /// Get a capability by ID.
  CapabilityDescriptor? getCapability(String id) {
    return _capabilities[id];
  }

  /// List all registered capabilities.
  List<CapabilityDescriptor> get all => _capabilities.values.toList();

  /// Check if a capability is registered and available.
  bool isAvailable(String capabilityId) {
    final cap = _capabilities[capabilityId];
    return cap != null && cap.isAvailable;
  }

  /// Resolve a list of required capability IDs.
  ///
  /// Returns resolution results for each requirement.
  List<CapabilityResolution> resolve(List<String> requiredIds) {
    return requiredIds.map((id) {
      final cap = _capabilities[id];
      if (cap == null) {
        return CapabilityResolution(
          capabilityId: id,
          status: CapabilityResolutionStatus.unavailable,
          reason: 'Capability not registered',
        );
      }
      if (!cap.isAvailable) {
        return CapabilityResolution(
          capabilityId: id,
          status: CapabilityResolutionStatus.unavailable,
          reason: 'Capability currently unavailable',
        );
      }
      return CapabilityResolution(
        capabilityId: id,
        status: CapabilityResolutionStatus.resolved,
        descriptor: cap,
      );
    }).toList();
  }
}

/// Resolution status for a capability requirement.
enum CapabilityResolutionStatus { resolved, unavailable, futureUnsupported }

/// Result of resolving a single capability requirement.
class CapabilityResolution {
  final String capabilityId;
  final CapabilityResolutionStatus status;
  final CapabilityDescriptor? descriptor;
  final String? reason;

  const CapabilityResolution({
    required this.capabilityId,
    required this.status,
    this.descriptor,
    this.reason,
  });

  bool get isResolved => status == CapabilityResolutionStatus.resolved;
}
