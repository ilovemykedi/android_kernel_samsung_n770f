/*
 * Temporary bringup display: use the bootloader's existing linear RGB scanout.
 *
 * Based on "arm64: exynos8895: Add on-screen boot checkpoints" by nhglong
 * (LumiPlayground/android_kernel_samsung_exynos8895 7d8a7fdf6ef0), adapted
 * to Exynos 9810 (r7): DECON0/IDMA/SysMMU addresses from exynos9810.dts and
 * dpu_9810 register definitions, all three DPU SysMMUs are probed, the
 * dreamlte fixed-address fallback is dropped and the DECON trigger is only
 * read-modify-written (HW_TRIG_EN) instead of overwritten.
 */
#include <linux/boot_checkpoint.h>
#include <linux/delay.h>
#include <linux/font.h>
#include <linux/io.h>
#include <linux/init.h>
#include <linux/initrd.h>
#include <linux/kernel.h>
#include <linux/memblock.h>
#include <linux/sched.h>
#include <linux/ptrace.h>
#include <linux/uaccess.h>
#include <linux/compat.h>
#include <linux/spinlock.h>
#include <linux/string.h>
#include <asm/cacheflush.h>
#include <asm/early_ioremap.h>
#include <asm/memory.h>
#include <asm/sections.h>

#define ROWS 60
#define COLS 76

/* exynos9810.dts: decon_f@0x16030000, dpp@0x16021000..0x16026000 */
#define DECON			0x16030000
#define IDMA			0x16021000
#define NR_IDMA			6

/* dpu_9810/regs-decon.h */
#define GLOBAL_CONTROL		0x0000
#define RUN_STATUS		BIT(4)
#define HW_SW_TRIG_CONTROL	0x0070
#define HW_TRIG_MASK_DECON	BIT(4)
#define HW_TRIG_EN		BIT(0)
#define DATA_PATH_CONTROL_0	0x0214	/* WIN_EN_F(win) = 1 << (4 * win) */
#define DATA_PATH_CONTROL_1	0x0218	/* WIN_CHMAP_F(win, ch) */

/* dpu_9810/regs-dpp.h */
#define IDMA_ENABLE		0x0000
#define IDMA_INSTANT_OFF_PENDING BIT(1)
#define IDMA_IN_CON		0x0008
#define IDMA_VR_MODE_EN		BIT(31)
#define IDMA_ROTATION_MASK	(7 << 8)
#define IDMA_AFBC_EN		BIT(7)
#define IDMA_BLOCK_EN		BIT(3)
#define IDMA_SRC_SIZE		0x0010
#define IDMA_SRC_OFFSET		0x0014
#define IDMA_IMG_SIZE		0x0018
#define IDMA_IN_BASE_ADDR_Y	0x0040

/* exynos9810.dts: sysmmu_dpu0..2; drivers/iommu/exynos-iommu.h */
static const phys_addr_t dpu_sysmmu[] = { 0x160a0000, 0x160b0000, 0x160c0000 };
#define REG_MMU_CTRL		0x000
#define REG_PT_BASE_PPN		0x00c

static char lines[ROWS][COLS];
static DEFINE_RAW_SPINLOCK(checkpoint_lock);
static phys_addr_t fb_phys;
static unsigned int stride, width, height, scale, format;
static bool linear, active;
static u32 orig_trig;

static u32 __init early_reg(phys_addr_t addr)
{
	void __iomem *p = early_ioremap(addr, 4);
	u32 value = 0;

	if (p) {
		value = readl(p);
		early_iounmap(p, 4);
	}
	return value;
}

static u32 __init early_pte(phys_addr_t addr)
{
	void *p;
	u32 value = 0;

	if (!memblock_is_region_memory(addr, 4))
		return 0;
	p = early_memremap(addr, 4);
	if (p) {
		value = READ_ONCE(*(u32 *)p);
		early_memunmap(p, 4);
	}
	return value;
}

/* Exynos SysMMU uses 36-bit physical addresses encoded with a four-bit shift. */
static phys_addr_t __init scanout_phys(u32 addr, phys_addr_t table)
{
	u32 pte;

	if (!table)
		return addr;
	pte = early_pte(table + (addr >> 20) * 4);
	if ((pte & 7) == 2)
		return ((phys_addr_t)(pte & ~0xffffU) << 4) | (addr & 0xfffff);
	if ((pte & 7) != 1)
		return 0;
	pte = early_pte(((phys_addr_t)(pte & ~0x3fU) << 4) +
			((addr >> 12) & 255) * 4);
	if ((pte & 3) == 2)
		return ((phys_addr_t)(pte & ~0xffU) << 4) | (addr & 0xfff);
	if ((pte & 3) == 1)
		return ((phys_addr_t)(pte & ~0xfffU) << 4) | (addr & 0xffff);
	return 0;
}

static void __ref draw_row(unsigned int row)
{
	unsigned int x, y, bit, ch, px, py, pitch = 18 * scale;
	unsigned int y0 = 24 + row * pitch;
	size_t bytes = (size_t)stride * pitch * 4;
	phys_addr_t addr = fb_phys + (size_t)y0 * stride * 4;
	u32 *pixels;
	u32 black = format == 2 || format == 3 || format == 6 || format == 7 ?
		0x000000ff : 0xff000000;

	if (!active || y0 + pitch > height)
		return;
	pixels = linear ? phys_to_virt(addr) : early_memremap(addr, bytes);
	if (!pixels)
		return;
	for (y = 0; y < pitch; y++)
		for (x = 0; x < width; x++)
			pixels[y * stride + x] = black;
	for (ch = 0; ch < COLS - 1 && lines[row][ch]; ch++) {
		if (24 + (ch + 1) * 8 * scale > width)
			break;
		for (y = 0; y < 16; y++) {
			u8 glyph = ((const u8 *)font_vga_8x16.data)[(u8)lines[row][ch] * 16 + y];
			for (bit = 0; bit < 8; bit++) {
				if (!(glyph & (0x80 >> bit)))
					continue;
				for (py = 0; py < scale; py++)
					for (px = 0; px < scale; px++)
						pixels[(y * scale + py) * stride +
							24 + (ch * 8 + bit) * scale + px] = ~0U;
			}
		}
	}
	__flush_dcache_area(pixels, bytes);
	if (!linear)
		early_memunmap(pixels, bytes);
}

void boot_checkpoint(unsigned int row, const char *fmt, ...)
{
	unsigned long flags;
	va_list ap;

	if (row >= ROWS || !raw_spin_trylock_irqsave(&checkpoint_lock, flags))
		return;
	snprintf(lines[row], COLS, "%02u ", row);
	va_start(ap, fmt);
	vsnprintf(lines[row] + 3, COLS - 3, fmt, ap);
	va_end(ap);
	draw_row(row);
	raw_spin_unlock_irqrestore(&checkpoint_lock, flags);
}

/*
 * Accept a candidate only if every page of the scanout is reserved, mapped
 * RAM outside the kernel image and initrd, and translates consistently.
 */
static bool __init scanout_valid(phys_addr_t phys, u32 dma, size_t bytes,
				 phys_addr_t table)
{
	phys_addr_t p, end = phys + PAGE_ALIGN(bytes);

	if (!phys || !memblock_is_region_memory(phys, PAGE_ALIGN(bytes)))
		return false;
	/* Never treat an IOVA as RAM, or write into kernel/initrd allocations. */
	if (phys < __pa_symbol(_end) && end > __pa_symbol(_text))
		return false;
	if (initrd_start && phys < __virt_to_phys(initrd_end) &&
	    end > __virt_to_phys(initrd_start))
		return false;
	for (p = phys; p < end; p += PAGE_SIZE)
		if (!memblock_is_reserved(p) || !memblock_is_map_memory(p) ||
		    scanout_phys(dma + p - phys, table) != p)
			return false;
	return true;
}

/* The bootloader passes its (unreserved) scanout as s3cfb.bootloaderfb=. */
static phys_addr_t __init cmdline_fb(void)
{
	const char *p = strstr(boot_command_line, "s3cfb.bootloaderfb=");

	return p ? memparse(p + strlen("s3cfb.bootloaderfb="), NULL) : 0;
}

/*
 * The bootloader framebuffer is not in reserved-memory on r7. Claim it
 * only if it is plain RAM outside the kernel/initrd that nothing has
 * reserved yet (or that is already fully reserved).
 */
static bool __init claim_cmdline_fb(phys_addr_t phys, size_t bytes)
{
	phys_addr_t end = phys + PAGE_ALIGN(bytes);

	if (!phys || (phys & ~PAGE_MASK) ||
	    !memblock_is_region_memory(phys, PAGE_ALIGN(bytes)))
		return false;
	if (phys < __pa_symbol(_end) && end > __pa_symbol(_text))
		return false;
	if (initrd_start && phys < __virt_to_phys(initrd_end) &&
	    end > __virt_to_phys(initrd_start))
		return false;
	if (memblock_is_region_reserved(phys, PAGE_ALIGN(bytes)))
		return scanout_valid(phys, phys, bytes, 0);
	return !memblock_reserve(phys, PAGE_ALIGN(bytes));
}

void __init boot_checkpoint_fb_init(void)
{
	u32 windows, channels, channel = 0, win, cfg, src, img, offset, dma, trig;
	phys_addr_t table, mmu, bootfb = cmdline_fb();
	size_t bytes;
	void __iomem *trigger;
	bool translated = false;
	const char *how = "DECON";
	int i;

	if (!(early_reg(DECON + GLOBAL_CONTROL) & RUN_STATUS))
		goto fallback;
	windows = early_reg(DECON + DATA_PATH_CONTROL_0);
	channels = early_reg(DECON + DATA_PATH_CONTROL_1);
	for (win = 0; win < 6; win++)
		if ((windows & (3U << (win * 4))) == (1U << (win * 4)))
			break;
	if (win == 6)
		goto fallback;
	channel = (channels >> (win * 4)) & 7;
	if (channel >= NR_IDMA)
		goto fallback;
	mmu = IDMA + channel * 0x1000;
	cfg = early_reg(mmu + IDMA_IN_CON);
	format = (cfg >> 11) & 31;
	/* 32bpp linear RGB only: no AFBC, block mode, rotation or VR mode */
	if (format > 7 || (cfg & (IDMA_VR_MODE_EN | IDMA_ROTATION_MASK |
				  IDMA_AFBC_EN | IDMA_BLOCK_EN)) ||
	    (early_reg(mmu + IDMA_ENABLE) & IDMA_INSTANT_OFF_PENDING))
		goto fallback;
	src = early_reg(mmu + IDMA_SRC_SIZE);
	img = early_reg(mmu + IDMA_IMG_SIZE);
	offset = early_reg(mmu + IDMA_SRC_OFFSET);
	dma = early_reg(mmu + IDMA_IN_BASE_ADDR_Y);
	stride = src & 0xffff;
	width = img & 0x1fff;
	height = (img >> 16) & 0x1fff;
	if (offset || width < 720 || width > 4096 || height < 1280 ||
	    height > 4096 || stride < width || stride > 1536 ||
	    height > ((src >> 16) & 0x3fff))
		goto fallback;
	scale = width >= 1280 ? 2 : 1;
	bytes = (size_t)stride * height * 4;
	if (!dma || (dma & ~PAGE_MASK) || (u64)dma + bytes > (1ULL << 32))
		goto fallback;

	/* The DPP-to-SysMMU routing is not fixed here: try each enabled one. */
	for (i = 0; i < ARRAY_SIZE(dpu_sysmmu); i++) {
		if (!(early_reg(dpu_sysmmu[i] + REG_MMU_CTRL) & BIT(0)))
			continue;
		translated = true;
		table = (phys_addr_t)early_reg(dpu_sysmmu[i] + REG_PT_BASE_PPN) << 12;
		fb_phys = scanout_phys(dma, table);
		if (scanout_valid(fb_phys, dma, bytes, table) ||
		    (fb_phys == bootfb && claim_cmdline_fb(fb_phys, bytes)))
			goto found;
	}
	/* No DPU SysMMU translating: the bootloader scans out physical RAM. */
	if (!translated) {
		fb_phys = dma;
		if (scanout_valid(fb_phys, dma, bytes, 0) ||
		    (fb_phys == bootfb && claim_cmdline_fb(fb_phys, bytes)))
			goto found;
	}

fallback:
	/*
	 * Registers unusable: fall back to the cmdline framebuffer with the
	 * r7 panel geometry (1080x2400 ARGB, linear, stride = width).
	 */
	how = "CMDLINE";
	format = 0;
	width = stride = 1080;
	height = 2400;
	scale = 1;
	bytes = (size_t)stride * height * 4;
	fb_phys = bootfb;
	if (!claim_cmdline_fb(fb_phys, bytes))
		goto unavailable;

found:
	active = true;
	for (win = 0; win < ROWS; win++)
		if (lines[win][0])
			draw_row(win);
	boot_checkpoint(0, "BOOT CHECKPOINTS %ux%u CH%u %s", width, height,
			channel, how);
	boot_checkpoint(1, "RGB BUFFER %llx FORMAT %u", (u64)fb_phys, format);
	/* Keep the running bootloader command-mode scanout refreshing on TE. */
	trigger = early_ioremap(DECON + HW_SW_TRIG_CONTROL, 4);
	if (trigger) {
		/* as decon_reg_set_trigger(DECON_TRIG_ENABLE) for HW trigger */
		trig = readl(trigger);
		orig_trig = trig;
		writel((trig & ~HW_TRIG_MASK_DECON) | HW_TRIG_EN, trigger);
		early_iounmap(trigger, 4);
	}
	pr_info("boot-checkpoint: %s scanout %pa %ux%u stride %u channel %u\n",
		how, &fb_phys, width, height, stride, channel);
	return;
unavailable:
	fb_phys = 0;
	pr_warn("boot-checkpoint: unsupported bootloader scanout; RAM not modified\n");
}

void __init boot_checkpoint_linear(void)
{
	linear = true;
}

/*
 * Called before the DPU drivers take over: once DSIM/DECON power up, the
 * DPU SysMMUs switch to the kernel's page tables, which do not map the
 * bootloader buffer. Restore the bootloader's trigger setting (stopping
 * the TE-driven fetch), let an in-flight frame finish, and stop drawing.
 */
void boot_checkpoint_display_release(void)
{
	void __iomem *trigger;
	unsigned long flags;

	if (!active)
		return;
	boot_checkpoint(39, "DISPLAY HANDED BACK TO DPU DRIVER");
	raw_spin_lock_irqsave(&checkpoint_lock, flags);
	active = false;
	raw_spin_unlock_irqrestore(&checkpoint_lock, flags);
	trigger = ioremap(DECON + HW_SW_TRIG_CONTROL, 4);
	if (trigger) {
		writel(orig_trig, trigger);
		iounmap(trigger);
	}
	msleep(20);
}

bool boot_checkpoint_display_active(void)
{
	return active;
}

bool boot_checkpoint_reserved(phys_addr_t start, size_t size)
{
	return active && start < fb_phys + (size_t)stride * height * 4 &&
		start + size > fb_phys;
}

void boot_checkpoint_syscall(bool exit, long nr, long ret, unsigned long pc)
{
	static unsigned long enters, exits;
	unsigned long n;

	if (task_pid_nr(current) != 1)
		return;
	n = exit ? ++exits : ++enters;
	if (n > 64 && (n & 1023))
		return;
	boot_checkpoint(exit ? 48 : 47, "PID1 %s NR=%ld RET=%ld COUNT=%lu",
		exit ? "EXIT" : "ENTER", nr, ret, n);
	boot_checkpoint(49, "PID1 USER PC %016lx", pc);
}

/*
 * Debug: log stdout/stderr writes and failing syscalls of the boringssl
 * self tests (their stdio goes to /dev/null under init).
 */
static void bcp_log_write(struct pt_regs *regs)
{
	char buf[200];
	unsigned long len = min_t(unsigned long, regs->regs[2], sizeof(buf) - 1);
	const char __user *ubuf = (const char __user *)regs->regs[1];

	if (regs->regs[0] != 1 && regs->regs[0] != 2)
		return;
	if (is_compat_task())
		ubuf = compat_ptr((u32)regs->regs[1]);
	if (copy_from_user(buf, ubuf, len))
		return;
	buf[len] = 0;
	pr_info("bcp: %s[%d] fd%llu: %s\n", current->comm,
		task_pid_nr(current), regs->regs[0], buf);
}

void boot_checkpoint_trace(bool exit, struct pt_regs *regs)
{
	long nr = regs->syscallno;

	if (task_pid_nr(current) == 1) {
		boot_checkpoint_syscall(exit, nr, exit ? regs_return_value(regs) : 0,
					regs->pc);
		return;
	}
	if (strncmp(current->comm, "boringssl", 9))
		return;
	if (!exit) {
		/* write: 4 on AArch32, 64 on AArch64 */
		if (nr == (is_compat_task() ? 4 : 64))
			bcp_log_write(regs);
		return;
	}
	if (regs_return_value(regs) < 0 && regs_return_value(regs) > -4096)
		pr_info("bcp: %s[%d]%s syscall %ld = %ld\n", current->comm,
			task_pid_nr(current), is_compat_task() ? " compat" : "",
			nr, regs_return_value(regs));
}
