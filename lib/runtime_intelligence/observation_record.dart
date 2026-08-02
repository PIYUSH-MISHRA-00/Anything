/// ObservationRecord — one structural fact about how a running Experience
/// was used. Deliberately privacy-safe by construction: every field is
/// an id, a count, a boolean, or an enum — never a raw value, search
/// term, form field, or query result. There is no field on this class
/// capable of holding personal content; this is a structural guarantee,
/// not a policy someone has to remember to follow.
library;

import 'ril_types.dart';

class ObservationRecord {
  final String id;
  final ObservationCategory category;
  final String? experienceId;
  final String? screenId;
  final String? entityId;
  final String? capabilityId;
  final bool succeeded;

  /// A structural count only (result count, argument count, filter
  /// count) — never the underlying content.
  final int? count;

  final DateTime timestamp;

  const ObservationRecord({
    required this.id,
    required this.category,
    this.experienceId,
    this.screenId,
    this.entityId,
    this.capabilityId,
    this.succeeded = true,
    this.count,
    required this.timestamp,
  });
}
