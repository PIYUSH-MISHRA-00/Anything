/// Tests for foundational Intent contract.
import 'package:flutter_test/flutter_test.dart';
import 'package:anything/core/contracts/intent.dart';

void main() {
  group('Intent', () {
    test('create generates unique ID', () {
      final intent1 = Intent.create(expression: 'Build a calculator');

      final intent2 = Intent.create(expression: 'Build a calculator');

      expect(intent1.id, isNot(equals(intent2.id)));
    });

    test('create sets timestamps', () {
      final before = DateTime.now();
      final intent = Intent.create(expression: 'Test');
      final after = DateTime.now();

      expect(
        intent.createdAt.isAfter(before) ||
            intent.createdAt.isAtSameMomentAs(before),
        isTrue,
      );
      expect(
        intent.updatedAt.isBefore(after) ||
            intent.updatedAt.isAtSameMomentAs(after),
        isTrue,
      );
    });

    test('create sets default status to draft', () {
      final intent = Intent.create(expression: 'Test');
      expect(intent.status, equals(IntentStatus.draft));
    });

    test('create sets default modality to text', () {
      final intent = Intent.create(expression: 'Test');
      expect(intent.modality, equals(InputModality.text));
    });

    test('canSubmit returns true for non-empty draft', () {
      final intent = Intent.create(expression: 'Test');
      expect(intent.canSubmit, isTrue);
    });

    test('canSubmit returns false for empty expression', () {
      final intent = Intent.create(expression: '');
      expect(intent.canSubmit, isFalse);
    });

    test('canSubmit returns false for non-draft status', () {
      final intent = Intent.create(
        expression: 'Test',
      ).copyWith(status: IntentStatus.submitted);
      expect(intent.canSubmit, isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      final intent = Intent.create(
        expression: 'Original',
        modality: InputModality.voice,
      );

      final modified = intent.copyWith(expression: 'Modified');

      expect(modified.expression, equals('Modified'));
      expect(modified.modality, equals(InputModality.voice));
      expect(modified.id, equals(intent.id));
    });

    test('equality compares by id, expression, and status', () {
      final intent1 = Intent.create(expression: 'Test');
      final intent2 = Intent.create(expression: 'Test');

      // Different IDs, so not equal
      expect(intent1, isNot(equals(intent2)));

      // Same intent via copyWith
      final intent3 = intent1.copyWith();
      expect(intent1, equals(intent3));
    });

    test('hasAttachments is false by default', () {
      final intent = Intent.create(expression: 'Test');
      expect(intent.hasAttachments, isFalse);
    });
  });

  group('IntentAttachment', () {
    test('create generates unique ID', () {
      final att1 = IntentAttachment.create(
        name: 'file.txt',
        type: AttachmentType.file,
        localPath: '/path/to/file.txt',
      );

      final att2 = IntentAttachment.create(
        name: 'file.txt',
        type: AttachmentType.file,
        localPath: '/path/to/file.txt',
      );

      expect(att1.id, isNot(equals(att2.id)));
    });
  });

  group('InputModality', () {
    test('has expected values', () {
      expect(InputModality.values, contains(InputModality.text));
      expect(InputModality.values, contains(InputModality.voice));
      expect(InputModality.values, contains(InputModality.mixed));
      expect(InputModality.values, contains(InputModality.image));
      expect(InputModality.values, contains(InputModality.file));
      expect(InputModality.values, contains(InputModality.url));
    });
  });

  group('IntentStatus', () {
    test('has expected values', () {
      expect(IntentStatus.values, contains(IntentStatus.draft));
      expect(IntentStatus.values, contains(IntentStatus.submitted));
      expect(IntentStatus.values, contains(IntentStatus.awaitingProvider));
      expect(IntentStatus.values, contains(IntentStatus.accepted));
      expect(IntentStatus.values, contains(IntentStatus.failed));
      expect(IntentStatus.values, contains(IntentStatus.cancelled));
    });
  });

  group('ExperienceType', () {
    test('has all expected types', () {
      expect(ExperienceType.values, contains(ExperienceType.generativeUi));
      expect(ExperienceType.values, contains(ExperienceType.application));
      expect(ExperienceType.values, contains(ExperienceType.workspace));
      expect(ExperienceType.values, contains(ExperienceType.dashboard));
      expect(ExperienceType.values, contains(ExperienceType.tool));
      expect(ExperienceType.values, contains(ExperienceType.unknown));
    });
  });
}
