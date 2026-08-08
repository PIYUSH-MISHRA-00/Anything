"""IS-R59 — classify every lib/ file into exactly one runtime state.

Categories (IS-R59 requires exactly one per file, no UNKNOWN):

  REACHABLE    an import chain from lib/main.dart reaches it
  DORMANT      not reachable from main(), but referenced by test/ — it has
               coverage and a revival path
  EXPERIMENTAL not reachable, not tested, but imported by another lib/ file —
               part of a coherent but disconnected subsystem
  DEAD         not reachable, not tested, imported by nothing at all
  DEPRECATED   carries an explicit @Deprecated / DEPRECATED marker

Evidence only: import edges and textual references, never inference.
"""
import io
import json
import os
import re

LIB = 'lib'
TEST = 'test'
ENTRY = 'lib/main.dart'
IMPORT = re.compile(r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""", re.M)


def dart_files(root):
    out = []
    for r, _d, fs in os.walk(root):
        for f in fs:
            if f.endswith('.dart'):
                out.append(os.path.join(r, f).replace('\\', '/'))
    return sorted(out)


def read(p):
    return io.open(p, encoding='utf-8', errors='replace').read()


def resolve(importer, uri):
    if uri.startswith('package:anything/'):
        return 'lib/' + uri[len('package:anything/'):]
    if uri.startswith('package:') or uri.startswith('dart:'):
        return None
    return os.path.normpath(
        os.path.join(os.path.dirname(importer), uri)).replace('\\', '/')


def main():
    lib_files = dart_files(LIB)
    test_files = dart_files(TEST)

    graph = {}
    for f in lib_files:
        src = read(f)
        targets = []
        for uri in IMPORT.findall(src):
            t = resolve(f, uri)
            if t and t.startswith('lib/') and os.path.exists(t):
                targets.append(t)
        graph[f] = targets

    # transitive closure from the single canonical entry
    reachable, stack = set(), [ENTRY]
    while stack:
        cur = stack.pop()
        if cur in reachable:
            continue
        reachable.add(cur)
        stack.extend(t for t in graph.get(cur, []) if t not in reachable)

    # who imports whom, from anywhere in lib/
    imported_by = {f: set() for f in lib_files}
    for f, ts in graph.items():
        for t in ts:
            imported_by[t].add(f)

    # test references: import edges from test/ into lib/
    test_refs = {f: 0 for f in lib_files}
    for tf in test_files:
        src = read(tf)
        for uri in IMPORT.findall(src):
            t = resolve(tf, uri)
            if t and t.startswith('lib/') and t in test_refs:
                test_refs[t] += 1

    rows = []
    for f in lib_files:
        src = read(f)
        deprecated = ('@Deprecated' in src) or ('DEPRECATED' in src)
        if f in reachable:
            cls = 'REACHABLE'
        elif deprecated:
            cls = 'DEPRECATED'
        elif test_refs[f] > 0:
            cls = 'DORMANT'
        elif imported_by[f]:
            cls = 'EXPERIMENTAL'
        else:
            cls = 'DEAD'
        rows.append({
            'file': f,
            'class': cls,
            'test_refs': test_refs[f],
            'lib_importers': len(imported_by[f]),
        })

    counts = {}
    for r in rows:
        counts[r['class']] = counts.get(r['class'], 0) + 1

    print('TOTAL lib/ dart files: %d' % len(lib_files))
    for k in ['REACHABLE', 'DORMANT', 'EXPERIMENTAL', 'DEPRECATED', 'DEAD']:
        print('  %-13s %3d' % (k, counts.get(k, 0)))
    print()
    for k in ['DEAD', 'EXPERIMENTAL', 'DORMANT']:
        sel = [r for r in rows if r['class'] == k]
        if not sel:
            continue
        print('=== %s (%d) ===' % (k, len(sel)))
        for r in sel:
            print('  %-62s tests=%-3d libImporters=%d'
                  % (r['file'], r['test_refs'], r['lib_importers']))
        print()

    io.open('tool/reachability_report.json', 'w', encoding='utf-8').write(
        json.dumps({'counts': counts, 'rows': rows}, indent=1))


if __name__ == '__main__':
    main()
