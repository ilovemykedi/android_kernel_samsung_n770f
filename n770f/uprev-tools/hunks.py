#!/usr/bin/env python3
"""Print conflict hunks of files: hunks.py [-n maxlines] file..."""
import sys
args=sys.argv[1:]; mx=40
if args and args[0]=='-n': mx=int(args[1]); args=args[2:]
for p in args:
    L=open(p,errors='replace').read().split('\n')
    i=0; k=0
    while i<len(L):
        if L[i].startswith('<<<<<<< '):
            k+=1; j=i
            while not L[j].startswith('>>>>>>> '): j+=1
            blk=L[i:j+1]
            print(f'### {p}:{i+1} hunk {k} ({len(blk)} lines)')
            if len(blk)>mx: blk=blk[:mx//2]+['   [...]']+blk[-mx//2:]
            print('\n'.join(blk))
            i=j
        i+=1
