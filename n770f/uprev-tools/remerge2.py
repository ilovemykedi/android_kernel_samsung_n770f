#!/usr/bin/env python3
"""Per-file base selection for an in-progress `git merge THEIRS` of an
upstream release into a stable-based vendor tree.

For each conflicted path, re-merge with the stable tag as base ONLY if every
line the stable series added to that file (vs the mainline base) is already
present in THEIRS; otherwise keep git's own result (mainline base), which
never drops our side. Usage: remerge2.py STABLE THEIRS MAINLINE_BASE OUT"""
import subprocess, sys, os, tempfile
stable, theirs_ref, up_base, out = sys.argv[1:5]
def blob(ref, path):
    r = subprocess.run(['git', 'cat-file', '-p', f'{ref}:{path}'], capture_output=True)
    return r.stdout if r.returncode == 0 else None
def stage(path, n):
    r = subprocess.run(['git', 'ls-files', '-u', '-z', '--', path], capture_output=True).stdout
    for ent in r.split(b'\0'):
        if not ent: continue
        meta, _ = ent.split(b'\t', 1)
        mode, sha, st = meta.split()
        if int(st) == n:
            return subprocess.run(['git', 'cat-file', 'blob', sha.decode()], capture_output=True).stdout
    return None
renames = {}
for line in subprocess.run(['git', 'diff', '--name-status', '-M', '-l30000', up_base, theirs_ref],
                           capture_output=True, text=True, check=True).stdout.splitlines():
    f = line.split('\t')
    if f[0].startswith('R'): renames[f[2]] = f[1]
def lines(b):
    return {l.strip() for l in (b or b'').split(b'\n') if len(l.strip()) > 3}
files = [f.decode() for f in subprocess.run(['git', 'diff', '--name-only', '--diff-filter=U', '-z'],
         capture_output=True, check=True).stdout.split(b'\0') if f]
st = {'clean-stablebase': 0, 'markers-stablebase': 0, 'kept-git': 0, 'skip': 0}
rep = open(out, 'w')
for p in files:
    o, t = stage(p, 2), stage(p, 3)
    src = renames.get(p, p)
    b191, b49 = blob(stable, src), blob(up_base, src)
    if o is None or t is None or b191 is None:
        st['skip'] += 1; rep.write(f'skip\t{p}\n'); continue
    missing = (lines(b191) - lines(b49)) - lines(t)
    if missing:
        st['kept-git'] += 1; rep.write(f'kept-git({len(missing)})\t{p}\n'); continue
    with tempfile.TemporaryDirectory() as d:
        fo, fb, ft = (os.path.join(d, n) for n in 'obt')
        for f, data in ((fo, o), (fb, b191), (ft, t)): open(f, 'wb').write(data)
        r = subprocess.run(['git', 'merge-file', '-p', '-L', 'ours', '-L', stable, '-L', theirs_ref,
                            fo, fb, ft], capture_output=True)
    if r.returncode == 0:
        open(p, 'wb').write(r.stdout); subprocess.run(['git', 'add', '--', p], check=True)
        st['clean-stablebase'] += 1; rep.write(f'clean\t{p}\n')
    elif r.returncode > 0:
        open(p, 'wb').write(r.stdout); st['markers-stablebase'] += 1; rep.write(f'markers\t{p}\n')
print(st)
