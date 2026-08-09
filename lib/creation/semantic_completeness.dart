/// Semantic completeness — intent/capability requirements vs generated package.
///
/// Deterministic. Does not hard-code product domains; checks capability
/// presence against what the package actually exposes.
library;

import '../synthesis/app_blueprint.dart';
import 'app_capabilities.dart';
import 'experience_package.dart';

/// One missing or incomplete capability.
class CapabilityGap {
  final String capabilityId;
  final String reason;

  const CapabilityGap({required this.capabilityId, required this.reason});
}

/// Result of comparing required capabilities to a package.
class SemanticCompletenessResult {
  final bool isComplete;
  final List<CapabilityGap> gaps;
  final List<String> warnings;

  const SemanticCompletenessResult({
    required this.isComplete,
    this.gaps = const [],
    this.warnings = const [],
  });

  List<String> get errorMessages => gaps
      .map((g) => 'missing_capability:${g.capabilityId}: ${g.reason}')
      .toList();
}

/// Validates that a generated package satisfies inferred capabilities.
class SemanticCompletenessValidator {
  const SemanticCompletenessValidator();

  SemanticCompletenessResult validate({
    required ExperiencePackage package,
    required Set<String> requiredCapabilities,
    AppBlueprint? blueprint,
  }) {
    final probe = PackageCapabilityProbe(package);
    final gaps = <CapabilityGap>[];
    final warnings = <String>[];

    if (requiredCapabilities.contains(AppCapabilityIds.calculation) ||
        requiredCapabilities.contains(AppCapabilityIds.scientificCalculation)) {
      if (!probe.hasCalculationPad && !probe.hasTextInput) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.calculation,
            reason: 'no numeric input controls for calculation',
          ),
        );
      } else if (!probe.hasCalculationPad) {
        // Form-only calculators are incomplete for interactive use.
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.calculation,
            reason:
                'calculation requires digit pad, operators, equals, and clear',
          ),
        );
      }
      if (requiredCapabilities.contains(
            AppCapabilityIds.scientificCalculation,
          ) &&
          probe.hasCalculationPad &&
          !probe.hasScientificOps) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.scientificCalculation,
            reason:
                'scientific calculation requires unary/scientific operations',
          ),
        );
      }
      if (!probe.hasResultDisplay) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.resultDisplay,
            reason: 'no result/display binding for calculation output',
          ),
        );
      }
    }

    if (requiredCapabilities.contains(AppCapabilityIds.timers)) {
      if (!probe.hasTimingControls) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.timers,
            reason:
                'timing requires start, pause/reset, and an elapsed display',
          ),
        );
      }
      if (!probe.hasResultDisplay) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.resultDisplay,
            reason: 'no display binding for elapsed time',
          ),
        );
      }
    }

    if (requiredCapabilities.contains(AppCapabilityIds.weatherData)) {
      if (!probe.hasWeatherService) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.weatherData,
            reason: 'weather requires a weatherData service, not knowledge',
          ),
        );
      }
      if (probe.hasKnowledgeService && !probe.hasWeatherService) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.weatherData,
            reason:
                'generic knowledge/Wikipedia cannot satisfy weatherData',
          ),
        );
      }
      if (!probe.hasTextInput || !probe.hasRefreshAction) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.weatherData,
            reason: 'weather needs location input and search/refresh',
          ),
        );
      }
      if (!probe.hasLoadingState || !probe.hasErrorState) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.loadingState,
            reason: 'weather needs loading and error states',
          ),
        );
      }
    }

    if (requiredCapabilities.contains(AppCapabilityIds.newsData)) {
      if (!probe.hasNewsService) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.newsData,
            reason: 'news requires a newsData service, not knowledge',
          ),
        );
      }
      if (probe.hasKnowledgeService && !probe.hasNewsService) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.newsData,
            reason: 'generic knowledge/Wikipedia cannot satisfy newsData',
          ),
        );
      }
      if (!probe.hasTextInput || !probe.hasRefreshAction) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.newsData,
            reason: 'news needs query input and search/refresh',
          ),
        );
      }
    }

    // Network/reference shells are installable without a CRUD surface. Models
    // often emit leftover entities/actions for "dashboard" prompts; those must
    // not block a package that already has query/refresh/loading/error.
    final networkShellSatisfied =
        requiredCapabilities.contains(AppCapabilityIds.networkData) &&
        probe.hasKnowledgeService &&
        probe.hasRefreshAction &&
        probe.hasTextInput;

    // Calculation pads are the primary surface for utility math apps. Models
    // frequently emit a decorative "history" entity; that must not block install
    // once a real keypad/result binding exists.
    final calculationShellSatisfied = probe.hasCalculationPad;
    final timingShellSatisfied = probe.hasTimingControls;

    if (requiredCapabilities.contains(AppCapabilityIds.crud) &&
        !networkShellSatisfied &&
        !calculationShellSatisfied &&
        !timingShellSatisfied) {
      if (!probe.hasEntityList && !probe.hasEntityForm) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.crud,
            reason: 'CRUD apps need a list or form surface',
          ),
        );
      }
      if (!probe.hasEntityForm) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.form,
            reason: 'create/edit form missing',
          ),
        );
      }
      if (!probe.hasPersistence) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.persistence,
            reason: 'durable entity schema missing',
          ),
        );
      }
    }

    if (requiredCapabilities.contains(AppCapabilityIds.networkData) ||
        requiredCapabilities.contains(AppCapabilityIds.webData)) {
      if (!probe.hasTextInput) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.input,
            reason: 'network/data apps need a query or location input',
          ),
        );
      }
      if (!probe.hasRefreshAction) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.refresh,
            reason: 'no refresh action for external data',
          ),
        );
      }
      if (!probe.hasLoadingState) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.loadingState,
            reason: 'loading state variable missing',
          ),
        );
      }
      if (!probe.hasErrorState) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.errorState,
            reason: 'error state variable missing',
          ),
        );
      }
      if (!probe.hasResultDisplay) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.resultDisplay,
            reason: 'no surface to present retrieved data',
          ),
        );
      }
      if (!probe.hasKnowledgeService) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.networkData,
            reason: 'no knowledgeRetrieval/httpClient service declared',
          ),
        );
      }
    }

    if (requiredCapabilities.contains(AppCapabilityIds.persistence) &&
        !probe.hasPersistence &&
        !requiredCapabilities.contains(AppCapabilityIds.calculation) &&
        !requiredCapabilities.contains(AppCapabilityIds.timers)) {
      // Pure utilities may claim no persistence; skip when calculation-only.
      if (blueprint == null ||
          blueprint.actions.any(
            (a) =>
                a.actionType == BlueprintActionType.create ||
                a.actionType == BlueprintActionType.update ||
                a.actionType == BlueprintActionType.delete,
          )) {
        gaps.add(
          const CapabilityGap(
            capabilityId: AppCapabilityIds.persistence,
            reason: 'persistence required but data schema empty',
          ),
        );
      }
    }

    return SemanticCompletenessResult(
      isComplete: gaps.isEmpty,
      gaps: gaps,
      warnings: warnings,
    );
  }
}
