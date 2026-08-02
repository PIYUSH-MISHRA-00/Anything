/// Vision V11 — SoftwareIdentity / SoftwareFingerprint.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/software_cognition/software_identity.dart';
import 'package:anything/software_cognition/software_types.dart';

void main() {
  group('SoftwareIdentity', () {
    test('stable identity is deterministic and namespaced by kind', () {
      final a = SoftwareIdentity.stable(SoftwareNodeKind.package, 'http');
      final b = SoftwareIdentity.stable(SoftwareNodeKind.package, 'http');
      expect(a, equals(b));
      expect(a.value, 'package:http');
    });

    test('structural identity is order-independent', () {
      final a = SoftwareIdentity.structural(SoftwareNodeKind.entity, ['name', 'text']);
      final b = SoftwareIdentity.structural(SoftwareNodeKind.entity, ['text', 'name']);
      expect(a, equals(b));
    });

    test('different kinds never collide even with the same raw id', () {
      final repo = SoftwareIdentity.stable(SoftwareNodeKind.repository, 'x');
      final pkg = SoftwareIdentity.stable(SoftwareNodeKind.package, 'x');
      expect(repo, isNot(equals(pkg)));
    });
  });

  group('SoftwareFingerprint', () {
    test('identical signatures are fully similar', () {
      final a = SoftwareFingerprint(['http', 'sqflite']);
      final b = SoftwareFingerprint(['sqflite', 'http']);
      expect(a.similarityTo(b), 1.0);
    });

    test('disjoint signatures have zero similarity', () {
      final a = SoftwareFingerprint(['http']);
      final b = SoftwareFingerprint(['sqflite']);
      expect(a.similarityTo(b), 0.0);
    });

    test('partial overlap is a real Jaccard ratio', () {
      final a = SoftwareFingerprint(['a', 'b', 'c']);
      final b = SoftwareFingerprint(['b', 'c', 'd']);
      // intersection {b,c}=2, union {a,b,c,d}=4
      expect(a.similarityTo(b), closeTo(0.5, 0.0001));
    });

    test('two empty fingerprints are fully similar (both empty)', () {
      expect(SoftwareFingerprint([]).similarityTo(SoftwareFingerprint([])), 1.0);
    });
  });
}
