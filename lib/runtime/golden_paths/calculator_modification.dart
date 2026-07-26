/// Calculator modification — adds percentage button.
///
/// Golden path for Stage 8 modification testing.
library;

import '../../creation/experience_package.dart';
import '../../creation/modification/experience_modification_spec.dart';
import '../../creation/modification/modification_engine.dart';

/// Modify Calculator to add percentage functionality.
Future<ModificationResult> addPercentageToCalculator(
  ExperiencePackage existing,
) async {
  final spec = ExperienceModificationSpec(
    targetExperienceId: existing.manifest.experienceId,
    basePackageVersion: existing.manifest.version,
    objective: 'Add a percentage button to Calculator',
    operations: [
      const ModificationOperation(
        type: ModificationType.addUiNode,
        params: {'nodeType': 'button', 'label': '%', 'action': 'percentage'},
      ),
    ],
  );

  final engine = ModificationEngine();
  return await engine.modify(existing, spec);
}
