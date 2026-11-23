#!/usr/bin/env python3
"""resolve.py FILE CHOICE...   one choice per conflict hunk, in order:
  o = ours, t = theirs, ot = ours then theirs, to = theirs then ours,
  @path = replace hunk with contents of path, - = leave hunk unresolved.
Stages the file when no hunk is left."""
import sys, subprocess
p, ch = sys.argv[1], sys.argv[2:]
L = open(p, errors='surrogateescape').read().split('\n')
out = []; i = 0; k = 0; left = 0
while i < len(L):
    if L[i].startswith('<<<<<<< '):
        m = i
        while L[m] != '=======': m += 1
        e = m
        while not L[e].startswith('>>>>>>> '): e += 1
        o, t = L[i+1:m], L[m+1:e]
        c = ch[k] if k < len(ch) else '-'
        k += 1
        if c == 'o': out += o
        elif c == 't': out += t
        elif c == 'ot': out += o + t
        elif c == 'to': out += t + o
        elif c.startswith('@'): out += open(c[1:]).read().rstrip('\n').split('\n')
        else: out += L[i:e+1]; left += 1
        i = e + 1; continue
    out.append(L[i]); i += 1
if k != len(ch) and len(ch) > 0: print(f'warning: {p} has {k} hunks, {len(ch)} choices')
open(p, 'w', errors='surrogateescape').write('\n'.join(out))
if not left: subprocess.run(['git', 'add', '--', p], check=True); print(f'{p}: resolved')
else: print(f'{p}: {left} hunks left')
