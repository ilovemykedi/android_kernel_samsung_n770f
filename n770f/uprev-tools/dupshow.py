#!/usr/bin/env python3
import sys, collections
p, N = sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 6
L = open(p, errors='replace').read().split('\n'); key = [l.strip() for l in L]
pos = collections.defaultdict(list)
for i in range(len(key) - N + 1):
    w = tuple(key[i:i+N])
    if sum(1 for x in w if len(x) > 3) < N - 1: continue
    pos[w].append(i + 1)
seen = set()
for w, ps in sorted(pos.items(), key=lambda kv: kv[1][0]):
    if len(ps) < 2: continue
    if any(abs(ps[0] - s) < N for s in seen): continue
    seen.add(ps[0]); print(f'lines {ps}: {w[0][:60]!r} .. {w[-1][:40]!r}')
