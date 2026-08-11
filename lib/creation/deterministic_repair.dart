/// Bounded deterministic repair for missing capabilities.
///
/// Generate → validate → identify gaps → repair if possible → validate again.
/// No LLM loop. At most one repair pass per package.
///
/// IS-P12: repair must NOT change product category / primary intent. It may
/// only fill missing actions/state/bindings for the already-selected purpose.
library;

import '../synthesis/app_blueprint.dart';
import 'app_capabilities.dart';
import 'calculation_interface_factory.dart';
import 'calculation_spec.dart';
import 'experience_package.dart';
import 'network_reference_interface_factory.dart';
import 'semantic_completeness.dart';
import 'timing_interface_factory.dart';

/// Outcome of a deterministic repair attempt.
class DeterministicRepairResult {
  final ExperiencePackage package;
  final bool repaired;
  final List<String> appliedFixes;
  final SemanticCompletenessResult completeness;

  const DeterministicRepairResult({
    required this.package,
    required this.repaired,
    required this.appliedFixes,
    required this.completeness,
  });
}

/// Applies structural fixes when missing capabilities have known templates.
class DeterministicCapabilityRepair {
  const DeterministicCapabilityRepair();

  DeterministicRepairResult repair({
    required ExperiencePackage package,
    required Set<String> requiredCapabilities,
    AppBlueprint? blueprint,
  }) {
    final validator = const SemanticCompletenessValidator();
    var current = package;
    final fixes = <String>[];

    var completeness = validator.validate(
      package: current,
      requiredCapabilities: requiredCapabilities,
      blueprint: blueprint,
    );
    if (completeness.isComplete) {
      return DeterministicRepairResult(
        package: current,
        repaired: false,
        appliedFixes: const [],
        completeness: completeness,
      );
    }

    final gapIds = completeness.gaps.map((g) => g.capabilityId).toSet();

    // Timing first — never inject a calculator when timers are required.
    final wantsTiming =
        requiredCapabilities.contains(AppCapabilityIds.timers) ||
        gapIds.contains(AppCapabilityIds.timers);
    if (wantsTiming) {
      final before = PackageCapabilityProbe(current);
      if (!before.hasTimingControls) {
        current = const TimingInterfaceFactory().applyToPackage(
          current,
          name: blueprint?.name ?? current.manifest.name,
        );
        fixes.add('injected_timing_surface');
      }
    }

    // Calculation only when explicitly required — never from bare utility.
    final wantsCalculation =
        !wantsTiming &&
        (requiredCapabilities.contains(AppCapabilityIds.calculation) ||
            gapIds.contains(AppCapabilityIds.calculation) ||
            ((gapIds.contains(AppCapabilityIds.crud) ||
                    gapIds.contains(AppCapabilityIds.form)) &&
                blueprint != null &&
                _looksNumericCalculation(blueprint)));
    if (wantsCalculation) {
      final before = PackageCapabilityProbe(current);
      final calcSpec = CalculationSpec.resolve(
        capabilityIds: {...requiredCapabilities, ...gapIds},
        intentExpression: blueprint?.name ?? current.manifest.name,
      );
      final needsSci =
          calcSpec.isScientific ||
          requiredCapabilities.contains(AppCapabilityIds.scientificCalculation);
      if ((!before.hasCalculationPad && !before.hasTimingControls) ||
          (needsSci && !before.hasScientificOps && !before.hasTimingControls)) {
        current = const CalculationInterfaceFactory().applyToPackage(
          current,
          name: blueprint?.name ?? current.manifest.name,
          spec: needsSci
              ? const CalculationSpec(
                  mode: CalculationMode.scientific,
                  operations: CalculationSpec.scientificOps,
                )
              : calcSpec,
        );
        fixes.add(
          needsSci
              ? 'injected_scientific_calculation_pad'
              : 'injected_calculation_pad',
        );
      }
    }

    // Generic external data shell: weather, news, stocks, etc. all route
    // through NetworkReferenceInterfaceFactory (WebWeaveX via knowledgeRetrieval).
    final needsExternalData =
        requiredCapabilities.contains(AppCapabilityIds.weatherData) ||
        requiredCapabilities.contains(AppCapabilityIds.newsData) ||
        requiredCapabilities.contains(AppCapabilityIds.networkData) ||
        requiredCapabilities.contains(AppCapabilityIds.webData) ||
        requiredCapabilities.contains(AppCapabilityIds.webKnowledge) ||
        gapIds.contains(AppCapabilityIds.weatherData) ||
        gapIds.contains(AppCapabilityIds.newsData) ||
        gapIds.contains(AppCapabilityIds.networkData) ||
        gapIds.contains(AppCapabilityIds.webData);

    if (needsExternalData) {
      final needsNetworkShell =
          requiredCapabilities.contains(AppCapabilityIds.networkData) ||
          requiredCapabilities.contains(AppCapabilityIds.webData) ||
          requiredCapabilities.contains(AppCapabilityIds.webKnowledge) ||
          requiredCapabilities.contains(AppCapabilityIds.weatherData) ||
          requiredCapabilities.contains(AppCapabilityIds.newsData) ||
          blueprint?.networkConfig != null;
      final networkGaps =
          gapIds.contains(AppCapabilityIds.networkData) ||
          gapIds.contains(AppCapabilityIds.webData) ||
          gapIds.contains(AppCapabilityIds.weatherData) ||
          gapIds.contains(AppCapabilityIds.newsData) ||
          gapIds.contains(AppCapabilityIds.refresh) ||
          gapIds.contains(AppCapabilityIds.loadingState) ||
          gapIds.contains(AppCapabilityIds.errorState);
      final probe = PackageCapabilityProbe(current);
      if (needsNetworkShell && (networkGaps || !probe.hasKnowledgeService)) {
        current = const NetworkReferenceInterfaceFactory().applyToPackage(
          current,
          name: blueprint?.name ?? current.manifest.name,
          purpose: blueprint?.description ?? current.manifest.description,
        );
        fixes.add('injected_network_reference_shell');
      }
    } else {
      final needsNetworkShell =
          requiredCapabilities.contains(AppCapabilityIds.networkData) ||
          requiredCapabilities.contains(AppCapabilityIds.webData) ||
          requiredCapabilities.contains(AppCapabilityIds.webKnowledge) ||
          blueprint?.networkConfig != null;
      final networkGaps =
          gapIds.contains(AppCapabilityIds.networkData) ||
          gapIds.contains(AppCapabilityIds.webData) ||
          gapIds.contains(AppCapabilityIds.refresh) ||
          gapIds.contains(AppCapabilityIds.loadingState) ||
          gapIds.contains(AppCapabilityIds.errorState);
      final probe = PackageCapabilityProbe(current);
      if (needsNetworkShell && (networkGaps || !probe.hasKnowledgeService)) {
        current = const NetworkReferenceInterfaceFactory().applyToPackage(
          current,
          name: blueprint?.name ?? current.manifest.name,
          purpose: blueprint?.description ?? current.manifest.description,
        );
        fixes.add('injected_network_reference_shell');
      }
    }

    completeness = validator.validate(
      package: current,
      requiredCapabilities: requiredCapabilities,
      blueprint: blueprint,
    );

    // Recompute integrity after structural mutation.
    if (fixes.isNotEmpty) {
      final hash = ExperiencePackage.computeIntegrityHash(current);
      current = ExperiencePackage(
        packageVersion: current.packageVersion,
        manifest: current.manifest,
        interface: current.interface,
        behavior: current.behavior,
        state: current.state,
        data: current.data,
        services: current.services,
        networkDeclarations: current.networkDeclarations,
        capabilityDeclarations: current.capabilityDeclarations,
        permissionDeclarations: current.permissionDeclarations,
        protection: current.protection,
        provenance: current.provenance,
        integrity: PackageIntegrity(
          contentHash: hash,
          computedAt: DateTime.now(),
        ),
      );
    }

    return DeterministicRepairResult(
      package: current,
      repaired: fixes.isNotEmpty,
      appliedFixes: fixes,
      completeness: completeness,
    );
  }

  /// True arithmetic shape only — NOT "any utility archetype".
  bool _looksNumericCalculation(AppBlueprint blueprint) {
    if (blueprint.entities.isEmpty) return false;
    final fields = blueprint.entities.expand((e) => e.fields).toList();
    if (fields.isEmpty) return false;
    final hasOperator = fields.any(
      (f) =>
          f.type == BlueprintFieldType.category ||
          f.allowedValues.any(
            (v) => const ['+', '-', '*', '/', '×', '÷'].contains(v),
          ),
    );
    final numeric = fields
        .where(
          (f) =>
              f.type == BlueprintFieldType.integer ||
              f.type == BlueprintFieldType.decimal,
        )
        .length;
    final hasResultish = fields.any(
      (f) =>
          f.id.contains('result') ||
          f.name.toLowerCase().contains('result') ||
          f.name.toLowerCase().contains('total'),
    );
    return numeric >= 2 && (hasOperator || hasResultish);
  }
}
