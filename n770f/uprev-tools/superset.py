#!/usr/bin/env python3
"""superset.py LOG FILE...  Resolve conflict hunks where one side's
non-blank lines are all contained in the other side: keep the superset.
(theirs <= ours -> ours, ours <= theirs -> theirs). Mixed hunks are left.
Every decision is logged with both sides for review. Stages files that end
up with no conflict markers."""
import sys, subprocess

log = open(sys.argv[1], 'a')
tot = {'ours': 0, 'theirs': 0, 'left': 0}
for p in sys.argv[2:]:
    L = open(p, errors='surrogateescape').read().split('\n')
    out = []; i = 0; left = 0
    while i < len(L):
        if L[i].startswith('<<<<<<< '):
            m = i
            while not (L[m] == '=======' or L[m].startswith('||||||| ')): m += 1
            b = m
            while L[b] != '=======': b += 1
            e = b
            while not L[e].startswith('>>>>>>> '): e += 1
            ours, theirs = L[i + 1:m], L[b + 1:e]
            so = {x.strip() for x in ours if x.strip()}
            st = {x.strip() for x in theirs if x.strip()}
            if so and st and st <= so:
                out += ours; tot['ours'] += 1; kind = 'OURS(superset)'
            elif so and st and so <= st:
                out += theirs; tot['theirs'] += 1; kind = 'THEIRS(superset)'
            else:
                out += L[i:e + 1]; left += 1; tot['left'] += 1; i = e + 1; continue
            log.write(f'== {p}:{i + 1} {kind}\n--- ours\n' + '\n'.join(ours) +
                      '\n--- theirs\n' + '\n'.join(theirs) + '\n')
            i = e + 1
            continue
        out.append(L[i]); i += 1
    open(p, 'w', errors='surrogateescape').write('\n'.join(out))
    if left == 0:
        subprocess.run(['git', 'add', '--', p], check=True)
print(tot)
