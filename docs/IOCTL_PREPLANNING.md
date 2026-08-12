# Preplanning Specification: ioctl Interface Translation Layer

**Module**: `sys_compat / ioctl_bridge`  
**Target Subsystems**: TTY/Console, Sockets/Networking, Character Devices, Graphics/DRM  
**License**: Public Domain / CC0 1.0 Universal  

---

## 1. Overview & Architectural Challenge

In Linux and POSIX systems, `ioctl` (I/O Control) serves as the primary catch-all syscall for device-specific and driver-specific operations. Unlike standard filesystem calls (`read`, `write`), `ioctl` opcodes and memory payloads vary dramatically between drivers and OS architectures.

To provide seamless compatibility without kernel panics or buffer corruption:
1. Linux `ioctl` command numbers must be decoded into their direction (`_IOC_DIR`), size (`_IOC_SIZE`), type (`_IOC_TYPE`), and nr (`_IOC_NR`).
2. Bitmasks, command IDs, and underlying data structures must be unpacked, translated into Haiku native ioctl / `sys_ioctl` commands or driver messages, executed, and packed back into Linux userland memory buffers.

---

## 2. Linux ioctl Command Structure Analysis

On Linux, `ioctl` request codes are encoded as 32-bit bitfields:
* **Bits 0..7**: Command Number (`NR`)
* **Bits 8..15**: Type / Magic Number (`TYPE` or 'Group')
* **Bits 16..29**: Parameter Size (`SIZE` - 14 bits)
* **Bits 30..31**: Direction (`DIR` - 2 bits: None=0, Write=1, Read=2, Read/Write=3)

```cpp
// linux_ioctl.h
#define LINUX_IOC_NRSHIFT    0
#define LINUX_IOC_TYPESHIFT  8
#define LINUX_IOC_SIZESHIFT  16
#define LINUX_IOC_DIRSHIFT   30

#define LINUX_IOC_NR(cmd)   (((cmd) >> LINUX_IOC_NRSHIFT) & 0xFF)
#define LINUX_IOC_TYPE(cmd) (((cmd) >> LINUX_IOC_TYPESHIFT) & 0xFF)
#define LINUX_IOC_SIZE(cmd) (((cmd) >> LINUX_IOC_SIZESHIFT) & 0x3FFF)
#define LINUX_IOC_DIR(cmd)  (((cmd) >> LINUX_IOC_DIRSHIFT) & 0x03)
```

---

## 3. Subsystem Translation Breakdown

### 3.1 Terminal & TTY Control ('T' Magic / 0x54)

Terminal applications (`bash`, `busybox`, `htop`, `ncurses`) rely heavily on TTY ioctls.

| Linux Opcode | Linux Macro | Target Haiku Operation / Flag | Structural Difference |
|---|---|---|---|
| `0x5401` | `TCGETS` | `B_TTY_INDEX` / `tcgetattr()` | Linux `struct termios` vs Haiku termios flag offsets |
| `0x5402` | `TCSETS` | `tcsetattr(TCSANOW)` | Direct flag mapping required |
| `0x5403` | `TCSETSW` | `tcsetattr(TCSADRAIN)` | Direct flag mapping required |
| `0x5413` | `TIOCGWINSZ` | `B_TTY_GET_DEVICE_NAME` / Window size | Linux `struct winsize` (`row`, `col`, `xpixel`, `ypixel`) |
| `0x540F` | `TIOCGPGRP` | `tcgetpgrp()` | Process group ID mapping |
| `0x5410` | `TIOCSPGRP` | `tcsetpgrp()` | Process group ID mapping |

#### TTY Structure Translator Skeleton:

```cpp
// ioctl_tty.cpp
struct linux_termios {
    uint32 c_iflag;
    uint32 c_oflag;
    uint32 c_cflag;
    uint32 c_lflag;
    uint8  c_line;
    uint8  c_cc[19];
};

int64
linux_ioctl_tcgets(int fd, struct linux_termios* user_ltermios)
{
    struct termios htermios;
    status_t status = _kern_ioctl(fd, TCGETA, &htermios, sizeof(htermios));
    if (status != B_OK)
        return haiku_to_linux_error(status);

    struct linux_termios ltermios;
    memset(&ltermios, 0, sizeof(ltermios));
    ltermios.c_iflag = map_iflags_haiku_to_linux(htermios.c_iflag);
    ltermios.c_oflag = map_oflags_haiku_to_linux(htermios.c_oflag);
    ltermios.c_cflag = map_cflags_haiku_to_linux(htermios.c_cflag);
    ltermios.c_lflag = map_lflags_haiku_to_linux(htermios.c_lflag);
    memcpy(ltermios.c_cc, htermios.c_cc, 19);

    if (user_memcpy(user_ltermios, &ltermios, sizeof(ltermios)) != B_OK)
        return -EFAULT;

    return 0;
}
```

### 3.2 Socket & Network Control ('S' Magic / 0x89)

Network utilities (`ip`, `ifconfig`, `netstat`, socket control) query interfaces via socket file descriptors.

| Linux Opcode | Linux Macro | Target Haiku Socket Command | Description |
|---|---|---|---|
| `0x8912` | `SIOCGIFCONF` | `SIOCGIFCONF` | Get interface list configuration |
| `0x8913` | `SIOCGIFFLAGS` | `SIOCGIFFLAGS` | Get interface active flags (UP, RUNNING, BROADCAST) |
| `0x8915` | `SIOCGIFADDR` | `SIOCGIFADDR` | Get IPv4/IPv6 socket address |
| `0x8927` | `SIOCGIFHWADDR` | `SIOCGIFHWADDR` | Get MAC hardware address |
| `0x8910` | `FIONBIO` | `FIONBIO` / `_kern_set_file_flags(O_NONBLOCK)` | Set non-blocking I/O mode |

### 3.3 Framebuffer & DRM Graphics Preplanning ('d' Magic / 0x64)

For future GUI / hardware-accelerated rendering compatibility, Linux DRI/DRM ioctls need direct routing to Haiku's acceleration drivers (`/dev/graphics/...`).

* **DRM Command Range**: `0x6400` to `0x6499` (`DRM_IOCTL_VERSION`, `DRM_IOCTL_GET_UNIQUE`, `DRM_IOCTL_MODE_GETRESOURCES`).
* **Strategy**: Create a passthrough driver adapter that translates Linux `drm_version_t` and GEM/PRIME buffer handles into Haiku accelerator areas.

---

## 4. Phase-by-Phase ioctl Implementation Roadmap

* **Phase 1 (Terminal Fundamentals)**: Implement `TCGETS`, `TCSETS`, `TIOCGWINSZ`, `TIOCGPGRP`, and `FIONBIO`. Enables interactive shell applications and terminal text editors.
* **Phase 2 (Networking & Sockets)**: Map `SIOCGIFCONF`, `SIOCGIFADDR`, `SIOCGIFFLAGS`, and `FIONREAD` (bytes available).
* **Phase 3 (Device Passthrough & Storage)**: Map `BLKGETSIZE64`, `HDIO_GETGEO`, and generic device queries for storage utilities.
* **Phase 4 (DRM/Graphics Subsystem)**: Shim Linux DRM ioctl structures onto native Haiku graphics display drivers.
