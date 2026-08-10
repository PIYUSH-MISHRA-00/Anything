/// Tests for Result type.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:anything/core/errors/errors.dart';

void main() {
  group('Result', () {
    test('Ok returns isOk true', () {
      const result = Ok(42);
      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
    });

    test('Err returns isErr true', () {
      final result = Err<int>(const IntentError(message: 'fail'));
      expect(result.isOk, isFalse);
      expect(result.isErr, isTrue);
    });

    test('Ok unwrap returns value', () {
      const result = Ok('hello');
      expect(result.unwrap, equals('hello'));
    });

    test('Err unwrap throws', () {
      final result = Err<String>(const IntentError(message: 'fail'));
      expect(() => result.unwrap, throwsA(isA<AnythingError>()));
    });

    test('unwrapOr returns default on Err', () {
      final result = Err<int>(const IntentError(message: 'fail'));
      expect(result.unwrapOr(0), equals(0));
    });

    test('unwrapOr returns value on Ok', () {
      const result = Ok(42);
      expect(result.unwrapOr(0), equals(42));
    });

    test('map transforms Ok value', () {
      const result = Ok(21);
      final mapped = result.map((v) => v * 2);
      expect(mapped.unwrap, equals(42));
    });

    test('map preserves Err', () {
      final result = Err<int>(const IntentError(message: 'fail'));
      final mapped = result.map((v) => v * 2);
      expect(mapped.isErr, isTrue);
    });

    test('flatMap chains Ok values', () {
      const result = Ok(21);
      final flatMapped = result.flatMap((v) => Ok(v * 2));
      expect(flatMapped.unwrap, equals(42));
    });

    test('flatMap short-circuits on Err', () {
      final result = Err<int>(const IntentError(message: 'fail'));
      final flatMapped = result.flatMap((v) => Ok(v * 2));
      expect(flatMapped.isErr, isTrue);
    });

    test('equality for Ok', () {
      const a = Ok(42);
      const b = Ok(42);
      expect(a, equals(b));
    });

    test('equality for Err', () {
      final a = Err<int>(const IntentError(message: 'fail'));
      final b = Err<int>(const IntentError(message: 'fail'));
      expect(a, equals(b));
    });
  });
}
