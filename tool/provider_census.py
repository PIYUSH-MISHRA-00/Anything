"""IS-R59 Phase 6 — census every provider / state holder and its runtime class."""
import io
import json
import os
import re

d = json.load(io.open('tool/reachability_report.json', encoding='utf-8'))
cls = {r['file']: r['class'] for r in d['rows']}

PROVIDER = re.compile(
    r'final\s+(\w+)\s*=\s*'
    r'(Provider|StateProvider|StateNotifierProvider|FutureProvider|StreamProvider)'
    r'[<(]')
HOLDER = re.compile(r'\bclass\s+(\w+)\s+extends\s+(ChangeNotifier|ValueNotifier)')

providers, holders = [], []
for root, _dirs, files in os.walk('lib'):
    for f in files:
        if not f.endswith('.dart'):
            continue
        p = os.path.join(root, f).replace(os.sep, '/')
        try:
            s = io.open(p, encoding='utf-8', errors='replace').read()
        except OSError:
            continue
        c = cls.get(p, 'UNKNOWN')
        for m in PROVIDER.finditer(s):
            providers.append((m.group(1), m.group(2), p, c))
        for m in HOLDER.finditer(s):
            holders.append((m.group(1), m.group(2), p, c))

lines = ['# Provider Reachability Matrix — IS-R59 Phase 6', '',
         'Every Riverpod provider and every `ChangeNotifier`/`ValueNotifier` in',
         '`lib/`, with the runtime class of the file that declares it.', '',
         '## Riverpod providers', '',
         '| Provider | Kind | File | Runtime class |', '|---|---|---|---|']
for name, kind, p, c in sorted(providers):
    lines.append('| `%s` | %s | `%s` | **%s** |' % (name, kind, p, c))

lines += ['', '**Every Riverpod provider below is UNREACHABLE.** A provider is',
          'resolved only inside a `ProviderScope`, and no `ProviderScope` exists',
          'anywhere in `lib/` or `test/` — certified by I-85. None of these can',
          'be constructed at runtime today.', '',
          '## ChangeNotifier / ValueNotifier holders', '',
          '| Holder | Base | File | Runtime class |', '|---|---|---|---|']
for name, kind, p, c in sorted(holders):
    lines.append('| `%s` | %s | `%s` | **%s** |' % (name, kind, p, c))

lines += ['', '## Summary', '',
          '| | Count |', '|---|---|',
          '| Riverpod providers | %d |' % len(providers),
          '| ChangeNotifier/ValueNotifier holders | %d |' % len(holders),
          '| Providers in REACHABLE files | %d |'
          % sum(1 for _n, _k, _p, c in providers if c == 'REACHABLE'),
          '', 'No `Bloc`, `Cubit` or `InheritedWidget` state management exists',
          '(the `Bloc` grep matches are prose in documentation comments, not types).']

io.open('docs/audit/PROVIDER_REACHABILITY_MATRIX.md', 'w',
        encoding='utf-8').write('\n'.join(lines) + '\n')
print('providers: %d  holders: %d' % (len(providers), len(holders)))
print('providers in REACHABLE files: %d'
      % sum(1 for _n, _k, _p, c in providers if c == 'REACHABLE'))
