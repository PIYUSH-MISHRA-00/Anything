/// Implementation Specification IS-R46 — Architectural Integrity
/// Certification, Canonical Architecture Enforcement.
///
/// WHY THIS FILE EXISTS. R45 shipped, was declared complete, and did NOT
/// meet its own success criterion: `ExperiencesScreen` (the "My Apps" tab,
/// a top-level navigation destination) bypassed the unified entry pipeline
/// in all three of its Experience-opening paths, and that went unnoticed
/// because the specification enumerated the call sites to inspect and the
/// implementation satisfied that list rather than the goal. A second audit
/// pass found it. This file exists so the NEXT such regression fails CI
/// instead of waiting for an audit.
///
/// WHERE THE CERTIFICATION LIVES, AND WHY IT IS NOT IN lib/. Architectural
/// certification is a build-time concern with zero runtime value: no user
/// benefits from the app scanning its own source at runtime, and shipping a
/// certification subsystem inside `lib/` would itself be exactly the kind of
/// speculative parallel machinery every milestone since MIS-1 has forbidden.
/// The enforcement point is therefore this test file, which reads the REAL
/// source from disk. Nothing was added to `lib/` for R46.
///
/// HOW IT CERTIFIES. Two mechanisms, both mechanical, neither relying on
/// manual reasoning or inferred ownership:
///
///   STATIC  — every `.dart` file under `lib/` is enumerated from disk (no
///             filename assumptions, no hardcoded file list; the scanner
///             walks the real directory tree), comments and string literals
///             are stripped so documentation and prose can never create a
///             false positive, and construction sites of each canonical type
///             are counted and compared against a PINNED ALLOWLIST. A new
///             construction site anywhere in `lib/` fails, naming the file.
///
///   DYNAMIC — the REAL production composition and REAL widgets are built,
///             and identity/behavior invariants are asserted on live objects
///             (one shared instance, one activation manager actually shared
///             across both entry surfaces, every runtime really supervised,
///             activation really flowing through the scheduler).
///
/// The allowlists below are deliberately EXPLICIT rather than "count == 1".
/// Reality is not "one construction site" for every type — `HomeScreen`
/// legitimately composes its own pipeline from individually-resolved fields
/// so per-field test injection keeps working (R45), and the compiler
/// certification runner legitimately builds a Kernel with a fake reasoner.
/// Pinning the exact permitted set is both honest about that reality and
/// strictly stronger than a count: it fails on a NEW site even when an old
/// one is deleted in the same change.
library;

import 'dart:io';

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/app_composition.dart';
import 'package:anything/app/experience_activation_manager.dart';
import 'package:anything/app/experience_entry_pipeline.dart';
import 'package:anything/app/workspace_runtime_supervisor.dart';
import 'package:anything/app/workspace_scheduling_engine.dart';
import 'package:anything/features/experiences/experiences_screen.dart';
import 'package:anything/features/home/home_screen.dart';

// ── The repository scanner ────────────────────────────────────────────────

/// One real `.dart` file under `lib/`, with its source already stripped of
/// comments and string literals.
class _SourceFile {
  /// Repository-relative, forward-slashed (e.g. `lib/app/app_composition.dart`)
  /// so assertions and failure messages are platform-independent.
  final String path;

  /// Source with comments and string literals stripped — used for
  /// construction/declaration detection.
  final String code;

  /// The untouched source. Required for import certification: an import URI
  /// IS a string literal, so it does not survive stripping.
  final String raw;

  const _SourceFile(this.path, this.code, this.raw);
}

/// Enumerates every `.dart` file under `lib/` from the REAL directory tree.
/// No filename assumptions and no hardcoded list — if a new subsystem is
/// added in a new directory, it is scanned automatically.
List<_SourceFile> _scanLib() {
  final root = Directory('lib');
  if (!root.existsSync()) {
    fail('lib/ not found. Tests must run from the package root (CWD=${Directory.current.path}).');
  }
  final files = <_SourceFile>[];
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final rel = entity.path.replaceAll(r'\', '/');
    final raw = entity.readAsStringSync();
    files.add(_SourceFile(rel, _stripCommentsAndStrings(raw), raw));
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// Removes block comments, line comments and string literal CONTENT, so that
/// a type name mentioned in a doc comment or inside a string can never be
/// mistaken for a real construction site.
///
/// This matters concretely: `lib/application_engineering/lifecycle_engineering.dart`
/// contains the STRING `'ExperienceOpeningCoordinator (trusted opening)'`,
/// which a naive grep counts as a construction of that type. String contents
/// are replaced (not deleted) so byte offsets stay meaningful for line
/// reporting.
String _stripCommentsAndStrings(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';

    // Block comment (covers /** doc comments too).
    if (c == '/' && next == '*') {
      final end = source.indexOf('*/', i + 2);
      final stop = end == -1 ? source.length : end + 2;
      for (var k = i; k < stop; k++) {
        out.write(source[k] == '\n' ? '\n' : ' ');
      }
      i = stop;
      continue;
    }

    // Line comment (covers /// doc comments too).
    if (c == '/' && next == '/') {
      while (i < source.length && source[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }

    // String literal — single, double, and triple-quoted, raw or not.
    if (c == "'" || c == '"') {
      final isTriple = i + 2 < source.length && source[i + 1] == c && source[i + 2] == c;
      final delim = isTriple ? c * 3 : c;
      out.write(' ' * delim.length);
      i += delim.length;
      while (i < source.length) {
        if (source[i] == r'\' && !isTriple) {
          out.write('  ');
          i += 2;
          continue;
        }
        if (i + delim.length <= source.length && source.substring(i, i + delim.length) == delim) {
          out.write(' ' * delim.length);
          i += delim.length;
          break;
        }
        out.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
      continue;
    }

    out.write(c);
    i++;
  }
  return out.toString();
}

/// Files that CONSTRUCT [type], excluding the file that declares it (a class
/// declaring its own constructor is the owner, not a duplicate). Matches
/// `Type(` not preceded by an identifier character or a dot, so
/// `SomeOtherType(` and `foo.Type(` never match.
List<String> _constructionSites(List<_SourceFile> files, String type) {
  final ctor = RegExp('(?<![A-Za-z0-9_\$.])$type\\s*\\(');
  final sites = <String>[];
  for (final f in files) {
    if (_declaresClass(f, type)) continue; // declaring file owns its constructor
    if (ctor.hasMatch(f.code)) sites.add(f.path);
  }
  return sites..sort();
}

/// Whether [f] declares `class [type]`. Any leading modifiers (`abstract`,
/// `sealed`, `final`, ...) precede the `class` keyword, so matching on
/// `class <Type>` alone is both sufficient and free of the catastrophic
/// backtracking a modifier-alternation quantifier caused (it made the full
/// verification pass take ~19s; this takes milliseconds).
bool _declaresClass(_SourceFile f, String type) =>
    RegExp('\\bclass\\s+$type\\b').hasMatch(f.code);

/// Files declaring `class [type]`, repository-wide.
List<String> _declaringFiles(List<_SourceFile> files, String type) =>
    files.where((f) => _declaresClass(f, type)).map((f) => f.path).toList()..sort();

/// Every `path:line` where [pattern] really occurs in stripped source.
List<String> _matchSites(List<_SourceFile> files, RegExp pattern) =>
    _matchSitesIn(files, pattern, raw: false);

/// Import URIs are string literals and therefore do NOT survive stripping —
/// import certification must scan raw source. This was a real bug in the
/// first run of this file: both external-package boundary tests reported
/// zero import sites, which would have silently certified "no Kaalka imports
/// anywhere" as a pass had the expected list also been empty.
List<String> _matchRawSites(List<_SourceFile> files, RegExp pattern) =>
    _matchSitesIn(files, pattern, raw: true);

List<String> _matchSitesIn(List<_SourceFile> files, RegExp pattern, {required bool raw}) {
  final sites = <String>[];
  for (final f in files) {
    final lines = (raw ? f.raw : f.code).split('\n');
    for (var n = 0; n < lines.length; n++) {
      if (pattern.hasMatch(lines[n])) sites.add('${f.path}:${n + 1}');
    }
  }
  return sites..sort();
}

// ── The pinned canonical architecture ─────────────────────────────────────

/// THE INVARIANT TABLE. Key = canonical type. Value = the ONLY files in
/// `lib/` permitted to construct it. Adding a file here is an explicit,
/// reviewable architectural decision; adding one by accident fails CI.
///
/// Rationale for every entry with more than one permitted site is recorded
/// in `docs/architecture/ARCHITECTURAL_INTEGRITY_CERTIFICATION.md` and
/// summarised inline below — no unexplained exceptions.
const Map<String, List<String>> canonicalConstructionSites = {
  // The entry pipeline itself. `home_screen` composes a local instance from
  // its own individually-resolved fields so R32-R44's established per-field
  // test injection keeps taking real effect (IS-R45); it delegates to the
  // SAME shared activation manager in production, which the dynamic
  // certification below proves on live objects rather than asserting here.
  'ExperienceEntryPipeline': ['lib/app/app_composition.dart', 'lib/features/home/home_screen.dart'],

  // THE R45 INVARIANT. The pipeline is the ONLY thing that may put an
  // Experience on screen. This single line is the mechanical form of "every
  // production experience entry flows through one canonical pipeline".
  'ExperienceHostScreen': ['lib/app/experience_entry_pipeline.dart'],

  'WorkspaceRuntimeSupervisor': ['lib/app/app_composition.dart'],
  'UniversalIntentRouter': ['lib/app/app_composition.dart'],
  'IntentExecutionPipeline': ['lib/app/app_composition.dart'],
  'ExperienceWorkspaceManager': ['lib/app/app_composition.dart'],
  'IntentSessionManager': ['lib/app/app_composition.dart'],

  // Same IS-R45 DI-consistency rationale as the pipeline above.
  'WorkspaceSchedulingEngine': ['lib/app/app_composition.dart', 'lib/features/home/home_screen.dart'],
  'ExperienceActivationManager': ['lib/app/app_composition.dart', 'lib/features/home/home_screen.dart'],
  'ExperienceOpeningCoordinator': ['lib/app/app_composition.dart', 'lib/features/home/home_screen.dart'],

  // The reasoning boundary's owner. `certification_runner` builds a Kernel
  // with a FAKE reasoner and a FAKE provider registry to compare the legacy
  // and compiler pipelines (R23) — a real second Kernel INSTANCE, but
  // provably not a second AI boundary, which the AI certification proves
  // separately by pinning the real model-invocation sites.
  'AnythingKernel': ['lib/app/app_composition.dart', 'lib/compiler_certification/certification_runner.dart'],

  // Per-session, owned by the host screen — "exactly one runtime controller
  // per session" is a runtime cardinality invariant, proven dynamically.
  'AnythingRuntime': ['lib/runtime/experience_host_screen.dart'],
  'ExperienceRuntimeController': ['lib/runtime/experience_host_screen.dart'],
};

/// Every file permitted to reach a real language model. Pinned so that a new
/// LLM call anywhere in `lib/` fails CI — the mechanical form of "exactly one
/// reasoning boundary".
const List<String> permittedModelInvocationFiles = [
  // Runtime AI capability, exposed to generated Experiences. NOT part of the
  // creation path and not a reasoning boundary: it is a capability an
  // Experience may invoke, mediated by the capability platform.
  'lib/capabilities/adapters/model_provider_ai_adapter.dart',
  'lib/capabilities/builtin/ai_capability.dart',
  // Optional, degradable intent understanding: falls back to deterministic
  // heuristics when no provider is configured OR when the model call throws.
  // Never mandatory, never blocking.
  'lib/kernel/understanding/model_understanding_service.dart',
  // THE ONE mandatory creation-path reasoning boundary: SemanticApp
  // generation, reached only when DeterministicReasoner returns
  // ReasoningProviderRequired.
  'lib/synthesis/model_reasoner.dart',
];

/// The ONE real canonical-type name collision in `lib/`, pinned explicitly so
/// it is visible in CI rather than averaged away by a count.
///
/// `lib/core/contracts/runtime.dart` declares a v1-era `abstract class
/// AnythingRuntime` whose shape does not match the live implementation at
/// all. It is imported by nothing and implemented by nothing (certified
/// separately below). Recorded as an R46 finding; deletion recommended for
/// R47, deliberately not performed inside a certification milestone.
const Map<String, List<String>> knownDuplicateDeclarations = {
  'AnythingRuntime': ['lib/core/contracts/runtime.dart', 'lib/runtime/anything_runtime.dart'],
};

/// External protection/knowledge packages must stay behind their single
/// documented adapter boundary.
const List<String> permittedKaalkaImportFiles = ['lib/security/kaalka_service.dart'];
const List<String> permittedWebWeaveXImportFiles = [
  'lib/knowledge/webweavex_adapter.dart',
  'lib/software_cognition/component_analyzer.dart',
  'lib/software_cognition/package_analyzer.dart',
  'lib/software_cognition/repository_analyzer.dart',
];

void main() {
  late List<_SourceFile> libFiles;

  setUpAll(() {
    libFiles = _scanLib();
  });

  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  // ── Scanner self-certification ──────────────────────────────────────────
  //
  // A certification layer that silently scans nothing, or that miscounts,
  // is worse than none: it reports success forever. These prove the
  // instrument works before any invariant is trusted.
  group('R46 scanner self-certification — the instrument is proven before it is trusted', () {
    test('the scanner really walks the repository and finds a substantial number of real lib/ files', () {
      expect(libFiles.length, greaterThan(400), reason: 'lib/ contained 462 .dart files at R46; a collapse to near-zero would mean the scanner silently stopped working and every invariant below would vacuously pass');
      expect(libFiles.map((f) => f.path), contains('lib/app/app_composition.dart'));
      expect(libFiles.map((f) => f.path), contains('lib/app/experience_entry_pipeline.dart'));
    });

    test('comment stripping really removes doc comments, line comments and block comments', () {
      const src = '''
/// ExperienceHostScreen( in a doc comment
// ExperienceHostScreen( in a line comment
/* ExperienceHostScreen( in a block comment */
final x = 1;
''';
      final stripped = _stripCommentsAndStrings(src);
      expect(stripped.contains('ExperienceHostScreen'), isFalse, reason: 'a type named only in prose must never count as a construction site');
      expect(stripped.contains('final x = 1;'), isTrue, reason: 'real code must survive stripping');
    });

    test('string-literal stripping really removes type names inside strings — the concrete false positive this guards against is real, in lifecycle_engineering.dart', () {
      const src = "const label = 'ExperienceOpeningCoordinator (trusted opening)';\nfinal y = 2;";
      final stripped = _stripCommentsAndStrings(src);
      expect(stripped.contains('ExperienceOpeningCoordinator'), isFalse);
      expect(stripped.contains('final y = 2;'), isTrue);

      // And prove it on the REAL file, not just a synthetic string.
      final real = libFiles.where((f) => f.path == 'lib/application_engineering/lifecycle_engineering.dart');
      expect(real, isNotEmpty, reason: 'the real file this guard exists for must still be present');
      expect(real.first.code.contains('ExperienceOpeningCoordinator'), isFalse, reason: 'the real string-literal mention must be stripped, which is why this file is absent from the ExperienceOpeningCoordinator allowlist');
    });

    test('the construction matcher does not match a longer identifier that merely ends with the type name', () {
      const code = 'final a = MyExperienceHostScreen();';
      final probe = [const _SourceFile('lib/probe.dart', code, code)];
      expect(_constructionSites(probe, 'ExperienceHostScreen'), isEmpty);
    });

    test('the construction matcher DOES match a real construction, so a true positive is not silently missed', () {
      const code = 'final a = ExperienceHostScreen(package: p);';
      final probe = [const _SourceFile('lib/probe.dart', code, code)];
      expect(_constructionSites(probe, 'ExperienceHostScreen'), ['lib/probe.dart']);
    });
  });

  // ── STATIC CERTIFICATION ────────────────────────────────────────────────
  group('R46 STATIC certification — canonical construction ownership, repository-wide', () {
    for (final entry in canonicalConstructionSites.entries) {
      test('${entry.key} is constructed ONLY in its ${entry.value.length} permitted site(s)', () {
        final actual = _constructionSites(libFiles, entry.key);
        final expected = [...entry.value]..sort();
        expect(
          actual,
          expected,
          reason: 'Architectural invariant violated for ${entry.key}.\n'
              'Permitted: $expected\n'
              'Found:     $actual\n'
              'If this is a deliberate architectural change, update '
              'canonicalConstructionSites in this file AND '
              'docs/architecture/ARCHITECTURAL_INTEGRITY_CERTIFICATION.md. '
              'If it is not deliberate, a second construction path has been '
              'introduced — exactly the class of regression R45 shipped with.',
        );
      });
    }

    test('every canonical type is declared exactly once in lib/ — except the ONE real, documented name collision, which is pinned rather than hidden', () {
      for (final type in canonicalConstructionSites.keys) {
        final declaring = _declaringFiles(libFiles, type);
        final expected = knownDuplicateDeclarations[type] ?? [];
        if (expected.isNotEmpty) {
          expect(declaring, expected, reason: 'the known, documented declaration set for $type changed');
        } else {
          expect(declaring.length, 1, reason: '$type must be declared exactly once in lib/; found: $declaring');
        }
      }
    });

    test('the dead v1 AnythingRuntime contract stays dead — nothing imports it, so the name collision cannot become a real ambiguity', () {
      // R46 FINDING. `lib/core/contracts/runtime.dart` declares
      // `abstract class AnythingRuntime`, a v1-era contract with a
      // COMPLETELY different shape from the real, live
      // `lib/runtime/anything_runtime.dart` (`openExperience(ExperienceId)`
      // vs `openExperience(ExperiencePackage)`). Nothing implements it and
      // nothing imports it — in lib/ OR test/ — so it is genuinely dead,
      // orphaned residue of exactly the kind MIS-1 Part 1 documented.
      //
      // R46 is a certification milestone, so the file is NOT deleted here;
      // deletion is recommended for R47 and left to architectural review.
      // What IS enforced is that it stays unreferenced: the moment anything
      // imports it, two different `AnythingRuntime` types are in play and
      // this fails.
      final importers = libFiles
          .where((f) => f.path != 'lib/core/contracts/runtime.dart')
          .where((f) => RegExp(r'''import\s+['"][^'"]*contracts/runtime\.dart''').hasMatch(f.raw))
          .map((f) => f.path)
          .toList();
      expect(importers, isEmpty, reason: 'The dead v1 runtime contract acquired importers: $importers. Two different AnythingRuntime types would now be live.');

      final implementors = libFiles
          .where((f) => RegExp(r'(?:implements|extends)\s+AnythingRuntime\b').hasMatch(f.code))
          .map((f) => f.path)
          .toList();
      expect(implementors, isEmpty, reason: 'Nothing implemented the v1 contract at R46; found: $implementors');
    });
  });

  // ── PIPELINE CERTIFICATION ──────────────────────────────────────────────
  group('R46 PIPELINE certification — every Experience entry flows through ExperienceEntryPipeline', () {
    test('ExperienceEntryPipeline is the ONLY file in lib/ that constructs ExperienceHostScreen', () {
      expect(
        _constructionSites(libFiles, 'ExperienceHostScreen'),
        ['lib/app/experience_entry_pipeline.dart'],
        reason: 'This is the load-bearing R45 invariant restated mechanically. '
            'Before R45\'s second pass, lib/features/experiences/experiences_screen.dart '
            'also constructed it in three places, bypassing workspace registration, '
            'the scheduler, runtime supervision and the activation manager entirely.',
      );
    });

    test('no production screen outside the pipeline pushes a route that builds an Experience host', () {
      // Belt-and-braces: a raw Navigator.push whose builder mentions the host
      // screen would be caught by the construction check above, but this
      // states the intent directly and fails with a clearer message.
      final pushers = libFiles
          .where((f) => f.path != 'lib/app/experience_entry_pipeline.dart')
          .where((f) => f.code.contains('ExperienceHostScreen') && RegExp(r'Navigator\s*\.\s*(of\s*\([^)]*\)\s*\.)?push').hasMatch(f.code))
          .map((f) => f.path)
          .toList();
      expect(pushers, isEmpty, reason: 'These files both reference ExperienceHostScreen and call Navigator.push: $pushers');
    });
  });

  // ── AI CERTIFICATION ────────────────────────────────────────────────────
  group('R46 AI certification — exactly one reasoning boundary', () {
    test('real model invocation happens only in the pinned set of files', () {
      final sites = _matchSites(libFiles, RegExp(r'\b_?provider\s*\.\s*generate\s*\('));
      final files = sites.map((s) => s.split(':').first).toSet().toList()..sort();
      expect(
        files,
        permittedModelInvocationFiles,
        reason: 'A new language-model invocation site appeared in lib/.\n'
            'Permitted: $permittedModelInvocationFiles\n'
            'Found:     $files\n'
            'Sites:     $sites\n'
            'Anything permits exactly one MANDATORY creation-path reasoning '
            'boundary (SemanticApp generation). Any addition here must be '
            'justified in docs/architecture/ARCHITECTURAL_INTEGRITY_CERTIFICATION.md.',
      );
    });

    test('exactly one ApplicationReasoner implementation in lib/ actually reaches a ModelProvider', () {
      final impls = libFiles
          .where((f) => RegExp(r'implements\s+ApplicationReasoner').hasMatch(f.code))
          .map((f) => f.path)
          .toList()
        ..sort();
      // Reality, verified by reading each: DeterministicReasoner never calls a
      // provider; CompositeApplicationReasoner only DELEGATES (deterministic
      // first, model on ReasoningProviderRequired); _FixedReasoner in the
      // certification runner is a fake that returns a fixture.
      expect(impls, [
        'lib/compiler_certification/certification_runner.dart',
        'lib/synthesis/composite_reasoner.dart',
        'lib/synthesis/deterministic_reasoner.dart',
        'lib/synthesis/model_reasoner.dart',
      ], reason: 'A new ApplicationReasoner implementation appeared; confirm it does not open a second AI boundary.');

      final reachesModel = impls.where((p) => permittedModelInvocationFiles.contains(p)).toList();
      expect(reachesModel, ['lib/synthesis/model_reasoner.dart'], reason: 'Exactly ONE reasoner implementation may invoke a real model.');
    });

    test('the intent-understanding model call is genuinely optional — it degrades to deterministic heuristics, so it is not a second MANDATORY boundary', () {
      final understanding = libFiles.firstWhere((f) => f.path == 'lib/kernel/understanding/model_understanding_service.dart');
      expect(understanding.code.contains('_heuristicUnderstanding'), isTrue);
      // Two independent fallbacks: no/unconfigured provider, and a thrown
      // model error. Both must remain.
      expect(RegExp(r'provider\s*==\s*null').hasMatch(understanding.code), isTrue, reason: 'must still fall back when no provider is configured');
      expect(RegExp(r'catch\s*\(').hasMatch(understanding.code), isTrue, reason: 'must still fall back when the model call throws');
    });
  });

  // ── EXTERNAL BOUNDARY CERTIFICATION (Kaalka / WebWeaveX) ────────────────
  group('R46 external-package boundary certification', () {
    test('package:kaalka is imported ONLY behind its single documented adapter boundary', () {
      final files = _matchRawSites(libFiles, RegExp('''import\\s+['"]package:kaalka'''))
          .map((s) => s.split(':').first)
          .toSet()
          .toList()
        ..sort();
      expect(files, isNotEmpty, reason: 'sanity: Kaalka must actually be imported somewhere, otherwise this test would pass vacuously');
      expect(files, permittedKaalkaImportFiles, reason: 'Kaalka must remain the sole protection mechanism, reached only through KaalkaService.');
    });

    test('package:webweavex is imported ONLY by its documented adapters/analyzers', () {
      final files = _matchRawSites(libFiles, RegExp('''import\\s+['"]package:webweavex'''))
          .map((s) => s.split(':').first)
          .toSet()
          .toList()
        ..sort();
      expect(files, isNotEmpty, reason: 'sanity: WebWeaveX must actually be imported somewhere, otherwise this test would pass vacuously');
      expect(files, permittedWebWeaveXImportFiles, reason: 'WebWeaveX must stay behind its adapter boundary; the Kernel/UI must never import it.');
    });

    test('neither the Kernel nor any UI file imports an external cognition/protection package directly', () {
      final offenders = libFiles
          .where((f) => f.path.startsWith('lib/kernel/') || f.path.startsWith('lib/features/') || f.path.startsWith('lib/screens/'))
          .where((f) => RegExp('''import\\s+['"]package:(kaalka|webweavex)''').hasMatch(f.raw))
          .map((f) => f.path)
          .toList();
      expect(offenders, isEmpty, reason: 'Kernel/UI must reach these only through their adapters; found: $offenders');
    });
  });

  // ── DYNAMIC CERTIFICATION ───────────────────────────────────────────────
  //
  // Static analysis proves no SECOND construction path exists. It cannot
  // prove the ONE path is actually wired coherently at runtime. These do.
  group('R46 DYNAMIC certification — the real production graph, on live objects', () {
    test('AppComposition.production() exposes exactly one instance of each canonical service, stable across reads', () {
      final c = AppComposition.production();
      addTearDown(() => c.experienceRepository.close());

      expect(identical(c.experienceEntryPipeline, c.experienceEntryPipeline), isTrue);
      expect(identical(c.experienceActivationManager, c.experienceActivationManager), isTrue);
      expect(identical(c.workspaceSchedulingEngine, c.workspaceSchedulingEngine), isTrue);
      expect(identical(c.workspaceRuntimeSupervisor, c.workspaceRuntimeSupervisor), isTrue);
      expect(identical(c.workspaceManager, c.workspaceManager), isTrue);
      expect(identical(c.intentRouter, c.intentRouter), isTrue);
      expect(identical(c.intentExecutionPipeline, c.intentExecutionPipeline), isTrue);

      expect(c.experienceEntryPipeline, isA<ExperienceEntryPipeline>());
      expect(c.experienceActivationManager, isA<ExperienceActivationManager>());
      expect(c.workspaceSchedulingEngine, isA<WorkspaceSchedulingEngine>());
      expect(c.workspaceRuntimeSupervisor, isA<WorkspaceRuntimeSupervisor>());
    });

    test('the composition wires the scheduler and the activation manager to the SAME supervisor and workspace — no split-brain graph', () {
      final c = AppComposition.production();
      addTearDown(() => c.experienceRepository.close());

      expect(identical(c.workspaceSchedulingEngine.supervisor, c.workspaceRuntimeSupervisor), isTrue,
          reason: 'the ONE scheduler must supervise through the ONE supervisor');
      expect(identical(c.workspaceSchedulingEngine.workspace, c.workspaceManager), isTrue,
          reason: 'the ONE scheduler must schedule sessions of the ONE workspace manager');
      expect(identical(c.experienceActivationManager.scheduler, c.workspaceSchedulingEngine), isTrue,
          reason: 'the ONE activation manager must activate through the ONE scheduler');
      expect(identical(c.experienceEntryPipeline.activationManager, c.experienceActivationManager), isTrue,
          reason: 'the ONE entry pipeline must activate through the ONE activation manager');
      expect(identical(c.experienceEntryPipeline.scheduler, c.workspaceSchedulingEngine), isTrue);
      expect(identical(c.experienceEntryPipeline.runtimeSupervisor, c.workspaceRuntimeSupervisor), isTrue);
      expect(identical(c.experienceEntryPipeline.workspaceManager, c.workspaceManager), isTrue);
    });

    test('the two production entry surfaces share the ONE ExperienceActivationManager — the invariant that prevents duplicate Experience routes across tabs', () {
      // WHY THIS IS CERTIFIED STATICALLY. `ExperiencesScreen` resolves the
      // shared pipeline off the composition, so its activation manager is
      // the shared one by construction. `HomeScreen` composes a LOCAL
      // pipeline from individually-resolved fields (IS-R45), which is safe
      // ONLY because, with no per-field overrides, its scheduler resolves to
      // the composition singleton and its activation manager is then bound
      // by an `identical(...)` check to the composition's activation manager.
      // If that binding were ever dropped, the Home and My Apps tabs would
      // track routes independently and could each push a host screen for the
      // same session.
      //
      // Proving this on live objects would require reading HomeScreen's
      // private `_activationManager`, i.e. adding test-only public accessors
      // to production code. That was deliberately rejected: R46 adds nothing
      // to lib/. Certifying the resolution STRUCTURE instead is weaker than
      // an object-identity assertion but costs no production surface, and it
      // fails loudly if the binding is removed or inverted. Recorded as a
      // known limitation in the R46 documentation.
      final home = libFiles.firstWhere((f) => f.path == 'lib/features/home/home_screen.dart');

      expect(
        RegExp(r'identical\(\s*_scheduler\s*,\s*_composition\.workspaceSchedulingEngine\s*\)').hasMatch(home.code),
        isTrue,
        reason: 'HomeScreen must keep binding its activation manager to the composition singleton via an identical() check on the scheduler.',
      );
      expect(
        home.code.contains('_composition.experienceActivationManager'),
        isTrue,
        reason: 'HomeScreen must still be able to resolve THE shared activation manager in the no-override case.',
      );
      // The fresh-scheduler branch must remain strictly conditional: an
      // unconditional local scheduler would silently split the graph in
      // production, where no overrides are ever passed.
      expect(
        RegExp(r'needsConsistentScheduler\s*=\s*widget\.scheduler\s*==\s*null\s*&&').hasMatch(home.code),
        isTrue,
        reason: 'the local scheduler must only be built when a caller really overrode a workspace field without a scheduler.',
      );
    });

    testWidgets('both real production entry surfaces build against the same composition without throwing', (tester) async {
      final c = AppComposition.production();
      addTearDown(() => c.experienceRepository.close());

      // Scaffold, not a bare MaterialApp home: HomeScreen contains a
      // TextField, which requires a Material ancestor.
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ExperiencesScreen(composition: c))));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(find.byType(ExperiencesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomeScreen(composition: c))));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('SCHEDULER certification — activation cannot bypass the scheduler: the activation manager has no path to a runtime except through it', () {
      final c = AppComposition.production();
      addTearDown(() => c.experienceRepository.close());

      // Structural, on live objects: the activation manager's ONLY collaborator
      // capable of starting/pausing a runtime is the scheduler it was given.
      expect(identical(c.experienceActivationManager.scheduler, c.workspaceSchedulingEngine), isTrue);
      // And the scheduler is the only thing holding the supervisor.
      expect(identical(c.workspaceSchedulingEngine.supervisor, c.workspaceRuntimeSupervisor), isTrue);
    });

    test('RUNTIME certification — a fresh supervisor reports no unsupervised runtimes, and registration is the only way in', () {
      final c = AppComposition.production();
      addTearDown(() => c.experienceRepository.close());

      // Nothing is registered before any Experience is opened.
      expect(c.workspaceRuntimeSupervisor.registrations, isEmpty,
          reason: 'a freshly composed production graph must supervise nothing yet — any pre-registered runtime would mean something constructed a runtime outside the entry pipeline');
    });
  });

  // ── REGRESSION / BACKWARD COMPATIBILITY ─────────────────────────────────
  group('R46 regression and backward compatibility', () {
    test('R46 added nothing to lib/ — certification is a build-time concern only', () {
      final r46InLib = libFiles.where((f) => f.path.contains('r46') || f.path.contains('architectural_integrity')).toList();
      expect(r46InLib, isEmpty, reason: 'R46 must not ship a certification subsystem inside lib/; found: ${r46InLib.map((f) => f.path)}');
    });

    testWidgets('a bare HomeScreen() and a bare ExperiencesScreen() still render without throwing', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: HomeScreen())));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ExperiencesScreen())));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(find.byType(ExperiencesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ── PERFORMANCE ─────────────────────────────────────────────────────────
  group('R46 performance — real measurements of the certification itself', () {
    test('repository scan and full invariant verification latency', () {
      final scanWatch = Stopwatch()..start();
      final files = _scanLib();
      scanWatch.stop();

      final verifyWatch = Stopwatch()..start();
      for (final type in canonicalConstructionSites.keys) {
        _constructionSites(files, type);
      }
      _matchSites(files, RegExp(r'\b_?provider\s*\.\s*generate\s*\('));
      _matchRawSites(files, RegExp('''import\\s+['"]package:kaalka'''));
      _matchRawSites(files, RegExp('''import\\s+['"]package:webweavex'''));
      verifyWatch.stop();

      final bytes = files.fold<int>(0, (sum, f) => sum + f.code.length);
      // ignore: avoid_print
      print('R46 repository scan: ${files.length} files, ${bytes ~/ 1024}KB stripped source, ${scanWatch.elapsedMilliseconds}ms');
      // ignore: avoid_print
      print('R46 invariant verification (${canonicalConstructionSites.length} types + 3 boundary scans): ${verifyWatch.elapsedMilliseconds}ms');
      // ignore: avoid_print
      print('R46 total certification cost: ${scanWatch.elapsedMilliseconds + verifyWatch.elapsedMilliseconds}ms');

      // A guard, not a benchmark: certification must stay cheap enough that
      // nobody is ever tempted to skip it in CI.
      expect(scanWatch.elapsedMilliseconds + verifyWatch.elapsedMilliseconds, lessThan(30000),
          reason: 'certification must remain cheap enough to always run');
    });
  });
}
