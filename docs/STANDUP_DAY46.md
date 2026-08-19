# Developer standup: Day 46

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed (PR40)

Linux fbdev onto Haiku VESA, not DRM.

| Linux | Haiku |
|---|---|
| `open("/dev/fb0")` | placeholder fd; records the `vesa frame buffer` area |
| `FBIOGET_VSCREENINFO` / `FSCREENINFO` | width/height/pitch from `vesa shared info` `display_timing` |
| `mmap` of that fd | `vm_map_physical_memory` of the VESA aperture into the Linux team |
| `FBIOPUT_VSCREENINFO` / `FBIOBLANK` | no-op (do not steal the mode from app_server) |

### Guest-proven

Haiku `screenmode`: **1280 800, 32 bits, 75 Hz**. Area `vesa frame buffer` at phys **`0xFD000000`**.

| Probe | Result |
|---|---|
| `open("/dev/fb0")` | **`FBFD=3`** |
| `FBIOGET_VSCREENINFO` | **`x=1280 y=800 bpp=32`** |
| `FBIOGET_FSCREENINFO` | **`len=4096000 pitch=5120`** |
| `mmap` | **`FMAP` userspace**, COM1 `FBO` |
| read pixel 0 | **`FPIX=4026597203`** (live desktop) |
| `FBOK` / `FB_RC` | **0** |
| busybox `date -u` | still prints |

COM1: `FB 0x500x0x320 a=0x1f0b p=0xfd000000`. `PHfn=` `vm_map_physical_memory`. Banner `PR40`.

### Do not

- Build a Linux DRM/KMS stack.
- `FBIOPUT` a new mode while app_server owns the card.
- Pipe-cache guest `curl` of `sys_compat_dev.cpp` (Haiku curl keeps GET bodies).

### Next

Interactive `busybox sh` on the Haiku Terminal. Other ioctl families later.
