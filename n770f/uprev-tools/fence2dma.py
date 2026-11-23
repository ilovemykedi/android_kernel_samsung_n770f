#!/usr/bin/env python3
"""Apply the v4.10 'struct fence' -> 'struct dma_fence' rename to files.
Mapping is derived from identifiers defined in v4.10's dma-fence headers."""
import re, sys, subprocess
names = set()
for h in ['include/linux/dma-fence.h', 'include/linux/dma-fence-array.h',
          'include/trace/events/dma_fence.h']:
    s = subprocess.run(['git', 'show', f'v4.10:{h}'], capture_output=True, text=True).stdout
    names |= set(re.findall(r'\bdma_fence_[a-z0-9_]+\b', s))
pairs = sorted(((n[4:], n) for n in names if n.startswith('dma_fence_')), key=lambda p: -len(p[0]))
rules = [(re.compile(r'\bstruct fence\b'), 'struct dma_fence'),
         (re.compile(r'\bFENCE_FLAG_'), 'DMA_FENCE_FLAG_'),
         (re.compile(r'\bFENCE_TRACE\b'), 'DMA_FENCE_TRACE'),
         (re.compile(r'\bFENCE_WARN\b'), 'DMA_FENCE_WARN'),
         (re.compile(r'\bFENCE_ERR\b'), 'DMA_FENCE_ERR'),
         (re.compile(r'<linux/fence\.h>'), '<linux/dma-fence.h>'),
         (re.compile(r'<linux/fence-array\.h>'), '<linux/dma-fence-array.h>'),
         (re.compile(r'<trace/events/fence\.h>'), '<trace/events/dma_fence.h>'),
         (re.compile(r'\btrace_fence_'), 'trace_dma_fence_')]
pairs += [('fence_get_status_locked', 'dma_fence_get_status_locked'), ('fence_get_status', 'dma_fence_get_status'),
          ('fence_set_error', 'dma_fence_set_error'), ('to_fence_array', 'to_dma_fence_array'),
          ('fence_is_array', 'dma_fence_is_array'), ('fence_array_create', 'dma_fence_array_create')]
pairs.sort(key=lambda p: -len(p[0]))
rules += [(re.compile(r'\b' + re.escape(a) + r'\b'), b) for a, b in pairs]
for p in sys.argv[1:]:
    s = open(p, errors='surrogateescape').read(); t = s
    for r, b in rules: t = r.sub(b, t)
    if t != s:
        open(p, 'w', errors='surrogateescape').write(t); print('converted', p)
