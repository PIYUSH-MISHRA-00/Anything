/// Creation Context — contains everything the CreationEngine needs.
library;

import '../core/contracts/intent.dart';
import '../kernel/specification/experience_spec.dart';
import '../kernel/planning/execution_plan.dart';
import '../knowledge/knowledge_bundle.dart';
import '../capabilities/registry/capability_descriptor.dart';
import '../synthesis/app_blueprint.dart';

/// Platform context for creation.
class PlatformContext {
  final String platform;
  final int sdkVersion;
  final bool isDebug;

  const PlatformContext({
    required this.platform,
    required this.sdkVersion,
    this.isDebug = false,
  });
}

/// Security policy for creation.
class CreationSecurityPolicy {
  final List<String> allowedBehaviorNodeTypes;
  final List<String> allowedCapabilityIds;
  final int maxScreens;
  final int maxUiNodes;
  final int maxBehaviorNodes;
  final int maxStateVariables;
  final int maxAssetSizeBytes;
  final int maxTotalPackageSizeBytes;

  const CreationSecurityPolicy({
    this.allowedBehaviorNodeTypes = const [
      'event',
      'condition',
      'stateRead',
      'stateWrite',
      'calculation',
      'validation',
      'transform',
      'branch',
      'capabilityInvocation',
      'serviceInvocation',
      'navigation',
      'dataQuery',
      'dataMutation',
      'errorHandling',
      'return',
    ],
    this.allowedCapabilityIds = const [],
    this.maxScreens = 20,
    this.maxUiNodes = 500,
    this.maxBehaviorNodes = 200,
    this.maxStateVariables = 50,
    this.maxAssetSizeBytes = 5 * 1024 * 1024, // 5MB
    this.maxTotalPackageSizeBytes = 20 * 1024 * 1024, // 20MB
  });
}

/// The complete context for creating an Experience.
class CreationContext {
  final Intent intent;
  final ExperienceSpec specification;
  final ExecutionPlan plan;
  final AppBlueprint? blueprint;
  final KnowledgeBundle? knowledgeBundle;
  final List<CapabilityDescriptor> availableCapabilities;
  final PlatformContext platformContext;
  final CreationSecurityPolicy securityPolicy;
  final bool isOffline;
  final Map<String, dynamic> generationMetadata;

  const CreationContext({
    required this.intent,
    required this.specification,
    required this.plan,
    this.blueprint,
    this.knowledgeBundle,
    this.availableCapabilities = const [],
    required this.platformContext,
    required this.securityPolicy,
    this.isOffline = true,
    this.generationMetadata = const {},
  });
}
