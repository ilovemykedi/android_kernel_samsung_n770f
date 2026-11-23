#!/usr/bin/env python3
"""addinc.py LOG : for 'implicit declaration of function X' / 'use of undeclared identifier X'
errors whose symbol moved to a split header, add the #include to the file that
used it (the .c or .h named in the error). Prints what it changed."""
import re, sys, collections
M = {}
def m(h, *syms):
    for s in syms: M[s] = h
m('linux/sched/clock.h', 'cpu_clock', 'local_clock', 'sched_clock', 'running_clock', 'sched_clock_cpu')
m('linux/sched/task.h', 'put_task_struct', 'get_task_struct', 'task_lock', 'task_unlock', 'tasklist_lock')
m('linux/sched/mm.h', 'mmput', 'mmget_not_zero', 'mmput_async', 'mmdrop', 'get_task_mm', 'mmgrab', 'mmget', 'memalloc_noio_save', 'memalloc_noio_restore')
m('linux/sched/signal.h', 'signal_pending', 'fatal_signal_pending', 'send_sig_info', 'send_sig', 'lock_task_sighand',
  'unlock_task_sighand', 'task_rlimit', 'thread_group_leader', 'for_each_process', 'do_each_thread', 'while_each_thread',
  'signal_pending_state', 'rlimit', 'force_sig', 'kill_pid', 'for_each_thread', 'same_thread_group', 'task_rlimit_max', 'kill_pgrp')
m('linux/sched/debug.h', 'show_state_filter', 'show_stack', 'sched_show_task', 'show_regs', 'show_state')
m('linux/sched/cputime.h', 'task_cputime', 'task_cputime_adjusted', 'thread_group_cputime_adjusted')
m('linux/sched/xacct.h', 'inc_syscfs', 'inc_syscr', 'inc_syscw', 'add_rchar', 'add_wchar')
m('linux/nmi.h', 'touch_softlockup_watchdog')
m('linux/sched/rt.h', 'rt_task', 'rt_prio')
m('linux/sched/loadavg.h', 'avenrun', 'get_avenrun')
m('linux/sched/stat.h', 'nr_running', 'nr_iowait', 'nr_context_switches', 'nr_iowait_cpu')
m('linux/sched/topology.h', 'sched_domain_span', 'for_each_domain')
m('linux/sched/hotplug.h', 'idle_task_exit')
m('linux/sched/wake_q.h', 'wake_up_q', 'wake_q_add')
m('linux/sched/user.h', 'free_uid', 'find_user')
m('linux/sched/coredump.h', 'get_dumpable', 'set_dumpable')
m('linux/sched/numa_balancing.h', 'task_numa_fault')
m('linux/sched/autogroup.h', 'sched_autogroup_fork')
m('linux/sched/nohz.h', 'calc_load_nohz_start')
m('linux/sched/init.h', 'sched_init')
m('linux/sched/task_stack.h', 'task_stack_page', 'end_of_stack', 'task_stack_end_corrupted', 'object_is_on_stack', 'try_get_task_stack', 'put_task_stack', 'stack_not_used')
m('linux/cred.h', 'current_uid')
m('linux/sched/task.h', 'init_task')
m('linux/sched/topology.h', 'SCHED_CAPACITY_SHIFT', 'SCHED_CAPACITY_SCALE')
m('linux/shmem_fs.h', 'shmem_mapping')
m('linux/extable.h', 'search_extable', 'search_exception_tables')
m('net/neighbour.h', 'dst_neigh_output')
STRUCT = {'sched_param': 'uapi/linux/sched/types.h', 'syscore_ops': 'linux/syscore_ops.h', 'sched_attr': 'uapi/linux/sched/types.h'}
L = open(sys.argv[1], errors='replace').read().split('\n')
need = collections.defaultdict(set)
for l in L:
    r = re.match(r"(\S+?\.[ch]):\d+:\d+: error: (?:implicit declaration of function|use of undeclared identifier) '(\w+)'", l)
    if not r:
        r = re.match(r"(\S+?\.[ch]):\d+:\d+: error: variable has incomplete type 'struct (\w+)'", l)
        if r and r.group(2) in STRUCT:
            f = r.group(1)
            if f.startswith('./'): f = f[2:]
            need[f].add(STRUCT[r.group(2)]); continue
    if r and r.group(2) in M:
        f = r.group(1)
        if f.startswith('./'): f = f[2:]
        need[f].add(M[r.group(2)])
for f, hs in sorted(need.items()):
    try: s = open(f, errors='surrogateescape').read()
    except OSError: print('skip', f); continue
    lines = s.split('\n')
    add = [h for h in sorted(hs) if f'<{h}>' not in s]
    if not add: continue
    idx = [i for i, x in enumerate(lines) if re.match(r'#include\s*<linux/', x)]
    if not idx: idx = [i for i, x in enumerate(lines) if x.startswith('#include')]
    if not idx: print('noinc', f); continue
    at = idx[0] + 1
    for h in reversed(add): lines.insert(at, f'#include <{h}>')
    open(f, 'w', errors='surrogateescape').write('\n'.join(lines))
    print(f, add)
