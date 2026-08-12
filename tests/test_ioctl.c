/*
 * ioctl translation test suite for sys_compat (TTY & DRM/KMS)
 * License: Public Domain / CC0 1.0 Universal
 */

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <termios.h>

struct drm_version {
    int    version_major;
    int    version_minor;
    int    version_patchlevel;
    size_t name_len;
    char*  name;
    size_t date_len;
    char*  date;
    size_t desc_len;
    char*  desc;
};

#define DRM_IOCTL_VERSION 0xC0406400

int main(void)
{
    printf("====================================================\n");
    printf("  sys_compat ioctl Translation Engine Test Suite    \n");
    printf("====================================================\n");

    // 1. Test TTY window size ioctl (TIOCGWINSZ)
    struct winsize ws;
    memset(&ws, 0, sizeof(ws));
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0) {
        printf("[+] TIOCGWINSZ Success: Terminal Rows=%d, Cols=%d (Pixel X=%d, Y=%d)\n",
               ws.ws_row, ws.ws_col, ws.ws_xpixel, ws.ws_ypixel);
    } else {
        perror("[-] TIOCGWINSZ failed");
    }

    // 2. Test TTY termios attributes ioctl (TCGETS)
    struct termios term;
    memset(&term, 0, sizeof(term));
    if (ioctl(STDIN_FILENO, TCGETS, &term) == 0) {
        printf("[+] TCGETS Success: lflag=0x%x, iflag=0x%x, oflag=0x%x, cflag=0x%x\n",
               term.c_lflag, term.c_iflag, term.c_oflag, term.c_cflag);
    } else {
        perror("[-] TCGETS failed");
    }

    // 3. Test DRM/KMS display driver version ioctl (DRM_IOCTL_VERSION)
    char name_buf[64] = {0};
    char desc_buf[128] = {0};
    struct drm_version ver;
    memset(&ver, 0, sizeof(ver));
    ver.name = name_buf;
    ver.name_len = sizeof(name_buf) - 1;
    ver.desc = desc_buf;
    ver.desc_len = sizeof(desc_buf) - 1;

    if (ioctl(0, DRM_IOCTL_VERSION, &ver) == 0) {
        printf("[+] DRM_IOCTL_VERSION Success: Driver '%s' v%d.%d.%d ('%s')\n",
               ver.name, ver.version_major, ver.version_minor, ver.version_patchlevel, ver.desc);
    } else {
        perror("[-] DRM_IOCTL_VERSION failed");
    }

    printf("[+] All ioctl Translation Tests Executed!\n");
    return 0;
}
