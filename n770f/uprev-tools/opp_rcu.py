#!/usr/bin/env python3
"""opp_rcu.py FILE... : convert pre-4.11 OPP users (rcu_read_lock around
dev_pm_opp_find_*/devfreq_recommended_opp) to the 4.11 refcounted API, the way
upstream 8a31d9d94297 converted in-tree users: drop the RCU read section and
dev_pm_opp_put() the OPP after its last use."""
import re, sys
for p in sys.argv[1:]:
    L = open(p).read().split('\n')
    out = []; i = 0; n = 0
    while i < len(L):
        m = re.match(r'^(\s*)rcu_read_lock\(\);\s*$', L[i])
        if not m:
            out.append(L[i]); i += 1; continue
        ind = m.group(1)
        # region end: rcu_read_unlock() at the same indentation
        j = i + 1
        while not re.match(r'^' + ind + r'rcu_read_unlock\(\);\s*$', L[j]): j += 1
        reg = L[i + 1:j]
        txt = '\n'.join(reg)
        if 'opp' not in txt:
            out.append(L[i]); i += 1; continue
        var = re.search(r'IS_ERR\((\w+)\)', txt).group(1)
        reg = [x for x in reg if not re.match(r'^\s*rcu_read_unlock\(\);\s*$', x)]
        if re.search(r'\bdo\s*\{', txt):
            # loop walking the table: put right after the IS_ERR break
            new = []
            k = 0
            while k < len(reg):
                new.append(reg[k])
                mm = re.match(r'^(\s*)if \(IS_ERR\(' + var + r'\)\)\s*$', reg[k])
                if mm and 'break' in reg[k + 1]:
                    new.append(reg[k + 1]); k += 2
                    new.append(mm.group(1) + 'dev_pm_opp_put(' + var + ');')
                    continue
                k += 1
            reg = new
        else:
            last = max(idx for idx, x in enumerate(reg) if var in x and 'IS_ERR' not in x
                       and '=' in x and not re.match(r'^\s*' + var + r'\s*=', x))
            reg.insert(last + 1, ind + 'dev_pm_opp_put(' + var + ');')
        out += reg; i = j + 1; n += 1
    open(p, 'w').write('\n'.join(out))
    print(p, n)
