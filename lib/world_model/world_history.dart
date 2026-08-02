/// WorldHistory — every WorldSnapshot ever produced, in order. Nothing
/// is ever removed or overwritten, mirroring ReviewHistory (V6) /
/// EvolutionHistory (V7)'s append-only shape.
library;

import 'world_snapshot.dart';

class WorldHistory {
  final List<WorldSnapshot> _snapshots = [];

  void record(WorldSnapshot snapshot) => _snapshots.add(snapshot);

  List<WorldSnapshot> get snapshots => List.unmodifiable(_snapshots);

  WorldSnapshot? get latest => _snapshots.isEmpty ? null : _snapshots.last;

  int get snapshotCount => _snapshots.length;
}
