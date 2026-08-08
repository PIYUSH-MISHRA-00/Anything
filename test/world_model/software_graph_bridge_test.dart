/// Vision V11 — SoftwareGraphBridge. Proves the 6th World Model Bridge
/// translates SemanticSoftwareGraph into a GraphUpdate correctly and
/// deterministically, without re-implementing Software Cognition's own
/// analysis.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/software_cognition/semantic_software_graph.dart';
import 'package:anything/software_cognition/software_identity.dart' as sc;
import 'package:anything/software_cognition/software_node.dart' as sc;
import 'package:anything/software_cognition/software_types.dart' as sc;
import 'package:anything/world_model/bridges/software_graph_bridge.dart';
import 'package:anything/world_model/world_types.dart';

void main() {
  group('SoftwareGraphBridge', () {
    test('a repository node maps to WorldNodeKind.repository', () {
      final repoId = sc.SoftwareIdentity.stable(
        sc.SoftwareNodeKind.repository,
        'orchid-tracker',
      );
      final graph = SemanticSoftwareGraph(
        nodes: [
          sc.SoftwareNode(
            identity: repoId,
            kind: sc.SoftwareNodeKind.repository,
            label: 'orchid-tracker',
          ),
        ],
      );

      final update = const SoftwareGraphBridge().bridge(graph);
      expect(update.addedNodes.single.kind, WorldNodeKind.repository);
      expect(update.addedNodes.single.label, 'orchid-tracker');
    });

    test('a package node maps to WorldNodeKind.softwarePackage', () {
      final pkgId = sc.SoftwareIdentity.stable(
        sc.SoftwareNodeKind.package,
        'flutter',
      );
      final graph = SemanticSoftwareGraph(
        nodes: [
          sc.SoftwareNode(
            identity: pkgId,
            kind: sc.SoftwareNodeKind.package,
            label: 'flutter',
          ),
        ],
      );

      final update = const SoftwareGraphBridge().bridge(graph);
      expect(update.addedNodes.single.kind, WorldNodeKind.softwarePackage);
    });

    test(
      'a widget/component/endpoint node maps to WorldNodeKind.softwareComponent',
      () {
        final widgetId = sc.SoftwareIdentity.stable(
          sc.SoftwareNodeKind.widget,
          'MyScreen',
        );
        final graph = SemanticSoftwareGraph(
          nodes: [
            sc.SoftwareNode(
              identity: widgetId,
              kind: sc.SoftwareNodeKind.widget,
              label: 'MyScreen',
            ),
          ],
        );

        final update = const SoftwareGraphBridge().bridge(graph);
        expect(update.addedNodes.single.kind, WorldNodeKind.softwareComponent);
      },
    );

    test('an entity node unifies with the World Graph\'s own entity kind', () {
      final entityId = sc.SoftwareIdentity.stable(
        sc.SoftwareNodeKind.entity,
        'Task',
      );
      final graph = SemanticSoftwareGraph(
        nodes: [
          sc.SoftwareNode(
            identity: entityId,
            kind: sc.SoftwareNodeKind.entity,
            label: 'Task',
          ),
        ],
      );

      final update = const SoftwareGraphBridge().bridge(graph);
      expect(update.addedNodes.single.kind, WorldNodeKind.entity);
    });

    test(
      'a dependsOn edge maps to RelationshipKind.dependsOn and both endpoints are added',
      () {
        final repoId = sc.SoftwareIdentity.stable(
          sc.SoftwareNodeKind.repository,
          'orchid-tracker',
        );
        final pkgId = sc.SoftwareIdentity.stable(
          sc.SoftwareNodeKind.package,
          'flutter',
        );
        final graph = SemanticSoftwareGraph(
          nodes: [
            sc.SoftwareNode(
              identity: repoId,
              kind: sc.SoftwareNodeKind.repository,
              label: 'orchid-tracker',
            ),
            sc.SoftwareNode(
              identity: pkgId,
              kind: sc.SoftwareNodeKind.package,
              label: 'flutter',
            ),
          ],
          edges: [
            sc.SoftwareEdge(
              fromId: repoId,
              toId: pkgId,
              kind: sc.SoftwareRelationshipKind.dependsOn,
              evidence: const sc.SoftwareEvidence(
                sourceUrl: 'https://example.com/orchid-tracker',
                sourceArtifact: 'flutter',
              ),
            ),
          ],
        );

        final update = const SoftwareGraphBridge().bridge(graph);
        expect(update.addedEdges.single.kind, RelationshipKind.dependsOn);
        expect(update.addedNodes, hasLength(2));
      },
    );

    test(
      'R14: new authenticationPattern/navigationPattern node kinds map to WorldNodeKind.softwareComponent (no second taxonomy)',
      () {
        final authId = sc.SoftwareIdentity.stable(
          sc.SoftwareNodeKind.authenticationPattern,
          'firebase_auth',
        );
        final navId = sc.SoftwareIdentity.stable(
          sc.SoftwareNodeKind.navigationPattern,
          'go_router',
        );
        final graph = SemanticSoftwareGraph(
          nodes: [
            sc.SoftwareNode(
              identity: authId,
              kind: sc.SoftwareNodeKind.authenticationPattern,
              label: 'firebase_auth',
            ),
            sc.SoftwareNode(
              identity: navId,
              kind: sc.SoftwareNodeKind.navigationPattern,
              label: 'go_router',
            ),
          ],
        );

        final update = const SoftwareGraphBridge().bridge(graph);
        expect(update.addedNodes.map((n) => n.kind).toSet(), {
          WorldNodeKind.softwareComponent,
        });
      },
    );

    test('an empty SemanticSoftwareGraph produces an empty GraphUpdate', () {
      final update = const SoftwareGraphBridge().bridge(
        const SemanticSoftwareGraph(),
      );
      expect(update.isEmpty, isTrue);
    });
  });
}
