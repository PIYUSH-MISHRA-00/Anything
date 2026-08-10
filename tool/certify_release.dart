// ignore_for_file: avoid_print
/// P21 release certification runner — invokes critical test files.
///
/// Usage (from repo root):
///   dart run tool/certify_release.dart
///
/// Does not fake device evidence. Prints OPEN when device/ADB unavailable.
library;

import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final root = Directory.current.path;
  final reportDir = Directory(
    '${Platform.environment['USERPROFILE']}\\Desktop\\Anything_P21_FINAL',
  )..createSync(recursive: true);

  final suites = <String>[
    'test/dynamic/p21_intent_contract_test.dart',
    'test/dynamic/p21_hardcoding_probe_test.dart',
    'test/dynamic/p21_provider_independence_test.dart',
    'test/dynamic/p21_novel_domain_test.dart',
    'test/dynamic/p20_fullstack_unknown_domain_test.dart',
    'test/p11_webweavex_path_test.dart',
    'test/p11_kaalka_restart_test.dart',
    'test/p12_export_import_test.dart',
  ];

  final results = <Map<String, dynamic>>[];
  for (final suite in suites) {
    stdout.writeln('RUN $suite');
    final proc = await Process.run(
      'flutter',
      ['test', suite, '--reporter', 'compact'],
      workingDirectory: root,
      runInShell: true,
    );
    final ok = proc.exitCode == 0;
    results.add({
      'suite': suite,
      'exitCode': proc.exitCode,
      'status': ok ? 'PASS' : 'FAIL',
    });
    stdout.writeln(ok ? 'PASS $suite' : 'FAIL $suite');
  }

  final adb = File(
    '${Platform.environment['LOCALAPPDATA']}\\Android\\sdk\\platform-tools\\adb.exe',
  );
  var deviceStatus = 'BLOCKED';
  var deviceDetail = 'adb not found';
  if (adb.existsSync()) {
    final d = await Process.run(adb.path, ['devices'], runInShell: true);
    final out = '${d.stdout}\n${d.stderr}';
    if (out.contains('\tdevice')) {
      deviceStatus = 'OPEN';
      deviceDetail = 'device attached — run manual matrix';
    } else if (out.contains('unauthorized')) {
      deviceStatus = 'BLOCKED';
      deviceDetail = 'device unauthorized — allow USB debugging';
    } else {
      deviceStatus = 'BLOCKED';
      deviceDetail = 'no device';
    }
  }

  final allPass = results.every((r) => r['status'] == 'PASS');
  final json = {
    'milestone': 'P21',
    'gitHint': 'run git rev-parse HEAD',
    'automatedSuites': results,
    'device': {'status': deviceStatus, 'detail': deviceDetail},
    'verdict': allPass
        ? (deviceStatus == 'OPEN'
              ? 'PARTIAL — automated PASS; device matrix OPEN'
              : 'NOT PRODUCTION COMPLETE — device $deviceStatus')
        : 'NOT PRODUCTION COMPLETE — automated FAIL',
  };

  File(
    '${reportDir.path}\\26_CERTIFICATION_REPORT.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
  File('${reportDir.path}\\25_CERTIFICATION_REPORT.md').writeAsStringSync('''
# P21 Certification Report (tool/certify_release.dart)

## Automated suites
${results.map((r) => '- ${r['status']}: `${r['suite']}` (exit ${r['exitCode']})').join('\n')}

## Device
- status: **$deviceStatus**
- detail: $deviceDetail

## Verdict
**${json['verdict']}**
''');

  stdout.writeln('Wrote ${reportDir.path}\\25_CERTIFICATION_REPORT.md');
  exit(allPass ? 0 : 1);
}
