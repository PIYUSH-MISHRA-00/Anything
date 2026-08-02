/// EvolutionValidator — validates the package produced by executing an
/// EvolutionProposal. Reuses the existing ExperiencePackageValidator (V1/
/// M2) directly; never a second, competing package validator.
library;

import '../creation/experience_package.dart';
import '../creation/package_validator.dart';

class EvolutionValidationResult {
  final bool isValid;
  final List<String> errors;

  const EvolutionValidationResult({required this.isValid, this.errors = const []});
}

class EvolutionValidator {
  const EvolutionValidator();

  EvolutionValidationResult validate(ExperiencePackage package) {
    final result = ExperiencePackageValidator.validate(package);
    return EvolutionValidationResult(isValid: result.isValid, errors: result.errors);
  }
}
