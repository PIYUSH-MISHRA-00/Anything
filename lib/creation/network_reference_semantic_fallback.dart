/// Deterministic SemanticApp for network/reference intents when knowledge
/// acquisition cannot complete at plan time (IS-P10).
///
/// Capability-based — never branches on product domain names.
library;

import '../kernel/understanding/intent_understanding.dart';
import '../synthesis/app_blueprint.dart';
import '../synthesis/application_reasoner.dart';
import 'app_capabilities.dart';
import 'display_naming.dart';

/// Builds a reference/network SemanticApp the CreationEngine already knows
/// how to materialize into a query/refresh/loading/error/result Experience.
class NetworkReferenceSemanticFallback {
  const NetworkReferenceSemanticFallback();

  SemanticApp fromUnderstanding(
    IntentUnderstanding understanding, {
    String? knowledgePurpose,
  }) {
    final name = experienceDisplayName(
      generatedName: '',
      userIntent: understanding.objective,
    );
    final purpose = knowledgePurpose?.trim().isNotEmpty == true
        ? knowledgePurpose!.trim()
        : understanding.desiredOutcome.isNotEmpty
        ? understanding.desiredOutcome
        : understanding.objective;

    // No synthetic entity/action IDs — BlueprintValidator rejects dangling
    // targetEntityId references, and NetworkReferenceInterfaceFactory /
    // DeterministicCapabilityRepair materialize the query/refresh shell from
    // requiredCapabilities + networkConfig.
    return SemanticApp(
      name: name,
      purpose: purpose,
      entities: const [],
      actions: const [],
      views: const [
        SemanticView(
          id: 'reference_main',
          name: 'Dashboard',
          purpose: 'Query and display live reference data',
          viewType: BlueprintViewType.dashboard,
          isDefault: true,
        ),
      ],
      tags: const ['network', 'reference'],
      archetypes: const ['reference'],
      requiredCapabilities: const [
        AppCapabilityIds.networkData,
        AppCapabilityIds.webData,
        AppCapabilityIds.refresh,
        AppCapabilityIds.loadingState,
        AppCapabilityIds.errorState,
        AppCapabilityIds.input,
        AppCapabilityIds.resultDisplay,
      ],
      networkConfig: BlueprintNetworkConfig(purpose: purpose),
    );
  }
}
