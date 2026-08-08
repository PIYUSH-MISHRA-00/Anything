"""IS-R59 — compute runtime reachability by transitive import closure.

Evidence, not inference: starts at lib/main.dart and follows every `import`
directive that resolves inside lib/. A file is REACHABLE only if a real import
chain from main() reaches it.

Usage:  python tool/reachability.py [--json]
"""
import io
import json
import os
import re
import sys

LIB = 'lib'
ENTRY = 'lib/main.dart'

IMPORT = re.compile(r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""", re.M)


def all_lib_files():
    out = []
    for root, _dirs, files in os.walk(LIB):
        for f in files:
            if f.endswith('.dart'):
                out.append(os.path.join(root, f).replace('\\', '/'))
    return sorted(out)


def resolve(importing_file, uri):
    """Resolve a Dart import URI to a lib/ path, or None if external."""
    if uri.startswith('package:anything/'):
        return 'lib/' + uri[len('package:anything/'):]
    if uri.startswith('package:') or uri.startswith('dart:'):
        return None
    # relative
    base = os.path.dirname(importing_file)
    return os.path.normpath(os.path.join(base, uri)).replace('\\', '/')


def edges_of(path):
    try:
        src = io.open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        return []
    out = []
    for uri in IMPORT.findall(src):
        target = resolve(path, uri)
        if target and target.startswith('lib/') and os.path.exists(target):
            out.append(target)
    return out


def main():
    files = all_lib_files()
    graph = {f: edges_of(f) for f in files}

    reachable = set()
    stack = [ENTRY]
    parent = {ENTRY: None}
    while stack:
        cur = stack.pop()
        if cur in reachable:
            continue
        reachable.add(cur)
        for nxt in graph.get(cur, []):
            if nxt not in reachable:
                parent.setdefault(nxt, cur)
                stack.append(nxt)

    unreachable = sorted(set(files) - reachable)

    if '--json' in sys.argv:
        print(json.dumps({
            'total': len(files),
            'reachable': sorted(reachable),
            'unreachable': unreachable,
        }, indent=1))
        return

    print('ENTRY            : %s' % ENTRY)
    print('lib/ dart files  : %d' % len(files))
    print('REACHABLE        : %d' % len(reachable))
    print('UNREACHABLE      : %d' % len(unreachable))
    print()
    by_dir = {}
    for f in unreachable:
        d = '/'.join(f.split('/')[:2])
        by_dir.setdefault(d, []).append(f)
    print('UNREACHABLE by directory:')
    for d in sorted(by_dir, key=lambda k: -len(by_dir[k])):
        print('  %-42s %3d' % (d, len(by_dir[d])))


if __name__ == '__main__':
    main()
