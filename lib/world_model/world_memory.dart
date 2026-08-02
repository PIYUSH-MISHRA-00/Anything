/// WorldMemory — recall a prior WorldSnapshot by version number.
/// Honestly scoped exactly like ReviewMemory (V6) / EvolutionMemory (V7)
/// / ObservationMemory-family (V8): real, deterministic, versioned, and
/// held in-memory on whatever owns the WorldModelEngine/Coordinator
/// instance — repository audit confirmed zero SQLite/disk persistence
/// exists in any of those three prior subsystems, and WorldMemory
/// follows the identical, already-established pattern rather than
/// claiming a durability none of them actually have.
library;

import 'world_snapshot.dart';

class WorldMemory {
  final List<WorldSnapshot> _snapshots = [];

  void record(WorldSnapshot snapshot) => _snapshots.add(snapshot);

  WorldSnapshot? recall(int versionNumber) {
    for (var i = _snapshots.length - 1; i >= 0; i--) {
      if (_snapshots[i].version.number == versionNumber) return _snapshots[i];
    }
    return null;
  }

  WorldSnapshot? get latest => _snapshots.isEmpty ? null : _snapshots.last;

  int get snapshotCount => _snapshots.length;
}
