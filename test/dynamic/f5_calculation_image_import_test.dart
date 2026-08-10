/// Fable 5 — calculation modes, remote image sanitize, import bytes path.
library;

import 'dart:typed_data';

import 'package:anything/capabilities/adapters/file_service_adapter.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/creation/app_capabilities.dart';
import 'package:anything/creation/calculation_interface_factory.dart';
import 'package:anything/creation/calculation_spec.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/runtime/calculation_session.dart';
import 'package:anything/runtime/remote_image.dart';
import 'package:anything/runtime/state_engine.dart';
import 'package:anything/synthesis/app_archetype.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ExperiencePackage bare(String name) {
    final now = DateTime.now();
    return ExperiencePackage(
      manifest: ExperienceManifest(
        experienceId: 'x',
        name: name,
        description: name,
        createdAt: now,
        updatedAt: now,
      ),
      interface: const InterfaceDefinition(),
      behavior: const BehaviorGraph(),
      state: const StateSchema(),
      provenance: const PackageProvenance(
        creationEngineVersion: '1.0.0',
        specVersion: 1,
        planVersion: 1,
      ),
      integrity: PackageIntegrity(contentHash: '', computedAt: now),
    );
  }

  group('CalculationSpec differentiation', () {
    test('basic vs scientific resolve differently', () {
      final basic = CalculationSpec.resolve(
        capabilityIds: {AppCapabilityIds.calculation},
        intentExpression: 'create a calculator',
      );
      final sci = CalculationSpec.resolve(
        capabilityIds: {
          AppCapabilityIds.calculation,
          AppCapabilityIds.scientificCalculation,
        },
        intentExpression: 'create a scientific calculator',
      );
      expect(basic.mode, CalculationMode.basic);
      expect(sci.mode, CalculationMode.scientific);
      expect(sci.isScientific, isTrue);
      expect(basic.isScientific, isFalse);
    });

    test('scientific pad includes unary ops; basic does not', () {
      final factory = const CalculationInterfaceFactory();
      final basicPkg = factory.applyToPackage(
        bare('Calc'),
        name: 'Calc',
        spec: const CalculationSpec(
          mode: CalculationMode.basic,
          operations: CalculationSpec.basicOps,
        ),
      );
      final sciPkg = factory.applyToPackage(
        bare('SciCalc'),
        name: 'SciCalc',
        spec: const CalculationSpec(
          mode: CalculationMode.scientific,
          operations: CalculationSpec.scientificOps,
        ),
      );
      expect(PackageCapabilityProbe(basicPkg).hasCalculationPad, isTrue);
      expect(PackageCapabilityProbe(basicPkg).hasScientificOps, isFalse);
      expect(PackageCapabilityProbe(sciPkg).hasCalculationPad, isTrue);
      expect(PackageCapabilityProbe(sciPkg).hasScientificOps, isTrue);
    });

    test('scientific unary sqrt(16) = 4', () {
      final engine = ExperienceStateEngine()
        ..initialize(
          const StateSchema(
            variables: [
              StateVariable(id: 'display', type: 'string', defaultValue: '16'),
              StateVariable(id: 'expression', type: 'string', defaultValue: ''),
              StateVariable(
                id: 'storedValue',
                type: 'decimal',
                defaultValue: 0.0,
              ),
              StateVariable(
                id: 'currentOperation',
                type: 'string',
                defaultValue: '',
              ),
              StateVariable(
                id: 'newInput',
                type: 'boolean',
                defaultValue: false,
              ),
              StateVariable(id: 'error', type: 'string', defaultValue: ''),
              StateVariable(
                id: 'angleMode',
                type: 'string',
                defaultValue: 'degrees',
              ),
            ],
          ),
        );
      CalculationSession.apply(
        engine,
        eventId: CalculationSession.unary,
        data: {'op': 'sqrt'},
      );
      expect(engine.read('display'), '4');
      expect(engine.read('error'), '');
    });

    test('inferrer adds scientificCalculation for scientific prompt', () {
      final bp = AppBlueprint(
        id: 'bp',
        name: 'Calc',
        description: 'math',
        archetypes: const [AppArchetype.utility],
      );
      final caps = const AppCapabilityInferrer().infer(
        blueprint: bp,
        intent: Intent.create(expression: 'scientific calculator'),
      );
      expect(caps.contains(AppCapabilityIds.calculation), isTrue);
      expect(caps.contains(AppCapabilityIds.scientificCalculation), isTrue);
    });
  });

  group('RemoteImageUrl', () {
    test('accepts https and rejects javascript', () {
      expect(
        RemoteImageUrl.sanitize('https://example.com/a.png'),
        'https://example.com/a.png',
      );
      expect(RemoteImageUrl.sanitize('javascript:alert(1)'), isNull);
      expect(RemoteImageUrl.sanitize(''), isNull);
      expect(RemoteImageUrl.sanitize('not-a-url'), isNull);
    });
  });

  group('PickedFile bytes import', () {
    test('hasReadableContent from bytes without path', () {
      final picked = PickedFile(
        name: 'app.anything',
        bytes: utf8Bytes('{"ok":true}'),
      );
      expect(picked.path, isNull);
      expect(picked.hasReadableContent, isTrue);
    });
  });
}

Uint8List utf8Bytes(String s) => Uint8List.fromList(s.codeUnits);
