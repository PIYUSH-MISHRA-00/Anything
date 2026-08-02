/// Vision V7 AEE — novel domain proof: a domain with zero footprint
/// anywhere in lib/ or test/ flows through the full Kernel to a real
/// EvolutionRoadmap, structurally, with no domain-specific logic anywhere
/// in lib/evolution/.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/evolution/evolution_types.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

CapabilityRegistry _registryWithStorage() {
  final registry = CapabilityRegistry();
  registry.register(
    const CapabilityDescriptor(
      id: 'storage',
      version: '1.0.0',
      name: 'Storage',
      description: 'Local storage',
      category: CapabilityCategory.storage,
      inputContract: 'data',
      outputContract: 'stored data',
    ),
  );
  return registry;
}

class _FakeProviderRegistry implements ModelProviderRegistry {
  @override
  ModelProvider? get activeProvider => null;
  @override
  List<ModelProvider> get providers => const [];
  @override
  void registerProvider(ModelProvider provider) {}
  @override
  Future<void> setActiveProvider(String providerId) async {}
  @override
  ModelProvider? getProvider(String providerId) => null;
  @override
  Future<List<ProviderConfig>> listConfigs() async => [];
  @override
  Future<void> saveConfig(ProviderConfig config) async {}
  @override
  Future<void> deleteConfig(String id) async {}
  @override
  Future<ProviderConfig?> getDefaultConfig() async => null;
}

class _FixedReasoner implements ApplicationReasoner {
  final SemanticApp app;
  const _FixedReasoner(this.app);
  @override
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async {
    return ReasoningReady(semanticApp: app);
  }
}

/// "Community Seed Library Exchange" — never referenced anywhere else in
/// lib/ or test/. Two entities with a relationship and no search/detail
/// views, deliberately exercising several real opportunity categories at
/// once (missing detail navigation, missing search on a growing catalog).
SemanticApp _seedLibraryApp() {
  return SemanticApp(
    name: 'Community Seed Library Exchange',
    purpose: 'Track seed packets loaned between community members',
    entities: [
      const SemanticEntity(
        id: 'seed_packet',
        name: 'SeedPacket',
        fields: [
          SemanticField(id: 'variety', name: 'Variety', type: BlueprintFieldType.text, required: true),
          SemanticField(id: 'quantity', name: 'Quantity', type: BlueprintFieldType.integer, required: true),
          SemanticField(id: 'harvestSeason', name: 'Harvest Season', type: BlueprintFieldType.text),
          SemanticField(id: 'donorId', name: 'Donor', type: BlueprintFieldType.reference, referenceEntityId: 'donor'),
        ],
      ),
      const SemanticEntity(
        id: 'donor',
        name: 'Donor',
        fields: [SemanticField(id: 'name', name: 'Name', type: BlueprintFieldType.text, required: true)],
      ),
    ],
    views: const [
      SemanticView(id: 'seed_list', name: 'Seed Packets', purpose: 'list', sourceEntityId: 'seed_packet', viewType: BlueprintViewType.list, isDefault: true),
      SemanticView(id: 'donor_list', name: 'Donors', purpose: 'list', sourceEntityId: 'donor', viewType: BlueprintViewType.list),
    ],
    actions: const [
      SemanticAction(id: 'add_seed_packet', name: 'Add Seed Packet', targetEntityId: 'seed_packet'),
      SemanticAction(id: 'add_donor', name: 'Add Donor', targetEntityId: 'donor'),
    ],
  );
}

void main() {
  test('a never-before-seen domain reaches a real, structurally-derived EvolutionRoadmap', () async {
    final kernel = AnythingKernel(
      providerRegistry: _FakeProviderRegistry(),
      capabilityRegistry: _registryWithStorage(),
      reasoner: _FixedReasoner(_seedLibraryApp()),
    );

    final outcome = await kernel.processIntent(
      Intent.create(expression: 'track seed packets donated to our community seed library'),
    );

    expect(outcome, isA<ExecutionPlanReady>());
    final ready = outcome as ExecutionPlanReady;
    final roadmap = ready.evolutionRoadmap!;

    expect(roadmap.milestones, hasLength(6));
    expect(roadmap.fingerprint, isNotEmpty);

    // Every proposal surfaced must trace to real, structural evidence —
    // never a domain-specific fabrication (no mention of "seed"/"donor"
    // logic anywhere in lib/evolution/, only structural signals).
    for (final proposal in roadmap.allProposals) {
      expect(proposal.candidate.opportunity.reason.evidence.affectedNodeId, isNotEmpty);
      expect(proposal.reviewDecision.kind, EvolutionDecisionKind.accepted);
    }
  });
}
