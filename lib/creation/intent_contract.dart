/// Typed intent contract frozen at submit — validates generated packages.
///
/// Builds on [CreationRequest] immutability. Does not select application
/// templates by name; it only records semantic expectations and rejects
/// packages that violate them.
library;

import 'app_capabilities.dart';
import 'creation_request.dart';
import 'experience_package.dart';
import 'intent_preservation.dart';

/// Machine-checkable expectations derived from a frozen creation request.
class IntentContract {
  final CreationRequest request;
  final IntentPurpose primaryPurpose;
  final Set<String> expectedCapabilities;
  final Set<String> forbiddenCapabilities;
  final bool requiresScientificCalculation;
  final bool requiresContinuousTiming;

  const IntentContract({
    required this.request,
    required this.primaryPurpose,
    required this.expectedCapabilities,
    this.forbiddenCapabilities = const {},
    this.requiresScientificCalculation = false,
    this.requiresContinuousTiming = false,
  });

  /// Derive a contract from an immutable [CreationRequest].
  factory IntentContract.fromRequest(CreationRequest request) {
    final validator = const IntentPreservationValidator();
    final purpose = validator.purposeFromPrompt(request.normalizedPrompt);
    final lower = request.normalizedPrompt.toLowerCase();
    final expected = <String>{};
    final forbidden = <String>{};
    var scientific = false;
    var continuousTiming = false;

    switch (purpose) {
      case IntentPurpose.timing:
        expected.addAll({
          AppCapabilityIds.timers,
          AppCapabilityIds.input,
          AppCapabilityIds.resultDisplay,
        });
        forbidden.add(AppCapabilityIds.calculation);
        continuousTiming = true;
      case IntentPurpose.calculation:
        expected.addAll({
          AppCapabilityIds.calculation,
          AppCapabilityIds.input,
          AppCapabilityIds.resultDisplay,
        });
        forbidden.add(AppCapabilityIds.timers);
        scientific =
            lower.contains('scientific') ||
            lower.contains('trig') ||
            lower.contains('engineering');
        if (scientific) {
          expected.add(AppCapabilityIds.scientificCalculation);
        }
      case IntentPurpose.weather:
        expected.addAll({
          AppCapabilityIds.weatherData,
          AppCapabilityIds.input,
          AppCapabilityIds.refresh,
          AppCapabilityIds.loadingState,
          AppCapabilityIds.errorState,
        });
        forbidden.add(AppCapabilityIds.webKnowledge);
      case IntentPurpose.news:
        expected.addAll({
          AppCapabilityIds.newsData,
          AppCapabilityIds.input,
          AppCapabilityIds.refresh,
          AppCapabilityIds.loadingState,
          AppCapabilityIds.errorState,
        });
        forbidden.add(AppCapabilityIds.webKnowledge);
      case IntentPurpose.networkReference:
        expected.addAll({
          AppCapabilityIds.networkData,
          AppCapabilityIds.refresh,
        });
      case IntentPurpose.collection:
        expected.addAll({
          AppCapabilityIds.crud,
          AppCapabilityIds.persistence,
          AppCapabilityIds.collection,
        });
        if (lower.contains('search')) expected.add(AppCapabilityIds.search);
        if (lower.contains('filter')) expected.add(AppCapabilityIds.filter);
        if (lower.contains('sort')) expected.add(AppCapabilityIds.sort);
      case IntentPurpose.unknown:
        break;
    }

    return IntentContract(
      request: request,
      primaryPurpose: purpose,
      expectedCapabilities: expected,
      forbiddenCapabilities: forbidden,
      requiresScientificCalculation: scientific,
      requiresContinuousTiming: continuousTiming,
    );
  }

  /// Validate a generated package against this contract.
  IntentContractResult evaluate(
    ExperiencePackage package, {
    Set<String> inferredCapabilities = const {},
  }) {
    final preservation = const IntentPreservationValidator().validate(
      rawPrompt: request.normalizedPrompt,
      package: package,
      requiredCapabilities: inferredCapabilities,
    );
    if (!preservation.isCompatible) {
      return IntentContractResult.fail(
        contract: this,
        reason: preservation.reason,
      );
    }

    final probe = PackageCapabilityProbe(package);
    final caps = {...inferredCapabilities};

    if (requiresContinuousTiming && !probe.hasTimingControls) {
      return IntentContractResult.fail(
        contract: this,
        reason: 'IntentContract: timing controls missing for stopwatch/timer',
      );
    }
    if (requiresScientificCalculation && !probe.hasScientificOps) {
      return IntentContractResult.fail(
        contract: this,
        reason:
            'IntentContract: scientific operations missing '
            '(basic calculator is not sufficient)',
      );
    }
    if (primaryPurpose == IntentPurpose.timing && probe.hasCalculationPad) {
      return IntentContractResult.fail(
        contract: this,
        reason: 'IntentContract: timing intent must not become a calculator',
      );
    }
    if (primaryPurpose == IntentPurpose.weather && probe.hasKnowledgeService) {
      // Weather is now satisfied through the generic knowledge retrieval path.
      // Knowledge-only is acceptable when weatherData capability is declared.
    }
    if (primaryPurpose == IntentPurpose.news &&
        !probe.hasNewsService &&
        !caps.contains(AppCapabilityIds.newsData) &&
        probe.hasKnowledgeService) {
      // News is now satisfied through the generic knowledge retrieval path.
      // Knowledge-only is acceptable when newsData capability is declared.
    }

    for (final forbidden in forbiddenCapabilities) {
      if (forbidden == AppCapabilityIds.calculation &&
          primaryPurpose == IntentPurpose.timing &&
          probe.hasCalculationPad) {
        return IntentContractResult.fail(
          contract: this,
          reason: 'IntentContract: forbidden calculation surface on timing app',
        );
      }
    }

    return IntentContractResult.ok(contract: this);
  }

  Map<String, dynamic> toDiagnosticJson() => {
    'request': request.toDiagnosticJson(),
    'primaryPurpose': primaryPurpose.name,
    'expectedCapabilities': expectedCapabilities.toList()..sort(),
    'forbiddenCapabilities': forbiddenCapabilities.toList()..sort(),
    'requiresScientificCalculation': requiresScientificCalculation,
    'requiresContinuousTiming': requiresContinuousTiming,
  };
}

/// Outcome of evaluating an [IntentContract].
class IntentContractResult {
  final bool isSatisfied;
  final IntentContract contract;
  final String reason;

  const IntentContractResult({
    required this.isSatisfied,
    required this.contract,
    required this.reason,
  });

  factory IntentContractResult.ok({required IntentContract contract}) =>
      IntentContractResult(
        isSatisfied: true,
        contract: contract,
        reason: 'satisfied',
      );

  factory IntentContractResult.fail({
    required IntentContract contract,
    required String reason,
  }) => IntentContractResult(
    isSatisfied: false,
    contract: contract,
    reason: reason,
  );
}
