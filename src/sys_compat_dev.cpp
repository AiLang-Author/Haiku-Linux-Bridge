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
#define LINUX_ENOMEM       12
#define LINUX_EACCES       13
#define LINUX_EFAULT       14
#define LINUX_ENOTDIR      20
#define LINUX_EISDIR       21
#define LINUX_EEXIST       17
#define LINUX_EINVAL       22
#define LINUX_ENAMETOOLONG 36
#define LINUX_ENOSYS       38

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
#define HAIKU_WRITE_STAT 0x9d
/* Guest libroot dump (hrev57937): unmap=0xd5 mprotect=0xd6.
 * Later Haiku sources insert two syscalls before these. */
#define HAIKU_UNMAP      0xd5
#define HAIKU_MPROTECT   0xd6
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
#define HAIKU_CLOCK_REALTIME  ((int32)-1)
#define HAIKU_CLOCK_MONOTONIC ((int32)0)

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

#define IA32_FS_BASE 0xc0000100

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
			}
			dprintf("[sys_compat] kSyscallInfos=%p read_dir=%#" B_PRIx64
				" read_stat=%#" B_PRIx64 " write_stat=%#" B_PRIx64
				" unmap=%#" B_PRIx64 " mprotect=%#" B_PRIx64
				" rename_thr=%#" B_PRIx64 "\n",
				sSyscallInfos, sReadDirFn, sReadStatFn, sWriteStatFn,
				sUnmapFn, sMprotectFn, sRenameThrFn);
			return;
		}
	}
	dprintf("[sys_compat] kSyscallInfos scan missed\n");
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
	case 0x8000000a: return -LINUX_EINTR;        /* B_INTERRUPTED */
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

	if (get_team_info(B_CURRENT_TEAM, &info) != B_OK)
		return -1;
	gLinuxTeam[0] = info.team;
	if (gLinuxN == 0)
		gLinuxN = 1;
	sHaveUid = 0;
	sHaveGid = 0;
	sClearTid = 0;
	sRobustList = 0;
	sRobustLen = 0;
	dprintf("[sys_compat] mark team=%" B_PRId32 " parent=%" B_PRId32 "\n",
		info.team, info.parent);
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

	if (get_team_info(B_CURRENT_TEAM, &info) != B_OK)
		return 1;
	return info.team;
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
	sRobustList = (uint64)(addr_t)head;
	sRobustLen = len;
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
	discover_syscall_table();
	return B_OK;
}

extern "C" void
uninit_driver(void)
{
	linux_clear_all();
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
