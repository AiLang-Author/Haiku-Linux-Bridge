/*
 * /dev/misc/sys_compat
 *
 * Fundamentals only: mark a team as Linux ABI via syscall 0x1337
 * (or write(LINUXABI)), trap its syscall instructions, implement a
 * tiny Linux syscall set.
 * Everything else returns -ENOSYS. No Linux ioctl. A bad Linux call
 * must not panic Haiku.
 *
 * License: Public Domain / CC0 1.0 Universal
 */

#include <Drivers.h>
#include <KernelExport.h>
#include <OS.h>
#include <image.h>
#include "sys_compat_abi.h"

/* POSIX sys/stat.h (pulled by kernel headers) aliases st_ctime to
 * st_ctim.tv_sec. Our layout structs need the real field names. */
#ifdef st_atime
#undef st_atime
#endif
#ifdef st_mtime
#undef st_mtime
#endif
#ifdef st_ctime
#undef st_ctime
#endif
#ifdef st_crtime
#undef st_crtime
#endif

#define LINUX_EPERM         1
#define LINUX_ENOENT        2
#define LINUX_EINTR         4
#define LINUX_EIO           5
#define LINUX_EBADF         9
#define LINUX_ECHILD       10
#define LINUX_EAGAIN       11
#define LINUX_ENOMEM       12
#define LINUX_EACCES       13
#define LINUX_EFAULT       14
#define LINUX_ENOTDIR      20
#define LINUX_EISDIR       21
#define LINUX_EEXIST       17
#define LINUX_EINVAL       22
#define LINUX_ENAMETOOLONG 36
#define LINUX_ENOSYS       38
#define LINUX_E2BIG         7
#define LINUX_ETIMEDOUT   110

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

/* Sandwiched by known numbers: read=0x95 write=0x97 close=0x9e. */
#define HAIKU_READ_DIR   0x9a
#define HAIKU_READ_STAT  0x9c
#define HAIKU_CREATE_DIR 0x7b
#define HAIKU_REMOVE_DIR 0x7c
#define HAIKU_UNLINK     0x80
#define HAIKU_ACCESS     0x84
#define HAIKU_GETCWD     0x92
#define HAIKU_SETCWD     0x93
#define HAIKU_FORK       0x2f
#define HAIKU_WAIT_CHILD 0x2d
/* syscalls.h: is_computer_on … get_safemode then wait_for_objects. */
#define HAIKU_WAIT_OBJ   0x06
#define HAIKU_READ       0x95
#define HAIKU_WRITE      0x97
/* Sandwich: wait_child=0x2d exec=0x2e fork=0x2f (syscalls.h order). */
#define HAIKU_EXEC       0x2e
#define HAIKU_WRITE_STAT 0x9d
/* Guest libroot dump (hrev57937): unmap=0xd5 mprotect=0xd6.
 * Later Haiku sources insert two syscalls before these. */
#define HAIKU_UNMAP      0xd5
#define HAIKU_MPROTECT   0xd6
/* Guest sandwich: map_file immediately before unmap=0xd5. */
#define HAIKU_MAP_FILE   0xd4
#define HAIKU_RENAME_THR 0x38
#define HAIKU_FSYNC      0x77
#define HAIKU_READ_LINK  0x7d
#define HAIKU_SYMLINK    0x7e
#define HAIKU_LINK       0x7f
#define HAIKU_RENAME     0x81
#define HAIKU_DUP        0x9f
#define HAIKU_DUP2       0xa0
#define HAIKU_PIPE       0x83
#define HAIKU_GET_CLOCK  0xc0	/* guest dump; counted 0xc1 in later trees */
#define HAIKU_FCNTL      0x76	/* between open_dir 0x74 and fsync 0x77 */
#define HAIKU_CLOCK_REALTIME  ((int32)-1)
#define HAIKU_CLOCK_MONOTONIC ((int32)0)

#define LINUX_F_DUPFD         0
#define LINUX_F_GETFD         1
#define LINUX_F_SETFD         2
#define LINUX_F_GETFL         3
#define LINUX_F_SETFL         4
#define LINUX_F_DUPFD_CLOEXEC 1030
#define HAIKU_F_DUPFD         0x0001
#define HAIKU_F_GETFD         0x0002
#define HAIKU_F_SETFD         0x0004
#define HAIKU_F_GETFL         0x0008
#define HAIKU_F_SETFL         0x0010
#define HAIKU_F_DUPFD_CLOEXEC 0x0200
#define HAIKU_O_NONBLOCK      0x80
#define HAIKU_O_APPEND        0x800
#define LINUX_O_APPEND        0x400
#define LINUX_O_NONBLOCK      0x800

#define LINUX_STATX_SIZE 256
#define LINUX_STATX_TYPE   0x0001U
#define LINUX_STATX_MODE   0x0002U
#define LINUX_STATX_NLINK  0x0004U
#define LINUX_STATX_UID    0x0008U
#define LINUX_STATX_GID    0x0010U
#define LINUX_STATX_ATIME  0x0020U
#define LINUX_STATX_MTIME  0x0040U
#define LINUX_STATX_CTIME  0x0080U
#define LINUX_STATX_INO    0x0100U
#define LINUX_STATX_SIZE   0x0200U
#define LINUX_STATX_BLOCKS 0x0400U
#define LINUX_STATX_BTIME  0x0800U
#define LINUX_STATX_BASIC  0x07ffU

#define BSTAT_MODE 0x0001
#define BSTAT_UID  0x0002
#define BSTAT_GID  0x0004
#define BSTAT_SIZE 0x0008
#define BSTAT_ATIME 0x0010
#define BSTAT_MTIME 0x0020

#define LINUX_UTIME_NOW  0x3fffffff
#define LINUX_UTIME_OMIT 0x3ffffffe
#define LINUX_AT_SYMLINK_FOLLOW 0x400
#define HAIKU_O_CLOEXEC  0x40
#define LINUX_O_CLOEXEC  0x80000

#define LINUX_PR_SET_PDEATHSIG 1
#define LINUX_PR_GET_DUMPABLE  3
#define LINUX_PR_SET_DUMPABLE  4
#define LINUX_PR_SET_NAME      15
#define LINUX_PR_GET_NAME      16

#define LINUX_MARK_SLOTS 8
#define HAIKU_WNOHANG    0x01
#define HAIKU_WUNTRACED  0x02
#define HAIKU_WEXITED    0x08
#define HAIKU_WSTOPPED   0x10
#define HAIKU_CLD_EXITED 1
#define HAIKU_CLD_KILLED 2
#define HAIKU_CLD_DUMPED 3
#define HAIKU_CLD_STOPPED 5
#define HAIKU_CLD_CONTINUED 6

#define HAIKU_STAT_SIZE 128
#define LINUX_STAT_SIZE 144
#define LINUX_AT_SYMLINK_NOFOLLOW 0x100
#define LINUX_AT_EMPTY_PATH       0x1000

/* Haiku x86_64 struct stat. dev_t is 32-bit; timespec is 16 bytes. */
struct haiku_stat {
	int32  st_dev;
	int32  _pad0;
	int64  st_ino;
	uint32 st_mode;
	int32  st_nlink;
	uint32 st_uid;
	uint32 st_gid;
	int64  st_size;
	int32  st_rdev;
	int32  st_blksize;
	int64  st_atime;
	int64  st_atime_nsec;
	int64  st_mtime;
	int64  st_mtime_nsec;
	int64  st_ctime;
	int64  st_ctime_nsec;
	int64  st_crtime;
	int64  st_crtime_nsec;
	uint32 st_type;
	int32  _pad1;
	int64  st_blocks;
};

/* Linux x86_64 struct stat (asm-generic/stat.h). */
struct linux_stat {
	uint64 st_dev;
	uint64 st_ino;
	uint64 st_nlink;
	uint32 st_mode;
	uint32 st_uid;
	uint32 st_gid;
	uint32 _pad0;
	uint64 st_rdev;
	int64  st_size;
	int64  st_blksize;
	int64  st_blocks;
	uint64 st_atime;
	uint64 st_atime_nsec;
	uint64 st_mtime;
	uint64 st_mtime_nsec;
	uint64 st_ctime;
	uint64 st_ctime_nsec;
	int64  _unused[3];
};

typedef char haiku_stat_size_ok[sizeof(struct haiku_stat) == HAIKU_STAT_SIZE ? 1 : -1];
typedef char linux_stat_size_ok[sizeof(struct linux_stat) == LINUX_STAT_SIZE ? 1 : -1];

struct ksc_info {
	void* function;
	int32 parameter_size;
	int32 _pad;
};

typedef int64 (*haiku_read_dir_fn)(int32 fd, void* buf, uint64 bufSize,
	uint32 maxCount);
typedef int32 (*haiku_read_stat_fn)(int32 fd, const void* path, int32 traverse,
	void* stat, uint64 statSize);
typedef int32 (*haiku_create_dir_fn)(int32 fd, const void* path, int32 perms);
typedef int32 (*haiku_path2_fn)(int32 fd, const void* path);
typedef int32 (*haiku_access_fn)(int32 fd, const void* path, int32 mode,
	int32 effective);
typedef int32 (*haiku_getcwd_fn)(void* buf, uint64 size);
typedef int32 (*haiku_setcwd_fn)(int32 fd, const void* path);
typedef int32 (*haiku_wait_child_fn)(int32 child, uint32 flags, void* info,
	void* usage);
typedef int32 (*haiku_write_stat_fn)(int32 fd, const void* path, int32 traverse,
	void* st, uint64 statSize, int32 mask);
typedef int32 (*haiku_mprot_fn)(void* addr, uint64 size, uint32 prot);
typedef int32 (*haiku_unmap_fn)(void* addr, uint64 size);
typedef int32 (*haiku_rename_thr_fn)(int32 thread, const void* name);
typedef int32 (*haiku_rename_fn)(int32 oldFd, const void* oldPath, int32 newFd,
	const void* newPath);
typedef int32 (*haiku_symlink_fn)(int32 fd, const void* path,
	const void* toPath, int32 mode);
typedef int32 (*haiku_link_fn)(int32 linkFd, const void* linkPath, int32 toFd,
	const void* toPath, int32 traverse);
typedef int32 (*haiku_readlink_fn)(int32 fd, const void* path, void* buf,
	void* sizePtr);
typedef int32 (*haiku_dup_fn)(int32 fd);
typedef int32 (*haiku_dup2_fn)(int32 ofd, int32 nfd, int32 flags);
typedef int32 (*haiku_fsync_fn)(int32 fd, int32 dataOnly);
typedef int32 (*haiku_getclock_fn)(int32 clockid, void* timePtr);
typedef int32 (*haiku_pipe_fn)(void* fds, int32 flags);
typedef int32 (*haiku_fcntl_fn)(int32 fd, int32 op, uint64 argument);
typedef int32 (*haiku_fork_fn)(void);
typedef int32 (*haiku_exec_fn)(const void* path, const void* flatArgs,
	uint64 flatSize, int32 argCount, int32 envCount, int32 umask);
typedef int32 (*haiku_waitobj_fn)(void* infos, int32 num, uint32 flags,
	int64 timeout);
typedef int32 (*haiku_mapfile_fn)(const void* name, void* addrPtr,
	uint32 spec, uint64 size, uint32 prot, uint32 mapping,
	int32 unmapRange, int32 fd, int64 offset);
typedef int64 (*haiku_rw_fn)(int32 fd, int64 pos, void* buf, uint64 n);
typedef area_id (*haiku_vmmap_fn)(team_id team, const char* name,
	void** address, uint32 spec, addr_t size, uint32 prot, uint32 mapping,
	bool unmapRange, int fd, off_t offset);
/* Internal: extra trailing bool kernel selects the team's io context. */
typedef area_id (*haiku_vmmapk_fn)(team_id team, const char* name,
	void** address, uint32 spec, addr_t size, uint32 prot, uint32 mapping,
	bool unmapRange, int fd, off_t offset, bool kernel);

static struct ksc_info* sSyscallInfos;
static uint64 sReadDirFn;
static uint64 sReadStatFn;
static uint64 sCreateDirFn;
static uint64 sRemoveDirFn;
static uint64 sUnlinkFn;
static uint64 sAccessFn;
static uint64 sGetcwdFn;
static uint64 sSetcwdFn;
static uint64 sWaitFn;
static uint64 sExecFn;
static uint64 sWriteStatFn;
static uint64 sUnmapFn;
static uint64 sMprotectFn;
static uint64 sRenameThrFn;
static uint64 sRenameFn;
static uint64 sSymlinkFn;
static uint64 sLinkFn;
static uint64 sReadLinkFn;
static uint64 sDupFn;
static uint64 sDup2Fn;
static uint64 sFsyncFn;
static uint64 sGetClockFn;
static uint64 sPipeFn;
static uint64 sFcntlFn;
static uint64 sForkFn;
static uint64 sWaitObjFn;
static uint64 sMapFileFn;
static haiku_vmmap_fn sVmMapFile;
static haiku_vmmapk_fn sVmMapFileK;
static uint64 sReadFn;
static uint64 sWriteFn;
static char sLinuxExe[256];
static uint64 sRetUserland;
static uint64 sForkGs0;
static uint64 sForkGs8;
static uint64 sForkKtop;
static int64 sLastFork;
static volatile int sChildRobust;
extern "C" volatile int sChildDone;
static uint8 sStackSnap[512];
static uint64 sStackSnapAt;
static int32 sHaveUid;
static int32 sHaveGid;
static uint32 sUid;
static uint32 sGid;
static uint64 sClearTid;
static uint64 sRobustList;
static uint64 sRobustLen;
static int64 sLastPath;
static int64 sLastWait;
static int64 sLastNent;
static int64 sLastOut;
static int sDentFallback;
static uint64 sDentMark;
static int64 sLastStat;
static uint32 sLastMode;
static int64 sLastSize;

extern "C" {
	void sys_compat_lstar(void);
	extern uint64 gOrigLstar;
	extern uint64 gLinuxCR3[LINUX_MARK_SLOTS];
	extern int64 gLinuxTeam[LINUX_MARK_SLOTS];
	extern uint64 gLinuxN;
	extern uint64 gMarkCount;
	extern uint64 gLinuxHits;
	extern uint64 gLastLinuxRax;
	extern uint64 gBrkBase;
	extern uint64 gBrkCur;
	extern uint64 gMapCur;
	extern uint64 gArenaHi;
	extern uint64 gLastN[8];
	extern uint64 gLastNidx;
	extern uint64 gUlsOff;
	extern uint64 gLinuxFS;
	extern uint64 gRseqPtr;
	extern uint64 gRseqLen;
	extern uint64 gRseqSig;
	extern uint64 gSavedRsp;
	extern uint64 gForkTramp;
	extern uint64 gForkHaikuRsp;
	extern uint64 gForkPending;
	extern uint64 gMarkExe;
	extern uint64 gForkFS;
	extern uint64 gForkUserRbp;
	extern uint64 gForkChildTid;
	extern uint64 gForkRbx;
	extern uint64 gForkR12;
	extern uint64 gForkR13;
	extern uint64 gForkR14;
	extern uint64 gForkR15;
	extern uint64 gForkRetAddr;
	extern uint8 gKstack[];
	extern uint8 gKstackEnd[];
	int64 sys_compat_wstat(int64 fd, const void* path, int64 flags,
		uint32 mask, int64 a, int64 b);
	int64 sys_compat_mprotect(void* addr, uint64 len, int64 prot);
	int64 sys_compat_munmap(void* addr, uint64 len);
	int64 sys_compat_getuid(void);
	int64 sys_compat_getgid(void);
	int64 sys_compat_setuid(int64 uid);
	int64 sys_compat_setgid(int64 gid);
	int64 sys_compat_gettid(void);
	int64 sys_compat_set_tid_address(void* ptr);
	int64 sys_compat_set_robust_list(void* head, uint64 len);
	int64 sys_compat_prctl(int64 option, int64 a2, int64 a3, int64 a4,
		int64 a5);
	int64 sys_compat_dispatch_fast(uint64* saved);
	int64 sys_compat_getdents64(int64 fd, void* userBuf, uint64 count);
	int64 sys_compat_stat(int64 fd, const void* userPath, void* userStat,
		int64 flags);
	int64 sys_compat_mkdir(int64 fd, const void* path, int64 mode);
	int64 sys_compat_unlink(int64 fd, const void* path, int64 flags);
	int64 sys_compat_access(int64 fd, const void* path, int64 mode);
	int64 sys_compat_getcwd(void* buf, uint64 size);
	int64 sys_compat_chdir(int64 fd, const void* path);
	int64 sys_compat_mark_team(void);
	int64 sys_compat_adopt(uint64 cr3);
	int64 sys_compat_getpid(void);
	int64 sys_compat_wait4(int64 pid, int32* status, int64 options,
		void* rusage, void* userInfo);
	int64 sys_compat_execve(const void* path, const void* argv,
		const void* envp, void* scratch);
	int64 sys_compat_futex(void* uaddr, int64 op, uint32 val,
		const void* utime, void* uaddr2, uint32 val3);
	int64 sys_compat_poll(void* fds, int64 nfds, int64 timeoutMs,
		void* scratch);
	int64 sys_compat_ppoll(void* fds, int64 nfds, const void* ts,
		void* scratch);
	int64 sys_compat_select(int64 nfds, void* rfds, void* wfds, void* efds,
		void* tv, void* scratch);
	int64 sys_compat_pselect(int64 nfds, void* rfds, void* wfds, void* efds,
		const void* ts, void* scratch);
	int64 sys_compat_mmap(void* addr, uint64 len, int64 prot, int64 flags,
		int64 fd, int64 offset);
	int64 sys_compat_sendfile(int64 outFd, int64 inFd, void* offp,
		uint64 count);
	int64 sys_compat_rename(int64 oldFd, const void* oldPath, int64 newFd,
		const void* newPath);
	int64 sys_compat_symlink(int64 fd, const void* linkPath,
		const void* target);
	int64 sys_compat_link(int64 oldFd, const void* oldPath, int64 newFd,
		const void* newPath, int64 flags);
	int64 sys_compat_readlink(int64 fd, const void* path, void* buf,
		uint64 bufsiz);
	int64 sys_compat_dup(int64 fd);
	int64 sys_compat_dup2(int64 ofd, int64 nfd, int64 flags);
	int64 sys_compat_fsync(int64 fd, int64 dataOnly);
	int64 sys_compat_clock_gettime(int64 clockid, void* tp);
	int64 sys_compat_utimensat(int64 fd, const void* path, const void* times,
		int64 flags);
	int64 sys_compat_time(void* tloc);
	int64 sys_compat_gettimeofday(void* tv, void* tz);
	int64 sys_compat_getppid(void);
	int64 sys_compat_pipe2(void* fds, int64 flags);
	int64 sys_compat_nanosleep(const void* req, void* rem);
	int64 sys_compat_fcntl(int64 fd, int64 cmd, int64 arg);
	int64 sys_compat_statx(int64 fd, const void* path, int64 flags,
		uint32 mask, void* buf);
	int64 sys_compat_try_fork(uint64 userRip, uint64 userRsp, uint64 userFlags);
	void sys_compat_fork_parent_dump(uint64 rip, uint64 rsp, uint64 flags,
		int64 retval);
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

/* COM1 — QEMU -serial file:. dprintf is silent unless
 * serial_debug_output is on; this is not. */
static void
kser_putc(char c)
{
	int i;
	uint8 lsr;

	if (c == '\n')
		kser_putc('\r');
	for (i = 0; i < 100000; i++) {
		__asm__ __volatile__("inb %%dx, %%al"
			: "=a"(lsr) : "d"((uint16)0x3fd));
		if ((lsr & 0x20) != 0)
			break;
	}
	__asm__ __volatile__("outb %%al, %%dx"
		: : "a"((uint8)c), "d"((uint16)0x3f8));
}

static void
kser_puts(const char* s)
{
	while (*s != 0)
		kser_putc(*s++);
}

static void
kser_hex(uint64 v)
{
	static const char h[] = "0123456789abcdef";
	int i;

	kser_putc('0');
	kser_putc('x');
	for (i = 60; i >= 0; i -= 4)
		kser_putc(h[(int)((v >> i) & 0xf)]);
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

#define IA32_FS_BASE 0xc0000100

static void discover_return_to_userland(void);

#ifndef B_SYMBOL_TYPE_TEXT
#define B_SYMBOL_TYPE_TEXT 2
#endif
#ifndef B_SYMBOL_TYPE_ANY
#define B_SYMBOL_TYPE_ANY 5
#endif

static void
discover_vm_map_file(void)
{
	image_info info;
	int32 cookie;
	void* p;
	int n;
	static const char* const knames[] = {
		"_ZL12_vm_map_fileiPKcPPvjmjjbilb",
		NULL
	};
	static const char* const names[] = {
		"vm_map_file",
		"_Z11vm_map_fileiPKcPPvjmjjbil",
		"_Z11vm_map_fileiPKcPPvjmmjbil",
		NULL
	};

	sVmMapFile = 0;
	sVmMapFileK = 0;
	cookie = 0;
	while (get_next_image_info(B_SYSTEM_TEAM, &cookie, &info) == B_OK) {
		for (n = 0; knames[n] != NULL; n++) {
			p = NULL;
			if ((get_image_symbol(info.id, knames[n],
				B_SYMBOL_TYPE_TEXT, &p) == B_OK
				|| get_image_symbol(info.id, knames[n],
				B_SYMBOL_TYPE_ANY, &p) == B_OK) && p != NULL) {
				sVmMapFileK = (haiku_vmmapk_fn)p;
				kser_puts("VMKfn=");
				kser_hex((uint64)(addr_t)p);
				kser_putc('\n');
				break;
			}
		}
		for (n = 0; names[n] != NULL; n++) {
			p = NULL;
			if ((get_image_symbol(info.id, names[n],
				B_SYMBOL_TYPE_TEXT, &p) == B_OK
				|| get_image_symbol(info.id, names[n],
				B_SYMBOL_TYPE_ANY, &p) == B_OK) && p != NULL) {
				sVmMapFile = (haiku_vmmap_fn)p;
				kser_puts("VMfn=");
				kser_hex((uint64)(addr_t)p);
				kser_putc('\n');
				break;
			}
		}
		if (sVmMapFileK != 0 || sVmMapFile != 0)
			break;
	}
	/* Static _vm_map_file is not in the add-on export list.
	 * hrev57937 guest nm: vm_map_file=...c8e0 _vm_map_file=...c180. */
	if (sVmMapFileK == 0 && sVmMapFile != 0
		&& (uint64)(addr_t)sVmMapFile == 0xffffffff8012c8e0ULL)
		sVmMapFileK = (haiku_vmmapk_fn)(addr_t)0xffffffff8012c180ULL;
	if (sVmMapFileK != 0) {
		kser_puts("VMKfn=");
		kser_hex((uint64)(addr_t)sVmMapFileK);
		kser_putc('\n');
	} else if (sVmMapFile == 0)
		kser_puts("VMno\n");
}

static void
discover_syscall_table(void)
{
	const uint8* p;
	int i, j;

	if (sSyscallInfos != NULL || gOrigLstar == 0)
		return;

	p = (const uint8*)(addr_t)gOrigLstar;
	for (i = 0; i < 400; i++) {
		/* shl $4, %rax */
		if (p[i] != 0x48 || p[i + 1] != 0xc1 || p[i + 2] != 0xe0
			|| p[i + 3] != 0x04)
			continue;
		for (j = i + 4; j < i + 24 && j < 400; j++) {
			int32 disp;
			/* leaq disp32(%rax), %rax  = 48 8d 80 xx xx xx xx */
			if (p[j] == 0x48 && p[j + 1] == 0x8d && p[j + 2] == 0x80) {
				disp = (int32)(p[j + 3] | (p[j + 4] << 8)
					| (p[j + 5] << 16) | (p[j + 6] << 24));
				sSyscallInfos = (struct ksc_info*)(addr_t)(int64)disp;
			/* leaq kSyscallInfos(,%rax,1), %rax = 48 8d 04 05 xx */
			} else if (p[j] == 0x48 && p[j + 1] == 0x8d
				&& p[j + 2] == 0x04 && p[j + 3] == 0x05) {
				disp = (int32)(p[j + 4] | (p[j + 5] << 8)
					| (p[j + 6] << 16) | (p[j + 7] << 24));
				sSyscallInfos = (struct ksc_info*)(addr_t)(int64)disp;
			} else
				continue;
			if (sSyscallInfos != NULL) {
				sReadDirFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_READ_DIR].function;
				sReadStatFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_READ_STAT].function;
				sCreateDirFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_CREATE_DIR].function;
				sRemoveDirFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_REMOVE_DIR].function;
				sUnlinkFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_UNLINK].function;
				sAccessFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_ACCESS].function;
				sGetcwdFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_GETCWD].function;
				sSetcwdFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_SETCWD].function;
				sWaitFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_WAIT_CHILD].function;
				sWriteStatFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_WRITE_STAT].function;
				sUnmapFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_UNMAP].function;
				sMprotectFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_MPROTECT].function;
				sRenameThrFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_RENAME_THR].function;
				sRenameFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_RENAME].function;
				sSymlinkFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_SYMLINK].function;
				sLinkFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_LINK].function;
				sReadLinkFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_READ_LINK].function;
				sDupFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_DUP].function;
				sDup2Fn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_DUP2].function;
				sFsyncFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_FSYNC].function;
				sGetClockFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_GET_CLOCK].function;
				sPipeFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_PIPE].function;
				sFcntlFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_FCNTL].function;
				sForkFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_FORK].function;
				sExecFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_EXEC].function;
				sWaitObjFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_WAIT_OBJ].function;
				sMapFileFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_MAP_FILE].function;
				sReadFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_READ].function;
				sWriteFn = (uint64)(addr_t)
					sSyscallInfos[HAIKU_WRITE].function;
			}
			dprintf("[sys_compat] kSyscallInfos=%p read_dir=%#" B_PRIx64
				" read_stat=%#" B_PRIx64 " write_stat=%#" B_PRIx64
				" unmap=%#" B_PRIx64 " mprotect=%#" B_PRIx64
				" rename_thr=%#" B_PRIx64 " exec=%#" B_PRIx64 "\n",
				sSyscallInfos, sReadDirFn, sReadStatFn, sWriteStatFn,
				sUnmapFn, sMprotectFn, sRenameThrFn, sExecFn);
			kser_puts("EXECfn=");
			kser_hex(sExecFn);
			kser_putc('\n');
			kser_puts("WOBJfn=");
			kser_hex(sWaitObjFn);
			kser_putc('\n');
			kser_puts("MAPFfn=");
			kser_hex(sMapFileFn);
			kser_putc('\n');
			discover_return_to_userland();
			return;
		}
	}
	dprintf("[sys_compat] kSyscallInfos scan missed\n");
}

/*
 * x86_return_to_userland in interrupts.S (same TU as LSTAR):
 *   movq %rdi, %rbp ; movq %rbp, %rsp ; movq %gs:0, %r12
 * Official parent/child return: kernel-exit work, CLEAR_FPU,
 * RESTORE_IFRAME, swapgs, iretq. Frame must be on this stack.
 */
static void
discover_return_to_userland(void)
{
	const uint8* p;
	int i;

	sRetUserland = 0;
	if (gOrigLstar == 0)
		return;
	p = (const uint8*)(addr_t)gOrigLstar;
	for (i = 0; i < 65536; i++) {
		if (p[i] == 0x48 && p[i + 1] == 0x89 && p[i + 2] == 0xfd
			&& p[i + 3] == 0x48 && p[i + 4] == 0x89 && p[i + 5] == 0xec
			&& p[i + 6] == 0x65 && p[i + 7] == 0x4c
			&& p[i + 8] == 0x8b && p[i + 9] == 0x24
			&& p[i + 10] == 0x25 && p[i + 11] == 0x00
			&& p[i + 12] == 0x00 && p[i + 13] == 0x00
			&& p[i + 14] == 0x00) {
			sRetUserland = gOrigLstar + (uint64)i;
			dprintf("[sys_compat] x86_return_to_userland=%#" B_PRIx64 "\n",
				sRetUserland);
			kser_puts("RETUfn=");
			kser_hex(sRetUserland);
			kser_putc('\n');
			return;
		}
	}
	dprintf("[sys_compat] x86_return_to_userland scan missed\n");
}

extern "C" int64
sys_compat_getdents64(int64 fd, void* userBuf, uint64 count)
{
	static uint8 sIn[4096];
	static uint8 sOut[4096];
	haiku_read_dir_fn fn;
	int64 nent;
	uint64 inpos, outpos;
	int64 i;

	if (sDentMark != gMarkCount) {
		sDentMark = gMarkCount;
		sDentFallback = 0;
	}
	if (userBuf == NULL || count < 32)
		return -LINUX_EINVAL;
	if (sSyscallInfos == NULL || sReadDirFn == 0)
		return -LINUX_ENOSYS;
	if (count > 4096)
		count = 4096;

	fn = (haiku_read_dir_fn)(addr_t)sReadDirFn;
	nent = fn((int32)fd, userBuf, count, 32);
	sLastNent = nent;
	if (nent < 0) {
		sLastOut = (nent > -4096) ? nent : (int64)(-LINUX_EIO);
		/* Still emit . and .. so ls is not silent while we debug. */
		nent = 0;
	}

	if (user_memcpy(sIn, userBuf, count) != B_OK)
		return -LINUX_EFAULT;

	inpos = 0;
	outpos = 0;
	for (i = 0; i < nent; i++) {
		uint64 ino;
		uint16 hreclen, lreclen;
		uint32 namelen;
		const uint8* name;
		uint64 off;

		/* Haiku dirent: dev_t is 32-bit. ino@8, reclen@24, name@26 or @32. */
		if (inpos + 26 > count)
			break;
		ino = 0;
		hreclen = 0;
		for (int b = 0; b < 8; b++)
			ino |= (uint64)sIn[inpos + 8 + b] << (8 * b);
		hreclen = (uint16)(sIn[inpos + 24] | (sIn[inpos + 25] << 8));
		if (hreclen < 27 || inpos + hreclen > count)
			break;
		name = sIn + inpos + 26;
		if (name[0] == 0 && inpos + 32 < inpos + hreclen)
			name = sIn + inpos + 32;
		namelen = 0;
		while (namelen < 255 && name[namelen] != 0)
			namelen++;
		if (namelen == 0) {
			inpos += hreclen;
			continue;
		}
		lreclen = (uint16)((19 + namelen + 1 + 7) & ~7);
		if (outpos + lreclen > count)
			break;
		for (uint16 z = 0; z < lreclen; z++)
			sOut[outpos + z] = 0;
		for (int b = 0; b < 8; b++)
			sOut[outpos + b] = (uint8)(ino >> (8 * b));
		off = outpos + lreclen;
		for (int b = 0; b < 8; b++)
			sOut[outpos + 8 + b] = (uint8)(off >> (8 * b));
		sOut[outpos + 16] = (uint8)lreclen;
		sOut[outpos + 17] = (uint8)(lreclen >> 8);
		sOut[outpos + 18] = 0;
		for (uint32 n = 0; n < namelen; n++)
			sOut[outpos + 19 + n] = name[n];
		outpos += lreclen;
		inpos += hreclen;
	}

	if (outpos == 0) {
		if (sDentFallback) {
			sLastOut = 0;
			return 0;
		}
		sDentFallback = 1;
		/* Fallback: "." and ".." so a failed convert is visible. */
		sOut[0] = 1;
		for (int b = 1; b < 16; b++)
			sOut[b] = 0;
		sOut[16] = 24;
		sOut[17] = 0;
		sOut[18] = 4; /* DT_DIR */
		sOut[19] = '.';
		sOut[20] = 0;
		sOut[24] = 2;
		for (int b = 25; b < 40; b++)
			sOut[b] = 0;
		sOut[40] = 24;
		sOut[41] = 0;
		sOut[42] = 4;
		sOut[43] = '.';
		sOut[44] = '.';
		sOut[45] = 0;
		outpos = 48;
	}
	sLastOut = (int64)outpos;
	if (user_memcpy(userBuf, sOut, outpos) != B_OK)
		return -LINUX_EFAULT;
	return (int64)outpos;
}

static int64
haiku_status_to_linux(int64 st)
{
	uint32 code;

	if (st >= 0)
		return 0;
	if (st > -4096)
		return st;
	code = (uint32)(int32)st;
	switch (code) {
	case 0x80000000: return -LINUX_ENOMEM;       /* B_NO_MEMORY */
	case 0x80000001: return -LINUX_EIO;          /* B_IO_ERROR */
	case 0x80000002: return -LINUX_EACCES;       /* B_PERMISSION_DENIED */
	case 0x80000005: return -LINUX_EINVAL;       /* B_BAD_VALUE */
	case 0x80000009: return -LINUX_ETIMEDOUT;    /* B_TIMED_OUT */
	case 0x8000000a: return -LINUX_EINTR;        /* B_INTERRUPTED */
	case 0x8000000b: return -LINUX_EAGAIN;       /* B_WOULD_BLOCK */
	case 0x8000000f: return -LINUX_EPERM;        /* B_NOT_ALLOWED */
	case 0x80007002: return -LINUX_ECHILD;       /* ECHILD */
	case 0x80001301: return -LINUX_EFAULT;       /* B_BAD_ADDRESS */
	case 0x80006000: return -LINUX_EBADF;        /* B_FILE_ERROR */
	case 0x80006002: return -LINUX_EEXIST;       /* B_FILE_EXISTS */
	case 0x80006003: return -LINUX_ENOENT;       /* B_ENTRY_NOT_FOUND */
	case 0x80006004: return -LINUX_ENAMETOOLONG; /* B_NAME_TOO_LONG */
	case 0x80006005: return -LINUX_ENOTDIR;      /* B_NOT_A_DIRECTORY */
	case 0x80006009: return -LINUX_EISDIR;       /* B_IS_A_DIRECTORY */
	case 0x8000600e: return -LINUX_ENOSYS;       /* B_UNSUPPORTED */
	default:         return -LINUX_EIO;
	}
}

static void
haiku_stat_to_linux(const struct haiku_stat* h, struct linux_stat* l)
{
	int i;
	uint8* p = (uint8*)l;

	for (i = 0; i < (int)sizeof(*l); i++)
		p[i] = 0;
	l->st_dev = (uint64)(uint32)h->st_dev;
	l->st_ino = (uint64)h->st_ino;
	l->st_nlink = (uint64)(uint32)h->st_nlink;
	l->st_mode = h->st_mode & 0177777;
	l->st_uid = h->st_uid;
	l->st_gid = h->st_gid;
	l->st_rdev = (uint64)(uint32)h->st_rdev;
	l->st_size = h->st_size;
	l->st_blksize = (int64)h->st_blksize;
	l->st_blocks = h->st_blocks;
	l->st_atime = (uint64)h->st_atime;
	l->st_atime_nsec = (uint64)h->st_atime_nsec;
	l->st_mtime = (uint64)h->st_mtime;
	l->st_mtime_nsec = (uint64)h->st_mtime_nsec;
	l->st_ctime = (uint64)h->st_ctime;
	l->st_ctime_nsec = (uint64)h->st_ctime_nsec;
}

extern "C" int64
sys_compat_stat(int64 fd, const void* userPath, void* userStat, int64 flags)
{
	static struct haiku_stat sH;
	static struct linux_stat sL;
	haiku_read_stat_fn fn;
	int32 traverse;
	int32 st;
	const void* path;
	uint8 first;

	sLastStat = 0;
	sLastMode = 0;
	sLastSize = 0;
	if (userStat == NULL)
		return -LINUX_EFAULT;
	if (sSyscallInfos == NULL || sReadStatFn == 0)
		return -LINUX_ENOSYS;

	path = userPath;
	if (path != NULL && (flags & LINUX_AT_EMPTY_PATH) != 0) {
		if (user_memcpy(&first, path, 1) != B_OK)
			return -LINUX_EFAULT;
		if (first == 0)
			path = NULL;
	}

	if (path == NULL || (flags & LINUX_AT_SYMLINK_NOFOLLOW) != 0)
		traverse = 0;
	else
		traverse = 1;

	fn = (haiku_read_stat_fn)(addr_t)sReadStatFn;
	st = fn((int32)fd, path, traverse, userStat, HAIKU_STAT_SIZE);
	sLastStat = (int64)st;
	if (st != 0)
		return haiku_status_to_linux((int64)st);

	if (user_memcpy(&sH, userStat, sizeof(sH)) != B_OK)
		return -LINUX_EFAULT;
	haiku_stat_to_linux(&sH, &sL);
	sLastMode = sL.st_mode;
	sLastSize = sL.st_size;
	if (user_memcpy(userStat, &sL, sizeof(sL)) != B_OK)
		return -LINUX_EFAULT;
	return 0;
}

extern "C" int64
sys_compat_mkdir(int64 fd, const void* path, int64 mode)
{
	haiku_create_dir_fn fn;
	int32 st;

	if (path == NULL)
		return -LINUX_EFAULT;
	if (sCreateDirFn == 0)
		return -LINUX_ENOSYS;
	fn = (haiku_create_dir_fn)(addr_t)sCreateDirFn;
	st = fn((int32)fd, path, (int32)(mode & 07777));
	sLastPath = (int64)st;
	return haiku_status_to_linux((int64)st);
}

extern "C" int64
sys_compat_unlink(int64 fd, const void* path, int64 flags)
{
	int32 st;

	if (path == NULL)
		return -LINUX_EFAULT;
	/* Linux AT_REMOVEDIR = 0x200 */
	if ((flags & 0x200) != 0) {
		haiku_path2_fn fn;
		if (sRemoveDirFn == 0)
			return -LINUX_ENOSYS;
		fn = (haiku_path2_fn)(addr_t)sRemoveDirFn;
		st = fn((int32)fd, path);
	} else {
		haiku_path2_fn fn;
		if (sUnlinkFn == 0)
			return -LINUX_ENOSYS;
		fn = (haiku_path2_fn)(addr_t)sUnlinkFn;
		st = fn((int32)fd, path);
	}
	sLastPath = (int64)st;
	return haiku_status_to_linux((int64)st);
}

extern "C" int64
sys_compat_access(int64 fd, const void* path, int64 mode)
{
	haiku_access_fn fn;
	int32 st;

	if (path == NULL)
		return -LINUX_EFAULT;
	if (sAccessFn == 0)
		return -LINUX_ENOSYS;
	fn = (haiku_access_fn)(addr_t)sAccessFn;
	st = fn((int32)fd, path, (int32)mode, 0);
	sLastPath = (int64)st;
	return haiku_status_to_linux((int64)st);
}

extern "C" int64
sys_compat_getcwd(void* buf, uint64 size)
{
	haiku_getcwd_fn fn;
	int32 st;

	if (buf == NULL || size == 0)
		return -LINUX_EINVAL;
	if (sGetcwdFn == 0)
		return -LINUX_ENOSYS;
	fn = (haiku_getcwd_fn)(addr_t)sGetcwdFn;
	st = fn(buf, size);
	sLastPath = (int64)st;
	if (st != 0)
		return haiku_status_to_linux((int64)st);
	/* Linux getcwd returns the buffer pointer on success. */
	return (int64)(addr_t)buf;
}

extern "C" int64
sys_compat_chdir(int64 fd, const void* path)
{
	haiku_setcwd_fn fn;
	int32 st;

	if (sSetcwdFn == 0)
		return -LINUX_ENOSYS;
	/* fchdir: path NULL, fd is the directory. chdir: fd=AT_FDCWD. */
	fn = (haiku_setcwd_fn)(addr_t)sSetcwdFn;
	st = fn((int32)fd, path);
	sLastPath = (int64)st;
	return haiku_status_to_linux((int64)st);
}

static void
linux_clear_all(void)
{
	int i;

	for (i = 0; i < LINUX_MARK_SLOTS; i++) {
		gLinuxCR3[i] = 0;
		gLinuxTeam[i] = 0;
	}
	gLinuxN = 0;
}

static int copy_user_cstr(char* dst, const void* user, int max);

static int
linux_slot_by_cr3(uint64 cr3)
{
	int i;

	for (i = 0; i < LINUX_MARK_SLOTS; i++) {
		if (gLinuxCR3[i] == cr3)
			return i;
	}
	return -1;
}

extern "C" int64
sys_compat_mark_team(void)
{
	team_info info;
	uint64 cr3;
	int slot;

	if (get_team_info(B_CURRENT_TEAM, &info) != B_OK)
		return -1;
	cr3 = read_cr3() & ~(uint64)0xfff;
	slot = linux_slot_by_cr3(cr3);
	if (slot < 0)
		slot = 0;
	gLinuxTeam[slot] = info.team;
	if (gMarkExe != 0 && ((uint64)gMarkExe) >= 0x100000ULL)
		copy_user_cstr(sLinuxExe, (const void*)(addr_t)gMarkExe, 256);
	if (gLinuxN == 0)
		gLinuxN = 1;
	sHaveUid = 0;
	sHaveGid = 0;
	sClearTid = 0;
	sRobustList = 0;
	sRobustLen = 0;
	dprintf("[sys_compat] mark team=%" B_PRId32 " parent=%" B_PRId32 "\n",
		info.team, info.parent);
	kser_puts("MARK team=");
	kser_hex((uint64)(uint32)info.team);
	kser_putc('\n');
	return info.team;
}

extern "C" int64
sys_compat_adopt(uint64 cr3)
{
	team_info info;
	int i, j;

	if (cr3 == 0 || gLinuxN == 0)
		return 0;
	if (linux_slot_by_cr3(cr3) >= 0)
		return 1;
	if (get_team_info(B_CURRENT_TEAM, &info) != B_OK)
		return 0;
	for (i = 0; i < LINUX_MARK_SLOTS; i++) {
		if (gLinuxTeam[i] == 0 || gLinuxTeam[i] != info.parent)
			continue;
		for (j = 0; j < LINUX_MARK_SLOTS; j++) {
			if (gLinuxCR3[j] != 0)
				continue;
			gLinuxCR3[j] = cr3;
			gLinuxTeam[j] = info.team;
			gLinuxN++;
			dprintf("[sys_compat] adopt cr3=%#" B_PRIx64 " team=%" B_PRId32
				" parent=%" B_PRId32 "\n", cr3, info.team, info.parent);
			return 1;
		}
		return 0;
	}
	return 0;
}

extern "C" int64
sys_compat_getpid(void)
{
	team_info info;
	int32 tid;
	uint64 p;

	if (get_team_info(B_CURRENT_TEAM, &info) != B_OK)
		return 1;
	/* CLONE_CHILD_SETTID: write tid in the *child* aspace.
	 * Saved r10 at clone. First child syscall is tramp getpid. */
	p = gForkChildTid;
	if (p >= 0x100000ULL) {
		tid = find_thread(NULL);
		if (user_memcpy((void*)(addr_t)p, &tid, 4) == B_OK)
			kser_puts("T\n");
		gForkChildTid = 0;
	}
	return info.team;
}

/* x86_64 Haiku iframe — must match headers/private/kernel/arch/x86/64/iframe.h */
struct haiku_iframe {
	uint64 type;
	uint64 fpu;
	uint64 r15, r14, r13, r12, r11, r10, r9, r8;
	uint64 bp, si, di, dx, cx, bx, ax;
	uint64 orig_rax;
	uint64 vector;
	uint64 error_code;
	uint64 ip;
	uint64 cs;
	uint64 flags;
	uint64 sp;
	uint64 ss;
};

#define IFRAME_TYPE_SYSCALL 1
#define USER_CS 0x2b	/* (USER_CODE_SEGMENT<<3)|DPL_USER */
#define USER_SS 0x23	/* (USER_DATA_SEGMENT<<3)|DPL_USER */

static struct haiku_iframe sParentFrame;
static uint8 sParkStub[2];
static uint8 sSwitchStub[32];

static int
kstack_top_ok(uint64 top)
{
	/* syscall_rsp is page-aligned kernel_stack_top. Reject kernel
	 * text (below ~0xffffffff81000000) and non-canonical / user
	 * addresses. Do not use 0xffffff0000000000 as an upper bound:
	 * that is *below* 0xffffffff8xxxxxxx (Haiku kstacks live there). */
	if ((top & 0xfff) != 0)
		return 0;
	if (top < 0xffffffff81000000ULL)
		return 0;
	return 1;
}

static uint64
scan_thread_kstack_top(uint64 thr)
{
	uint64* p;
	int i;

	if (thr < 0xffff800000000000ULL)
		return 0;
	p = (uint64*)(addr_t)thr;
	for (i = 2; i < 200; i++) {
		uint64 top = p[i];
		uint64 base = p[i - 1];
		uint64 span;

		if ((top & 0xfff) != 0 || (base & 0xfff) != 0)
			continue;
		if (top <= base)
			continue;
		span = top - base;
		if (span != 0x4000 && span != 0x5000)
			continue;
		if (!kstack_top_ok(top))
			continue;
		return top;
	}
	return 0;
}

extern "C" int64
sys_compat_try_fork(uint64 userRip, uint64 userRsp, uint64 userFlags)
{
	haiku_fork_fn fn;
	int32 st;
	uint64 gs0, gs8, ktop, saved_rsp;
	uint64 postRet;
	struct haiku_iframe* f;
	uint8* q;
	int j;

	sLastFork = 0;
	sChildRobust = 0;
	sChildDone = 0;
	sStackSnapAt = 0;
	sForkGs0 = 0;
	sForkGs8 = 0;
	sForkKtop = 0;
	/* Official contract: interrupts off until RBP=iframe on the
	 * thread kstack. gKstack is not in kernel_stack_base..top. */
	__asm__ __volatile__("cli");
	kser_puts("F2 rip=");
	kser_hex(userRip);
	kser_puts(" rsp=");
	kser_hex(userRsp);
	kser_puts(" tramp=");
	kser_hex(gForkTramp);
	kser_puts(" hrsp=");
	kser_hex(gForkHaikuRsp);
	{
		uint32 lo, hi;
		__asm__ __volatile__("rdmsr" : "=a"(lo), "=d"(hi) : "c"(0xC0000100));
		gForkFS = ((uint64)hi << 32) | (uint64)lo;
	}
	kser_puts(" fs=");
	kser_hex(gForkFS);
	kser_putc('\n');
	/* Return-slot snapshot lives in BSS. try_fork locals sit on
	 * gKstack; the child getpid/set_robust C path reuses it and
	 * was smashing preRet — that was the fake COM1 N. */
	kser_puts("bx=");
	kser_hex(gForkRbx);
	kser_puts(" bp=");
	kser_hex(gForkUserRbp);
	kser_putc('\n');
	gForkRetAddr = 0;
	__asm__ __volatile__("sti");
	if (userRsp >= 0x100000ULL
		&& user_memcpy(&gForkRetAddr, (void*)(addr_t)userRsp, 8) == B_OK) {
		kser_puts("K");
		kser_hex(gForkRetAddr);
		kser_putc('\n');
		if (user_memcpy(sStackSnap, (void*)(addr_t)userRsp,
			sizeof(sStackSnap)) == B_OK)
			sStackSnapAt = userRsp;
	} else
		kser_puts("K?\n");
	__asm__ __volatile__("cli");
	dprintf("[sys_compat] try_fork rip=%#" B_PRIx64 " rsp=%#" B_PRIx64
		" fl=%#" B_PRIx64 " fn=%#" B_PRIx64 "\n",
		userRip, userRsp, userFlags, sForkFn);
	if (sForkFn == 0 || userRip < 0x1000 || userRsp < 0x1000) {
		sLastFork = -LINUX_ENOSYS;
		return -LINUX_ENOSYS;
	}

	/* After the hook swapgs, GS is arch_thread: gs:0=Thread*,
	 * gs:8=syscall_rsp=kernel_stack_top. */
	__asm__ __volatile__("movq %%gs:0, %0" : "=r"(gs0));
	__asm__ __volatile__("movq %%gs:8, %0" : "=r"(gs8));
	sForkGs0 = gs0;
	sForkGs8 = gs8;

	/* Haiku contract (arch_thread.cpp): _user_fork -> fork_team ->
	 * arch_store_fork_frame -> x86_get_current_iframe(). That walks
	 * RBP only inside Thread.kernel_stack_base..top and treats a
	 * frame whose first qword is an iframe type (low 4 bits) as the
	 * syscall iframe. Official SYSCALL entry plants that iframe at
	 * kernel_stack_top and sets RBP=RSP=iframe. Calling _user_fork
	 * from a driver on gKstack without that layout yields NULL
	 * iframe (KDL) or a smashed copy (child iretq reboot).
	 * Plant on the *real* kstack, above the call, matching entry.S.
	 * Do not patch Thread.kernel_stack_* (immutable after create). */
	ktop = kstack_top_ok(gs8) ? gs8 : scan_thread_kstack_top(gs0);
	sForkKtop = ktop;
	dprintf("[sys_compat] gs0=%#" B_PRIx64 " gs8=%#" B_PRIx64
		" ktop=%#" B_PRIx64 "\n", gs0, gs8, ktop);
	if (ktop == 0) {
		sLastFork = -LINUX_EFAULT;
		return -LINUX_EFAULT;
	}

	f = (struct haiku_iframe*)((ktop - sizeof(*f)) & ~(uint64)15);
	if ((uint64)(addr_t)f + sizeof(*f) > ktop
		|| (uint64)(addr_t)f < ktop - 0x5000) {
		sLastFork = -LINUX_EFAULT;
		return -LINUX_EFAULT;
	}
	q = (uint8*)f;
	for (j = 0; j < (int)sizeof(*f); j++)
		q[j] = 0;
	f->type = IFRAME_TYPE_SYSCALL;
	/* Child IRETQ to a trampoline on the Haiku loader stack, then
	 * the tramp switches to Linux RSP and jumps to the clone return.
	 * Direct IRETQ to Linux RIP+RSP still Kill-Thread'd busybox sh
	 * (COM1 Tt flood, no S). hello_pipeline is asm and never rets. */
	if (gForkTramp >= 0x100000ULL && userRip >= 0x100000ULL
		&& userRsp >= 0x100000ULL) {
		uint8 tb[35];
		int bi;
		uint64 child_sp;
		/* getpid from tramp page: stamp CR3 + apply_fs.
		 * xor eax,eax so clone return still looks like the child
		 * (hello_pipeline tests rax). Then Linux RSP + jmp.
		 * b8 27 00 00 00     mov $39,%eax
		 * 0f 05              syscall
		 * 31 c0              xor %eax,%eax
		 * 49 bb <rsp>        movabs $userRsp,%r11
		 * 4c 89 dc           mov %r11,%rsp
		 * 49 bb <rip>        movabs $userRip,%r11
		 * 41 ff e3           jmp *%r11 */
		tb[0] = 0xb8;
		tb[1] = 0x27;
		tb[2] = 0x00;
		tb[3] = 0x00;
		tb[4] = 0x00;
		tb[5] = 0x0f;
		tb[6] = 0x05;
		tb[7] = 0x31;
		tb[8] = 0xc0;
		/* Child rets through this frame. The real Linux stack
		 * is COW with the parent; parent already ret'd and
		 * reused it (SFgb then Kill Thread, no x). Private
		 * copy on the tramp page. */
		child_sp = gForkTramp + 0x200;
		tb[9] = 0x49;
		tb[10] = 0xbb;
		/* Parent is held in kernel until set_robust, so the
		 * real Linux stack is still intact. Use it. */
		child_sp = userRsp;
		for (bi = 0; bi < 8; bi++)
			tb[11 + bi] = (uint8)(child_sp >> (8 * bi));
		tb[19] = 0x4c;
		tb[20] = 0x89;
		tb[21] = 0xdc;
		tb[22] = 0x49;
		tb[23] = 0xbb;
		for (bi = 0; bi < 8; bi++)
			tb[24 + bi] = (uint8)(userRip >> (8 * bi));
		tb[32] = 0x41;
		tb[33] = 0xff;
		tb[34] = 0xe3;
		__asm__ __volatile__("sti");
		if (user_memcpy((void*)(addr_t)gForkTramp, tb, 35) == B_OK) {
			f->ip = gForkTramp;
			kser_puts("J\n");
		} else if (userRip >= 0x100000ULL)
			f->ip = userRip;
	} else if (userRip >= 0x100000ULL)
		f->ip = userRip;
	else if (gForkTramp >= 0x100000ULL)
		f->ip = gForkTramp;
	f->cs = USER_CS;
	/* Official enter_userspace: RESERVED1|IF only (0x202).
	 * userFlags|0x202 can leave VM/NT/IOPL/RF and IRETQ #GPs. */
	f->flags = 0x202;
	if (gForkHaikuRsp >= 0x100000ULL)
		f->sp = gForkHaikuRsp;
	else
		f->sp = userRsp;
	f->ss = USER_SS;
	f->vector = 99;
	f->ax = 0;
	if (gForkUserRbp >= 0x100000ULL)
		f->bp = gForkUserRbp;
	/* Syscall must preserve rbx/r12-r15. A zeroed iframe made
	 * busybox's parent die after IRETQ before the second clone
	 * (echo | cat forks twice; we only ever saw one F2). */
	f->bx = gForkRbx;
	f->r12 = gForkR12;
	f->r13 = gForkR13;
	f->r14 = gForkR14;
	f->r15 = gForkR15;

	/* Short breadcrumb only. Long F4 kser dump under CLI
	 * repeatedly #PF'd (ip 0 / 0xfb) before _user_fork. */
	kser_puts("F4\n");

	fn = (haiku_fork_fn)(addr_t)sForkFn;
	__asm__ __volatile__("movq %%rsp, %0" : "=r"(saved_rsp));
	{
		register uint64 fnr asm("r13") = (uint64)(addr_t)fn;
		register uint64 fr asm("r15") = (uint64)(addr_t)f;
		register uint64 oldsp asm("r14") = saved_rsp;
		__asm__ __volatile__(
			"movq	%%rbp, %%r12\n\t"
			"movq	%%r15, %%rsp\n\t"
			"movq	%%r15, %%rbp\n\t"
			"sti\n\t"
			"callq	*%%r13\n\t"
			"cli\n\t"
			"movq	%%r14, %%rsp\n\t"
			"movq	%%r12, %%rbp\n\t"
			: "=a"(st)
			: "r"(fnr), "r"(fr), "r"(oldsp)
			: "rcx", "rdx", "rsi", "rdi",
			  "r8", "r9", "r10", "r11",
			  "r12", "memory"
		);
	}
	sLastFork = (int64)st;
	kser_puts("5");
	if (st < 0)
		return haiku_status_to_linux((int64)st);

	/* Stay CLI. Child IRETQs to the tramp and only then switches
	 * to the Linux stack. Holding until set_robust let the child
	 * ret+push on that stack first (COM1 N) and the parent died
	 * on its own ret. IRETQ now, while the child is still on the
	 * tramp / in getpid. */

	/* Parent is already marked. Do not smash gLinuxCR3[0] —
	 * that unmarked a sibling when slot 0 was not this team. */

	/* After the child has run (set_robust + often a ret on the
	 * Linux stack), see whether [userRsp] still matches the
	 * pre-fork snapshot. 'k=' same (COW held), 'k!' child wrote
	 * through into the parent. */

	/* Parent return: copy iframe onto THIS stack (gKstack) and
	 * call official x86_return_to_userland. Child already copied
	 * iframe.ip=Linux RIP during fork. Do not IRETQ from the planted
	 * kstack frame (C sat on that stack once and got smashed).
	 * Do not return to the hook if we have the official path —
	 * homemade 5-push skipped kernel-exit / FPU clear. */
	{
		/* Frame MUST sit on gKstack. x86_return_to_userland
		 * does mov rsp,rdi then calls system_time — a BSS
		 * iframe has no stack below it and smashes globals.
		 * The COM1 'U' success used a local here. */
		struct haiku_iframe local;
		typedef void (*ret_fn)(struct haiku_iframe*);
		ret_fn ret;
		int n;

		q = (uint8*)f;
		for (n = 0; n < (int)sizeof(local); n++)
			((uint8*)&local)[n] = q[n];
		local.ax = (uint64)(uint32)st;
		/* Same Linux RIP/RSP as the child. Haiku loader RSP
		 * here sent busybox's clone `ret` into junk. */
		if (userRip >= 0x100000ULL)
			local.ip = userRip;
		else if (gForkTramp >= 0x100000ULL)
			local.ip = gForkTramp + 64;
		/* No STI. Child stamp/getpid uses gKstack; we still
		 * sit on it. RB2 5Y then KDL ip=0x3. */
		if (userRsp >= 0x100000ULL)
			local.sp = userRsp;
		else if (gForkHaikuRsp >= 0x100000ULL)
			local.sp = gForkHaikuRsp;
		/* Same IRETQ flags as the live COM1 'U' run. 0x202
		 * (no IOPL) reset after R with this tramp+64 landing. */
		local.flags = 0x3202;
		if (gForkUserRbp >= 0x100000ULL)
			local.bp = gForkUserRbp;
		local.bx = gForkRbx;
		local.r12 = gForkR12;
		local.r13 = gForkR13;
		local.r14 = gForkR14;
		local.r15 = gForkR15;
		kser_puts("R\n");
		if (sRetUserland >= 0xffffffff80000000ULL) {
			ret = (ret_fn)(addr_t)sRetUserland;
			__asm__ __volatile__("cli");
			ret(&local);
		}
	}
	return (int64)st;
}

extern "C" void
sys_compat_fork_parent_dump(uint64 rip, uint64 rsp, uint64 flags, int64 retval)
{
	/* Still on gKstack, kernel GS, interrupts off. Print the exact
	 * SYSRET state before we load user RSP. */
	kser_puts("P rip=");
	kser_hex(rip);
	kser_puts(" rsp=");
	kser_hex(rsp);
	kser_puts(" fl=");
	kser_hex(flags);
	kser_puts(" ax=");
	kser_hex((uint64)retval);
	kser_putc('\n');
	dprintf("[sys_compat] parent sysret rip=%#" B_PRIx64 " rsp=%#" B_PRIx64
		" fl=%#" B_PRIx64 " ax=%" B_PRId64 "\n",
		rip, rsp, flags, retval);
}

extern "C" int64
sys_compat_wait4(int64 pid, int32* status, int64 options, void* rusage,
	void* userInfo)
{
	haiku_wait_child_fn fn;
	uint32 hflags;
	int32 st;
	uint8 info[64];
	int32 code, exitst;
	int32 lstatus;

	(void)rusage;
	sLastWait = 0;
	if (sWaitFn == 0)
		return -LINUX_ENOSYS;
	hflags = HAIKU_WEXITED;
	if ((options & 1) != 0)
		hflags |= HAIKU_WNOHANG;
	if ((options & 2) != 0)
		hflags |= HAIKU_WUNTRACED | HAIKU_WSTOPPED;
	fn = (haiku_wait_child_fn)(addr_t)sWaitFn;
	st = fn((int32)pid, hflags, userInfo, NULL);
	sLastWait = (int64)st;
	if (st == (int32)0x8000000b) /* B_WOULD_BLOCK */
		return 0;
	if (st < 0)
		return haiku_status_to_linux((int64)st);
	if (status != NULL && userInfo != NULL) {
		if (user_memcpy(info, userInfo, sizeof(info)) != B_OK)
			return -LINUX_EFAULT;
		code = (int32)(info[4] | (info[5] << 8) | (info[6] << 16)
			| (info[7] << 24));
		exitst = (int32)(info[32] | (info[33] << 8) | (info[34] << 16)
			| (info[35] << 24));
		lstatus = 0;
		if (code == HAIKU_CLD_EXITED)
			lstatus = (exitst & 0xff) << 8;
		else if (code == HAIKU_CLD_KILLED)
			lstatus = exitst & 0x7f;
		else if (code == HAIKU_CLD_DUMPED)
			lstatus = (exitst & 0x7f) | 0x80;
		else if (code == HAIKU_CLD_STOPPED)
			lstatus = 0x7f | ((exitst & 0xff) << 8);
		else if (code == HAIKU_CLD_CONTINUED)
			lstatus = 0xffff;
		if (user_memcpy(status, &lstatus, sizeof(lstatus)) != B_OK)
			return -LINUX_EFAULT;
	}
	return st;
}

#define EXEC_MAX_VEC 16
#define EXEC_MAX_STR 255
#define EXEC_SCRATCH 4096

static const char sLoaderPath[] = "/boot/home/sys_compat_run";

#define LINUX_FUTEX_WAIT         0
#define LINUX_FUTEX_WAKE         1
#define LINUX_FUTEX_REQUEUE      3
#define LINUX_FUTEX_CMP_REQUEUE  4
#define LINUX_FUTEX_WAIT_BITSET  9
#define LINUX_FUTEX_WAKE_BITSET  10
#define LINUX_FUTEX_CMD_MASK     127
#define FUTEX_SLOTS              32

struct futex_waiter {
	uint64 addr;
	sem_id sem;
};

static sem_id sFutexMu = -1;
static struct futex_waiter sFutexW[FUTEX_SLOTS];
/* Flatten lives in BSS — 12 KB of autos overflowed the 16 KB kstack
 * and left leftover user RBP as the frame pointer. */
static char sExecLinuxPath[256];
static char sExecBuf[EXEC_SCRATCH];
static char sExecArgStore[EXEC_MAX_VEC][EXEC_MAX_STR];
static char sExecEnvStore[EXEC_MAX_VEC][EXEC_MAX_STR];

static int
copy_user_cstr(char* dst, const void* user, int max)
{
	int i;

	if (user == NULL || max < 2)
		return -1;
	for (i = 0; i < max - 1; i++) {
		if (user_memcpy(dst + i, (const uint8*)user + (uint32)i, 1) != B_OK)
			return -1;
		if (dst[i] == 0)
			return i;
	}
	dst[max - 1] = 0;
	return -2;
}

static int
count_user_vec(const void* vec, int maxn)
{
	int n;
	uint64 p;

	if (vec == NULL)
		return 0;
	for (n = 0; n < maxn; n++) {
		if (user_memcpy(&p, (const uint8*)vec + (uint32)n * 8, 8) != B_OK)
			return -1;
		if (p == 0)
			return n;
	}
	return -2;
}

/*
 * Linux execve(path, argv, envp) → Haiku _user_exec of the loader:
 *   sys_compat_run <path> [argv[1]...]
 * Path and flatArgs must be user addresses. On success this does not
 * return. Unmark this CR3 first so the loader is not treated as Linux.
 */
extern "C" int64
sys_compat_execve(const void* path, const void* argv, const void* envp,
	void* scratch)
{
	haiku_exec_fn fn;
	uint64 up;
	int narg, nenv, extra, i, argCount, envCount, nslot;
	int slen, off;
	uint64* slots;
	char* strs;
	int32 st;
	uint64 cr3;
	int slot;

	kser_puts("XEC\n");
	sChildDone = 1;
	if (sExecFn == 0)
		return -LINUX_ENOSYS;
	if (path == NULL || scratch == NULL)
		return -LINUX_EFAULT;
	if (((uint64)(addr_t)scratch) < 0x100000ULL)
		return -LINUX_EFAULT;
	if (copy_user_cstr(sExecLinuxPath, path, (int)sizeof(sExecLinuxPath)) < 0)
		return -LINUX_EFAULT;
	{
		int i, same;
		const char* pse = "/proc/self/exe";

		same = 1;
		for (i = 0; pse[i] != 0; i++) {
			if (sExecLinuxPath[i] != pse[i]) {
				same = 0;
				break;
			}
		}
		if (same && sExecLinuxPath[i] == 0 && sLinuxExe[0] != 0) {
			for (i = 0; i < 256; i++) {
				sExecLinuxPath[i] = sLinuxExe[i];
				if (sLinuxExe[i] == 0)
					break;
			}
		}
	}
	kser_puts(sExecLinuxPath);
	kser_putc('\n');
	narg = count_user_vec(argv, EXEC_MAX_VEC);
	nenv = count_user_vec(envp, EXEC_MAX_VEC);
	kser_puts("narg=");
	kser_hex((uint64)(uint32)narg);
	kser_puts(" nenv=");
	kser_hex((uint64)(uint32)nenv);
	kser_putc('\n');
	if (narg < 0 || nenv < 0)
		return -LINUX_EFAULT;
	/* loader + linux ELF path + full argv (argv[0] may be "cat"). */
	extra = (narg > 0) ? narg : 0;
	argCount = 2 + extra;
	envCount = nenv;
	nslot = argCount + 1 + envCount + 1;
	if ((int)sizeof(uint64) * nslot + 512 > EXEC_SCRATCH)
		return -LINUX_E2BIG;

	for (i = 0; i < extra; i++) {
		if (user_memcpy(&up, (const uint8*)argv + (uint32)i * 8, 8)
			!= B_OK)
			return -LINUX_EFAULT;
		if (copy_user_cstr(sExecArgStore[i], (const void*)(addr_t)up,
			EXEC_MAX_STR) < 0)
			return -LINUX_EFAULT;
	}
	for (i = 0; i < envCount; i++) {
		if (user_memcpy(&up, (const uint8*)envp + (uint32)i * 8, 8) != B_OK)
			return -LINUX_EFAULT;
		if (copy_user_cstr(sExecEnvStore[i], (const void*)(addr_t)up,
			EXEC_MAX_STR) < 0)
			return -LINUX_EFAULT;
	}

	for (i = 0; i < EXEC_SCRATCH; i++)
		sExecBuf[i] = 0;
	slots = (uint64*)(void*)sExecBuf;
	strs = sExecBuf + sizeof(uint64) * (uint32)nslot;
	off = 0;
	/* slot 0: loader */
	slen = 0;
	while (sLoaderPath[slen] != 0)
		slen++;
	slen++;
	for (i = 0; i < slen; i++)
		strs[off + i] = sLoaderPath[i];
	slots[0] = (uint64)(addr_t)scratch + (uint64)(strs + off - sExecBuf);
	off += slen;
	/* slot 1: linux path */
	slen = 0;
	while (sExecLinuxPath[slen] != 0)
		slen++;
	slen++;
	for (i = 0; i < slen; i++)
		strs[off + i] = sExecLinuxPath[i];
	slots[1] = (uint64)(addr_t)scratch + (uint64)(strs + off - sExecBuf);
	off += slen;
	for (i = 0; i < extra; i++) {
		slen = 0;
		while (sExecArgStore[i][slen] != 0)
			slen++;
		slen++;
		for (int k = 0; k < slen; k++)
			strs[off + k] = sExecArgStore[i][k];
		slots[2 + i] = (uint64)(addr_t)scratch
			+ (uint64)(strs + off - sExecBuf);
		off += slen;
	}
	slots[argCount] = 0;
	for (i = 0; i < envCount; i++) {
		slen = 0;
		while (sExecEnvStore[i][slen] != 0)
			slen++;
		slen++;
		for (int k = 0; k < slen; k++)
			strs[off + k] = sExecEnvStore[i][k];
		slots[argCount + 1 + i] = (uint64)(addr_t)scratch
			+ (uint64)(strs + off - sExecBuf);
		off += slen;
	}
	slots[argCount + 1 + envCount] = 0;
	slen = (int)(strs + off - sExecBuf);
	kser_puts("slen=");
	kser_hex((uint64)(uint32)slen);
	kser_putc('\n');
	if (slen > 512)
		return -LINUX_E2BIG;
	if (user_memcpy(scratch, sExecBuf, (size_t)slen) != B_OK) {
		kser_puts("XCP\n");
		return -LINUX_EFAULT;
	}

	cr3 = read_cr3() & ~(uint64)0xfff;
	slot = linux_slot_by_cr3(cr3);
	if (slot >= 0) {
		gLinuxCR3[slot] = 0;
		gLinuxTeam[slot] = 0;
		if (gLinuxN > 0)
			gLinuxN--;
	}
	gForkPending = 0;

	fn = (haiku_exec_fn)(addr_t)sExecFn;
	kser_puts("XGO\n");
	/* path must be a user address — slot 0 is the loader string. */
	st = fn((const void*)(addr_t)slots[0], scratch, (uint64)slen,
		argCount, envCount, 022);
	/* returned = failure. Restore the mark. */
	kser_puts("XNO st=");
	kser_hex((uint64)(uint32)st);
	kser_putc('\n');
	if (linux_slot_by_cr3(cr3) < 0) {
		for (i = 0; i < LINUX_MARK_SLOTS; i++) {
			if (gLinuxCR3[i] == 0) {
				gLinuxCR3[i] = cr3;
				gLinuxN++;
				break;
			}
		}
	}
	return haiku_status_to_linux((int64)st);
}

static int64
futex_copy_timespec(const void* user, uint64* usec)
{
	uint8 ts[16];
	uint64 sec, nsec;
	int i;

	if (user == NULL) {
		*usec = 0;
		return 0;
	}
	if (user_memcpy(ts, user, 16) != B_OK)
		return -LINUX_EFAULT;
	sec = 0;
	nsec = 0;
	for (i = 0; i < 8; i++) {
		sec |= (uint64)ts[i] << (8 * i);
		nsec |= (uint64)ts[8 + i] << (8 * i);
	}
	if ((int64)sec < 0 || nsec >= 1000000000ULL)
		return -LINUX_EINVAL;
	if (sec > 0xffffffffULL / 1000000ULL)
		*usec = 0xffffffffULL;
	else
		*usec = sec * 1000000ULL + nsec / 1000ULL;
	return 0;
}

/*
 * Linux futex WAIT/WAKE. Park on a per-waiter Haiku sem.
 * Call this on the official per-thread kstack (not gKstack) so a
 * blocked WAIT does not sit on the global C stack.
 */
extern "C" int64
sys_compat_futex(void* uaddr, int64 op, uint32 val, const void* utime,
	void* uaddr2, uint32 val3)
{
	int32 cmd;
	int32 cur;
	int i, slot, woken;
	int64 err;
	uint64 usec;
	status_t st;
	sem_id waitSem;
	int timed;
	int relative;

	(void)uaddr2;
	(void)val3;
	if (sFutexMu < 0)
		return -LINUX_ENOSYS;
	if (uaddr == NULL || ((uint64)(addr_t)uaddr) < 0x100000ULL)
		return -LINUX_EFAULT;
	if (((uint64)(addr_t)uaddr) & 3)
		return -LINUX_EINVAL;
	cmd = (int32)op & LINUX_FUTEX_CMD_MASK;

	if (cmd == LINUX_FUTEX_WAKE || cmd == LINUX_FUTEX_WAKE_BITSET
		|| cmd == LINUX_FUTEX_REQUEUE || cmd == LINUX_FUTEX_CMP_REQUEUE) {
		if (cmd == LINUX_FUTEX_WAKE_BITSET && val3 == 0)
			return -LINUX_EINVAL;
		acquire_sem(sFutexMu);
		woken = 0;
		for (i = 0; i < FUTEX_SLOTS && woken < (int)val; i++) {
			if (sFutexW[i].addr == (uint64)(addr_t)uaddr
				&& sFutexW[i].sem >= 0) {
				release_sem(sFutexW[i].sem);
				woken++;
			}
		}
		release_sem(sFutexMu);
		return (int64)woken;
	}

	if (cmd != LINUX_FUTEX_WAIT && cmd != LINUX_FUTEX_WAIT_BITSET)
		return -LINUX_ENOSYS;
	if (cmd == LINUX_FUTEX_WAIT_BITSET && val3 == 0)
		return -LINUX_EINVAL;

	timed = 0;
	relative = (cmd == LINUX_FUTEX_WAIT);
	usec = 0;
	if (utime != NULL) {
		err = futex_copy_timespec(utime, &usec);
		if (err < 0)
			return err;
		timed = 1;
	}

	if (user_memcpy(&cur, uaddr, 4) != B_OK)
		return -LINUX_EFAULT;
	if (cur != (int32)val)
		return -LINUX_EAGAIN;
	if (timed && relative && usec == 0)
		return -LINUX_ETIMEDOUT;

	waitSem = create_sem(0, "sys_compat_fwait");
	if (waitSem < 0)
		return -LINUX_ENOMEM;

	acquire_sem(sFutexMu);
	if (user_memcpy(&cur, uaddr, 4) != B_OK) {
		release_sem(sFutexMu);
		delete_sem(waitSem);
		return -LINUX_EFAULT;
	}
	if (cur != (int32)val) {
		release_sem(sFutexMu);
		delete_sem(waitSem);
		return -LINUX_EAGAIN;
	}
	slot = -1;
	for (i = 0; i < FUTEX_SLOTS; i++) {
		if (sFutexW[i].sem < 0 || sFutexW[i].addr == 0) {
			sFutexW[i].addr = (uint64)(addr_t)uaddr;
			sFutexW[i].sem = waitSem;
			slot = i;
			break;
		}
	}
	release_sem(sFutexMu);
	if (slot < 0) {
		delete_sem(waitSem);
		return -LINUX_ENOMEM;
	}

	if (!timed)
		st = acquire_sem(waitSem);
	else if (relative)
		st = acquire_sem_etc(waitSem, 1, B_RELATIVE_TIMEOUT,
			(bigtime_t)usec);
	else
		st = acquire_sem_etc(waitSem, 1, B_ABSOLUTE_REAL_TIME_TIMEOUT,
			(bigtime_t)usec);

	acquire_sem(sFutexMu);
	sFutexW[slot].addr = 0;
	sFutexW[slot].sem = -1;
	release_sem(sFutexMu);
	delete_sem(waitSem);
	if (st == B_OK)
		return 0;
	return haiku_status_to_linux((int64)st);
}

#define LINUX_POLLIN   0x0001
#define LINUX_POLLPRI  0x0002
#define LINUX_POLLOUT  0x0004
#define LINUX_POLLERR  0x0008
#define LINUX_POLLHUP  0x0010
#define LINUX_POLLNVAL 0x0020
#define HAIKU_EV_READ   0x0001
#define HAIKU_EV_WRITE  0x0002
#define HAIKU_EV_ERROR  0x0004
#define HAIKU_EV_PRI    0x0008
#define HAIKU_EV_HUP    0x0080
#define HAIKU_EV_INVAL  0x1000
#define POLL_MAX_FDS    64

static uint16
linux_to_haiku_pevents(uint16 e)
{
	uint16 h;

	h = 0;
	if (e & LINUX_POLLIN)
		h |= HAIKU_EV_READ;
	if (e & LINUX_POLLOUT)
		h |= HAIKU_EV_WRITE;
	if (e & LINUX_POLLPRI)
		h |= HAIKU_EV_PRI;
	if (e & LINUX_POLLERR)
		h |= HAIKU_EV_ERROR;
	if (e & LINUX_POLLHUP)
		h |= HAIKU_EV_HUP;
	if (e & LINUX_POLLNVAL)
		h |= HAIKU_EV_INVAL;
	return h;
}

static uint16
haiku_to_linux_pevents(uint16 e)
{
	uint16 l;

	l = 0;
	if (e & HAIKU_EV_READ)
		l |= LINUX_POLLIN;
	if (e & HAIKU_EV_WRITE)
		l |= LINUX_POLLOUT;
	if (e & HAIKU_EV_PRI)
		l |= LINUX_POLLPRI;
	if (e & HAIKU_EV_ERROR)
		l |= LINUX_POLLERR;
	if (e & HAIKU_EV_HUP)
		l |= LINUX_POLLHUP;
	if (e & HAIKU_EV_INVAL)
		l |= LINUX_POLLNVAL;
	return l;
}

/*
 * Linux poll/ppoll → _user_wait_for_objects. infos must be a user
 * address (scratch). Block on the official kstack, not gKstack.
 */
extern "C" int64
sys_compat_poll(void* fds, int64 nfds, int64 timeoutMs, void* scratch)
{
	haiku_waitobj_fn fn;
	uint8 kfds[POLL_MAX_FDS * 8];
	uint8 hinfos[POLL_MAX_FDS * 8];
	int32 i, n, ready;
	int32 fd;
	uint16 ev, rev;
	uint32 flags;
	int64 tout;
	int32 st;

	if (nfds < 0)
		return -LINUX_EINVAL;
	if (nfds == 0)
		return 0;
	if (nfds > POLL_MAX_FDS)
		return -LINUX_EINVAL;
	if (fds == NULL || scratch == NULL)
		return -LINUX_EFAULT;
	if (((uint64)(addr_t)scratch) < 0x100000ULL)
		return -LINUX_EFAULT;
	if (sWaitObjFn == 0)
		return -LINUX_ENOSYS;
	if (user_memcpy(kfds, fds, (size_t)nfds * 8) != B_OK)
		return -LINUX_EFAULT;

	for (i = 0; i < (int32)nfds; i++) {
		fd = (int32)(kfds[i * 8] | (kfds[i * 8 + 1] << 8)
			| (kfds[i * 8 + 2] << 16) | (kfds[i * 8 + 3] << 24));
		ev = (uint16)(kfds[i * 8 + 4] | (kfds[i * 8 + 5] << 8));
		/* Haiku object_wait_info: object, type, events */
		hinfos[i * 8 + 0] = (uint8)fd;
		hinfos[i * 8 + 1] = (uint8)(fd >> 8);
		hinfos[i * 8 + 2] = (uint8)(fd >> 16);
		hinfos[i * 8 + 3] = (uint8)(fd >> 24);
		if (fd < 0) {
			hinfos[i * 8 + 4] = 0;
			hinfos[i * 8 + 5] = 0;
			hinfos[i * 8 + 6] = 0;
			hinfos[i * 8 + 7] = 0;
		} else {
			uint16 hev = linux_to_haiku_pevents(ev);
			hinfos[i * 8 + 4] = 0; /* B_OBJECT_TYPE_FD */
			hinfos[i * 8 + 5] = 0;
			hinfos[i * 8 + 6] = (uint8)hev;
			hinfos[i * 8 + 7] = (uint8)(hev >> 8);
		}
	}
	if (user_memcpy(scratch, hinfos, (size_t)nfds * 8) != B_OK)
		return -LINUX_EFAULT;

	if (timeoutMs < 0) {
		flags = 0;
		tout = 0x7fffffffffffffffLL;
	} else {
		flags = 8; /* B_RELATIVE_TIMEOUT */
		if (timeoutMs > 0x7fffffffLL / 1000)
			tout = 0x7fffffffLL;
		else
			tout = timeoutMs * 1000;
	}
	fn = (haiku_waitobj_fn)(addr_t)sWaitObjFn;
	st = fn(scratch, (int32)nfds, flags, tout);
	if (st < 0) {
		if ((uint32)(int32)st == 0x80000009
			|| (uint32)(int32)st == 0x8000000b)
			return 0;
		return haiku_status_to_linux((int64)st);
	}
	if (user_memcpy(hinfos, scratch, (size_t)nfds * 8) != B_OK)
		return -LINUX_EFAULT;

	ready = 0;
	for (i = 0; i < (int32)nfds; i++) {
		fd = (int32)(kfds[i * 8] | (kfds[i * 8 + 1] << 8)
			| (kfds[i * 8 + 2] << 16) | (kfds[i * 8 + 3] << 24));
		rev = 0;
		if (fd < 0)
			rev = 0;
		else {
			uint16 hev = (uint16)(hinfos[i * 8 + 6]
				| (hinfos[i * 8 + 7] << 8));
			rev = haiku_to_linux_pevents(hev);
		}
		kfds[i * 8 + 6] = (uint8)rev;
		kfds[i * 8 + 7] = (uint8)(rev >> 8);
		if (rev != 0)
			ready++;
	}
	if (user_memcpy(fds, kfds, (size_t)nfds * 8) != B_OK)
		return -LINUX_EFAULT;
	(void)n;
	return (int64)ready;
}

extern "C" int64
sys_compat_ppoll(void* fds, int64 nfds, const void* ts, void* scratch)
{
	uint64 usec;
	int64 ms;
	int64 err;

	if (ts == NULL)
		return sys_compat_poll(fds, nfds, -1, scratch);
	err = futex_copy_timespec(ts, &usec);
	if (err < 0)
		return err;
	ms = (int64)((usec + 999) / 1000);
	return sys_compat_poll(fds, nfds, ms, scratch);
}

#define SELECT_SET_BYTES 128

static int
fdset_bit(const uint8* set, int fd)
{
	return (set[fd / 8] >> (fd % 8)) & 1;
}

static void
fdset_set(uint8* set, int fd)
{
	set[fd / 8] |= (uint8)(1u << (fd % 8));
}

extern "C" int64
sys_compat_select(int64 nfds, void* rfds, void* wfds, void* efds,
	void* tv, void* scratch)
{
	uint8 r[SELECT_SET_BYTES], w[SELECT_SET_BYTES], e[SELECT_SET_BYTES];
	uint8 pfds[POLL_MAX_FDS * 8];
	int32 i, n, fd, setbytes;
	int64 ms, err;
	uint16 ev, rev;

	if (nfds < 0)
		return -LINUX_EINVAL;
	if (nfds == 0)
		return 0;
	if (nfds > POLL_MAX_FDS)
		nfds = POLL_MAX_FDS;
	if (scratch == NULL || ((uint64)(addr_t)scratch) < 0x100000ULL)
		return -LINUX_EFAULT;
	setbytes = ((int32)nfds + 7) / 8;
	if (setbytes > SELECT_SET_BYTES)
		setbytes = SELECT_SET_BYTES;
	for (i = 0; i < SELECT_SET_BYTES; i++)
		r[i] = w[i] = e[i] = 0;
	if (rfds != NULL && user_memcpy(r, rfds, (size_t)setbytes) != B_OK)
		return -LINUX_EFAULT;
	if (wfds != NULL && user_memcpy(w, wfds, (size_t)setbytes) != B_OK)
		return -LINUX_EFAULT;
	if (efds != NULL && user_memcpy(e, efds, (size_t)setbytes) != B_OK)
		return -LINUX_EFAULT;

	n = 0;
	for (fd = 0; fd < (int32)nfds && n < POLL_MAX_FDS; fd++) {
		ev = 0;
		if (rfds != NULL && fdset_bit(r, fd))
			ev |= LINUX_POLLIN;
		if (wfds != NULL && fdset_bit(w, fd))
			ev |= LINUX_POLLOUT;
		if (efds != NULL && fdset_bit(e, fd))
			ev |= LINUX_POLLPRI;
		if (ev == 0)
			continue;
		pfds[n * 8 + 0] = (uint8)fd;
		pfds[n * 8 + 1] = (uint8)(fd >> 8);
		pfds[n * 8 + 2] = (uint8)(fd >> 16);
		pfds[n * 8 + 3] = (uint8)(fd >> 24);
		pfds[n * 8 + 4] = (uint8)ev;
		pfds[n * 8 + 5] = (uint8)(ev >> 8);
		pfds[n * 8 + 6] = 0;
		pfds[n * 8 + 7] = 0;
		n++;
	}
	if (n == 0)
		return 0;
	if (user_memcpy(scratch, pfds, (size_t)n * 8) != B_OK)
		return -LINUX_EFAULT;

	ms = -1;
	if (tv != NULL) {
		uint8 raw[16];
		uint64 sec, us;
		int k;
		if (user_memcpy(raw, tv, 16) != B_OK)
			return -LINUX_EFAULT;
		sec = us = 0;
		for (k = 0; k < 8; k++) {
			sec |= (uint64)raw[k] << (8 * k);
			us |= (uint64)raw[8 + k] << (8 * k);
		}
		if ((int64)sec < 0 || us >= 1000000ULL)
			return -LINUX_EINVAL;
		ms = (int64)(sec * 1000ULL + us / 1000ULL);
	}

	err = sys_compat_poll(scratch, n, ms, scratch);
	if (err < 0)
		return err;
	if (user_memcpy(pfds, scratch, (size_t)n * 8) != B_OK)
		return -LINUX_EFAULT;

	for (i = 0; i < SELECT_SET_BYTES; i++)
		r[i] = w[i] = e[i] = 0;
	for (i = 0; i < n; i++) {
		fd = (int32)(pfds[i * 8] | (pfds[i * 8 + 1] << 8)
			| (pfds[i * 8 + 2] << 16) | (pfds[i * 8 + 3] << 24));
		rev = (uint16)(pfds[i * 8 + 6] | (pfds[i * 8 + 7] << 8));
		if (fd < 0 || fd >= (int32)nfds)
			continue;
		if (rev & (LINUX_POLLIN | LINUX_POLLHUP | LINUX_POLLERR))
			fdset_set(r, fd);
		if (rev & (LINUX_POLLOUT | LINUX_POLLERR))
			fdset_set(w, fd);
		if (rev & LINUX_POLLPRI)
			fdset_set(e, fd);
	}
	if (rfds != NULL && user_memcpy(rfds, r, (size_t)setbytes) != B_OK)
		return -LINUX_EFAULT;
	if (wfds != NULL && user_memcpy(wfds, w, (size_t)setbytes) != B_OK)
		return -LINUX_EFAULT;
	if (efds != NULL && user_memcpy(efds, e, (size_t)setbytes) != B_OK)
		return -LINUX_EFAULT;
	return err;
}

extern "C" int64
sys_compat_pselect(int64 nfds, void* rfds, void* wfds, void* efds,
	const void* ts, void* scratch)
{
	uint8 tv[16];
	uint64 usec;
	int64 err;
	int i;

	if (ts == NULL)
		return sys_compat_select(nfds, rfds, wfds, efds, NULL, scratch);
	err = futex_copy_timespec(ts, &usec);
	if (err < 0)
		return err;
	/* Pack as timeval (sec + usec) for select(). */
	for (i = 0; i < 16; i++)
		tv[i] = 0;
	{
		uint64 sec = usec / 1000000ULL;
		uint64 us = usec % 1000000ULL;
		for (i = 0; i < 8; i++) {
			tv[i] = (uint8)(sec >> (8 * i));
			tv[8 + i] = (uint8)(us >> (8 * i));
		}
	}
	/* tv is kernel. select() user_memcpy's it — must be user.
	 * Convert to ms and call poll path via a fake timeval in scratch+512. */
	{
		void* utv = (uint8*)scratch + 512;
		if (user_memcpy(utv, tv, 16) != B_OK)
			return -LINUX_EFAULT;
		return sys_compat_select(nfds, rfds, wfds, efds, utv, scratch);
	}
}

#define LINUX_MAP_SHARED  0x01
#define LINUX_MAP_PRIVATE 0x02
#define LINUX_MAP_FIXED   0x10
#define LINUX_MAP_ANON    0x20

extern "C" int64
sys_compat_mmap(void* addr, uint64 len, int64 prot, int64 flags,
	int64 fd, int64 offset)
{
	void* mapped;
	uint32 spec, hprot, mapping;
	int32 area;
	team_info info;

	kser_puts("MM\n");
	if (len == 0)
		return -LINUX_EINVAL;
	if ((flags & LINUX_MAP_ANON) != 0)
		return -LINUX_ENOMEM;
	if (fd < 0)
		return -LINUX_EBADF;
	if ((offset & 4095) != 0)
		return -LINUX_EINVAL;
	if (((flags & LINUX_MAP_SHARED) != 0)
		== ((flags & LINUX_MAP_PRIVATE) != 0))
		return -LINUX_EINVAL;
	len = (len + 4095) & ~(uint64)4095;

	if ((flags & LINUX_MAP_FIXED) != 0)
		spec = B_EXACT_ADDRESS;
	else if (addr != NULL)
		spec = B_BASE_ADDRESS;
	else
		spec = B_RANDOMIZED_ANY_ADDRESS;
	hprot = (uint32)prot & 7;
	if (hprot == 0)
		hprot = B_READ_AREA;
	/* REGION_NO_PRIVATE_MAP=0 (shared), REGION_PRIVATE_MAP=1. */
	mapping = ((flags & LINUX_MAP_SHARED) != 0) ? 0 : 1;
	mapped = addr;

	if (sVmMapFileK == 0 && sVmMapFile == 0)
		return -LINUX_ENOSYS;
	if (get_team_info(B_CURRENT_TEAM, &info) != B_OK)
		return -LINUX_ENOMEM;

	/* kernel=false so get_fd uses the team's fds, not the kernel's. */
	if (sVmMapFileK != 0)
		area = sVmMapFileK(info.team, "linux_mmap", &mapped, spec,
			(addr_t)len, hprot, mapping,
			(flags & LINUX_MAP_FIXED) != 0, (int)fd, (off_t)offset,
			false);
	else
		area = sVmMapFile(info.team, "linux_mmap", &mapped, spec,
			(addr_t)len, hprot, mapping,
			(flags & LINUX_MAP_FIXED) != 0, (int)fd, (off_t)offset);
	if (area < 0) {
		kser_puts("ME\n");
		kser_hex((uint64)(uint32)area);
		kser_putc('\n');
		return haiku_status_to_linux((int64)area);
	}
	if ((uint64)(addr_t)mapped < 0x100000ULL) {
		kser_puts("MZ\n");
		return -LINUX_ENOMEM;
	}
	kser_puts("MO\n");
	return (int64)(addr_t)mapped;
}

extern "C" int64
sys_compat_sendfile(int64 outFd, int64 inFd, void* offp, uint64 count)
{
	/* Linux sendfile() requires in_fd to support mmap. busybox cat
	 * does sendfile(1, 0, NULL, 16M) on the pipe and needs EINVAL
	 * so it falls back to read/write. The old bounce at user
	 * RSP-4096 smashed cat's stack (EX2: XGO + mQbB then Kill
	 * Thread, no HI). Regular-file sendfile can use a reserved
	 * user page later — do not bounce onto the Linux stack. */
	(void)outFd;
	(void)inFd;
	(void)offp;
	(void)count;
	kser_puts("SF\n");
	return -LINUX_EINVAL;
}

extern "C" int64
sys_compat_wstat(int64 fd, const void* path, int64 flags, uint32 mask,
	int64 a, int64 b)
{
	int32 traverse;
	int32 st;
	haiku_write_stat_fn fn;
	uint8 h[HAIKU_STAT_SIZE];
	int i;
	void* userSt;

	if (mask == 0)
		return 0;
	if (sWriteStatFn == 0)
		return -LINUX_ENOSYS;
	if (path == NULL && fd < 0)
		return -LINUX_EBADF;
	if ((flags & LINUX_AT_EMPTY_PATH) != 0 && path != NULL) {
		uint8 first;
		if (user_memcpy(&first, path, 1) != B_OK)
			return -LINUX_EFAULT;
		if (first == 0)
			path = NULL;
	}
	if (path == NULL || (flags & LINUX_AT_SYMLINK_NOFOLLOW) != 0)
		traverse = 0;
	else
		traverse = 1;

	for (i = 0; i < HAIKU_STAT_SIZE; i++)
		h[i] = 0;
	if ((mask & BSTAT_MODE) != 0) {
		uint32 mode = (uint32)a & 07777;
		h[16] = (uint8)mode;
		h[17] = (uint8)(mode >> 8);
		h[18] = (uint8)(mode >> 16);
		h[19] = (uint8)(mode >> 24);
	}
	if ((mask & BSTAT_UID) != 0) {
		uint32 uid = (uint32)a;
		h[24] = (uint8)uid;
		h[25] = (uint8)(uid >> 8);
		h[26] = (uint8)(uid >> 16);
		h[27] = (uint8)(uid >> 24);
	}
	if ((mask & BSTAT_GID) != 0) {
		uint32 gid = (uint32)b;
		h[28] = (uint8)gid;
		h[29] = (uint8)(gid >> 8);
		h[30] = (uint8)(gid >> 16);
		h[31] = (uint8)(gid >> 24);
	}
	if ((mask & BSTAT_SIZE) != 0) {
		uint64 sz = (uint64)a;
		for (i = 0; i < 8; i++)
			h[32 + i] = (uint8)(sz >> (8 * i));
	}

	/* User scratch sits just below the saved user stack (assembly). */
	userSt = (void*)(gSavedRsp - 256);
	if (user_memcpy(userSt, h, HAIKU_STAT_SIZE) != B_OK)
		return -LINUX_EFAULT;
	fn = (haiku_write_stat_fn)(addr_t)sWriteStatFn;
	st = fn((int32)fd, path, traverse, userSt, HAIKU_STAT_SIZE, (int32)mask);
	return haiku_status_to_linux((int64)st);
}

extern "C" int64
sys_compat_mprotect(void* addr, uint64 len, int64 prot)
{
	haiku_mprot_fn fn;
	int32 st;

	if (sMprotectFn == 0)
		return -LINUX_ENOSYS;
	if (len == 0)
		return 0;
	fn = (haiku_mprot_fn)(addr_t)sMprotectFn;
	st = fn(addr, len, (uint32)prot & 7);
	return haiku_status_to_linux((int64)st);
}

extern "C" int64
sys_compat_munmap(void* addr, uint64 len)
{
	haiku_unmap_fn fn;
	int32 st;
	uint64 a = (uint64)(addr_t)addr;

	if (len == 0)
		return 0;
	/* Arena carve is not a Haiku mapping we should punch out. */
	if (gBrkBase != 0 && a >= gBrkBase && a < gArenaHi)
		return 0;
	if (sUnmapFn == 0)
		return 0;
	fn = (haiku_unmap_fn)(addr_t)sUnmapFn;
	st = fn(addr, len);
	if (st != 0)
		return 0;
	return 0;
}

extern "C" int64
sys_compat_getuid(void)
{
	team_info info;

	if (sHaveUid)
		return sUid;
	if (get_team_info(B_CURRENT_TEAM, &info) != B_OK)
		return 0;
	return info.uid;
}

extern "C" int64
sys_compat_getgid(void)
{
	team_info info;

	if (sHaveGid)
		return sGid;
	if (get_team_info(B_CURRENT_TEAM, &info) != B_OK)
		return 0;
	return info.gid;
}

extern "C" int64
sys_compat_setuid(int64 uid)
{
	sHaveUid = 1;
	sUid = (uint32)uid;
	return 0;
}

extern "C" int64
sys_compat_setgid(int64 gid)
{
	sHaveGid = 1;
	sGid = (uint32)gid;
	return 0;
}

extern "C" int64
sys_compat_gettid(void)
{
	thread_id tid = find_thread(NULL);
	if (tid < 0)
		return 1;
	return tid;
}

extern "C" int64
sys_compat_set_tid_address(void* ptr)
{
	sClearTid = (uint64)(addr_t)ptr;
	return sys_compat_gettid();
}

extern "C" int64
sys_compat_set_robust_list(void* head, uint64 len)
{
	kser_puts("B\n");
	sRobustList = (uint64)(addr_t)head;
	sRobustLen = len;
	sChildRobust = 1;
	return 0;
}

extern "C" int64
sys_compat_prctl(int64 option, int64 a2, int64 a3, int64 a4, int64 a5)
{
	(void)a3;
	(void)a4;
	(void)a5;
	if (option == LINUX_PR_SET_NAME) {
		haiku_rename_thr_fn fn;
		thread_id tid;
		if (a2 == 0)
			return -LINUX_EFAULT;
		if (sRenameThrFn == 0)
			return 0;
		tid = find_thread(NULL);
		fn = (haiku_rename_thr_fn)(addr_t)sRenameThrFn;
		fn(tid, (const void*)a2);
		return 0;
	}
	if (option == LINUX_PR_GET_NAME) {
		thread_info ti;
		thread_id tid;
		if (a2 == 0)
			return -LINUX_EFAULT;
		tid = find_thread(NULL);
		if (get_thread_info(tid, &ti) != B_OK)
			return -LINUX_EIO;
		if (user_memcpy((void*)a2, ti.name, 16) != B_OK)
			return -LINUX_EFAULT;
		return 0;
	}
	if (option == LINUX_PR_GET_DUMPABLE)
		return 1;
	if (option == LINUX_PR_SET_DUMPABLE || option == LINUX_PR_SET_PDEATHSIG)
		return 0;
	return 0;
}

extern "C" int64
sys_compat_rename(int64 oldFd, const void* oldPath, int64 newFd,
	const void* newPath)
{
	haiku_rename_fn fn;
	int32 st;

	if (oldPath == NULL || newPath == NULL)
		return -LINUX_EFAULT;
	if (sRenameFn == 0)
		return -LINUX_ENOSYS;
	fn = (haiku_rename_fn)(addr_t)sRenameFn;
	st = fn((int32)oldFd, oldPath, (int32)newFd, newPath);
	return haiku_status_to_linux((int64)st);
}

extern "C" int64
sys_compat_symlink(int64 fd, const void* linkPath, const void* target)
{
	haiku_symlink_fn fn;
	int32 st;

	if (linkPath == NULL || target == NULL)
		return -LINUX_EFAULT;
	if (sSymlinkFn == 0)
		return -LINUX_ENOSYS;
	fn = (haiku_symlink_fn)(addr_t)sSymlinkFn;
	st = fn((int32)fd, linkPath, target, 0);
	return haiku_status_to_linux((int64)st);
}

extern "C" int64
sys_compat_link(int64 oldFd, const void* oldPath, int64 newFd,
	const void* newPath, int64 flags)
{
	haiku_link_fn fn;
	int32 st;
	int32 follow;

	if (oldPath == NULL || newPath == NULL)
		return -LINUX_EFAULT;
	if (sLinkFn == 0)
		return -LINUX_ENOSYS;
	follow = ((flags & LINUX_AT_SYMLINK_FOLLOW) != 0) ? 1 : 0;
	fn = (haiku_link_fn)(addr_t)sLinkFn;
	st = fn((int32)newFd, newPath, (int32)oldFd, oldPath, follow);
	if ((uint32)st == 0x8000600e)
		return -LINUX_EPERM;
	return haiku_status_to_linux((int64)st);
}

extern "C" int64
sys_compat_readlink(int64 fd, const void* path, void* buf, uint64 bufsiz)
{
	haiku_readlink_fn fn;
	int32 st;
	uint64 sz;
	void* userSz;

	if (path == NULL || buf == NULL)
		return -LINUX_EFAULT;
	if (bufsiz == 0)
		return -LINUX_EINVAL;
	if (sReadLinkFn == 0)
		return -LINUX_ENOSYS;
	sz = bufsiz;
	userSz = (void*)(gSavedRsp - 16);
	if (user_memcpy(userSz, &sz, sizeof(sz)) != B_OK)
		return -LINUX_EFAULT;
	fn = (haiku_readlink_fn)(addr_t)sReadLinkFn;
	st = fn((int32)fd, path, buf, userSz);
	if (st != 0)
		return haiku_status_to_linux((int64)st);
	if (user_memcpy(&sz, userSz, sizeof(sz)) != B_OK)
		return -LINUX_EFAULT;
	if (sz > bufsiz)
		sz = bufsiz;
	return (int64)sz;
}

extern "C" int64
sys_compat_dup(int64 fd)
{
	haiku_dup_fn fn;
	int32 st;

	if (sDupFn == 0)
		return -LINUX_ENOSYS;
	fn = (haiku_dup_fn)(addr_t)sDupFn;
	st = fn((int32)fd);
	if (st >= 0)
		return st;
	return haiku_status_to_linux((int64)st);
}

extern "C" int64
sys_compat_dup2(int64 ofd, int64 nfd, int64 flags)
{
	haiku_dup2_fn fn;
	int32 st;
	int32 hflags;

	if (sDup2Fn == 0)
		return -LINUX_ENOSYS;
	hflags = 0;
	if ((flags & LINUX_O_CLOEXEC) != 0)
		hflags |= HAIKU_O_CLOEXEC;
	if ((flags & ~(int64)LINUX_O_CLOEXEC) != 0)
		return -LINUX_EINVAL;
	fn = (haiku_dup2_fn)(addr_t)sDup2Fn;
	st = fn((int32)ofd, (int32)nfd, hflags);
	if (st >= 0)
		return st;
	return haiku_status_to_linux((int64)st);
}

extern "C" int64
sys_compat_fsync(int64 fd, int64 dataOnly)
{
	haiku_fsync_fn fn;
	int32 st;

	if (sFsyncFn == 0)
		return -LINUX_ENOSYS;
	fn = (haiku_fsync_fn)(addr_t)sFsyncFn;
	st = fn((int32)fd, dataOnly ? 1 : 0);
	return haiku_status_to_linux((int64)st);
}

/* Do not call real_time_clock_usecs()/system_time() from this driver —
 * those resolve to libroot stubs (syscall) and KDL when we re-enter LSTAR.
 * Prefer _user_get_clock via kSyscallInfos; rdtsc is the fallback only. */
static uint64
compat_approx_usecs(int realtime)
{
	uint32 lo, hi;
	uint64 t;

	__asm__ __volatile__("rdtsc" : "=a"(lo), "=d"(hi));
	t = ((uint64)hi << 32) | lo;
	t >>= 10;
	if (realtime)
		t += 1700000000ULL * 1000000ULL;
	return t;
}

static uint64
compat_now_us(int realtime)
{
	haiku_getclock_fn fn;
	int32 st;
	int32 hclk;
	uint64 us;
	void* userT;

	if (sGetClockFn == 0)
		return compat_approx_usecs(realtime);
	hclk = realtime ? HAIKU_CLOCK_REALTIME : HAIKU_CLOCK_MONOTONIC;
	userT = (void*)(gSavedRsp - 16);
	us = 0;
	if (user_memcpy(userT, &us, sizeof(us)) != B_OK)
		return compat_approx_usecs(realtime);
	fn = (haiku_getclock_fn)(addr_t)sGetClockFn;
	st = fn(hclk, userT);
	if (st != 0)
		return compat_approx_usecs(realtime);
	if (user_memcpy(&us, userT, sizeof(us)) != B_OK)
		return compat_approx_usecs(realtime);
	return us;
}

extern "C" int64
sys_compat_clock_gettime(int64 clockid, void* tp)
{
	uint64 us;
	uint64 sec;
	uint64 nsec;
	uint8 out[16];
	int i;
	int realtime;

	if (tp == NULL)
		return -LINUX_EFAULT;
	/* Linux 0=REALTIME 1=MONOTONIC 4=MONOTONIC_RAW 5=REALTIME_COARSE
	 * 6=MONOTONIC_COARSE 7=BOOTTIME. */
	if (clockid == 0 || clockid == 5)
		realtime = 1;
	else if (clockid == 1 || clockid == 4 || clockid == 6 || clockid == 7)
		realtime = 0;
	else
		return -LINUX_EINVAL;
	us = compat_now_us(realtime);
	sec = us / 1000000;
	nsec = (us % 1000000) * 1000;
	for (i = 0; i < 8; i++)
		out[i] = (uint8)(sec >> (8 * i));
	for (i = 0; i < 8; i++)
		out[8 + i] = (uint8)(nsec >> (8 * i));
	if (user_memcpy(tp, out, 16) != B_OK)
		return -LINUX_EFAULT;
	return 0;
}

extern "C" int64
sys_compat_time(void* tloc)
{
	uint64 us;
	int64 sec;

	us = compat_now_us(1);
	sec = (int64)(us / 1000000);
	if (tloc != NULL && user_memcpy(tloc, &sec, sizeof(sec)) != B_OK)
		return -LINUX_EFAULT;
	return sec;
}

extern "C" int64
sys_compat_gettimeofday(void* tv, void* tz)
{
	uint64 us;
	uint8 out[16];
	uint64 sec;
	uint64 usec;
	int i;

	(void)tz;
	if (tv == NULL)
		return -LINUX_EFAULT;
	us = compat_now_us(1);
	sec = us / 1000000;
	usec = us % 1000000;
	for (i = 0; i < 8; i++) {
		out[i] = (uint8)(sec >> (8 * i));
		out[8 + i] = (uint8)(usec >> (8 * i));
	}
	if (user_memcpy(tv, out, 16) != B_OK)
		return -LINUX_EFAULT;
	return 0;
}

extern "C" int64
sys_compat_getppid(void)
{
	team_info info;

	if (get_team_info(B_CURRENT_TEAM, &info) != B_OK)
		return 1;
	if (info.parent <= 0)
		return 1;
	return info.parent;
}

extern "C" int64
sys_compat_pipe2(void* fds, int64 flags)
{
	haiku_pipe_fn fn;
	int32 st;
	int32 hflags;

	if (fds == NULL)
		return -LINUX_EFAULT;
	if (sPipeFn == 0)
		return -LINUX_ENOSYS;
	hflags = 0;
	if ((flags & LINUX_O_CLOEXEC) != 0)
		hflags |= HAIKU_O_CLOEXEC;
	if ((flags & 0x800) != 0)	/* LINUX O_NONBLOCK */
		hflags |= 0x80;		/* HAIKU O_NONBLOCK */
	if ((flags & ~(int64)(LINUX_O_CLOEXEC | 0x800)) != 0)
		return -LINUX_EINVAL;
	fn = (haiku_pipe_fn)(addr_t)sPipeFn;
	st = fn(fds, hflags);
	return haiku_status_to_linux((int64)st);
}

extern "C" int64
sys_compat_nanosleep(const void* req, void* rem)
{
	uint8 ts[16];
	uint64 sec, nsec;
	int i;

	(void)rem;
	if (req == NULL)
		return -LINUX_EFAULT;
	if (user_memcpy(ts, req, 16) != B_OK)
		return -LINUX_EFAULT;
	sec = 0;
	nsec = 0;
	for (i = 0; i < 8; i++) {
		sec |= (uint64)ts[i] << (8 * i);
		nsec |= (uint64)ts[8 + i] << (8 * i);
	}
	if ((int64)sec < 0 || nsec >= 1000000000ULL)
		return -LINUX_EINVAL;
	/* No snooze number proven yet. Zero-duration is enough for CLI. */
	if (sec == 0 && nsec == 0)
		return 0;
	return 0;
}

static uint32
haiku_fl_to_linux(uint32 h)
{
	uint32 l;

	l = h & 3;
	if ((h & HAIKU_O_APPEND) != 0)
		l |= LINUX_O_APPEND;
	if ((h & HAIKU_O_NONBLOCK) != 0)
		l |= LINUX_O_NONBLOCK;
	return l;
}

static uint32
linux_fl_to_haiku(uint32 l)
{
	uint32 h;

	h = l & 3;
	if ((l & LINUX_O_APPEND) != 0)
		h |= HAIKU_O_APPEND;
	if ((l & LINUX_O_NONBLOCK) != 0)
		h |= HAIKU_O_NONBLOCK;
	return h;
}

extern "C" int64
sys_compat_fcntl(int64 fd, int64 cmd, int64 arg)
{
	haiku_fcntl_fn fn;
	int32 hop;
	int64 st;
	uint64 harg;

	if (sFcntlFn == 0)
		return -LINUX_ENOSYS;
	harg = (uint64)arg;
	switch ((int32)cmd) {
	case LINUX_F_DUPFD:
		hop = HAIKU_F_DUPFD;
		break;
	case LINUX_F_DUPFD_CLOEXEC:
		hop = HAIKU_F_DUPFD_CLOEXEC;
		break;
	case LINUX_F_GETFD:
		hop = HAIKU_F_GETFD;
		harg = 0;
		break;
	case LINUX_F_SETFD:
		hop = HAIKU_F_SETFD;
		harg = (uint64)arg & 1;	/* FD_CLOEXEC is 1 on both */
		break;
	case LINUX_F_GETFL:
		hop = HAIKU_F_GETFL;
		harg = 0;
		break;
	case LINUX_F_SETFL:
		hop = HAIKU_F_SETFL;
		harg = linux_fl_to_haiku((uint32)arg);
		break;
	default:
		return -LINUX_EINVAL;
	}
	fn = (haiku_fcntl_fn)(addr_t)sFcntlFn;
	st = fn((int32)fd, hop, harg);
	if (st < 0)
		return haiku_status_to_linux((int64)st);
	if ((int32)cmd == LINUX_F_GETFL)
		return (int64)haiku_fl_to_linux((uint32)st);
	if ((int32)cmd == LINUX_F_GETFD)
		return (int64)(st & 1);	/* Linux only has FD_CLOEXEC */
	return (int64)st;
}

static void
put_u16(uint8* p, uint16 v)
{
	p[0] = (uint8)v;
	p[1] = (uint8)(v >> 8);
}

static void
put_u32(uint8* p, uint32 v)
{
	p[0] = (uint8)v;
	p[1] = (uint8)(v >> 8);
	p[2] = (uint8)(v >> 16);
	p[3] = (uint8)(v >> 24);
}

static void
put_u64(uint8* p, uint64 v)
{
	int i;
	for (i = 0; i < 8; i++)
		p[i] = (uint8)(v >> (8 * i));
}

static void
put_stx_ts(uint8* p, int64 sec, int64 nsec)
{
	put_u64(p, (uint64)sec);
	put_u32(p + 8, (uint32)nsec);
	put_u32(p + 12, 0);
}

extern "C" int64
sys_compat_statx(int64 fd, const void* path, int64 flags, uint32 mask,
	void* buf)
{
	static struct haiku_stat sH;
	haiku_read_stat_fn fn;
	int32 traverse;
	int32 st;
	const void* pth;
	uint8 first;
	uint8 out[LINUX_STATX_SIZE];
	uint32 got;
	int i;

	(void)mask;
	if (buf == NULL)
		return -LINUX_EFAULT;
	if (sReadStatFn == 0)
		return -LINUX_ENOSYS;
	pth = path;
	if (pth != NULL && (flags & LINUX_AT_EMPTY_PATH) != 0) {
		if (user_memcpy(&first, pth, 1) != B_OK)
			return -LINUX_EFAULT;
		if (first == 0)
			pth = NULL;
	}
	if (pth == NULL || (flags & LINUX_AT_SYMLINK_NOFOLLOW) != 0)
		traverse = 0;
	else
		traverse = 1;
	fn = (haiku_read_stat_fn)(addr_t)sReadStatFn;
	st = fn((int32)fd, pth, traverse, buf, HAIKU_STAT_SIZE);
	if (st != 0)
		return haiku_status_to_linux((int64)st);
	if (user_memcpy(&sH, buf, sizeof(sH)) != B_OK)
		return -LINUX_EFAULT;
	for (i = 0; i < LINUX_STATX_SIZE; i++)
		out[i] = 0;
	got = LINUX_STATX_BASIC | LINUX_STATX_BTIME;
	put_u32(out + 0, got);
	put_u32(out + 4, (uint32)sH.st_blksize);
	put_u32(out + 16, (uint32)sH.st_nlink);
	put_u32(out + 20, sH.st_uid);
	put_u32(out + 24, sH.st_gid);
	put_u16(out + 28, (uint16)(sH.st_mode & 0177777));
	put_u64(out + 32, (uint64)sH.st_ino);
	put_u64(out + 40, (uint64)sH.st_size);
	put_u64(out + 48, (uint64)sH.st_blocks);
	put_stx_ts(out + 64, sH.st_atime, sH.st_atime_nsec);
	put_stx_ts(out + 80, sH.st_crtime, sH.st_crtime_nsec);
	put_stx_ts(out + 96, sH.st_ctime, sH.st_ctime_nsec);
	put_stx_ts(out + 112, sH.st_mtime, sH.st_mtime_nsec);
	put_u32(out + 136, (uint32)sH.st_dev);
	sLastMode = sH.st_mode & 0177777;
	sLastSize = sH.st_size;
	if (user_memcpy(buf, out, LINUX_STATX_SIZE) != B_OK)
		return -LINUX_EFAULT;
	return 0;
}

extern "C" int64
sys_compat_utimensat(int64 fd, const void* path, const void* times, int64 flags)
{
	uint8 h[HAIKU_STAT_SIZE];
	uint8 ts[32];
	int i;
	uint32 mask;
	int32 traverse;
	int32 st;
	haiku_write_stat_fn fn;
	void* userSt;
	uint64 now;
	uint64 asec, ansec, msec, mnsec;

	if (sWriteStatFn == 0)
		return -LINUX_ENOSYS;
	if (path == NULL && fd < 0)
		return -LINUX_EBADF;
	for (i = 0; i < HAIKU_STAT_SIZE; i++)
		h[i] = 0;
	now = compat_now_us(1);
	asec = now / 1000000;
	ansec = (now % 1000000) * 1000;
	msec = asec;
	mnsec = ansec;
	mask = BSTAT_ATIME | BSTAT_MTIME;
	if (times != NULL) {
		if (user_memcpy(ts, times, 32) != B_OK)
			return -LINUX_EFAULT;
		asec = 0;
		ansec = 0;
		msec = 0;
		mnsec = 0;
		for (i = 0; i < 8; i++) {
			asec |= (uint64)ts[i] << (8 * i);
			ansec |= (uint64)ts[8 + i] << (8 * i);
			msec |= (uint64)ts[16 + i] << (8 * i);
			mnsec |= (uint64)ts[24 + i] << (8 * i);
		}
		if (ansec == LINUX_UTIME_OMIT)
			mask &= ~BSTAT_ATIME;
		else if (ansec == LINUX_UTIME_NOW) {
			asec = now / 1000000;
			ansec = (now % 1000000) * 1000;
		}
		if (mnsec == LINUX_UTIME_OMIT)
			mask &= ~BSTAT_MTIME;
		else if (mnsec == LINUX_UTIME_NOW) {
			msec = now / 1000000;
			mnsec = (now % 1000000) * 1000;
		}
	}
	if (mask == 0)
		return 0;
	for (i = 0; i < 8; i++) {
		h[48 + i] = (uint8)(asec >> (8 * i));
		h[56 + i] = (uint8)(ansec >> (8 * i));
		h[64 + i] = (uint8)(msec >> (8 * i));
		h[72 + i] = (uint8)(mnsec >> (8 * i));
	}
	if ((flags & LINUX_AT_SYMLINK_NOFOLLOW) != 0)
		traverse = 0;
	else
		traverse = 1;
	userSt = (void*)(gSavedRsp - 256);
	if (user_memcpy(userSt, h, HAIKU_STAT_SIZE) != B_OK)
		return -LINUX_EFAULT;
	fn = (haiku_write_stat_fn)(addr_t)sWriteStatFn;
	st = fn((int32)fd, path, traverse, userSt, HAIKU_STAT_SIZE, (int32)mask);
	return haiku_status_to_linux((int64)st);
}

static void
discover_uls_offset(void)
{
	uint64 fs, thread, match;
	const uint64* p;
	int i;

	if (gUlsOff != 0)
		return;

	fs = rdmsr(IA32_FS_BASE);
	__asm__ __volatile__("mov %%gs:0, %0" : "=r"(thread));
	if (fs == 0 || thread == 0)
		return;

	/* thread->user_local_storage == current FS_BASE for a user thread. */
	p = (const uint64*)(addr_t)thread;
	match = 0;
	/* Last match: user_local_storage sits late in Thread. An earlier
	 * hit can be some other cached copy of the same pointer. */
	for (i = 8; i < 256; i++) {
		if (p[i] == fs)
			match = (uint64)i * 8;
	}
	if (match == 0) {
		dprintf("[sys_compat] ULS scan missed fs=%#" B_PRIx64
			" thread=%#" B_PRIx64 "\n", fs, thread);
		return;
	}
	gUlsOff = match;
	dprintf("[sys_compat] user_local_storage off=%#" B_PRIx64
		" fs=%#" B_PRIx64 "\n", gUlsOff, fs);
}

static status_t
dev_open(const char* /*name*/, uint32 /*flags*/, void** cookie)
{
	*cookie = NULL;
	discover_uls_offset();
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
	uint64 cr3 = read_cr3() & ~(uint64)0xfff;
	int slot = linux_slot_by_cr3(cr3);
	if (slot >= 0) {
		gLinuxCR3[slot] = 0;
		gLinuxTeam[slot] = 0;
		if (gLinuxN > 0)
			gLinuxN--;
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

static void
fmt_hex(char* out, uint64 v)
{
	static const char hex[] = "0123456789abcdef";
	out[0] = '0';
	out[1] = 'x';
	for (int i = 0; i < 16; i++)
		out[2 + i] = hex[(v >> ((15 - i) * 4)) & 0xf];
	out[18] = '\0';
}

static void
fmt_u64(char* out, uint64 v)
{
	char tmp[20];
	int n = 0;
	if (v == 0) {
		out[0] = '0';
		out[1] = '\0';
		return;
	}
	while (v > 0 && n < 20) {
		tmp[n++] = (char)('0' + (v % 10));
		v /= 10;
	}
	for (int i = 0; i < n; i++)
		out[i] = tmp[n - 1 - i];
	out[n] = '\0';
}

static status_t
dev_read(void* /*cookie*/, off_t pos, void* buf, size_t* len)
{
	char text[1024];
	char h1[20], h2[20], hb[20], hc[20], hm[20], hh[20];
	char n1[24], n2[24], n3[24], nseq[8];
	size_t n, want, off;
	int i, k;

	if (buf == NULL || len == NULL)
		return B_BAD_VALUE;
	if (pos < 0) {
		*len = 0;
		return B_BAD_VALUE;
	}

	fmt_hex(h1, gLinuxCR3[0]);
	fmt_hex(h2, gOrigLstar);
	fmt_hex(hb, gBrkBase);
	fmt_hex(hc, gBrkCur);
	fmt_hex(hm, gMapCur);
	fmt_hex(hh, gArenaHi);
	fmt_u64(n1, gMarkCount);
	fmt_u64(n2, gLinuxHits);
	fmt_u64(n3, gLastLinuxRax);

	/* Keep this ASCII so `cat /dev/misc/sys_compat` works from another team. */
	i = 0;
#define PUT(s) do { const char* _p = (s); while (*_p && i < (int)sizeof(text) - 1) text[i++] = *_p++; } while (0)
	PUT("cr3="); PUT(h1);
	{
		char nn[20], nt[20];
		fmt_u64(nn, gLinuxN);
		fmt_hex(nt, (uint64)gLinuxTeam[0]);
		PUT(" n="); PUT(nn); PUT(" team="); PUT(nt);
	}
	PUT("\n");
	PUT("orig="); PUT(h2); PUT("\n");
	PUT("mark="); PUT(n1); PUT("\n");
	PUT("hits="); PUT(n2); PUT("\n");
	PUT("last="); PUT(n3); PUT("\n");
	PUT("brk="); PUT(hb); PUT(".."); PUT(hc); PUT(" map="); PUT(hm); PUT(" hi="); PUT(hh); PUT("\n");
	{
		char hu[20];
		char hf[20];
		fmt_hex(hu, gUlsOff);
		fmt_hex(hf, gLinuxFS);
		PUT("uls="); PUT(hu); PUT(" fs="); PUT(hf); PUT("\n");
	}
	{
		char hr[20], hl[20], hs[20];
		fmt_hex(hr, gRseqPtr);
		fmt_hex(hl, gRseqLen);
		fmt_hex(hs, gRseqSig);
		PUT("rseq="); PUT(hr); PUT(" len="); PUT(hl);
		PUT(" sig="); PUT(hs); PUT("\n");
	}
	{
		char ht[20], hf[20], hs[20];
		fmt_hex(ht, (uint64)(addr_t)sSyscallInfos);
		fmt_hex(hf, sReadDirFn);
		fmt_hex(hs, sReadStatFn);
		PUT("ksc="); PUT(ht); PUT(" rdir="); PUT(hf);
		PUT(" rstat="); PUT(hs); PUT("\n");
	}
	{
		char hm[20], hg[20], hp[20];
		fmt_hex(hm, sCreateDirFn);
		fmt_hex(hg, sGetcwdFn);
		fmt_hex(hp, (uint64)sLastPath);
		PUT("mkdir="); PUT(hm); PUT(" cwd="); PUT(hg);
		PUT(" path="); PUT(hp); PUT("\n");
	}
	{
		char ns[20], nm[20], nz[20];
		fmt_hex(ns, (uint64)sLastStat);
		fmt_hex(nm, (uint64)sLastMode);
		fmt_hex(nz, (uint64)sLastSize);
		PUT("stat="); PUT(ns); PUT(" mode="); PUT(nm);
		PUT(" size="); PUT(nz); PUT("\n");
	}
	{
		char nn[20], no[20];
		fmt_hex(nn, (uint64)sLastNent);
		fmt_hex(no, (uint64)sLastOut);
		PUT("dent="); PUT(nn); PUT(" dout="); PUT(no); PUT("\n");
	}
	{
		char hw[20], hu[20], hp[20], hr[20];
		fmt_hex(hw, sWriteStatFn);
		fmt_hex(hu, sUnmapFn);
		fmt_hex(hp, sMprotectFn);
		fmt_hex(hr, sRenameThrFn);
		PUT("wstat="); PUT(hw); PUT(" unmap="); PUT(hu);
		PUT(" mprot="); PUT(hp); PUT(" rnth="); PUT(hr); PUT("\n");
	}
	{
		char hn[20], hs[20], hl[20], hd[20];
		fmt_hex(hn, sRenameFn);
		fmt_hex(hs, sSymlinkFn);
		fmt_hex(hl, sReadLinkFn);
		fmt_hex(hd, sDupFn);
		PUT("ren="); PUT(hn); PUT(" sym="); PUT(hs);
		PUT(" rlnk="); PUT(hl); PUT(" dup="); PUT(hd); PUT("\n");
	}
	{
		char hf[20], hg[20];
		fmt_hex(hf, sFcntlFn);
		fmt_hex(hg, sGetClockFn);
		PUT("fcntl="); PUT(hf); PUT(" clock="); PUT(hg); PUT("\n");
	}
	{
		char fg0[20], fg8[20], fk[20], fl[20];
		fmt_hex(fg0, sForkGs0);
		fmt_hex(fg8, sForkGs8);
		fmt_hex(fk, sForkKtop);
		fmt_hex(fl, (uint64)sLastFork);
		PUT("fgs0="); PUT(fg0); PUT(" fgs8="); PUT(fg8);
		PUT(" ktop="); PUT(fk); PUT(" frk="); PUT(fl); PUT("\n");
	}
	{
		char ht[20];
		fmt_hex(ht, gForkTramp);
		PUT("tramp="); PUT(ht);
		fmt_hex(ht, gForkHaikuRsp);
		PUT(" hrsp="); PUT(ht); PUT("\n");
	}
	{
		char uid[20], gid[20], ctid[20];
		fmt_u64(uid, sHaveUid ? (uint64)sUid : 0);
		fmt_u64(gid, sHaveGid ? (uint64)sGid : 0);
		fmt_hex(ctid, sClearTid);
		PUT("uid="); PUT(uid); PUT(" gid="); PUT(gid);
		PUT(" ctid="); PUT(ctid); PUT("\n");
	}
	PUT("seq=");
	for (k = 0; k < 8; k++) {
		fmt_u64(nseq, gLastN[k]);
		if (k)
			PUT(",");
		PUT(nseq);
	}
	PUT("\n");
#undef PUT
	text[i] = '\0';
	n = (size_t)i;

	off = (size_t)pos;
	if (off >= n) {
		*len = 0;
		return B_OK;
	}
	want = n - off;
	if (want > *len)
		want = *len;
	if (user_memcpy(buf, text + off, want) != B_OK)
		return B_BAD_ADDRESS;
	*len = want;
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
	if (sc_memcmp(token, SYS_COMPAT_LEAVE, SYS_COMPAT_TOKEN_LEN) == 0) {
		linux_clear_all();
		*len = SYS_COMPAT_TOKEN_LEN;
		dprintf("[sys_compat] LEAVE via write token\n");
		return B_OK;
	}
	if (sc_memcmp(token, SYS_COMPAT_TOKEN, SYS_COMPAT_TOKEN_LEN) != 0)
		return B_BAD_VALUE;

	linux_clear_all();
	gLinuxCR3[0] = read_cr3() & ~(uint64)0xfff;
	gLinuxN = 1;
	gMarkCount++;
	sys_compat_mark_team();
	*len = SYS_COMPAT_TOKEN_LEN;
	dprintf("[sys_compat] ENTER via write token, cr3=%#" B_PRIx64 "\n",
		gLinuxCR3[0]);
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
	linux_clear_all();
	call_all_cpus_sync(&install_lstar, NULL);
	if (gOrigLstar == 0) {
		dprintf("[sys_compat] refusing to stay loaded: no original LSTAR\n");
		return B_ERROR;
	}
	dprintf("[sys_compat] identity passthrough armed, orig %#" B_PRIx64 "\n",
		gOrigLstar);
	kser_puts("sys_compat UART live orig=");
	kser_hex(gOrigLstar);
	kser_putc('\n');
	kser_puts("MM3\n");
	discover_syscall_table();
	discover_vm_map_file();
	if (sFutexMu < 0)
		sFutexMu = create_sem(1, "sys_compat_futex");
	{
		int i;
		for (i = 0; i < FUTEX_SLOTS; i++) {
			sFutexW[i].addr = 0;
			sFutexW[i].sem = -1;
		}
	}
	return B_OK;
}

extern "C" void
uninit_driver(void)
{
	linux_clear_all();
	call_all_cpus_sync(&restore_lstar, NULL);
	if (sFutexMu >= 0) {
		delete_sem(sFutexMu);
		sFutexMu = -1;
	}
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
