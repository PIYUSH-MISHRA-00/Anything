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
    fail(
      'lib/ not found. Tests must run from the package root (CWD=${Directory.current.path}).',
    );
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
    //
    // INTERPOLATIONS ARE PRESERVED AS CODE. `'${DateTime.now()}'` contains
    // real, executing Dart inside the `${...}`; blanking it along with the
    // surrounding prose created a genuine blind spot in which any logic
    // written inside an interpolation was invisible to every static
    // invariant. IS-R48 found this the hard way: a mutation probe that
    // reintroduced timestamp-derived ids as
    // `return 'wwx-${DateTime.now().microsecondsSinceEpoch}';` did NOT fail
    // certification, because the offending code sat inside a string literal.
    //
    // Interpolated regions are now copied verbatim. That is deliberately the
    // conservative direction for a certification layer: a nested string
    // inside an interpolation could in principle produce a false positive,
    // which is loud and fixable, whereas a false negative is silent.
    if (c == "'" || c == '"') {
      final isTriple =
          i + 2 < source.length && source[i + 1] == c && source[i + 2] == c;
      final delim = isTriple ? c * 3 : c;
      out.write(' ' * delim.length);
      i += delim.length;
      while (i < source.length) {
        if (source[i] == r'\' && !isTriple) {
          out.write('  ');
          i += 2;
          continue;
        }
        // `${ ... }` — copy the expression through, tracking nested braces.
        if (source[i] == r'$' &&
            i + 1 < source.length &&
            source[i + 1] == '{') {
          out.write('  ');
          i += 2;
          var depth = 1;
          while (i < source.length && depth > 0) {
            final ch = source[i];
            if (ch == '{') depth++;
            if (ch == '}') {
              depth--;
              if (depth == 0) {
                out.write(' ');
                i++;
                break;
              }
            }
            out.write(ch == '\n' ? '\n' : ch);
            i++;
          }
          continue;
        }
        if (i + delim.length <= source.length &&
            source.substring(i, i + delim.length) == delim) {
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
    if (_declaresClass(f, type)) {
      continue; // declaring file owns its constructor
    }
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
    files.where((f) => _declaresClass(f, type)).map((f) => f.path).toList()
      ..sort();

/// The source of ONE class body, by brace matching from its declaration.
///
/// Needed because IS-R54 declares the framework, the evaluator and the planner
/// in one file, and "the evaluator cannot install" is a claim about the
/// EVALUATOR, not about the file. A whole-file check would be vacuous here —
/// the framework legitimately holds a repository three classes away.
///
/// Returns '' when the class is not found, so a caller must assert non-empty
/// rather than silently certify nothing.
String _classBody(String code, String type) {
  final start = RegExp('\\bclass\\s+$type\\b').firstMatch(code);
  if (start == null) return '';
  final open = code.indexOf('{', start.end);
  if (open < 0) return '';
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    if (code[i] == '{') depth++;
    if (code[i] == '}') {
      depth--;
      if (depth == 0) return code.substring(open, i + 1);
    }
  }
  return '';
}

/// Every `(start, end)` span of a `name(...)` call in [code], where `end` is
/// just past the balanced closing parenthesis.
///
/// Needed because IS-R56's ordering invariant is really a CONTAINMENT
/// question: "does presentation happen inside the critical section?" A
/// text-order comparison answered that wrongly on the first attempt and the
/// mutation probe caught it — moving the call inside the callback still put it
/// textually after `store.update(`.
List<(int, int)> _callRanges(String code, String name) {
  final ranges = <(int, int)>[];
  for (final m in RegExp('${RegExp.escape(name)}\\s*[(<]').allMatches(code)) {
    var i = code.indexOf('(', m.start);
    if (i < 0) continue;
    var depth = 0;
    for (var j = i; j < code.length; j++) {
      if (code[j] == '(') depth++;
      if (code[j] == ')') {
        depth--;
        if (depth == 0) {
          ranges.add((m.start, j + 1));
          break;
        }
      }
    }
  }
  return ranges;
}

/// `ActivityRepository` -> `activity_repository`, so a repository's own file
/// can be excluded from its own construction scan.
String _snake(String type) => type
    .replaceAllMapped(RegExp(r'(?<!^)([A-Z])'), (m) => '_${m.group(1)}')
    .toLowerCase();

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

List<String> _matchSitesIn(
  List<_SourceFile> files,
  RegExp pattern, {
  required bool raw,
}) {
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
  'ExperienceEntryPipeline': [
    'lib/app/app_composition.dart',
    'lib/features/home/home_screen.dart',
  ],

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
  'WorkspaceSchedulingEngine': [
    'lib/app/app_composition.dart',
    'lib/features/home/home_screen.dart',
  ],
  'ExperienceActivationManager': [
    'lib/app/app_composition.dart',
    'lib/features/home/home_screen.dart',
  ],
  'ExperienceOpeningCoordinator': [
    'lib/app/app_composition.dart',
    'lib/features/home/home_screen.dart',
  ],

  // The reasoning boundary's owner. `certification_runner` builds a Kernel
  // with a FAKE reasoner and a FAKE provider registry to compare the legacy
  // and compiler pipelines (R23) — a real second Kernel INSTANCE, but
  // provably not a second AI boundary, which the AI certification proves
  // separately by pinning the real model-invocation sites.
  'AnythingKernel': [
    'lib/app/app_composition.dart',
    'lib/compiler_certification/certification_runner.dart',
  ],

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

/// Canonical-type name collisions that are knowingly tolerated.
///
/// EMPTY AS OF R47. R46 found exactly one — `lib/core/contracts/runtime.dart`
/// declared a dead v1-era `abstract class AnythingRuntime` whose shape did
/// not match the live implementation — and recommended deletion. IS-R47
/// deleted it after re-verifying repository-wide that it remained
/// unreferenced and unimplemented. `AnythingRuntime` is now declared exactly
/// once in `lib/`, like every other canonical type, and a dedicated test
/// below proves the removed file cannot reappear.
///
/// This map is deliberately kept (rather than deleted along with its only
/// entry) so that a future, genuinely-justified collision must be recorded
/// here explicitly instead of silently relaxing the exactly-once rule.
const Map<String, List<String>> knownDuplicateDeclarations =
    <String, List<String>>{};

/// Files deleted by an architectural-debt milestone that must never come
/// back. R47 removed the dead v1 runtime contract; if any future change
/// recreates that path, certification fails rather than silently
/// reintroducing a second `AnythingRuntime` type.
const List<String> removedDeadFiles = ['lib/core/contracts/runtime.dart'];

/// THE single knowledge cache and its single durable store (IS-R48).
///
/// `KnowledgeCache` is the one canonical cache; `KnowledgeRepository` is its
/// implementation detail, not a second cache and not a second persistence
/// layer. Only these files may reference the repository type — anything else
/// referencing it would be a path around the cache.
const List<String> permittedKnowledgeRepositoryFiles = [
  'lib/app/app_composition.dart',
  'lib/knowledge/knowledge_acquisition_engine.dart',
];

/// Fake implementations that may exist in `lib/` because something real
/// depends on them, mapped to WHY (IS-R49 Task 1 audit).
///
/// Existence in `lib/` is not the problem — REGISTRATION IN THE PRODUCTION
/// COMPOSITION is, and that is certified separately below. R49 removed the
/// last two production registrations.
const Map<String, String> auditedFakeImplementations = {
  // Test doubles that live in lib/ beside the abstraction they double.
  // None is wired in production.
  'lib/capabilities/builtin/notification_capability.dart':
      'FakeNotificationService — test double only since IS-R49',
  'lib/capabilities/builtin/file_capability.dart':
      'FakeFileService — test double only since IS-R49',
  'lib/capabilities/builtin/knowledge_capability.dart':
      'FakeKnowledgeProvider — unused; real adapter wired (gap G-09)',
  'lib/capabilities/builtin/http_capability.dart':
      'FakeHttpTransport — unused; RealHttpTransport wired',
  'lib/capabilities/builtin/ai_capability.dart':
      'FakeAiProvider — unused; ModelProviderAiAdapter wired',
  // Deliberate, private fakes inside the R23 compiler-certification runner:
  // it compares the legacy and compiler pipelines with a fixed reasoner and
  // no provider, by design.
  'lib/compiler_certification/certification_runner.dart':
      '_FakeProviderRegistry/_FixedReasoner — R23 certification fixtures',
};

/// External protection/knowledge packages must stay behind their single
/// documented adapter boundary.
const List<String> permittedKaalkaImportFiles = [
  'lib/security/kaalka_service.dart',
];
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
  group(
    'R46 scanner self-certification — the instrument is proven before it is trusted',
    () {
      test(
        'the scanner really walks the repository and finds a substantial number of real lib/ files',
        () {
          expect(
            libFiles.length,
            greaterThan(400),
            reason:
                'lib/ contained 462 .dart files at R46; a collapse to near-zero would mean the scanner silently stopped working and every invariant below would vacuously pass',
          );
          expect(
            libFiles.map((f) => f.path),
            contains('lib/app/app_composition.dart'),
          );
          expect(
            libFiles.map((f) => f.path),
            contains('lib/app/experience_entry_pipeline.dart'),
          );
        },
      );

      test(
        'comment stripping really removes doc comments, line comments and block comments',
        () {
          const src = '''
/// ExperienceHostScreen( in a doc comment
// ExperienceHostScreen( in a line comment
/* ExperienceHostScreen( in a block comment */
final x = 1;
''';
          final stripped = _stripCommentsAndStrings(src);
          expect(
            stripped.contains('ExperienceHostScreen'),
            isFalse,
            reason:
                'a type named only in prose must never count as a construction site',
          );
          expect(
            stripped.contains('final x = 1;'),
            isTrue,
            reason: 'real code must survive stripping',
          );
        },
      );

      test(
        'string-literal stripping really removes type names inside strings — the concrete false positive this guards against is real, in lifecycle_engineering.dart',
        () {
          const src =
              "const label = 'ExperienceOpeningCoordinator (trusted opening)';\nfinal y = 2;";
          final stripped = _stripCommentsAndStrings(src);
          expect(stripped.contains('ExperienceOpeningCoordinator'), isFalse);
          expect(stripped.contains('final y = 2;'), isTrue);

          // And prove it on the REAL file, not just a synthetic string.
          final real = libFiles.where(
            (f) =>
                f.path ==
                'lib/application_engineering/lifecycle_engineering.dart',
          );
          expect(
            real,
            isNotEmpty,
            reason: 'the real file this guard exists for must still be present',
          );
          expect(
            real.first.code.contains('ExperienceOpeningCoordinator'),
            isFalse,
            reason:
                'the real string-literal mention must be stripped, which is why this file is absent from the ExperienceOpeningCoordinator allowlist',
          );
        },
      );

      test(
        'code inside a string INTERPOLATION survives stripping — the blind spot IS-R48 found by mutation',
        () {
          // A mutation probe reintroducing timestamp ids as
          //   return 'wwx-${DateTime.now().microsecondsSinceEpoch}';
          // passed certification, because the offending code lived inside a
          // string literal and the stripper blanked it wholesale. Interpolated
          // regions are real executing code and must remain visible.
          const src =
              "final a = 'wwx-\${DateTime.now().microsecondsSinceEpoch}';";
          final stripped = _stripCommentsAndStrings(src);
          expect(
            stripped.contains('microsecondsSinceEpoch'),
            isTrue,
            reason:
                'code inside \${...} must survive stripping, or any logic written there is invisible to every invariant',
          );

          // ... while the surrounding prose is still removed.
          const mixed =
              "final b = 'ExperienceHostScreen mentioned in prose \${Foo()} more prose';";
          final strippedMixed = _stripCommentsAndStrings(mixed);
          expect(
            strippedMixed.contains('ExperienceHostScreen'),
            isFalse,
            reason: 'plain string prose must still be stripped',
          );
          expect(
            strippedMixed.contains('Foo()'),
            isTrue,
            reason: 'the interpolated expression must survive',
          );

          // A construction inside an interpolation is therefore detectable.
          const construction = "final c = 'x \${ExperienceHostScreen()} y';";
          final probe = [
            _SourceFile(
              'lib/probe.dart',
              _stripCommentsAndStrings(construction),
              construction,
            ),
          ];
          expect(
            _constructionSites(probe, 'ExperienceHostScreen'),
            ['lib/probe.dart'],
            reason:
                'a rogue construction hidden inside an interpolation must still be caught',
          );
        },
      );

      test(
        'the construction matcher does not match a longer identifier that merely ends with the type name',
        () {
          const code = 'final a = MyExperienceHostScreen();';
          final probe = [const _SourceFile('lib/probe.dart', code, code)];
          expect(_constructionSites(probe, 'ExperienceHostScreen'), isEmpty);
        },
      );

      test(
        'the construction matcher DOES match a real construction, so a true positive is not silently missed',
        () {
          const code = 'final a = ExperienceHostScreen(package: p);';
          final probe = [const _SourceFile('lib/probe.dart', code, code)];
          expect(_constructionSites(probe, 'ExperienceHostScreen'), [
            'lib/probe.dart',
          ]);
        },
      );
    },
  );

  // ── STATIC CERTIFICATION ────────────────────────────────────────────────
  group(
    'R46 STATIC certification — canonical construction ownership, repository-wide',
    () {
      for (final entry in canonicalConstructionSites.entries) {
        test(
          '${entry.key} is constructed ONLY in its ${entry.value.length} permitted site(s)',
          () {
            final actual = _constructionSites(libFiles, entry.key);
            final expected = [...entry.value]..sort();
            expect(
              actual,
              expected,
              reason:
                  'Architectural invariant violated for ${entry.key}.\n'
                  'Permitted: $expected\n'
                  'Found:     $actual\n'
                  'If this is a deliberate architectural change, update '
                  'canonicalConstructionSites in this file AND '
                  'docs/architecture/ARCHITECTURAL_INTEGRITY_CERTIFICATION.md. '
                  'If it is not deliberate, a second construction path has been '
                  'introduced — exactly the class of regression R45 shipped with.',
            );
          },
        );
      }

      test(
        'every canonical type is declared exactly once in lib/ — except the ONE real, documented name collision, which is pinned rather than hidden',
        () {
          for (final type in canonicalConstructionSites.keys) {
            final declaring = _declaringFiles(libFiles, type);
            final expected = knownDuplicateDeclarations[type] ?? [];
            if (expected.isNotEmpty) {
              expect(
                declaring,
                expected,
                reason:
                    'the known, documented declaration set for $type changed',
              );
            } else {
              expect(
                declaring.length,
                1,
                reason:
                    '$type must be declared exactly once in lib/; found: $declaring',
              );
            }
          }
        },
      );

      test(
        'the dead v1 AnythingRuntime contract is GONE and cannot reappear (IS-R47 Task 1)',
        () {
          // R46 FINDING, R47 RESOLUTION. `lib/core/contracts/runtime.dart`
          // declared `abstract class AnythingRuntime`, a v1-era contract with a
          // COMPLETELY different shape from the live
          // `lib/runtime/anything_runtime.dart` (`openExperience(ExperienceId)`
          // vs `openExperience(ExperiencePackage)`) — two different types under
          // one name. R46 certified it was imported by nothing and implemented
          // by nothing, and recommended deletion. R47 re-verified that
          // repository-wide and deleted it.
          //
          // Three independent guards, so the debt cannot silently return:
          for (final removed in removedDeadFiles) {
            expect(
              File(removed).existsSync(),
              isFalse,
              reason:
                  '$removed was deleted by IS-R47 and must not be recreated.',
            );
            expect(libFiles.map((f) => f.path), isNot(contains(removed)));
          }

          // IMPORT *AND* EXPORT, and RELATIVE paths as well as package paths.
          //
          // This breadth is not theoretical. R47's first verification pass
          // searched only for the literal text `contracts/runtime.dart` and
          // concluded the file was completely unreferenced. It was not:
          // `lib/core/contracts/contracts.dart` re-exported it as
          // `export 'runtime.dart';` — a RELATIVE path with no `contracts/`
          // segment — so the barrel kept a live reference the search never saw.
          // The deletion produced a dangling `uri_does_not_exist` and the
          // analyzer baseline went 71 -> 72, which is how it was caught.
          // Matching the bare filename in both directives closes that hole.
          for (final removed in removedDeadFiles) {
            // Anchor the basename to a path boundary. A naive
            // `[^'"]*runtime\.dart` also matches `anything_runtime.dart` — the
            // LIVE implementation, imported all over the codebase — and reports
            // a repository-wide false positive. (It did exactly that on first
            // write; the full suite caught it.) The URI must be either exactly
            // the basename or end with `/<basename>`.
            final basename = RegExp.escape(removed.split('/').last);
            final referencers = libFiles
                .where(
                  (f) => RegExp(
                    '''(?:import|export)\\s+['"](?:[^'"]*/)?$basename['"]''',
                  ).hasMatch(f.raw),
                )
                .map((f) => f.path)
                .toList();
            expect(
              referencers,
              isEmpty,
              reason:
                  'Something imports or exports the deleted file $removed: $referencers',
            );
          }

          final implementors = libFiles
              .where(
                (f) => RegExp(
                  r'(?:implements|extends)\s+AnythingRuntime\b',
                ).hasMatch(f.code),
              )
              .map((f) => f.path)
              .toList();
          expect(
            implementors,
            isEmpty,
            reason: 'Nothing implemented the v1 contract; found: $implementors',
          );
        },
      );

      test(
        'AnythingRuntime is now declared exactly ONCE in lib/ — the R46 collision is genuinely resolved, not merely tolerated',
        () {
          expect(_declaringFiles(libFiles, 'AnythingRuntime'), [
            'lib/runtime/anything_runtime.dart',
          ]);
          expect(
            knownDuplicateDeclarations,
            isEmpty,
            reason:
                'No canonical-type name collision should remain after IS-R47.',
          );
        },
      );

      test(
        'the v1-specific event hierarchy the deleted file declared is gone from lib/ too — the deletion removed dead code, not just a name',
        () {
          // The dead contract also declared a sealed RuntimeEvent hierarchy.
          // Before deleting, R47 verified repository-wide (lib/ AND test/) that
          // all six of its symbols were used nowhere else.
          //
          // Only the three unmistakably-v1 names are pinned here. `ExperienceOpened`
          // and `ExperienceClosed` are deliberately NOT pinned: they are plausible
          // names for future *canonical* workspace events, and this guard exists
          // to stop dead v1 code returning, not to reserve English words forever.
          for (final symbol in [
            'RuntimeEvent',
            'CapabilityExecutionStarted',
            'CapabilityExecutionCompleted',
          ]) {
            final declaring = _declaringFiles(libFiles, symbol);
            expect(
              declaring,
              isEmpty,
              reason:
                  '$symbol was part of the deleted dead v1 contract and should not have been reintroduced; found in: $declaring',
            );
          }
        },
      );
    },
  );

  // ── PIPELINE CERTIFICATION ──────────────────────────────────────────────
  group(
    'R46 PIPELINE certification — every Experience entry flows through ExperienceEntryPipeline',
    () {
      test(
        'ExperienceEntryPipeline is the ONLY file in lib/ that constructs ExperienceHostScreen',
        () {
          expect(
            _constructionSites(libFiles, 'ExperienceHostScreen'),
            ['lib/app/experience_entry_pipeline.dart'],
            reason:
                'This is the load-bearing R45 invariant restated mechanically. '
                'Before R45\'s second pass, lib/features/experiences/experiences_screen.dart '
                'also constructed it in three places, bypassing workspace registration, '
                'the scheduler, runtime supervision and the activation manager entirely.',
          );
        },
      );

      test(
        'no production screen outside the pipeline pushes a route that builds an Experience host',
        () {
          // Belt-and-braces: a raw Navigator.push whose builder mentions the host
          // screen would be caught by the construction check above, but this
          // states the intent directly and fails with a clearer message.
          final pushers = libFiles
              .where((f) => f.path != 'lib/app/experience_entry_pipeline.dart')
              .where(
                (f) =>
                    f.code.contains('ExperienceHostScreen') &&
                    RegExp(
                      r'Navigator\s*\.\s*(of\s*\([^)]*\)\s*\.)?push',
                    ).hasMatch(f.code),
              )
              .map((f) => f.path)
              .toList();
          expect(
            pushers,
            isEmpty,
            reason:
                'These files both reference ExperienceHostScreen and call Navigator.push: $pushers',
          );
        },
      );
    },
  );

  // ── AI CERTIFICATION ────────────────────────────────────────────────────
  group('R46 AI certification — exactly one reasoning boundary', () {
    test('real model invocation happens only in the pinned set of files', () {
      final sites = _matchSites(
        libFiles,
        RegExp(r'\b_?provider\s*\.\s*generate\s*\('),
      );
      final files = sites.map((s) => s.split(':').first).toSet().toList()
        ..sort();
      expect(
        files,
        permittedModelInvocationFiles,
        reason:
            'A new language-model invocation site appeared in lib/.\n'
            'Permitted: $permittedModelInvocationFiles\n'
            'Found:     $files\n'
            'Sites:     $sites\n'
            'Anything permits exactly one MANDATORY creation-path reasoning '
            'boundary (SemanticApp generation). Any addition here must be '
            'justified in docs/architecture/ARCHITECTURAL_INTEGRITY_CERTIFICATION.md.',
      );
    });

    test(
      'exactly one ApplicationReasoner implementation in lib/ actually reaches a ModelProvider',
      () {
        final impls =
            libFiles
                .where(
                  (f) => RegExp(
                    r'implements\s+ApplicationReasoner',
                  ).hasMatch(f.code),
                )
                .map((f) => f.path)
                .toList()
              ..sort();
        // Reality, verified by reading each: DeterministicReasoner never calls a
        // provider; CompositeApplicationReasoner only DELEGATES (deterministic
        // first, model on ReasoningProviderRequired); _FixedReasoner in the
        // certification runner is a fake that returns a fixture.
        expect(
          impls,
          [
            'lib/compiler_certification/certification_runner.dart',
            'lib/synthesis/composite_reasoner.dart',
            'lib/synthesis/deterministic_reasoner.dart',
            'lib/synthesis/model_reasoner.dart',
          ],
          reason:
              'A new ApplicationReasoner implementation appeared; confirm it does not open a second AI boundary.',
        );

        final reachesModel = impls
            .where((p) => permittedModelInvocationFiles.contains(p))
            .toList();
        expect(
          reachesModel,
          ['lib/synthesis/model_reasoner.dart'],
          reason:
              'Exactly ONE reasoner implementation may invoke a real model.',
        );
      },
    );

    test(
      'the intent-understanding model call is genuinely optional — it degrades to deterministic heuristics, so it is not a second MANDATORY boundary',
      () {
        final understanding = libFiles.firstWhere(
          (f) =>
              f.path ==
              'lib/kernel/understanding/model_understanding_service.dart',
        );
        expect(understanding.code.contains('_heuristicUnderstanding'), isTrue);
        // Two independent fallbacks: no/unconfigured provider, and a thrown
        // model error. Both must remain.
        expect(
          RegExp(r'provider\s*==\s*null').hasMatch(understanding.code),
          isTrue,
          reason: 'must still fall back when no provider is configured',
        );
        expect(
          RegExp(r'catch\s*\(').hasMatch(understanding.code),
          isTrue,
          reason: 'must still fall back when the model call throws',
        );
      },
    );
  });

  // ── EXTERNAL BOUNDARY CERTIFICATION (Kaalka / WebWeaveX) ────────────────
  group('R46 external-package boundary certification', () {
    test(
      'package:kaalka is imported ONLY behind its single documented adapter boundary',
      () {
        final files = _matchRawSites(
          libFiles,
          RegExp('''import\\s+['"]package:kaalka'''),
        ).map((s) => s.split(':').first).toSet().toList()..sort();
        expect(
          files,
          isNotEmpty,
          reason:
              'sanity: Kaalka must actually be imported somewhere, otherwise this test would pass vacuously',
        );
        expect(
          files,
          permittedKaalkaImportFiles,
          reason:
              'Kaalka must remain the sole protection mechanism, reached only through KaalkaService.',
        );
      },
    );

    test(
      'package:webweavex is imported ONLY by its documented adapters/analyzers',
      () {
        final files = _matchRawSites(
          libFiles,
          RegExp('''import\\s+['"]package:webweavex'''),
        ).map((s) => s.split(':').first).toSet().toList()..sort();
        expect(
          files,
          isNotEmpty,
          reason:
              'sanity: WebWeaveX must actually be imported somewhere, otherwise this test would pass vacuously',
        );
        expect(
          files,
          permittedWebWeaveXImportFiles,
          reason:
              'WebWeaveX must stay behind its adapter boundary; the Kernel/UI must never import it.',
        );
      },
    );

    test(
      'deterministic serialization is reached ONLY through the approved adapter path (IS-R47 Task 4/5)',
      () {
        // R47 integrated WebWeaveX's canonical determinism primitives
        // (normalizeRuntimeValue, stableSerialize). They must be reached the
        // same way every other WebWeaveX capability is: through an adapter.
        // A direct call from the Kernel, the engine, or the UI would mean a
        // second normalization path had been introduced.
        final users = _matchSites(
          libFiles,
          RegExp(
            r'\b(?:wwx|webweavex)\s*\.\s*(?:stableSerialize|normalizeRuntimeValue)\s*\(',
          ),
        ).map((s) => s.split(':').first).toSet().toList()..sort();
        expect(
          users,
          ['lib/knowledge/webweavex_adapter.dart'],
          reason:
              'Deterministic serialization/normalization must stay inside the WebWeaveX adapter boundary. Found: $users',
        );
      },
    );

    test(
      'R47 introduced NO runtime graph, memory fabric, workflow runtime, or Kaalka-via-WebWeaveX (IS-R47 Task 5)',
      () {
        // The R46 audit CLOSED these four WebWeaveX surfaces deliberately:
        // adopting the graph or memory fabric would create a second graph and
        // second memory system; routing crypto through WebWeaveX would create
        // a second protection path and break I-21a. This keeps them closed.
        final forbidden = RegExp(
          r'\b(?:wwx|webweavex)\s*\.\s*(?:RuntimeGraph|buildRuntimeGraph|runtimeGraph|RuntimeMemory|MemoryLineage|queryMemory|replayMemory|KaalkaRuntime|kaalka)',
        );
        final offenders = _matchSites(libFiles, forbidden);
        expect(
          offenders,
          isEmpty,
          reason:
              'A deliberately-closed WebWeaveX surface was adopted: $offenders. '
              'These would create a second graph / second memory system / second protection path.',
        );
      },
    );

    test(
      'KnowledgeCache is the ONE knowledge cache — no second cache, no cache hierarchy (IS-R48 Task 2)',
      () {
        // IS-R48 forbids a PersistentKnowledgeCache, a CachedKnowledgeManager,
        // or any parallel cache hierarchy. Enforced structurally rather than by
        // name-blacklist: exactly one class in all of lib/ may be a *Cache.
        final cacheClasses =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(\w*Cache)\b',
                  ).allMatches(f.code).map((m) => '${f.path}:${m.group(1)}'),
                )
                .toList()
              ..sort();
        expect(
          cacheClasses,
          ['lib/knowledge/knowledge_acquisition_engine.dart:KnowledgeCache'],
          reason:
              'A second knowledge cache class appeared. KnowledgeCache must remain the single canonical cache; persistence is an implementation detail inside it.',
        );
      },
    );

    test(
      'the durable knowledge store cannot be bypassed — only KnowledgeCache and the composition root may reference it (IS-R48 Task 2/6)',
      () {
        final referencers =
            libFiles
                .where((f) => f.path != 'lib/storage/knowledge_repository.dart')
                .where(
                  (f) => RegExp(r'\bKnowledgeRepository\b').hasMatch(f.code),
                )
                .map((f) => f.path)
                .toList()
              ..sort();
        expect(
          referencers,
          permittedKnowledgeRepositoryFiles,
          reason:
              'KnowledgeRepository is an implementation detail of KnowledgeCache. '
              'A new referencer means something reaches persistence around the cache. Found: $referencers',
        );
      },
    );

    test(
      'the durable store never imports WebWeaveX — canonical form comes FROM the adapter, it is not recomputed in storage (IS-R48 Task 3)',
      () {
        final repo = libFiles.firstWhere(
          (f) => f.path == 'lib/storage/knowledge_repository.dart',
        );
        expect(
          RegExp('''import\\s+['"]package:webweavex''').hasMatch(repo.raw),
          isFalse,
          reason:
              'the repository must persist the canonical representation it is GIVEN, never compute one',
        );
        // And it must not hand-roll a canonical encoder of its own.
        expect(repo.code.contains('stableSerialize'), isFalse);
        expect(repo.code.contains('normalizeRuntimeValue'), isFalse);
      },
    );

    test(
      'resource identity is never timestamp-derived — the pre-R47 defect cannot return (IS-R48 Task 7)',
      () {
        final adapter = libFiles.firstWhere(
          (f) => f.path == 'lib/knowledge/webweavex_adapter.dart',
        );
        // Stripped code, so the doc comment that DESCRIBES the old scheme does
        // not trip this — only a real reintroduction would.
        expect(
          adapter.code.contains('microsecondsSinceEpoch'),
          isFalse,
          reason:
              'timestamp-derived resource ids returned; canonical ids could no longer survive restart',
        );
        expect(adapter.code.contains('millisecondsSinceEpoch'), isFalse);
        expect(
          adapter.code.contains('_deterministicId'),
          isTrue,
          reason: 'the canonical identity derivation must still be present',
        );
      },
    );

    test(
      'NO Fake* implementation is registered in the production composition (IS-R49 Task 5)',
      () {
        // THE R49 INVARIANT. `AppComposition` registered FakeNotificationService
        // and FakeFileService into the REAL capability platform until R49. This
        // is the mechanical form of "no production Fake* services remain".
        //
        // Scoped to the composition root deliberately: a Fake* CLASS may exist
        // in lib/ as a test double beside its abstraction (see
        // auditedFakeImplementations); constructing one in the production graph
        // is the actual defect.
        final composition = libFiles.firstWhere(
          (f) => f.path == 'lib/app/app_composition.dart',
        );
        final fakeConstructions =
            RegExp(r'(?<![A-Za-z0-9_$.])(Fake\w+)\s*\(')
                .allMatches(composition.code)
                .map((m) => m.group(1)!)
                .toSet()
                .toList()
              ..sort();
        expect(
          fakeConstructions,
          isEmpty,
          reason:
              'AppComposition constructs Fake* implementation(s) in the real production graph: $fakeConstructions',
        );
      },
    );

    test(
      'the real notification and file services are each registered EXACTLY ONCE in production (IS-R49 Task 5)',
      () {
        final composition = libFiles.firstWhere(
          (f) => f.path == 'lib/app/app_composition.dart',
        );
        for (final type in [
          'RealNotificationService',
          'RealFileService',
          'NotificationCapability',
          'FileCapability',
        ]) {
          final count = RegExp(
            '(?<![A-Za-z0-9_\$.])$type\\s*\\(',
          ).allMatches(composition.code).length;
          expect(
            count,
            1,
            reason:
                '$type must be constructed exactly once in the composition root; found $count',
          );
        }
      },
    );

    test(
      'there is exactly ONE implementation of NotificationService and ONE of FileService wired for production',
      () {
        // No duplicate service: a second Real*/production implementation of
        // either abstraction would mean two owners of the same capability.
        final notificationImpls =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(\w+)\s+implements\s+NotificationService\b',
                  ).allMatches(f.code).map((m) => m.group(1)!),
                )
                .toList()
              ..sort();
        final fileImpls =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(\w+)\s+implements\s+FileService\b',
                  ).allMatches(f.code).map((m) => m.group(1)!),
                )
                .toList()
              ..sort();

        expect(
          notificationImpls,
          ['FakeNotificationService', 'RealNotificationService'],
          reason: 'exactly one real implementation plus the test double',
        );
        expect(
          fileImpls,
          ['FakeFileService', 'RealFileService'],
          reason: 'exactly one real implementation plus the test double',
        );
      },
    );

    test(
      'the real notification service introduces no second notification framework — it reuses the existing EventBus and event type',
      () {
        final adapter = libFiles.firstWhere(
          (f) =>
              f.path ==
              'lib/capabilities/adapters/notification_service_adapter.dart',
        );
        expect(
          adapter.code.contains('NotificationGenerated'),
          isTrue,
          reason: 'delivery must reuse the EXISTING R35 event subtype',
        );
        // No new AnythingEvent subtype may be declared here.
        expect(
          RegExp(
            r'class\s+\w+\s+extends\s+AnythingEvent',
          ).hasMatch(adapter.code),
          isFalse,
          reason:
              'a new event subtype here would be a second notification hierarchy',
        );
        // And no scheduler/timer of its own.
        expect(
          adapter.code.contains('Timer.periodic'),
          isFalse,
          reason:
              'a self-driving timer here would be a second scheduler; BackgroundCoordinator owns planning',
        );
      },
    );

    test('the real file service introduces no duplicate storage system', () {
      final adapter = libFiles.firstWhere(
        (f) => f.path == 'lib/capabilities/adapters/file_service_adapter.dart',
      );
      for (final forbidden in [
        'sqflite',
        'SqliteExperienceRepository',
        'KnowledgeRepository',
        'SharedPreferences',
      ]) {
        expect(
          adapter.code.contains(forbidden),
          isFalse,
          reason:
              'the file service must own only user-imported files; $forbidden belongs to another owner',
        );
      }
    });

    test(
      'exactly ONE retention policy engine exists, and it is disjoint from the runtime lifecycle engine (IS-R50 Task 7)',
      () {
        // TWO engines, TWO disjoint domains — certified rather than asserted:
        //   WorkspaceLifecyclePolicyEngine -> runtime lifecycle (R39)
        //   RetentionPolicyEngine          -> data retention     (R50)
        // A third would be a parallel lifecycle manager. Overlap between these
        // two would be parallel ownership. Both are forbidden.
        final policyEngines =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(\w*(?:Retention|Lifecycle)\w*Engine)\b',
                  ).allMatches(f.code).map((m) => '${f.path}:${m.group(1)}'),
                )
                .toList()
              ..sort();
        expect(
          policyEngines,
          [
            'lib/app/retention_policy_engine.dart:RetentionPolicyEngine',
            'lib/app/workspace_lifecycle_policy_engine.dart:WorkspaceLifecyclePolicyEngine',
          ],
          reason:
              'A parallel lifecycle/retention engine appeared: $policyEngines',
        );

        // Disjointness, in both directions.
        final retention = libFiles.firstWhere(
          (f) => f.path == 'lib/app/retention_policy_engine.dart',
        );
        for (final runtimeConcept in [
          'ExperienceRuntimeController',
          'AppLifecycleState',
          'RuntimePolicyAction',
        ]) {
          expect(
            retention.code.contains(runtimeConcept),
            isFalse,
            reason:
                'the retention engine must not reach into the runtime lifecycle domain ($runtimeConcept)',
          );
        }
        final runtime = libFiles.firstWhere(
          (f) => f.path == 'lib/app/workspace_lifecycle_policy_engine.dart',
        );
        for (final retentionConcept in [
          'RetentionClass',
          'LifecycleCandidate',
          'maxEntries',
        ]) {
          expect(
            runtime.code.contains(retentionConcept),
            isFalse,
            reason:
                'the runtime lifecycle engine must not reach into the retention domain ($retentionConcept)',
          );
        }
      },
    );

    test(
      'the retention engine DECIDES but never DELETES — it holds no storage handle and performs no I/O (IS-R50)',
      () {
        final retention = libFiles.firstWhere(
          (f) => f.path == 'lib/app/retention_policy_engine.dart',
        );
        for (final forbidden in [
          'sqflite',
          'Database',
          'SharedPreferences',
          'dart:io',
          'File(',
          'Directory(',
          'Timer',
        ]) {
          expect(
            retention.code.contains(forbidden),
            isFalse,
            reason:
                'the retention engine must stay pure; $forbidden would give it storage or scheduling power it must not have',
          );
        }
        expect(retention.raw.contains("import 'dart:io'"), isFalse);
      },
    );

    test(
      'NO repository or capability service owns a retention rule of its own (IS-R50 Task 7)',
      () {
        // The concrete pre-R50 defect: three hardcoded bounds invented
        // independently in three files. Each of these delegates now, and this
        // stops any of them quietly re-inventing one.
        const delegators = [
          'lib/storage/intent_repository.dart',
          'lib/storage/activity_repository.dart',
          'lib/capabilities/adapters/notification_service_adapter.dart',
          'lib/capabilities/adapters/file_service_adapter.dart',
          'lib/storage/knowledge_repository.dart',
        ];
        for (final path in delegators) {
          final file = libFiles.firstWhere((f) => f.path == path);
          // No private retention constant of its own.
          final ownBounds = RegExp(
            r'static\s+const\s+int\s+_max(?:Records|Events|Scheduled|Entries|Retained)\b',
          ).allMatches(file.code).map((m) => m.group(0)!).toList();
          expect(
            ownBounds,
            isEmpty,
            reason:
                '$path re-invented a retention bound: $ownBounds — retention belongs to RetentionPolicyEngine',
          );
        }
      },
    );

    test(
      'KnowledgeRepository never owns retention — it reports facts and is told what to drop (IS-R50)',
      () {
        final repo = libFiles.firstWhere(
          (f) => f.path == 'lib/storage/knowledge_repository.dart',
        );
        expect(
          repo.code.contains('RetentionPolicyEngine'),
          isFalse,
          reason:
              'the repository must not evaluate policy; KnowledgeCache asks the engine and tells the repository what to remove',
        );
        expect(repo.code.contains('LifecycleDomain'), isFalse);
        expect(
          repo.code.contains('keySummaries'),
          isTrue,
          reason:
              'it must still be able to REPORT the facts retention is decided from',
        );
      },
    );

    test(
      'exactly ONE governance engine exists, and it is disjoint from the other two policy engines (IS-R51 Task 11)',
      () {
        // THREE policy engines, THREE disjoint domains:
        //   WorkspaceLifecyclePolicyEngine  -> runtime lifecycle  (R39)
        //   RetentionPolicyEngine           -> data retention     (R50)
        //   OperatingSystemGovernanceEngine -> system governance  (R51)
        // A FOURTH would be a parallel governance/policy manager.
        final engines =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(\w*(?:Retention|Lifecycle|Governance)\w*Engine)\b',
                  ).allMatches(f.code).map((m) => '${f.path}:${m.group(1)}'),
                )
                .toList()
              ..sort();
        expect(
          engines,
          [
            'lib/app/governance_engine.dart:OperatingSystemGovernanceEngine',
            'lib/app/retention_policy_engine.dart:RetentionPolicyEngine',
            'lib/app/workspace_lifecycle_policy_engine.dart:WorkspaceLifecyclePolicyEngine',
          ],
          reason: 'A parallel governance/policy engine appeared: $engines',
        );

        // Governance must not reach into the other two domains' vocabularies.
        final governance = libFiles.firstWhere(
          (f) => f.path == 'lib/app/governance_engine.dart',
        );
        for (final foreign in [
          'RetentionClass',
          'LifecycleCandidate',
          'RetentionPolicyEngine',
          'RuntimePolicyAction',
          'ExperienceRuntimeController',
          'AppLifecycleState',
          'AnythingKernel',
          'CapabilityPlatform',
        ]) {
          expect(
            governance.code.contains(foreign),
            isFalse,
            reason:
                'governance must own POLICY only; referencing $foreign would make it a second owner of that subsystem',
          );
        }
        // And they must not reach into governance.
        for (final path in [
          'lib/app/retention_policy_engine.dart',
          'lib/app/workspace_lifecycle_policy_engine.dart',
        ]) {
          final file = libFiles.firstWhere((f) => f.path == path);
          for (final governanceConcept in [
            'GovernanceDomain',
            'GovernanceDecision',
            'ExperienceTrustLevel',
          ]) {
            expect(
              file.code.contains(governanceConcept),
              isFalse,
              reason: '$path must not absorb governance ($governanceConcept)',
            );
          }
        }
      },
    );

    test(
      'the governance engine DECIDES but never ENFORCES — no I/O, no storage, no Timer, no capability execution (IS-R51)',
      () {
        final governance = libFiles.firstWhere(
          (f) => f.path == 'lib/app/governance_engine.dart',
        );
        for (final forbidden in [
          'sqflite',
          'Database',
          'SharedPreferences',
          'dart:io',
          'File(',
          'Directory(',
          'Timer',
          'http.',
          'ModelProvider',
        ]) {
          expect(
            governance.code.contains(forbidden),
            isFalse,
            reason:
                'governance must stay pure; $forbidden would give it enforcement power it must not have',
          );
        }
        expect(governance.raw.contains("import 'dart:io'"), isFalse);
        // Its only imports should be none at all — it is a pure policy library.
        final imports = RegExp(
          r'''^import\s+['"]([^'"]+)''',
          multiLine: true,
        ).allMatches(governance.raw).map((m) => m.group(1)!).toList();
        expect(
          imports,
          isEmpty,
          reason:
              'the governance engine imports nothing: a policy that depends on a subsystem is not a policy. Found: $imports',
        );
      },
    );

    test(
      'exactly ONE trust model exists — no duplicate trust or permission framework (IS-R51 Task 11)',
      () {
        // TWO enums in lib/ carry "Trust" in their name, and they are NOT
        // duplicates — they grade different subjects:
        //
        //   ExperienceTrustLevel (R51)  how much authority an EXPERIENCE has.
        //                               Governs capability access.
        //   TrustLevel (knowledge)      how reliable a RETRIEVED WEB SOURCE is
        //                               (official/community/unknown...). Feeds
        //                               ranking, never authority.
        //
        // Collapsing them would be worse than leaving them separate: an
        // Experience's privileges and a web page's credibility are not the same
        // scale, and one enum serving both would inevitably be misapplied.
        // Pinned explicitly so the distinction is visible in CI rather than
        // rediscovered, and so a genuinely duplicate EXPERIENCE trust model
        // still fails.
        final trustModels =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\benum\s+(\w*Trust\w*)\b',
                  ).allMatches(f.code).map((m) => '${f.path}:${m.group(1)}'),
                )
                .toList()
              ..sort();
        expect(trustModels, [
          'lib/app/governance_engine.dart:ExperienceTrustLevel',
          'lib/knowledge/knowledge_resource.dart:TrustLevel',
        ], reason: 'a second trust model appeared: $trustModels');

        // No parallel permission manager.
        final permissionManagers =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(\w*Permission\w*(?:Manager|Engine|Service)|\w*Authorization\w*)\b',
                  ).allMatches(f.code).map((m) => '${f.path}:${m.group(1)}'),
                )
                .toList()
              ..sort();
        expect(
          permissionManagers,
          isEmpty,
          reason:
              'a duplicate permission/authorization framework appeared: $permissionManagers',
        );
      },
    );

    test(
      'the Kernel and the repositories never own governance (IS-R51 Task 11/12)',
      () {
        // Governance is policy; the Kernel is reasoning; repositories are
        // storage. None of them may evaluate governance.
        const mustNotGovern = [
          'lib/kernel/anything_kernel.dart',
          'lib/storage/knowledge_repository.dart',
          'lib/storage/intent_repository.dart',
          'lib/storage/activity_repository.dart',
          'lib/storage/sqlite_experience_repository.dart',
        ];
        for (final path in mustNotGovern) {
          final file = libFiles.firstWhere((f) => f.path == path);
          for (final concept in [
            'OperatingSystemGovernanceEngine',
            'GovernanceDecision',
            'GovernanceDomain',
            'ExperienceTrustLevel',
          ]) {
            expect(
              file.code.contains(concept),
              isFalse,
              reason: '$path must not own or evaluate governance ($concept)',
            );
          }
        }
      },
    );

    test(
      'exactly ONE trust classifier and ONE provenance model exist (IS-R52 Task 11)',
      () {
        final classifiers =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(\w*Trust\w*Classifier|\w*Provenance\w*Engine)\b',
                  ).allMatches(f.code).map((m) => '${f.path}:${m.group(1)}'),
                )
                .toList()
              ..sort();
        expect(
          classifiers,
          ['lib/app/experience_provenance.dart:ExperienceTrustClassifier'],
          reason:
              'a duplicate trust classifier or provenance engine appeared: $classifiers',
        );

        // FOUR types carry "Provenance", and they are NOT duplicates — each
        // records the origin of a different subject:
        //
        //   ExperienceProvenance (R52)  where an EXPERIENCE came from -> trust
        //   PackageProvenance           how a PACKAGE was generated
        //                               (engine/spec version)
        //   ResourceProvenance          where a KNOWLEDGE RESOURCE was fetched
        //   SoftwareProvenance          how a SOFTWARE ANALYSIS was produced
        //
        // Only the first feeds trust classification. Collapsing them would be
        // worse than leaving them separate — a package's build metadata and an
        // Experience's origin are not the same fact. Pinned explicitly so the
        // distinction is visible in CI while a genuine duplicate EXPERIENCE
        // provenance model still fails, exactly as I-50 handles the two
        // TrustLevels.
        final provenanceModels =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(\w*Provenance\w*)\b',
                  ).allMatches(f.code).map((m) => '${f.path}:${m.group(1)}'),
                )
                .toList()
              ..sort();
        expect(
          provenanceModels,
          [
            'lib/app/experience_provenance.dart:ExperienceProvenance',
            'lib/creation/experience_package.dart:PackageProvenance',
            'lib/knowledge/knowledge_resource.dart:ResourceProvenance',
            'lib/software_cognition/software_provenance.dart:SoftwareProvenance',
          ],
          reason: 'a second provenance model appeared: $provenanceModels',
        );
      },
    );

    test(
      'GOVERNANCE NEVER COMPUTES TRUST — it consumes what the classifier produced (IS-R52 Task 11)',
      () {
        // The load-bearing separation of this milestone. If governance could
        // classify, "governance consumes trust" would collapse into "governance
        // decides everything" and R51's clean split would be gone.
        final governance = libFiles.firstWhere(
          (f) => f.path == 'lib/app/governance_engine.dart',
        );
        for (final concept in [
          'ExperienceTrustClassifier',
          'ExperienceProvenance',
          'ExperienceOrigin',
          'VerificationState',
          'classify',
        ]) {
          expect(
            governance.code.contains(concept),
            isFalse,
            reason:
                'the governance engine must not compute trust ($concept) — it consumes ExperienceTrustLevel only',
          );
        }
        // R51's I-49 must still hold: governance imports nothing at all.
        final imports = RegExp(
          r'''^import\s+['"]([^'"]+)''',
          multiLine: true,
        ).allMatches(governance.raw).map((m) => m.group(1)!).toList();
        expect(
          imports,
          isEmpty,
          reason:
              'R52 must not have given governance a dependency. Found: $imports',
        );
      },
    );

    test(
      'THE CLASSIFIER NEVER ENFORCES POLICY — it computes a level and nothing else (IS-R52 Task 11)',
      () {
        final classifier = libFiles.firstWhere(
          (f) => f.path == 'lib/app/experience_provenance.dart',
        );
        for (final forbidden in [
          'CapabilityPlatform',
          'CapabilityInvocationResult',
          'GovernanceDecision',
          'GovernanceEvaluation',
          'GovernanceRule',
          'sqflite',
          'Database',
          'SharedPreferences',
          'dart:io',
          'Timer',
        ]) {
          expect(
            classifier.code.contains(forbidden),
            isFalse,
            reason:
                'the classifier must not enforce, decide or store ($forbidden) — it computes trust only',
          );
        }
        // Its ONLY dependency is the governance vocabulary, one-way.
        final imports = RegExp(
          r'''^import\s+['"]([^'"]+)''',
          multiLine: true,
        ).allMatches(classifier.raw).map((m) => m.group(1)!).toList();
        expect(
          imports,
          ['governance_engine.dart'],
          reason:
              'the classifier depends on the trust VOCABULARY only. Found: $imports',
        );
      },
    );

    test(
      'the ExperienceRepository STORES provenance and never computes trust from it (IS-R52 Task 11)',
      () {
        final repo = libFiles.firstWhere(
          (f) => f.path == 'lib/storage/sqlite_experience_repository.dart',
        );
        expect(
          repo.code.contains('ExperienceProvenance'),
          isTrue,
          reason: 'it must be able to STORE provenance',
        );
        for (final concept in [
          'ExperienceTrustClassifier',
          'ExperienceTrustLevel',
          'classify(',
        ]) {
          expect(
            repo.code.contains(concept),
            isFalse,
            reason:
                'the repository must remain storage only; computing trust ($concept) would make it a second classifier',
          );
        }
      },
    );

    test(
      'the two "identity" libraries remain distinct subjects, both pinned (IS-R52)',
      () {
        // lib/experience_identity/ (R22) owns ScreenIdentity/ActionIdentity —
        // identity of screens and actions INSIDE an Experience, for compiler
        // equivalence comparison. lib/app/experience_provenance.dart (R52) owns
        // ExperienceIdentity — the identity of an Experience ITSELF. Different
        // subjects sharing a word; pinned so the near-collision is visible
        // rather than rediscovered, exactly as I-50 handles the two TrustLevels.
        final identityTypes =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(\w*Identity)\b',
                  ).allMatches(f.code).map((m) => '${f.path}:${m.group(1)}'),
                )
                .toList()
              ..sort();
        // SIX identity types, each identifying a different KIND of thing:
        //   ExperienceIdentity (R52)   an Experience itself      -> provenance
        //   Screen/ActionIdentity(R22) parts INSIDE an Experience -> compiler
        //                              equivalence comparison
        //   Entity/RelationshipIdentity world-model graph nodes
        //   SoftwareIdentity           analysed software
        // Only the first participates in trust. Pinned so the near-collision is
        // visible rather than rediscovered, while a genuine parallel EXPERIENCE
        // identity framework still fails.
        expect(
          identityTypes,
          [
            'lib/app/experience_provenance.dart:ExperienceIdentity',
            'lib/experience_identity/experience_identity.dart:ActionIdentity',
            'lib/experience_identity/experience_identity.dart:ScreenIdentity',
            'lib/software_cognition/software_identity.dart:SoftwareIdentity',
            'lib/world_model/entity_identity.dart:EntityIdentity',
            'lib/world_model/relationship_identity.dart:RelationshipIdentity',
          ],
          reason: 'a parallel identity framework appeared: $identityTypes',
        );
      },
    );

    test(
      'exactly ONE distribution framework and ONE package verifier exist (IS-R53 Task 11)',
      () {
        final movers =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(\w*(?:Distribution|Import|Export|Install)\w*(?:Framework|Engine|Pipeline|Manager|Service)|\w*Package\w*Verifier)\b',
                  ).allMatches(f.code).map((m) => '${f.path}:${m.group(1)}'),
                )
                .toList()
              ..sort();
        expect(
          movers,
          [
            // IS-R54 added the third entry. This invariant's pattern has always
            // included `Install`, so the new framework tripped it on its first run
            // — which is the invariant working, not a false positive. The set is
            // widened deliberately with the reason recorded, never by narrowing
            // the regex until it passes: a fourth mover must still fail here.
            'lib/app/experience_distribution.dart:ExperienceDistributionFramework',
            'lib/app/experience_distribution.dart:ExperiencePackageVerifier',
            'lib/app/experience_installation.dart:ExperienceInstallationFramework',
          ],
          reason:
              'a duplicate importer/exporter/installer/verifier appeared: $movers',
        );
      },
    );

    test(
      'DISTRIBUTION never computes trust, enforces governance or activates a runtime (IS-R53 Task 11)',
      () {
        final distribution = libFiles.firstWhere(
          (f) => f.path == 'lib/app/experience_distribution.dart',
        );
        for (final forbidden in [
          // Trust classification belongs to R52.
          'ExperienceTrustClassifier', 'ExperienceTrustLevel', 'classify(',
          // Policy belongs to R51.
          'OperatingSystemGovernanceEngine',
          'GovernanceDecision',
          'GovernanceEvaluation',
          // Activation belongs to R45.
          'ExperienceEntryPipeline', 'ExperienceHostScreen', 'Navigator',
          // Protection belongs to ExperienceProtectionService.
          'ExperienceProtectionService', 'KaalkaService',
        ]) {
          expect(
            distribution.code.contains(forbidden),
            isFalse,
            reason:
                'distribution moves experiences only; referencing $forbidden would make it a second owner of that subsystem',
          );
        }
      },
    );

    test(
      'the VERIFIER delegates structural validation and never computes trust (IS-R53 Task 6/11)',
      () {
        final distribution = libFiles.firstWhere(
          (f) => f.path == 'lib/app/experience_distribution.dart',
        );
        // It must DELEGATE to the pre-existing validator rather than
        // re-implementing one — the "no second verifier" rule in practice.
        expect(
          distribution.code.contains('ExperiencePackageValidator.validate'),
          isTrue,
          reason:
              'structural validation must be delegated to the canonical validator, never re-implemented',
        );
        // And a valid package must not be able to earn authority by being valid.
        expect(distribution.code.contains('ExperienceTrustLevel'), isFalse);
      },
    );

    test(
      'the distribution manifest EMBEDS the canonical ExperienceManifest rather than re-declaring it (IS-R53 Task 3)',
      () {
        // "Exactly one Experience Manifest" made mechanical: there must still be
        // exactly one class named ExperienceManifest in lib/, and the transport
        // envelope must hold a field OF that type rather than copying its
        // fields into a parallel record.
        final manifests =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(ExperienceManifest)\b',
                  ).allMatches(f.code).map((m) => '${f.path}:${m.group(1)}'),
                )
                .toList()
              ..sort();
        expect(manifests, [
          'lib/creation/experience_package.dart:ExperienceManifest',
        ], reason: 'a second Experience manifest appeared: $manifests');

        final distribution = libFiles.firstWhere(
          (f) => f.path == 'lib/app/experience_distribution.dart',
        );
        expect(
          RegExp(
            r'final\s+ExperienceManifest\s+manifest;',
          ).hasMatch(distribution.code),
          isTrue,
          reason:
              'the envelope must CARRY the canonical manifest, not duplicate its fields',
        );
      },
    );

    // ── IS-R54 — INSTALLATION OWNERSHIP (I-61 … I-67) ────────────────────
    //
    // The installer is the most dangerous kind of component in this system: it
    // is the last thing to touch a package before it becomes real, so every
    // other subsystem is one convenience call away from being absorbed into
    // it. These seven invariants exist to keep that from happening quietly.

    test(
      'exactly ONE installation framework, ONE compatibility evaluator and ONE dependency planner exist (IS-R54 Task 10)',
      () {
        final installers =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(\w*Install\w*(?:Framework|Engine|Pipeline|Manager|Service|Coordinator))\b',
                  ).allMatches(f.code).map((m) => '${f.path}:${m.group(1)}'),
                )
                .toList()
              ..sort();
        expect(installers, [
          'lib/app/experience_installation.dart:ExperienceInstallationFramework',
        ], reason: 'a second installer/updater appeared: $installers');

        // COMPATIBILITY. `CompatibilityCheck` is pinned rather than excluded:
        // it is a cross-artifact invariant record in the compiler/artifact
        // pipeline, a genuinely different domain from Experience installability.
        // Pinning keeps the distinction deliberate and still fails on a second
        // EXPERIENCE compatibility engine.
        final compat =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(\w*Compatibility\w*)\b',
                  ).allMatches(f.code).map((m) => '${f.path}:${m.group(1)}'),
                )
                .toList()
              ..sort();
        expect(compat, [
          'lib/app/experience_installation.dart:CompatibilityEvaluation',
          'lib/app/experience_installation.dart:CompatibilityFinding',
          'lib/app/experience_installation.dart:ExperienceCompatibilityEvaluator',
          'lib/artifact_intelligence/artifact_intelligence.dart:CompatibilityCheck',
        ], reason: 'a second compatibility engine appeared: $compat');

        // DEPENDENCIES. The eight pre-existing types expand a FEATURE CANDIDATE
        // into capability/permission/storage/navigation primitives during
        // design, or analyse the world graph. The planner added here plans
        // EXPERIENCE-TO-EXPERIENCE package dependencies at install time.
        // Different inputs, outputs and lifecycle stage — pinned, with the
        // reason recorded, so the distinction survives review.
        final planners =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(\w*Depend\w*(?:Planner|Resolver|Analyzer|Builder|Engine))\b',
                  ).allMatches(f.code).map((m) => '${f.path}:${m.group(1)}'),
                )
                .toList()
              ..sort();
        expect(planners, [
          'lib/app/experience_installation.dart:ExperienceDependencyPlanner',
          'lib/feature_discovery/dependency_resolver.dart:CapabilityDependencyResolver',
          'lib/feature_discovery/dependency_resolver.dart:DependencyGraphBuilder',
          'lib/feature_discovery/dependency_resolver.dart:DependencyResolver',
          'lib/feature_discovery/dependency_resolver.dart:NavigationDependencyResolver',
          'lib/feature_discovery/dependency_resolver.dart:OfflineDependencyResolver',
          'lib/feature_discovery/dependency_resolver.dart:PermissionDependencyResolver',
          'lib/feature_discovery/dependency_resolver.dart:StorageDependencyResolver',
          'lib/world_model/dependency_analyzer.dart:DependencyAnalyzer',
        ], reason: 'a second dependency planner appeared: $planners');
      },
    );

    test(
      'the INSTALLER never computes trust, enforces governance or performs distribution (IS-R54 Task 10)',
      () {
        final installer = libFiles.firstWhere(
          (f) => f.path == 'lib/app/experience_installation.dart',
        );
        for (final forbidden in [
          // Trust belongs to R52.
          'ExperienceTrustClassifier', 'ExperienceTrustLevel', 'classify(',
          // Policy belongs to R51.
          'OperatingSystemGovernanceEngine',
          'GovernanceDecision',
          'GovernanceEvaluation',
          // Movement belongs to R53. The installer must not become a second
          // importer just because it already holds the package.
          'ExperienceDistributionFramework',
          'DistributionSource',
          'ExperienceDistributionPackage',
          // Enforcement belongs to R49/R51.
          'CapabilityPlatform',
        ]) {
          expect(
            installer.code.contains(forbidden),
            isFalse,
            reason:
                'the installer commits only; referencing $forbidden would make it a second owner of that subsystem',
          );
        }
      },
    );

    test(
      'the EVALUATOR and the PLANNER are pure — they evaluate and plan, they cannot install (IS-R54 Tasks 3/4)',
      () {
        final installer = libFiles.firstWhere(
          (f) => f.path == 'lib/app/experience_installation.dart',
        );

        // Both are declared in the same file as the framework, so a field-level
        // check is what proves purity: neither may hold a repository, a
        // protection service or a transaction.
        for (final pure in [
          'ExperienceCompatibilityEvaluator',
          'ExperienceDependencyPlanner',
        ]) {
          final body = _classBody(installer.code, pure);
          expect(
            body,
            isNotEmpty,
            reason: '$pure must exist to be certified pure',
          );
          for (final forbidden in [
            'SqliteExperienceRepository',
            'ExperienceProtectionService',
            'InstallationTransaction',
            'savePackage',
            'saveMetadata',
          ]) {
            expect(
              body.contains(forbidden),
              isFalse,
              reason:
                  '$pure must only evaluate/plan; holding or calling $forbidden would let it install',
            );
          }
        }
      },
    );

    test(
      'INSTALL NEVER ACTIVATES — the installer may not name the activation layer at all (IS-R54 Task 9)',
      () {
        final installer = libFiles.firstWhere(
          (f) => f.path == 'lib/app/experience_installation.dart',
        );
        for (final forbidden in [
          'ExperienceEntryPipeline',
          'ExperienceHostScreen',
          'ExperienceActivationManager',
          'Navigator',
          'AnythingRuntime',
          'ExperienceRenderer',
        ]) {
          expect(
            installer.code.contains(forbidden),
            isFalse,
            reason:
                'installing something must not run it; referencing $forbidden would make install an activation path',
          );
        }
      },
    );

    test(
      'the INSTALLER REQUESTS protection and never performs it (IS-R54 Task 7)',
      () {
        final installer = libFiles.firstWhere(
          (f) => f.path == 'lib/app/experience_installation.dart',
        );

        // Task 7 explicitly wires the protection SERVICE into the installer, so
        // this is not a "must not reference" rule like the others — it is a
        // "must not reach past it" rule. The installer asks; Kaalka performs.
        expect(
          installer.code.contains('ExperienceProtectionService'),
          isTrue,
          reason:
              'Task 7 requires the installer to be able to REQUEST protection after a commit',
        );
        for (final forbidden in [
          'KaalkaService',
          'ProtectionProvider',
          'TimeSeed',
          'encrypt(',
          'decrypt(',
        ]) {
          expect(
            installer.code.contains(forbidden),
            isFalse,
            reason:
                'the installer requests protection; touching $forbidden would open a second crypto path',
          );
        }
      },
    );

    test(
      'the TRANSACTION delegates structural validation to the canonical validator (IS-R54 Task 5)',
      () {
        final installer = libFiles.firstWhere(
          (f) => f.path == 'lib/app/experience_installation.dart',
        );
        expect(
          installer.code.contains('ExperiencePackageValidator.validate'),
          isTrue,
          reason:
              'structural validation must be delegated, never re-implemented — the "no second verifier" rule at the install layer',
        );
      },
    );

    test(
      'NO SECOND MIGRATION ENGINE — the installer records requirements and executes none (IS-R54 Task 6)',
      () {
        final engines =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(\w*Migrat\w*(?:Engine|Executor|Runner|Service|Manager))\b',
                  ).allMatches(f.code).map((m) => '${f.path}:${m.group(1)}'),
                )
                .toList()
              ..sort();
        expect(
          engines,
          ['lib/storage/migration_executor.dart:MigrationExecutor'],
          reason:
              'the canonical migration engine already existed; a second one appeared: $engines',
        );

        // And the installer must not execute one. `MigrationRequirement` records
        // that a boundary was crossed; running operations is MigrationExecutor's
        // job and nothing else's.
        final installer = libFiles.firstWhere(
          (f) => f.path == 'lib/app/experience_installation.dart',
        );
        for (final forbidden in [
          'MigrationExecutor',
          'DataMigrationPlan',
          'MigrationOperation',
          'ALTER TABLE',
        ]) {
          expect(
            installer.code.contains(forbidden),
            isFalse,
            reason:
                'the installer prepares migrations; executing $forbidden would make it a second migration engine',
          );
        }
      },
    );

    test(
      'DISTRIBUTION NEVER COMMITS — the commit moved to the installer (IS-R54 Task 8)',
      () {
        // R53 wrote both repository rows from the distribution framework. R54
        // took that back. This is the invariant that keeps it taken: distribution
        // MOVES, the installer COMMITS, the repository STORES.
        final distribution = libFiles.firstWhere(
          (f) => f.path == 'lib/app/experience_distribution.dart',
        );
        for (final forbidden in [
          'savePackage',
          'saveMetadata',
          'repository.delete',
        ]) {
          expect(
            distribution.code.contains(forbidden),
            isFalse,
            reason:
                'distribution moves experiences; calling $forbidden would restore the second commit path R54 removed',
          );
        }
        expect(
          distribution.code.contains('ExperienceInstallationFramework'),
          isTrue,
          reason: 'distribution must commit THROUGH the one installer',
        );
      },
    );

    // ── IS-R55 — COMMIT OWNERSHIP (I-68 … I-74) ──────────────────────────
    //
    // R54 closed one of five commit paths and recorded the rest as gap G-30,
    // severity A. These invariants are what closing G-30 actually means: not
    // "a commit framework exists" but "nothing else can write".

    test(
      'exactly ONE commit framework and ONE transaction coordinator exist (IS-R55 Task 10)',
      () {
        final committers =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(\w*Commit\w*(?:Framework|Engine|Coordinator|Manager|Service)|\w*Transaction\w*Coordinator)\b',
                  ).allMatches(f.code).map((m) => '${f.path}:${m.group(1)}'),
                )
                .toList()
              ..sort();
        expect(
          committers,
          [
            'lib/app/experience_commit.dart:ExperienceCommitFramework',
            'lib/app/experience_commit.dart:RepositoryTransactionCoordinator',
          ],
          reason:
              'a second commit framework or transaction coordinator appeared: $committers',
        );
      },
    );

    test(
      'NOBODY OUTSIDE THE COMMIT FRAMEWORK WRITES TO THE EXPERIENCE REPOSITORY — G-30 (IS-R55 Task 10)',
      () {
        // THE invariant of this milestone. Before R55 there were six writers:
        // creation, modification (x3, including its rollback), evolution,
        // protection (x3), installation, and — found by the R55 audit, not on
        // R54's list — a UI screen calling delete() directly.
        //
        // `touchLastUsed` is DELIBERATELY EXCLUDED and pinned here rather than
        // silently omitted. It stamps an access time on an existing row: it
        // persists no package, no metadata record and no state any rollback
        // could need to restore. Routing four call sites through a commit
        // framework to bump a timestamp would add ownership ceremony with no
        // ownership benefit. Recorded as G-34 so the exclusion is reviewable.
        const writeMethods = [
          'savePackage',
          'saveMetadata',
          'deletePackage',
          'saveProtectedEnvelope',
          'deleteProtectedEnvelope',
          'updateProtectionState',
        ];
        final offenders = <String>[];
        for (final f in libFiles) {
          if (f.path == 'lib/app/experience_commit.dart') continue;
          if (f.path == 'lib/storage/sqlite_experience_repository.dart') {
            continue;
          }
          for (final method in writeMethods) {
            for (final m in RegExp(
              '\\.\\s*$method\\s*\\(',
            ).allMatches(f.code)) {
              offenders.add('${f.path}:$method@${m.start}');
            }
          }
          // `delete(` is too common a word to scan bare, so this targets a
          // delete called on something named like the Experience repository.
          for (final m in RegExp(
            r'\b_?repo(?:sitory)?\s*\.\s*delete\s*\(',
          ).allMatches(f.code)) {
            offenders.add('${f.path}:delete@${m.start}');
          }
        }
        expect(
          offenders,
          isEmpty,
          reason:
              'gap G-30 reopened — these write Experience state without going through the ONE commit owner: $offenders',
        );
      },
    );

    test(
      'EVERY write inside the commit framework runs in a transaction (IS-R55 Task 7)',
      () {
        // Task 7's whole justification. A write that forgot `using:` would
        // silently fall back to the raw database and reopen G-28's crash window
        // for that path only — the hardest kind of regression to notice, because
        // everything would still pass.
        final commit = libFiles.firstWhere(
          (f) => f.path == 'lib/app/experience_commit.dart',
        );
        final writes = RegExp(
          r'repository\.\s*(savePackage|saveMetadata|deletePackage|delete|saveProtectedEnvelope|deleteProtectedEnvelope|updateProtectionState)\s*\(([^;]*)\)',
        ).allMatches(commit.code).toList();
        expect(
          writes.length,
          greaterThanOrEqualTo(7),
          reason:
              'the write scan found ${writes.length} sites — if this collapsed, the check below is vacuous',
        );
        for (final w in writes) {
          expect(
            w.group(2),
            contains('using:'),
            reason:
                'commit-framework write "${w.group(1)}" does not pass a transaction executor; '
                'it would fall back to the raw database and reopen G-28 for that path',
          );
        }
        expect(
          commit.code.contains('db.transaction'),
          isTrue,
          reason:
              'the transaction coordinator must use sqflite\'s own transaction, not a hand-rolled one',
        );
      },
    );

    test(
      'the COMMIT FRAMEWORK persists and does nothing else (IS-R55 Task 10)',
      () {
        final commit = libFiles.firstWhere(
          (f) => f.path == 'lib/app/experience_commit.dart',
        );
        for (final forbidden in [
          // It never creates, installs, moves or changes an Experience.
          'CreationEngine',
          'ExperienceInstallationFramework',
          'ExperienceDistributionFramework',
          'ModificationEngine', 'EvolutionExecutor',
          // It never decides anything about an Experience.
          'ExperienceTrustClassifier', 'ExperienceTrustLevel',
          'OperatingSystemGovernanceEngine', 'GovernanceEvaluation',
          'ExperienceCompatibilityEvaluator', 'ExperienceDependencyPlanner',
          'CapabilityPlatform',
          // It never encrypts and never migrates.
          'KaalkaService', 'ProtectionProvider', 'ExperienceProtectionService',
          'encrypt(', 'decrypt(', 'MigrationExecutor', 'ALTER TABLE',
          // It never activates or navigates.
          'ExperienceEntryPipeline',
          'ExperienceHostScreen',
          'Navigator',
          'AnythingRuntime',
        ]) {
          expect(
            commit.code.contains(forbidden),
            isFalse,
            reason:
                'the commit framework persists finished state; referencing $forbidden would make it a second owner of that subsystem',
          );
        }
      },
    );

    test(
      'EXACTLY ONE ROLLBACK OWNER — every other rollback delegates (IS-R55 Task 9)',
      () {
        // There are four `rollback` methods in lib/, and that is correct: three
        // are façades in their own vocabulary (installation result, modification
        // result, transaction state). What makes ONE owner true is that only the
        // commit framework can write — so only it can actually restore anything.
        //
        // This asserts the façades really do reach it, rather than relying on
        // I-70 alone to prove they cannot write.
        final rollbackFiles =
            libFiles
                .where(
                  (f) => RegExp(
                    r'\b(Future<[^>]*>|void)\s+rollback\w*\s*\(',
                  ).hasMatch(f.code),
                )
                .map((f) => f.path)
                .toList()
              ..sort();
        expect(
          rollbackFiles,
          [
            'lib/app/experience_commit.dart',
            'lib/app/experience_installation.dart',
            'lib/app/experience_modification_coordinator.dart',
          ],
          reason: 'a rollback appeared somewhere new: $rollbackFiles',
        );

        for (final path in [
          'lib/app/experience_installation.dart',
          'lib/app/experience_modification_coordinator.dart',
        ]) {
          final f = libFiles.firstWhere((f) => f.path == path);
          expect(
            RegExp(
              r'(_?commits|commitFramework)\s*\.\s*(rollback|commit)\s*\(',
            ).hasMatch(f.code),
            isTrue,
            reason:
                '$path declares a rollback that must terminate inside the ONE commit owner',
          );
        }
      },
    );

    test(
      'EXACTLY ONE REPAIR OWNER — the installer requests, the framework coordinates (IS-R55 Task 8)',
      () {
        final repairFiles =
            libFiles
                .where(
                  (f) =>
                      RegExp(r'\bFuture<[^>]*>\s+repair\s*\(').hasMatch(f.code),
                )
                .map((f) => f.path)
                .toList()
              ..sort();
        expect(repairFiles, [
          'lib/app/experience_commit.dart',
          'lib/app/experience_installation.dart',
        ], reason: 'a repair appeared somewhere new: $repairFiles');

        final installer = libFiles.firstWhere(
          (f) => f.path == 'lib/app/experience_installation.dart',
        );
        expect(
          RegExp(r'commits\s*\.\s*repair\s*\(').hasMatch(installer.code),
          isTrue,
          reason: 'the installer must REQUEST repair, not perform it',
        );
      },
    );

    test(
      'the REPOSITORY still stores only — it does not know the commit framework exists (IS-R55)',
      () {
        // The dependency must run one way. A repository that reached back into
        // the commit framework would make the ownership circular and let a
        // future write re-enter through the bottom.
        final repo = libFiles.firstWhere(
          (f) => f.path == 'lib/storage/sqlite_experience_repository.dart',
        );
        for (final forbidden in [
          'ExperienceCommitFramework',
          'RepositoryTransactionCoordinator',
          'CommitResult',
          'CommitOrigin',
        ]) {
          expect(
            repo.code.contains(forbidden),
            isFalse,
            reason:
                'the repository stores; referencing $forbidden would invert the ownership R55 established',
          );
        }
        // It accepts an executor but must never open a transaction itself —
        // that is the coordinator's single job.
        expect(
          repo.code.contains('.transaction('),
          isFalse,
          reason:
              'transaction control belongs to RepositoryTransactionCoordinator, not the repository',
        );
      },
    );

    // ── IS-R56 — DURABLE COLLECTION OWNERSHIP (I-75 … I-77) ──────────────
    //
    // Derived from a MEASURED defect, not an anticipated one. Three
    // repositories each implemented read-the-whole-list / mutate / write-the-
    // whole-list with awaits in between and nothing serialising them. A probe
    // recorded ten concurrent schedules landing as ONE, and one due
    // notification being presented TWICE.

    test(
      'exactly ONE durable collection store, and nothing else touches SharedPreferences for a collection (IS-R56)',
      () {
        final stores =
            libFiles
                .expand(
                  (f) => RegExp(
                    r'\bclass\s+(\w*Durable\w*|\w*CollectionStore\w*)\b',
                  ).allMatches(f.code).map((m) => '${f.path}:${m.group(1)}'),
                )
                .toList()
              ..sort();
        expect(stores, [
          'lib/storage/durable_collection_store.dart:DurableCollectionStore',
        ], reason: 'a second durable-collection owner appeared: $stores');

        // Import scan runs on RAW source — import URIs are string literals and
        // do not survive stripping. (The R46 lesson: both boundary scans once
        // reported ZERO sites because they ran on stripped source.)
        final users =
            libFiles
                .where(
                  (f) => RegExp(
                    r'''import\s+['"]package:shared_preferences''',
                  ).hasMatch(f.raw),
                )
                .map((f) => f.path)
                .toList()
              ..sort();
        expect(
          users,
          [
            // THE owner.
            'lib/storage/durable_collection_store.dart',
            // PINNED, not overlooked: the theme provider stores ONE scalar key
            // (the selected theme mode). It performs no read-modify-write, holds
            // no collection, and has nothing to serialise — routing it through a
            // collection store would be ceremony. Recorded as G-39.
            'lib/design_system/theme/theme_provider.dart',
          ]..sort(),
          reason: 'a new direct SharedPreferences user appeared: $users',
        );
        expect(
          users,
          isNotEmpty,
          reason: 'the raw import scan must actually match something',
        );
      },
    );

    test('every durable COLLECTION mutates through the ONE store (IS-R56)', () {
      // The three that were duplicating the pattern must now delegate, and
      // must not have kept a private write path.
      for (final path in [
        'lib/storage/activity_repository.dart',
        'lib/storage/intent_repository.dart',
        'lib/capabilities/adapters/notification_service_adapter.dart',
      ]) {
        final f = libFiles.firstWhere((f) => f.path == path);
        expect(
          f.code.contains('DurableCollectionStore'),
          isTrue,
          reason: '$path must mutate through the ONE store',
        );
        for (final forbidden in [
          'SharedPreferences',
          'prefs.setString',
          'prefs.remove',
        ]) {
          expect(
            f.code.contains(forbidden),
            isFalse,
            reason:
                '$path must not reach past the store to $forbidden — that is the unserialised path R56 removed',
          );
        }
      }
    });

    test(
      'deliverDue CLAIMS before it PRESENTS — the ordering that makes exactly-once possible (IS-R56)',
      () {
        // The subtlest property in the milestone. Presenting first and
        // persisting after is what let a second concurrent caller re-read the
        // same due set and deliver it again. Code that still compiles, still
        // passes every single-threaded test, and silently double-delivers.
        final f = libFiles.firstWhere(
          (f) =>
              f.path ==
              'lib/capabilities/adapters/notification_service_adapter.dart',
        );
        final body = _classBody(f.code, 'RealNotificationService');
        expect(body, isNotEmpty);

        final presentIndex = body.indexOf('_presenter.present');
        expect(
          presentIndex,
          greaterThanOrEqualTo(0),
          reason: 'presentation must still happen',
        );
        expect(
          body.contains('store.update'),
          isTrue,
          reason: 'the due set must be claimed through the store',
        );

        // MECHANISM NOTE — this check was WRONG on its first attempt, and the
        // mutation probe is what found it.
        //
        // The first version asserted `indexOf(present) > lastIndexOf(update)`.
        // That passes trivially when presentation is moved INSIDE the mutation
        // callback, because the callback's text begins after `store.update(`
        // starts. It was a false negative: green, and checking nothing.
        //
        // The real property is containment, not ordering. Presentation must lie
        // OUTSIDE every `store.update(...)` argument list, so it cannot run
        // while the claim is still uncommitted.
        for (final range in _callRanges(body, 'store.update')) {
          expect(
            presentIndex >= range.$1 && presentIndex < range.$2,
            isFalse,
            reason:
                'present() must run AFTER the claim commits, never inside the mutation that claims — '
                'presenting from inside the critical section is the R49 double-delivery defect',
          );
        }
      },
    );

    // ── IS-R57 — REPOSITORY COMPOSITION OWNERSHIP (I-78 … I-80) ──────────
    //
    // R56's audit found ActivityRepository was the ONE repository with no
    // composition owner: nine construction sites, absent from AppComposition.
    // R56 proved that was not a correctness defect (the class is stateless and
    // SharedPreferences is a process singleton), so R57 is ownership
    // canonicalisation with behaviour deliberately unchanged.

    test(
      'every repository is constructed ONLY in its approved sites (IS-R57 Phase 8)',
      () {
        // Approved = the composition root, the repository's own file (its
        // constructor), and a constructor DEFAULT of the form
        // `x ?? Repository()`. That last one is not rogue construction: it is the
        // optional-injection seam this codebase has used since R32, and removing
        // it would break every test that relies on defaults — an API change this
        // milestone forbids. What it must never be is a bare construction with
        // no seam, which is what nine ActivityRepository sites had.
        const repositories = [
          'ActivityRepository',
          'IntentRepository',
          'KnowledgeRepository',
          'WorldModelRepository',
          'EngineeringMemoryRepository',
        ];
        final rogue = <String>[];
        for (final f in libFiles) {
          if (f.path == 'lib/app/app_composition.dart') continue;
          for (final repo in repositories) {
            if (f.path.endsWith('/${_snake(repo)}.dart')) continue;
            for (final m in RegExp(
              '(?<![?:]\\s{0,4})\\b$repo\\s*\\(',
            ).allMatches(f.code)) {
              // A construction preceded by `??` or `:` is a defaulted seam.
              final before = f.code.substring(
                (m.start - 24).clamp(0, m.start),
                m.start,
              );
              if (before.contains('??') || before.contains('const ')) continue;
              rogue.add('${f.path}:$repo');
            }
          }
        }
        expect(
          rogue,
          isEmpty,
          reason:
              'these construct a repository with NO injection seam, so production cannot '
              'share the composition instance and a test cannot substitute one: $rogue',
        );
      },
    );

    test(
      'AppComposition owns exactly ONE ActivityRepository and hands it out (IS-R57 Phase 3)',
      () {
        final composition = libFiles.firstWhere(
          (f) => f.path == 'lib/app/app_composition.dart',
        );
        final constructions = RegExp(
          r'\bActivityRepository\s*\(',
        ).allMatches(composition.code).length;
        expect(
          constructions,
          1,
          reason:
              'the composition must build exactly one activity repository; found $constructions',
        );
        expect(
          RegExp(
            r'final\s+ActivityRepository\s+activityRepository;',
          ).hasMatch(composition.code),
          isTrue,
          reason:
              'the composition must EXPOSE it, or consumers cannot receive it',
        );
        // And it must actually be handed to the coordinators it builds, or
        // exposing it would be decoration.
        expect(
          RegExp(
            r'activity:\s*activityRepository',
          ).allMatches(composition.code).length,
          greaterThanOrEqualTo(4),
          reason:
              'the composition must pass its instance to the coordinators it constructs',
        );
      },
    );

    test(
      'the dead repository contracts and MinimalKernel are gone and stay gone (IS-R57 Phase 4)',
      () {
        // Deleted by R57: four abstract contracts with twenty methods, ZERO
        // implementations, reachable only through a barrel re-export — and one
        // of them (`IntentRepository`) collided by name with the live storage
        // repository, so importing both would have failed to compile. Same shape
        // as the dead `runtime.dart` R47 removed.
        for (final removed in [
          'lib/core/contracts/repository.dart',
          'lib/kernel/minimal_kernel.dart',
        ]) {
          expect(
            libFiles.map((f) => f.path),
            isNot(contains(removed)),
            reason: '$removed was deleted as dead code; it must not return',
          );
        }
        // The barrel must not re-export it again — the dangling-export mistake
        // R47's deletion made, which only the analyzer caught.
        final barrel = libFiles.firstWhere(
          (f) => f.path == 'lib/core/contracts/contracts.dart',
        );
        expect(
          RegExp(r"export\s+'repository\.dart'").hasMatch(barrel.raw),
          isFalse,
        );
        // `IntentRepository` must now declare exactly once, repository-wide.
        expect(
          _declaringFiles(libFiles, 'IntentRepository'),
          ['lib/storage/intent_repository.dart'],
          reason: 'the name collision R57 removed must not come back',
        );
      },
    );

    test(
      'neither the Kernel nor any UI file imports an external cognition/protection package directly',
      () {
        final offenders = libFiles
            .where(
              (f) =>
                  f.path.startsWith('lib/kernel/') ||
                  f.path.startsWith('lib/features/') ||
                  f.path.startsWith('lib/screens/'),
            )
            .where(
              (f) => RegExp(
                '''import\\s+['"]package:(kaalka|webweavex)''',
              ).hasMatch(f.raw),
            )
            .map((f) => f.path)
            .toList();
        expect(
          offenders,
          isEmpty,
          reason:
              'Kernel/UI must reach these only through their adapters; found: $offenders',
        );
      },
    );
  });

  // ── DYNAMIC CERTIFICATION ───────────────────────────────────────────────
  //
  // Static analysis proves no SECOND construction path exists. It cannot
  // prove the ONE path is actually wired coherently at runtime. These do.
  group('R46 DYNAMIC certification — the real production graph, on live objects', () {
    test(
      'AppComposition.production() exposes exactly one instance of each canonical service, stable across reads',
      () {
        final c = AppComposition.production();
        addTearDown(() => c.experienceRepository.close());

        expect(
          identical(c.experienceEntryPipeline, c.experienceEntryPipeline),
          isTrue,
        );
        expect(
          identical(
            c.experienceActivationManager,
            c.experienceActivationManager,
          ),
          isTrue,
        );
        expect(
          identical(c.workspaceSchedulingEngine, c.workspaceSchedulingEngine),
          isTrue,
        );
        expect(
          identical(c.workspaceRuntimeSupervisor, c.workspaceRuntimeSupervisor),
          isTrue,
        );
        expect(identical(c.workspaceManager, c.workspaceManager), isTrue);
        expect(identical(c.intentRouter, c.intentRouter), isTrue);
        expect(
          identical(c.intentExecutionPipeline, c.intentExecutionPipeline),
          isTrue,
        );

        expect(c.experienceEntryPipeline, isA<ExperienceEntryPipeline>());
        expect(
          c.experienceActivationManager,
          isA<ExperienceActivationManager>(),
        );
        expect(c.workspaceSchedulingEngine, isA<WorkspaceSchedulingEngine>());
        expect(c.workspaceRuntimeSupervisor, isA<WorkspaceRuntimeSupervisor>());
      },
    );

    test(
      'the composition wires the scheduler and the activation manager to the SAME supervisor and workspace — no split-brain graph',
      () {
        final c = AppComposition.production();
        addTearDown(() => c.experienceRepository.close());

        expect(
          identical(
            c.workspaceSchedulingEngine.supervisor,
            c.workspaceRuntimeSupervisor,
          ),
          isTrue,
          reason: 'the ONE scheduler must supervise through the ONE supervisor',
        );
        expect(
          identical(c.workspaceSchedulingEngine.workspace, c.workspaceManager),
          isTrue,
          reason:
              'the ONE scheduler must schedule sessions of the ONE workspace manager',
        );
        expect(
          identical(
            c.experienceActivationManager.scheduler,
            c.workspaceSchedulingEngine,
          ),
          isTrue,
          reason:
              'the ONE activation manager must activate through the ONE scheduler',
        );
        expect(
          identical(
            c.experienceEntryPipeline.activationManager,
            c.experienceActivationManager,
          ),
          isTrue,
          reason:
              'the ONE entry pipeline must activate through the ONE activation manager',
        );
        expect(
          identical(
            c.experienceEntryPipeline.scheduler,
            c.workspaceSchedulingEngine,
          ),
          isTrue,
        );
        expect(
          identical(
            c.experienceEntryPipeline.runtimeSupervisor,
            c.workspaceRuntimeSupervisor,
          ),
          isTrue,
        );
        expect(
          identical(
            c.experienceEntryPipeline.workspaceManager,
            c.workspaceManager,
          ),
          isTrue,
        );
      },
    );

    test(
      'the two production entry surfaces share the ONE ExperienceActivationManager — the invariant that prevents duplicate Experience routes across tabs',
      () {
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
        final home = libFiles.firstWhere(
          (f) => f.path == 'lib/features/home/home_screen.dart',
        );

        expect(
          RegExp(
            r'identical\(\s*_scheduler\s*,\s*_composition\.workspaceSchedulingEngine\s*\)',
          ).hasMatch(home.code),
          isTrue,
          reason:
              'HomeScreen must keep binding its activation manager to the composition singleton via an identical() check on the scheduler.',
        );
        expect(
          home.code.contains('_composition.experienceActivationManager'),
          isTrue,
          reason:
              'HomeScreen must still be able to resolve THE shared activation manager in the no-override case.',
        );
        // The fresh-scheduler branch must remain strictly conditional: an
        // unconditional local scheduler would silently split the graph in
        // production, where no overrides are ever passed.
        expect(
          RegExp(
            r'needsConsistentScheduler\s*=\s*widget\.scheduler\s*==\s*null\s*&&',
          ).hasMatch(home.code),
          isTrue,
          reason:
              'the local scheduler must only be built when a caller really overrode a workspace field without a scheduler.',
        );
      },
    );

    testWidgets(
      'both real production entry surfaces build against the same composition without throwing',
      (tester) async {
        final c = AppComposition.production();
        addTearDown(() => c.experienceRepository.close());

        // Scaffold, not a bare MaterialApp home: HomeScreen contains a
        // TextField, which requires a Material ancestor.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ExperiencesScreen(composition: c)),
          ),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        expect(find.byType(ExperiencesScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: HomeScreen(composition: c)),
          ),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    test(
      'SCHEDULER certification — activation cannot bypass the scheduler: the activation manager has no path to a runtime except through it',
      () {
        final c = AppComposition.production();
        addTearDown(() => c.experienceRepository.close());

        // Structural, on live objects: the activation manager's ONLY collaborator
        // capable of starting/pausing a runtime is the scheduler it was given.
        expect(
          identical(
            c.experienceActivationManager.scheduler,
            c.workspaceSchedulingEngine,
          ),
          isTrue,
        );
        // And the scheduler is the only thing holding the supervisor.
        expect(
          identical(
            c.workspaceSchedulingEngine.supervisor,
            c.workspaceRuntimeSupervisor,
          ),
          isTrue,
        );
      },
    );

    test(
      'RUNTIME certification — a fresh supervisor reports no unsupervised runtimes, and registration is the only way in',
      () {
        final c = AppComposition.production();
        addTearDown(() => c.experienceRepository.close());

        // Nothing is registered before any Experience is opened.
        expect(
          c.workspaceRuntimeSupervisor.registrations,
          isEmpty,
          reason:
              'a freshly composed production graph must supervise nothing yet — any pre-registered runtime would mean something constructed a runtime outside the entry pipeline',
        );
      },
    );
  });

  // ── REGRESSION / BACKWARD COMPATIBILITY ─────────────────────────────────
  group('R46 regression and backward compatibility', () {
    test(
      'R46 added nothing to lib/ — certification is a build-time concern only',
      () {
        final r46InLib = libFiles
            .where(
              (f) =>
                  f.path.contains('r46') ||
                  f.path.contains('architectural_integrity'),
            )
            .toList();
        expect(
          r46InLib,
          isEmpty,
          reason:
              'R46 must not ship a certification subsystem inside lib/; found: ${r46InLib.map((f) => f.path)}',
        );
      },
    );

    testWidgets(
      'a bare HomeScreen() and a bare ExperiencesScreen() still render without throwing',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: HomeScreen())),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ExperiencesScreen())),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        expect(find.byType(ExperiencesScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
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
      print(
        'R46 repository scan: ${files.length} files, ${bytes ~/ 1024}KB stripped source, ${scanWatch.elapsedMilliseconds}ms',
      );
      // ignore: avoid_print
      print(
        'R46 invariant verification (${canonicalConstructionSites.length} types + 3 boundary scans): ${verifyWatch.elapsedMilliseconds}ms',
      );
      // ignore: avoid_print
      print(
        'R46 total certification cost: ${scanWatch.elapsedMilliseconds + verifyWatch.elapsedMilliseconds}ms',
      );

      // A guard, not a benchmark: certification must stay cheap enough that
      // nobody is ever tempted to skip it in CI.
      expect(
        scanWatch.elapsedMilliseconds + verifyWatch.elapsedMilliseconds,
        lessThan(30000),
        reason: 'certification must remain cheap enough to always run',
      );
    });
  });
}
