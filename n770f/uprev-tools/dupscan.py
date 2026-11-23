#!/usr/bin/env python3
"""Find blocks duplicated by a merge: a window of N non-trivial lines that
occurs >=2 times in the merge result but at most once in each parent."""
import subprocess, sys, collections
M, N = sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 6
files = subprocess.run(['git', 'diff', '--name-only', '--diff-filter=AM', M + '^1', M],
                       capture_output=True, text=True).stdout.split()
def show(ref, p):
    r = subprocess.run(['git', 'show', f'{ref}:{p}'], capture_output=True)
    return r.stdout.decode('utf-8', 'replace').split('\n') if r.returncode == 0 else []
def windows(lines):
    c = collections.Counter(); key = [l.strip() for l in lines]
    for i in range(len(key) - N + 1):
        w = key[i:i+N]
        if sum(1 for x in w if len(x) > 3) < N - 1: continue
        c[tuple(w)] += 1
    return c
for p in files:
    if not p.endswith(('.c', '.h', '.S')): continue
    cur = open(p, errors='replace').read().split('\n') if True else []
    cm = windows(cur)
    dups = [w for w, n in cm.items() if n >= 2]
    if not dups: continue
    a, b = windows(show(M + '^1', p)), windows(show(M + '^2', p))
    real = [w for w in dups if a.get(w, 0) < 2 and b.get(w, 0) < 2]
    if real:
        print(f'{p}: {len(real)} dup windows, e.g. {real[0][0][:70]!r}')
