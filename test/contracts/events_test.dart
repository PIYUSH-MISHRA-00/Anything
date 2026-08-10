/// Tests for typed event system.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:anything/core/events/events.dart';

void main() {
  group('EventBus', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('publish and subscribe to specific event type', () async {
      final received = <AnythingEvent>[];
      bus.on<IntentSubmitted>().listen(received.add);

      final event = IntentSubmitted(
        id: '1',
        timestamp: DateTime(2025),
        source: 'test',
        rawInput: 'Build a calculator',
      );

      bus.publish(event);
      await Future.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.first, isA<IntentSubmitted>());
    });

    test('subscribe to base AnythingEvent receives all events', () async {
      final received = <AnythingEvent>[];
      bus.on<AnythingEvent>().listen(received.add);

      bus.publish(
        IntentSubmitted(
          id: '1',
          timestamp: DateTime(2025),
          source: 'test',
          rawInput: 'Test',
        ),
      );

      bus.publish(
        ExperienceCreated(
          id: '2',
          timestamp: DateTime(2025),
          source: 'test',
          experienceId: 'exp-1',
          title: 'Test',
        ),
      );

      await Future.delayed(Duration.zero);

      expect(received, hasLength(2));
    });

    test('dispose closes all streams', () {
      bus.on<IntentSubmitted>().listen((_) {});
      bus.dispose();

      // After dispose, publishing should not throw
      expect(
        () => bus.publish(
          IntentSubmitted(
            id: '1',
            timestamp: DateTime(2025),
            source: 'test',
            rawInput: 'Test',
          ),
        ),
        returnsNormally,
      );
    });
  });
}
