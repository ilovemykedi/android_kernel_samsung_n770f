#!/usr/bin/env python3
"""Resolve one-sided conflict hunks (other side empty or whitespace-only).
Logs each auto-resolved hunk to a review file. Prints files still conflicted."""
import sys, subprocess
import os
SUBSET = os.environ.get('SUBSET') == '1'
log = open(sys.argv[1], 'a'); files = sys.argv[2:]
tot = {'ours': 0, 'theirs': 0, 'left': 0}
still = []
for p in files:
    L = open(p, errors='surrogateescape').read().split('\n')
    out = []; i = 0; left = 0
    while i < len(L):
        if L[i].startswith('<<<<<<< '):
            m = i
            while L[m] != '=======': m += 1
            e = m
            while not L[e].startswith('>>>>>>> '): e += 1
            ours, theirs = L[i+1:m], L[m+1:e]
            if not ''.join(theirs).strip():
                out += ours; tot['ours'] += 1
                log.write(f'== {p}:{i+1} KEEP-OURS ({len(ours)} lines)\n' + '\n'.join(ours[:6]) + '\n')
            elif not ''.join(ours).strip():
                out += theirs; tot['theirs'] += 1
                log.write(f'== {p}:{i+1} TAKE-THEIRS ({len(theirs)} lines)\n')
            else:
                so = [x.strip() for x in ours if x.strip()]
                st = [x.strip() for x in theirs if x.strip()]
                if SUBSET and set(st) <= set(so):
                    out += ours; tot['ours'] += 1
                    log.write(f'== {p}:{i+1} OURS-SUPERSET ({len(ours)}/{len(theirs)})\n')
                elif SUBSET and set(so) <= set(st):
                    out += theirs; tot['theirs'] += 1
                    log.write(f'== {p}:{i+1} THEIRS-SUPERSET ({len(ours)}/{len(theirs)})\n')
                else:
                    out += L[i:e+1]; left += 1; tot['left'] += 1
            i = e + 1; continue
        out.append(L[i]); i += 1
    open(p, 'w', errors='surrogateescape').write('\n'.join(out))
    if left: still.append(p)
    else: subprocess.run(['git', 'add', '--', p], check=True)
print(tot, 'files still conflicted:', len(still))
open('/root/kernel/uprev-tools/still.txt', 'w').write('\n'.join(still) + '\n')
