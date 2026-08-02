/// ObservationMemory — every ObservationRecord ever captured, in order.
/// Nothing is ever removed or overwritten; Learning reuses this record
/// rather than re-observing. Mirrors ReviewMemory (V6) / EvolutionMemory
/// (V7)'s append-only store shape.
library;

import 'observation_record.dart';
import 'ril_types.dart';

class ObservationMemory {
  final List<ObservationRecord> _records = [];

  void record(ObservationRecord record) => _records.add(record);

  List<ObservationRecord> get records => List.unmodifiable(_records);

  List<ObservationRecord> forExperience(String experienceId) =>
      _records.where((r) => r.experienceId == experienceId).toList();

  List<ObservationRecord> ofCategory(ObservationCategory category) =>
      _records.where((r) => r.category == category).toList();

  int get recordCount => _records.length;
}
