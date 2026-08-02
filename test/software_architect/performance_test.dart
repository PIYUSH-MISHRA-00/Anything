/// V2 ASAE — performance measurement.
///
/// Real, timed run through requirement extraction, architecture planning,
/// self-critique/refinement, and package generation for one realistic
/// novel-domain app. Not a strict benchmark (no fixed hardware/repeated
/// trials) — printed for docs/progress/V2_ASAE_PERFORMANCE.md to cite. No
/// thresholds asserted (would be flaky), except a basic sanity bound.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart'
    show NetworkNeed;
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/synthesis/composite_reasoner.dart';
import 'package:anything/synthesis/generic_package_builder.dart';
import 'package:anything/software_architect/architecture_planner.dart';
import 'package:anything/software_architect/architecture_to_blueprint.dart';
import 'package:anything/software_architect/refinement_planner.dart';
import 'package:anything/software_architect/requirement_extractor.dart';

SemanticApp _app() {
  return SemanticApp(
    name: 'Home Inventory Tracker',
    purpose: 'Track household items and their locations',
    entities: [
      SemanticEntity(
        id: 'item',
        name: 'Item',
        displayField: 'label',
        fields: [
          const SemanticField(
            id: 'label',
            name: 'Label',
            type: BlueprintFieldType.text,
            required: true,
          ),
          const SemanticField(
            id: 'quantity',
            name: 'Quantity',
            type: BlueprintFieldType.integer,
            minimum: 0,
          ),
          const SemanticField(
            id: 'locationRef',
            name: 'Location',
            type: BlueprintFieldType.reference,
            referenceEntityId: 'location',
          ),
        ],
      ),
      const SemanticEntity(
        id: 'location',
        name: 'Location',
        fields: [
          SemanticField(
            id: 'name',
            name: 'Name',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
    views: [
      const SemanticView(
        id: 'items_list',
        name: 'Items',
        purpose: 'list',
        sourceEntityId: 'item',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
      const SemanticView(
        id: 'items_form',
        name: 'Add Item',
        purpose: 'form',
        sourceEntityId: 'item',
        viewType: BlueprintViewType.form,
      ),
    ],
    actions: const [
      SemanticAction(id: 'add_item', name: 'Add Item', targetEntityId: 'item'),
      SemanticAction(
        id: 'delete_item',
        name: 'Delete Item',
        targetEntityId: 'item',
        actionType: BlueprintActionType.delete,
      ),
    ],
  );
}

IntentUnderstanding _understanding() {
  return IntentUnderstanding(
    intentId: 'perf-${DateTime.now().microsecondsSinceEpoch}',
    objective: 'track household inventory',
    category: IntentCategory.create,
    existingExperience: const ExistingExperienceResolution(
      status: ExistingExperienceStatus.notChecked,
    ),
    desiredOutcome: '',
    confidence: 0.9,
    networkNeed: NetworkNeed.none,
    creationNeed: CreationNeed.definitelyNeeded,
    modificationNeed: ModificationNeed.notNeeded,
  );
}

void main() {
  test(
    'measured timings: extraction, planning, refinement, package generation',
    () async {
      final app = _app();
      const extractor = RequirementExtractor();
      const planner = ArchitecturePlanner();
      final refinementPlanner = RefinementPlanner();
      const converter = ArchitectureToBlueprintConverter();
      final reasoner = CompositeApplicationReasoner();

      final extractionStart = DateTime.now();
      extractor.extract(app: app, understanding: _understanding());
      final extractionElapsed = DateTime.now().difference(extractionStart);

      final planningStart = DateTime.now();
      final candidate = planner.plan(app);
      final planningElapsed = DateTime.now().difference(planningStart);

      final refinementStart = DateTime.now();
      final report = refinementPlanner.refine(candidate);
      final refinementElapsed = DateTime.now().difference(refinementStart);

      final conversionStart = DateTime.now();
      final blueprint = converter.convert(
        originalApp: app,
        approved: report.finalCandidate,
        reasonerForConversion: reasoner,
      );
      final conversionElapsed = DateTime.now().difference(conversionStart);

      final packageStart = DateTime.now();
      GenericPackageBuilder.build(blueprint);
      final packageElapsed = DateTime.now().difference(packageStart);

      // ignore: avoid_print
      print(
        'ASAE PIPELINE PERFORMANCE '
        '(extraction_us=${extractionElapsed.inMicroseconds}, '
        'planning_us=${planningElapsed.inMicroseconds}, '
        'refinement_us=${refinementElapsed.inMicroseconds}, '
        'refinement_iterations=${report.finalCandidate.iteration}, '
        'blueprint_conversion_us=${conversionElapsed.inMicroseconds}, '
        'package_generation_us=${packageElapsed.inMicroseconds})',
      );

      final total =
          extractionElapsed +
          planningElapsed +
          refinementElapsed +
          conversionElapsed +
          packageElapsed;
      expect(total.inMilliseconds, lessThan(2000));
    },
  );
}
