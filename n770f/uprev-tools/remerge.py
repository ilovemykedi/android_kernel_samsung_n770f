#!/usr/bin/env python3
"""Re-resolve conflicted files of an in-progress `git merge <theirs>` using a
closer base (e.g. the stable tag the Samsung tree was built on).
Writes clean results and stages them; prints the files still needing work."""
import subprocess, sys, os, tempfile
base_ref, theirs_ref, out = sys.argv[1], sys.argv[2], sys.argv[3]
def blob(ref, path):
    r = subprocess.run(['git', 'cat-file', '-p', f'{ref}:{path}'], capture_output=True)
    return r.stdout if r.returncode == 0 else None
up_base = sys.argv[4] if len(sys.argv) > 4 else None   # e.g. v4.9 (for upstream renames)
renames = {}
if up_base:
    out_r = subprocess.run(['git', 'diff', '--name-status', '-M', '-l30000', up_base, theirs_ref],
                           capture_output=True, text=True, check=True).stdout
    for line in out_r.splitlines():
        f = line.split('\t')
        if f[0].startswith('R'): renames[f[2]] = f[1]
def stage(path, n):
    r = subprocess.run(['git', 'ls-files', '-u', '-z', '--', path], capture_output=True).stdout
    for ent in r.split(b'\0'):
        if not ent: continue
        meta, _ = ent.split(b'\t', 1)
        mode, sha, st = meta.split()
        if int(st) == n:
            return subprocess.run(['git', 'cat-file', 'blob', sha.decode()], capture_output=True).stdout
    return None
files = subprocess.run(['git', 'diff', '--name-only', '--diff-filter=U', '-z'],
                       capture_output=True, check=True).stdout.split(b'\0')
files = [f.decode() for f in files if f]
left = []
stats = {'clean': 0, 'deleted': 0, 'manual': 0}
for p in files:
    o, t = stage(p, 2), stage(p, 3)
    b = blob(base_ref, p)
    if b is None and p in renames: b = blob(base_ref, renames[p])
    if o is None and t is None:
        subprocess.run(['git', 'rm', '-q', '--cached', '--ignore-unmatch', '--', p])
        if os.path.exists(p): os.remove(p)
        stats['deleted'] += 1; continue
    if t is None:                      # deleted upstream
        if o == b:                     # only stable touched it
            subprocess.run(['git', 'rm', '-q', '-f', '--', p], check=True)
            stats['deleted'] += 1; continue
        left.append(('modify/delete(theirs-del)', p)); continue
    if o is None:                      # deleted in Samsung tree
        if b is None or b == t:
            subprocess.run(['git', 'rm', '-q', '-f', '--', p], check=True)
            stats['deleted'] += 1; continue
        left.append(('modify/delete(ours-del)', p)); continue
    if b is None: b = b''
    with tempfile.TemporaryDirectory() as d:
        fo, fb, ft = (os.path.join(d, n) for n in 'obt')
        for f, data in ((fo, o), (fb, b), (ft, t)):
            open(f, 'wb').write(data)
        r = subprocess.run(['git', 'merge-file', '-p', '-L', 'ours', '-L', base_ref,
                            '-L', theirs_ref, fo, fb, ft], capture_output=True)
        if r.returncode == 0:
            mode = subprocess.run(['git', 'ls-files', '-s', '--', p], capture_output=True,
                                  text=True).stdout.split()
            open(p, 'wb').write(r.stdout)
            subprocess.run(['git', 'add', '--', p], check=True)
            stats['clean'] += 1
        elif r.returncode > 0:
            open(p, 'wb').write(r.stdout)   # leave markers vs the closer base
            left.append((f'content({r.returncode})', p))
        else:
            left.append(('error', p))
stats['manual'] = len(left)
with open(out, 'w') as f:
    for k, p in left: f.write(f'{k}\t{p}\n')
print(stats)
