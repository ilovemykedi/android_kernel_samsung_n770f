/* SPDX-License-Identifier: GPL-2.0 */
/*
 * 4.9 compatibility: set_memory_*() live in asm/cacheflush.h on arm64 in
 * this tree. Provide the newer <linux/set_memory.h> entry point for the
 * backported BPF code.
 */
#ifndef _LINUX_SET_MEMORY_H_
#define _LINUX_SET_MEMORY_H_

#include <asm/cacheflush.h>

#ifndef CONFIG_ARCH_HAS_SET_DIRECT_MAP
struct page;
static inline int set_direct_map_invalid_noflush(struct page *page)
{
	return 0;
}
static inline int set_direct_map_default_noflush(struct page *page)
{
	return 0;
}
#endif

#endif /* _LINUX_SET_MEMORY_H_ */
