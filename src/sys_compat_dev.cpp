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
#define LINUX_EIO           5
#define LINUX_EBADF         9
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

static struct ksc_info* sSyscallInfos;
static uint64 sReadDirFn;
static uint64 sReadStatFn;
static uint64 sCreateDirFn;
static uint64 sRemoveDirFn;
static uint64 sUnlinkFn;
static uint64 sAccessFn;
static uint64 sGetcwdFn;
static uint64 sSetcwdFn;
static int64 sLastPath;
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
	extern uint64 gLinuxCR3;
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
	int64 sys_compat_dispatch_fast(uint64* saved);
	int64 sys_compat_getdents64(int64 fd, void* userBuf, uint64 count);
	int64 sys_compat_stat(int64 fd, const void* userPath, void* userStat,
		int64 flags);
	int64 sys_compat_mkdir(int64 fd, const void* path, int64 mode);
	int64 sys_compat_unlink(int64 fd, const void* path, int64 flags);
	int64 sys_compat_access(int64 fd, const void* path, int64 mode);
	int64 sys_compat_getcwd(void* buf, uint64 size);
	int64 sys_compat_chdir(int64 fd, const void* path);
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
			}
			dprintf("[sys_compat] kSyscallInfos=%p read_dir=%#" B_PRIx64
				" read_stat=%#" B_PRIx64 "\n",
				sSyscallInfos, sReadDirFn, sReadStatFn);
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
	case 0x8000000f: return -LINUX_EPERM;        /* B_NOT_ALLOWED */
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
	char text[512];
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

	fmt_hex(h1, gLinuxCR3);
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
	PUT("cr3="); PUT(h1); PUT("\n");
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
		gLinuxCR3 = 0;
		*len = SYS_COMPAT_TOKEN_LEN;
		dprintf("[sys_compat] LEAVE via write token\n");
		return B_OK;
	}
	if (sc_memcmp(token, SYS_COMPAT_TOKEN, SYS_COMPAT_TOKEN_LEN) != 0)
		return B_BAD_VALUE;

	gLinuxCR3 = read_cr3() & ~(uint64)0xfff;
	gMarkCount++;
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
	discover_syscall_table();
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
