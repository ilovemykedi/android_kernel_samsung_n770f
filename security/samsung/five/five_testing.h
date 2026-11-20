#ifndef __LINUX_FIVE_TESTING_H
#define __LINUX_FIVE_TESTING_H

#if defined(FIVE_KUNIT_ENABLED) || defined(PROCA_KUNIT_ENABLED)
#define KUNIT_UML // this define should be used for adding UML-specific modifications
#define __mockable __weak
#define __visible_for_testing
// <for five_main.c: five_ptrace(...)>
#ifdef KUNIT_UML
#define COMPAT_PTRACE_GETREGS		12
#define COMPAT_PTRACE_GET_THREAD_AREA	22
#define COMPAT_PTRACE_GETVFPREGS	27
#define COMPAT_PTRACE_GETHBPREGS	29
#endif
#else
#define __mockable
#define __visible_for_testing static
#endif // FIVE_KUNIT_ENABLED || PROCA_KUNIT_ENABLED

#endif // __LINUX_FIVE_TESTING_H
