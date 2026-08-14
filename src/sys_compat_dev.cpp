/*
 * /dev/misc/sys_compat
 *
 * Fundamentals only: mark a team as Linux ABI via write(LINUXABI),
 * trap its syscall instructions, implement a tiny Linux syscall set.
 * Everything else returns -ENOSYS. No Linux ioctl. A bad Linux call
 * must not panic Haiku.
 *
 * License: Public Domain / CC0 1.0 Universal
 */

#include <Drivers.h>
#include <KernelExport.h>
#include "sys_compat_abi.h"

#define LINUX_EIO     5
#define LINUX_EFAULT 14
#define LINUX_EINVAL 22
#define LINUX_ENOSYS 38

#define LINUX_O_RDONLY 0
#define LINUX_O_WRONLY 1
#define LINUX_O_RDWR   2
#define LINUX_O_CREAT  0100
#define LINUX_O_TRUNC  01000
#define LINUX_O_APPEND 02000

#ifndef O_RDONLY
#define O_RDONLY 0
#define O_WRONLY 1
#define O_RDWR   2
#define O_CREAT  0x0200
#define O_TRUNC  0x0400
#define O_APPEND 0x0008
#endif

#define DEVICE_NAME "misc/sys_compat"

extern "C" {
	void sys_compat_lstar(void);
	extern uint64 gOrigLstar;
	extern uint64 gLinuxCR3;
	int64 sys_compat_dispatch_fast(uint64* saved);
}

int32 api_version = B_CUR_DRIVER_API_VERSION;

static const char* sDeviceNames[] = {
	DEVICE_NAME,
	NULL
};

static inline uint64
rdmsr(uint32 msr)
{
	uint32 lo, hi;
	__asm__ __volatile__("rdmsr" : "=a"(lo), "=d"(hi) : "c"(msr));
	return ((uint64)hi << 32) | lo;
}

static inline void
wrmsr(uint32 msr, uint64 value)
{
	uint32 lo = (uint32)value;
	uint32 hi = (uint32)(value >> 32);
	__asm__ __volatile__("wrmsr" :: "c"(msr), "a"(lo), "d"(hi));
}

static inline uint64
read_cr3(void)
{
	uint64 value;
	__asm__ __volatile__("mov %%cr3, %0" : "=r"(value));
	return value;
}

static int
sc_memcmp(const void* a, const void* b, size_t n)
{
	const unsigned char* pa = (const unsigned char*)a;
	const unsigned char* pb = (const unsigned char*)b;
	while (n--) {
		if (*pa != *pb)
			return (int)*pa - (int)*pb;
		pa++;
		pb++;
	}
	return 0;
}

static int
sc_strcmp(const char* a, const char* b)
{
	while (*a && *a == *b) {
		a++;
		b++;
	}
	return (unsigned char)*a - (unsigned char)*b;
}

static void
install_lstar(void* /*cookie*/, int cpu)
{
	const uint32 IA32_LSTAR = 0xc0000082;
	uint64 current = rdmsr(IA32_LSTAR);
	uint64 hook = (uint64)(addr_t)sys_compat_lstar;

	if (hook == 0 || current == 0)
		return;
	if (current == hook)
		return;
	if (gOrigLstar == 0)
		gOrigLstar = current;
	if (gOrigLstar == 0 || gOrigLstar == hook)
		return;

	wrmsr(IA32_LSTAR, hook);
	dprintf("[sys_compat] CPU %d LSTAR %#" B_PRIx64 " -> hook %#" B_PRIx64 "\n",
		cpu, current, hook);
}

static void
restore_lstar(void* /*cookie*/, int /*cpu*/)
{
	const uint32 IA32_LSTAR = 0xc0000082;
	if (gOrigLstar != 0 && gOrigLstar != (uint64)(addr_t)sys_compat_lstar)
		wrmsr(IA32_LSTAR, gOrigLstar);
}

extern "C" int64
sys_compat_dispatch_fast(uint64* saved)
{
	uint64 num = saved[0];
	uint64 a1 = saved[1];
	uint64 a2 = saved[2];
	uint64 a3 = saved[3];

	(void)saved;
	return -LINUX_ENOSYS;
}

static status_t
dev_open(const char* /*name*/, uint32 /*flags*/, void** cookie)
{
	*cookie = NULL;
	return B_OK;
}

static status_t
dev_close(void* /*cookie*/)
{
	return B_OK;
}

static status_t
dev_free(void* /*cookie*/)
{
	uint64 cr3 = read_cr3();
	if (gLinuxCR3 != 0 && gLinuxCR3 == cr3) {
		gLinuxCR3 = 0;
		dprintf("[sys_compat] LEAVE cr3=%#" B_PRIx64 "\n", cr3);
	}
	return B_OK;
}

static status_t
dev_control(void* /*cookie*/, uint32 /*op*/, void* /*arg*/, size_t /*len*/)
{
	/* Linux ioctl is a later layer. Reject everything. */
	return B_BAD_VALUE;
}

static status_t
dev_read(void* /*cookie*/, off_t /*pos*/, void* /*buf*/, size_t* len)
{
	*len = 0;
	return B_OK;
}

static status_t
dev_write(void* /*cookie*/, off_t /*pos*/, const void* buf, size_t* len)
{
	char token[SYS_COMPAT_TOKEN_LEN];

	if (buf == NULL || len == NULL || *len < SYS_COMPAT_TOKEN_LEN)
		return B_BAD_VALUE;
	if (user_memcpy(token, buf, SYS_COMPAT_TOKEN_LEN) != B_OK)
		return B_BAD_ADDRESS;
	if (sc_memcmp(token, SYS_COMPAT_TOKEN, SYS_COMPAT_TOKEN_LEN) != 0)
		return B_BAD_VALUE;

	gLinuxCR3 = read_cr3();
	*len = SYS_COMPAT_TOKEN_LEN;
	dprintf("[sys_compat] ENTER via write token, cr3=%#" B_PRIx64 "\n", gLinuxCR3);
	return B_OK;
}

static device_hooks sHooks = {
	dev_open,
	dev_close,
	dev_free,
	dev_control,
	dev_read,
	dev_write
};

extern "C" status_t
init_hardware(void)
{
	return B_OK;
}

extern "C" status_t
init_driver(void)
{
	const uint32 IA32_LSTAR = 0xc0000082;
	uint64 current = rdmsr(IA32_LSTAR);

	if (current == 0) {
		dprintf("[sys_compat] refusing to load: LSTAR is zero\n");
		return B_ERROR;
	}

	dprintf("[sys_compat] loading, current LSTAR %#" B_PRIx64 "\n", current);
	call_all_cpus_sync(&install_lstar, NULL);
	if (gOrigLstar == 0) {
		dprintf("[sys_compat] refusing to stay loaded: no original LSTAR\n");
		return B_ERROR;
	}
	dprintf("[sys_compat] identity passthrough armed, orig %#" B_PRIx64 "\n",
		gOrigLstar);
	return B_OK;
}

extern "C" void
uninit_driver(void)
{
	gLinuxCR3 = 0;
	call_all_cpus_sync(&restore_lstar, NULL);
	dprintf("[sys_compat] LSTAR restored\n");
}

extern "C" const char**
publish_devices(void)
{
	return sDeviceNames;
}

extern "C" device_hooks*
find_device(const char* name)
{
	if (name == NULL)
		return NULL;
	if (sc_strcmp(name, DEVICE_NAME) == 0)
		return &sHooks;
	return NULL;
}
