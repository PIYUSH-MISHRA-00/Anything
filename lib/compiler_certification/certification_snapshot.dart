/// CertificationSnapshot — Implementation Milestone R23. A real,
/// deterministic regression/trend mechanism over `CertificationReport`
/// runs. Deliberately NOT a new SQLite table/repository: Engineering
/// Memory and World Model must remain unchanged this milestone (R23's own
/// explicit rule), and this is fundamentally a testing/reporting tool, not
/// a runtime feature — a checked-in JSON snapshot compared against the
/// current run is the lightest honest design that still proves regression
/// detection and trend reporting end-to-end.
///
/// Scope, honestly stated: this mechanism is proven correct by real tests
/// (see `test/r23_compiler_certification_test.dart`) using
/// programmatically-held snapshots. It is NOT wired into a live CI/
/// scheduled process in this milestone — that would be a separate,
/// infrastructure-level decision (see docs, "Recommendation for R24").
library;

import 'certification_report.dart';

/// One fixture's recorded score, for snapshot comparison.
class SnapshotEntry {
  final String category;
  final double compatibilityScore;

  const SnapshotEntry({
    required this.category,
    required this.compatibilityScore,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'compatibilityScore': compatibilityScore,
  };

  factory SnapshotEntry.fromJson(Map<String, dynamic> json) => SnapshotEntry(
    category: json['category'] as String,
    compatibilityScore: (json['compatibilityScore'] as num).toDouble(),
  );
}

class CertificationSnapshot {
  final DateTime recordedAt;
  final double migrationReadinessScore;
  final List<SnapshotEntry> entries;

  const CertificationSnapshot({
    required this.recordedAt,
    required this.migrationReadinessScore,
    required this.entries,
  });

  factory CertificationSnapshot.of(
    CertificationReport report, {
    DateTime? now,
  }) => CertificationSnapshot(
    recordedAt: now ?? DateTime.now(),
    migrationReadinessScore: report.migrationReadinessScore,
    entries: [
      for (final f in report.fixtures)
        SnapshotEntry(
          category: f.category,
          compatibilityScore: f.report.compatibilityScore,
        ),
    ],
  );

  Map<String, dynamic> toJson() => {
    'recordedAt': recordedAt.toIso8601String(),
    'migrationReadinessScore': migrationReadinessScore,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory CertificationSnapshot.fromJson(Map<String, dynamic> json) =>
      CertificationSnapshot(
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        migrationReadinessScore: (json['migrationReadinessScore'] as num)
            .toDouble(),
        entries: (json['entries'] as List)
            .map((e) => SnapshotEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One real, named regression: a fixture whose `compatibilityScore`
/// dropped versus the baseline snapshot.
class RegressionFinding {
  final String category;
  final double baselineScore;
  final double currentScore;

  const RegressionFinding({
    required this.category,
    required this.baselineScore,
    required this.currentScore,
  });

  @override
  String toString() =>
      '$category: $baselineScore -> $currentScore (regression)';
}

/// Real, deterministic comparison — a fixture missing from [current]
/// (e.g. the Kernel stopped reaching `ExecutionPlanReady` for it) counts
/// as a regression too, never silently ignored.
List<RegressionFinding> detectRegressions(
  CertificationSnapshot baseline,
  CertificationReport current,
) {
  final currentScores = {
    for (final f in current.fixtures) f.category: f.report.compatibilityScore,
  };
  final findings = <RegressionFinding>[];
  for (final entry in baseline.entries) {
    final currentScore = currentScores[entry.category];
    if (currentScore == null || currentScore < entry.compatibilityScore) {
      findings.add(
        RegressionFinding(
          category: entry.category,
          baselineScore: entry.compatibilityScore,
          currentScore: currentScore ?? 0.0,
        ),
      );
    }
  }
  return findings;
}

/// Real trend across an ordered sequence of snapshots (oldest first) —
/// the raw `migrationReadinessScore` series, so a caller can chart or
/// threshold it without this module inventing a smoothing/interpretation
/// scheme.
List<double> migrationReadinessTrend(List<CertificationSnapshot> history) =>
    history.map((s) => s.migrationReadinessScore).toList();
