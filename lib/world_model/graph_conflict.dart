/// GraphConflict — two real nodes claim the same EntityIdentity but
/// disagree on kind or label. Surfaced, never silently resolved.
library;

import 'entity_identity.dart';

class GraphConflict {
  final EntityIdentity identity;
  final String description;

  const GraphConflict({required this.identity, required this.description});
}
