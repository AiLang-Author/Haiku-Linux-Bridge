---
name: Bug report
about: A Linux ELF failed on the Haiku sys_compat layer
title: ""
labels: "needs-triage"
---

Read [docs/STATUS.md](../docs/STATUS.md) first. Known-not-yet: dynamic glibc, ioctl/TTY, CLONE_VM/pthread, interactive `sh`, sockets.

**Command** (exact):

```
sys_compat_run …
```

**Binary** (`file` output, static/dynamic, musl/glibc, where from):

**Expected:**

**Actual** (stdout / exit code / did the Haiku desktop stay up?):

**Failure class** (pick one):
- [ ] wrong output or errno / `-ENOSYS`
- [ ] Kill Thread / “Oh no!” / “Crashed program”
- [ ] KDL
- [ ] silent reboot

**Haiku revision** (`uname -a` from a Haiku shell) and QEMU vs hardware:

**`cat /dev/misc/sys_compat` after the run:**

```
```

**COM1 / `haiku_serial.log` tail** (if you have it):

```
```
