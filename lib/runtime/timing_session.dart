/// Generic timing session — start/pause/resume/reset/lap with wall-clock time.
///
/// Capability runtime for [AppCapabilityIds.timers]. Not a product-named
/// Stopwatch module: any Experience that emits `timer.*` actions uses this.
library;

import 'state_engine.dart';

/// Applies timing protocol events using DateTime.now()-based elapsed ms.
class TimingSession {
  TimingSession._();

  static const start = 'timer.start';
  static const pause = 'timer.pause';
  static const resume = 'timer.resume';
  static const reset = 'timer.reset';
  static const lap = 'timer.lap';
  static const tick = 'timer.tick';

  static bool handles(String eventId) {
    return eventId == start ||
        eventId == pause ||
        eventId == resume ||
        eventId == reset ||
        eventId == lap ||
        eventId == tick;
  }

  static void apply(
    ExperienceStateEngine state, {
    required String eventId,
    Map<String, dynamic>? data,
  }) {
    switch (eventId) {
      case start:
        _onStart(state);
      case pause:
        _onPause(state);
      case resume:
        _onResume(state);
      case reset:
        _onReset(state);
      case lap:
        _onLap(state);
      case tick:
        _syncDisplay(state);
    }
  }

  static void _onStart(ExperienceStateEngine state) {
    final running = state.read('running') == true;
    if (running) return;
    final accumulated = _asInt(state.read('accumulatedMs'));
    state.write('running', true);
    state.write('startedAtMs', DateTime.now().millisecondsSinceEpoch);
    state.write('accumulatedMs', accumulated);
    _syncDisplay(state);
  }

  static void _onPause(ExperienceStateEngine state) {
    if (state.read('running') != true) return;
    final elapsed = _elapsedMs(state);
    state.write('running', false);
    state.write('accumulatedMs', elapsed);
    state.write('startedAtMs', 0);
    _syncDisplay(state);
  }

  static void _onResume(ExperienceStateEngine state) {
    if (state.read('running') == true) return;
    final accumulated = _asInt(state.read('accumulatedMs'));
    if (accumulated <= 0 && _displayIsZero(state)) {
      _onStart(state);
      return;
    }
    state.write('running', true);
    state.write('startedAtMs', DateTime.now().millisecondsSinceEpoch);
    _syncDisplay(state);
  }

  static void _onReset(ExperienceStateEngine state) {
    state.write('running', false);
    state.write('startedAtMs', 0);
    state.write('accumulatedMs', 0);
    state.write('laps', <String>[]);
    state.write('display', '00:00.00');
    state.write('statusLabel', 'Ready');
  }

  static void _onLap(ExperienceStateEngine state) {
    final elapsed = _elapsedMs(state);
    final label = _format(elapsed);
    final raw = state.read('laps');
    final laps = <String>[];
    if (raw is List) {
      for (final e in raw) {
        laps.add(e.toString());
      }
    }
    laps.insert(0, 'Lap ${laps.length + 1}  $label');
    state.write('laps', laps);
    state.write('lapsText', laps.join('\n'));
    _syncDisplay(state);
  }

  static void _syncDisplay(ExperienceStateEngine state) {
    final elapsed = _elapsedMs(state);
    state.write('display', _format(elapsed));
    state.write(
      'statusLabel',
      state.read('running') == true ? 'Running' : 'Paused',
    );
    if (_asInt(state.read('accumulatedMs')) == 0 &&
        state.read('running') != true) {
      state.write('statusLabel', 'Ready');
    }
  }

  static int _elapsedMs(ExperienceStateEngine state) {
    final accumulated = _asInt(state.read('accumulatedMs'));
    if (state.read('running') != true) return accumulated;
    final started = _asInt(state.read('startedAtMs'));
    if (started <= 0) return accumulated;
    final now = DateTime.now().millisecondsSinceEpoch;
    return accumulated + (now - started);
  }

  static String _format(int ms) {
    if (ms < 0) ms = 0;
    final totalCs = ms ~/ 10;
    final cs = totalCs % 100;
    final totalSec = totalCs ~/ 100;
    final sec = totalSec % 60;
    final min = totalSec ~/ 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(min)}:${two(sec)}.${two(cs)}';
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static bool _displayIsZero(ExperienceStateEngine state) {
    final d = state.read('display')?.toString() ?? '';
    return d.isEmpty || d == '00:00.00' || d == '0';
  }
}
