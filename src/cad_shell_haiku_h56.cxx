/* cad_shell_haiku — native Haiku Interface Kit host for AILang CAD.
 *
 * Kernel (cad_app.x) owns geometry + software renderer.
 * This process is Haiku-native (libbe / app_server): blit frame.raw,
 * menus/toolbar, mouse/keys → cmd.txt. Same IPC as cad_host_x11.
 *
 *   g++ -O2 -o cad_shell_haiku cad_shell_haiku.cxx -lbe
 *   CAD_APP_STATE=/tmp/cad_app ./cad_shell_haiku
 *
 * Not Linux GUI. Not /dev/fb0 (that fights app_server). Pixels go
 * BBitmap → BView::DrawBitmap through Haiku's window server.
 *
 * Copyright (c) 2025-2026 Sean Collins, 2 Paws Machine and Engineering.
 * Licensed under the Sean Collins Software License (SCSL v1.0).
 */
#ifndef __HAIKU__
#error cad_shell_haiku.cxx is the Haiku Interface Kit host. Build on Haiku: g++ -O2 -o cad_shell_haiku cad_shell_haiku.cxx -lbe
#endif

#include <Application.h>
#include <Bitmap.h>
#include <Button.h>
#include <Menu.h>
#include <MenuBar.h>
#include <MenuItem.h>
#include <MessageRunner.h>
#include <Messenger.h>
#include <Screen.h>
#include <StringView.h>
#include <View.h>
#include <Window.h>

#include <ctype.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

enum {
    MSG_POLL = 'poll',
    MSG_CMD  = 'cmd_'
};

static char g_dir[512];
static char path_meta[600], path_frame[600], path_gen[600], path_cmd[600];
static char path_status[600], path_tool[600], path_parts[600], path_sel[600];

static void paths_init(const char *dir) {
    snprintf(g_dir, sizeof g_dir, "%s", dir);
    snprintf(path_meta, sizeof path_meta, "%s/meta.bin", dir);
    snprintf(path_frame, sizeof path_frame, "%s/frame.raw", dir);
    snprintf(path_gen, sizeof path_gen, "%s/gen.txt", dir);
    snprintf(path_cmd, sizeof path_cmd, "%s/cmd.txt", dir);
    snprintf(path_status, sizeof path_status, "%s/status.txt", dir);
    snprintf(path_tool, sizeof path_tool, "%s/tool.txt", dir);
    snprintf(path_parts, sizeof path_parts, "%s/parts.txt", dir);
    snprintf(path_sel, sizeof path_sel, "%s/sel.txt", dir);
}

static void write_cmd(const char *s) {
    int tries;
    for (tries = 0; tries < 40; tries++) {
        FILE *cf = fopen(path_cmd, "r");
        int busy = 0;
        if (cf) {
            int c = fgetc(cf);
            if (c != EOF && c != '\n' && c != '\r') busy = 1;
            fclose(cf);
        }
        if (!busy) break;
        usleep(2000);
    }
    FILE *f = fopen(path_cmd, "w");
    if (!f) return;
    fputs(s, f);
    fputc('\n', f);
    fclose(f);
}

static int cmd_busy(void) {
    FILE *cf = fopen(path_cmd, "r");
    if (!cf) return 0;
    int c = fgetc(cf);
    fclose(cf);
    return (c != EOF && c != '\n' && c != '\r');
}

static int read_gen(void) {
    FILE *f = fopen(path_gen, "r");
    if (!f) return -1;
    int g = -1;
    if (fscanf(f, "%d", &g) != 1) g = -1;
    fclose(f);
    return g;
}

static void read_line_file(const char *path, char *buf, size_t n) {
    buf[0] = 0;
    FILE *f = fopen(path, "r");
    if (!f) return;
    if (fgets(buf, (int)n, f)) {
        size_t L = strlen(buf);
        while (L && (buf[L - 1] == '\n' || buf[L - 1] == '\r')) buf[--L] = 0;
    }
    fclose(f);
}

static int sketch_mode(void) {
    FILE *f = fopen(path_tool, "r");
    if (!f) return 0;
    int mode = 0, tool = 0, nclick = 0, dirty = 0;
    int n = fscanf(f, "%d %d %d %d", &mode, &tool, &nclick, &dirty);
    fclose(f);
    if (n < 4) return 0;
    return mode == 1;
}

static int tool_nclick(void) {
    FILE *f = fopen(path_tool, "r");
    if (!f) return 0;
    int mode = 0, tool = 0, nclick = 0, dirty = 0;
    if (fscanf(f, "%d %d %d %d", &mode, &tool, &nclick, &dirty) < 4) nclick = 0;
    fclose(f);
    return nclick;
}

static int load_frame(uint8_t **out_pix, int *out_w, int *out_h, int *out_pitch) {
    int fd = open(path_meta, O_RDONLY);
    if (fd < 0) return -1;
    int32_t hdr[3];
    if (read(fd, hdr, 12) != 12) { close(fd); return -1; }
    close(fd);
    int w = hdr[0], h = hdr[1], pitch = hdr[2];
    if (w < 16 || h < 16 || pitch < w * 4) return -1;
    if (w > 4096 || h > 4096) return -1;
    size_t sz = (size_t)pitch * (size_t)h;
    uint8_t *pix = (uint8_t *)malloc(sz);
    if (!pix) return -1;
    fd = open(path_frame, O_RDONLY);
    if (fd < 0) { free(pix); return -1; }
    size_t got = 0;
    while (got < sz) {
        ssize_t n = read(fd, pix + got, sz - got);
        if (n <= 0) break;
        got += (size_t)n;
    }
    close(fd);
    if (got < sz) { free(pix); return -1; }
    *out_pix = pix;
    *out_w = w;
    *out_h = h;
    *out_pitch = pitch;
    return 0;
}

static BMessage *cmd_msg(const char *cmd) {
    BMessage *m = new BMessage(MSG_CMD);
    m->AddString("cmd", cmd);
    return m;
}

class CadView : public BView {
public:
    CadView(BRect frame)
        : BView(frame, "cad-view", B_FOLLOW_ALL_SIDES,
                B_WILL_DRAW | B_FULL_UPDATE_ON_RESIZE | B_NAVIGABLE | B_FRAME_EVENTS),
          fBitmap(NULL), fPix(NULL), fW(0), fH(0), fPitch(0),
          fOx(0), fOy(0),
          fDragging(0), fMoved(0), fPan(0),
          fDownX(0), fDownY(0), fLastX(0), fLastY(0),
          fClickPending(0), fClickSent(0), fClickSh(0),
          fPendOx(0), fPendOy(0), fPendZoom(0),
          fPendPanX(0), fPendPanY(0),
          fPendHover(0), fHoverX(0), fHoverY(0),
          fLastHoverX(-9999), fLastHoverY(-9999) {
        SetViewColor(0x12, 0x14, 0x1a);
        SetLowColor(0x12, 0x14, 0x1a);
        fDownTs.tv_sec = 0;
        fDownTs.tv_nsec = 0;
    }

    ~CadView() {
        delete fBitmap;
        free(fPix);
    }

    void AttachedToWindow() {
        MakeFocus(true);
    }

    int FrameX(BPoint p) const { return (int)(p.x - fOx); }
    int FrameY(BPoint p) const { return (int)(p.y - fOy); }

    void Draw(BRect) {
        if (fBitmap) {
            BRect src(0, 0, fW - 1, fH - 1);
            BRect dst(fOx, fOy, fOx + fW - 1, fOy + fH - 1);
            DrawBitmap(fBitmap, src, dst);
            DrawPartsOverlay();
        } else {
            SetHighColor(0x12, 0x14, 0x1a);
            FillRect(Bounds());
            SetHighColor(0xc0, 0xc8, 0xd8);
            const char *msg = "waiting for cad_app.x  (frame.raw)";
            DrawString(msg, BPoint(24, 40));
            const char *msg2 = "Haiku app_server blit — not Linux fbdev/X11";
            DrawString(msg2, BPoint(24, 58));
        }
    }

    void DrawPartsOverlay() {
        struct stat st;
        if (stat(path_parts, &st) != 0 || st.st_size <= 0) return;
        FILE *f = fopen(path_parts, "r");
        if (!f) return;
        int sel = 0;
        FILE *sf = fopen(path_sel, "r");
        if (sf) {
            if (fscanf(sf, "%d", &sel) != 1) sel = 0;
            fclose(sf);
        }
        float ox = fOx + 8, oy = fOy + 8;
        SetHighColor(0x10, 0x10, 0x18);
        FillRect(BRect(ox, oy, ox + 200, oy + 220));
        SetHighColor(0xc0, 0xc8, 0xd8);
        StrokeRect(BRect(ox, oy, ox + 200, oy + 220));
        DrawString("Parts (f list)", BPoint(ox + 8, oy + 16));
        char line[128];
        int row = 0;
        while (row < 12 && fgets(line, sizeof line, f)) {
            size_t L = strlen(line);
            while (L && (line[L - 1] == '\n' || line[L - 1] == '\r')) line[--L] = 0;
            if (!L) continue;
            float y = oy + 36 + row * 16;
            if (row == sel) {
                SetHighColor(0x30, 0x40, 0x60);
                FillRect(BRect(ox + 4, y - 12, ox + 196, y + 4));
                SetHighColor(0xff, 0xe0, 0x80);
            } else {
                SetHighColor(0xd0, 0xd8, 0xe8);
            }
            if (L > 28) line[28] = 0;
            DrawString(line, BPoint(ox + 8, y));
            row++;
        }
        fclose(f);
        SetHighColor(0xa0, 0xa8, 0xb8);
        DrawString("j/i sel  g open  p save", BPoint(ox + 8, oy + 208));
    }

    bool AdoptFrame(uint8_t *pix, int w, int h, int pitch) {
        BBitmap *nb = new BBitmap(BRect(0, 0, w - 1, h - 1), B_RGB32, true);
        if (!nb || !nb->IsValid() || !nb->Bits()) {
            delete nb;
            free(pix);
            return false;
        }
        uint8_t *dst = (uint8_t *)nb->Bits();
        int32 bpr = nb->BytesPerRow();
        int copy = w * 4;
        if (copy > pitch) copy = pitch;
        if (copy > bpr) copy = bpr;
        for (int y = 0; y < h; y++)
            memcpy(dst + (size_t)y * (size_t)bpr, pix + (size_t)y * (size_t)pitch, (size_t)copy);
        delete fBitmap;
        free(fPix);
        fBitmap = nb;
        fPix = pix;
        fW = w;
        fH = h;
        fPitch = pitch;
        LayoutOffset();
        Invalidate();
        return true;
    }

    void LayoutOffset() {
        BRect b = Bounds();
        int ww = (int)b.Width() + 1;
        int wh = (int)b.Height() + 1;
        fOx = (ww - fW) / 2;
        fOy = (wh - fH) / 2;
        if (fOx < 0) fOx = 0;
        if (fOy < 0) fOy = 0;
    }

    void FrameResized(float, float) {
        LayoutOffset();
        Invalidate();
    }

    void MouseDown(BPoint where) {
        MakeFocus(true);
        uint32 buttons = 0;
        GetMouse(&where, &buttons);
        int fx = FrameX(where);
        int fy = FrameY(where);
        if (buttons & B_PRIMARY_MOUSE_BUTTON) {
            fDragging = 1;
            fMoved = 0;
            fPan = 0;
            fClickPending = 0;
            fClickSent = 0;
            fDownX = fLastX = fx;
            fDownY = fLastY = fy;
            clock_gettime(CLOCK_MONOTONIC, &fDownTs);
            SetMouseEventMask(B_POINTER_EVENTS, B_LOCK_WINDOW_FOCUS);
            if (sketch_mode() && fx >= 0 && fy >= 0 && (fW <= 0 || (fx < fW && fy < fH))) {
                fClickPending = 1;
                fClickSh = (modifiers() & B_SHIFT_KEY) ? 1 : 0;
            }
        } else if (buttons & B_SECONDARY_MOUSE_BUTTON) {
            write_cmd("cancel");
        }
    }

    void MouseMoved(BPoint where, uint32, const BMessage *) {
        int fx = FrameX(where);
        int fy = FrameY(where);
        uint32 buttons = 0;
        BPoint cur = where;
        GetMouse(&cur, &buttons);
        if (fDragging && (buttons & B_PRIMARY_MOUSE_BUTTON)) {
            int dx = fx - fLastX;
            int dy = fy - fLastY;
            if (dx || dy) {
                int adx = abs(fx - fDownX), ady = abs(fy - fDownY);
                if (adx >= 3 || ady >= 3) fMoved = 1;
                if (sketch_mode()) {
                    struct timespec now;
                    clock_gettime(CLOCK_MONOTONIC, &now);
                    long ms = (now.tv_sec - fDownTs.tv_sec) * 1000L
                            + (now.tv_nsec - fDownTs.tv_nsec) / 1000000L;
                    if (!fPan && !fClickSent && ms >= 800) {
                        fPan = 1;
                        fClickPending = 0;
                    }
                    if (fPan) {
                        fPendPanX += dx;
                        fPendPanY += dy;
                        fLastX = fx;
                        fLastY = fy;
                    } else if (abs(fx - fLastHoverX) >= 1 || abs(fy - fLastHoverY) >= 1) {
                        fPendHover = 1;
                        fHoverX = fx;
                        fHoverY = fy;
                        fLastHoverX = fx;
                        fLastHoverY = fy;
                        fLastX = fx;
                        fLastY = fy;
                    }
                } else {
                    fPendOx += dx;
                    fPendOy += dy;
                    fLastX = fx;
                    fLastY = fy;
                }
            }
        } else if (!fDragging && sketch_mode()) {
            int need = (tool_nclick() > 0) ? 1 : 2;
            if (abs(fx - fLastHoverX) >= need || abs(fy - fLastHoverY) >= need) {
                if (fx >= 0 && fy >= 0 && (fW <= 0 || (fx < fW && fy < fH))) {
                    fPendHover = 1;
                    fHoverX = fx;
                    fHoverY = fy;
                    fLastHoverX = fx;
                    fLastHoverY = fy;
                }
            }
        }
    }

    void MouseUp(BPoint where) {
        if (!fDragging) return;
        int fx = FrameX(where);
        int fy = FrameY(where);
        int adx = abs(fx - fDownX), ady = abs(fy - fDownY);
        fDragging = 0;
        if (sketch_mode()) {
            if (fPan) {
                fPan = 0;
            } else if (fx >= 0 && fy >= 0 && (fW <= 0 || (fx < fW && fy < fH))) {
                if (fClickPending && !fClickSent) {
                    char cmd[64];
                    int cx = (fMoved && (adx >= 3 || ady >= 3)) ? fx : fDownX;
                    int cy = (fMoved && (adx >= 3 || ady >= 3)) ? fy : fDownY;
                    snprintf(cmd, sizeof cmd, "click %d %d %d", cx, cy, fClickSh);
                    write_cmd(cmd);
                    fClickSent = 1;
                    fClickPending = 0;
                    fPendHover = 1;
                    fHoverX = cx;
                    fHoverY = cy;
                    fLastHoverX = cx;
                    fLastHoverY = cy;
                }
            }
            fClickPending = 0;
        } else {
            if (!fMoved && adx < 4 && ady < 4) {
                if (fx >= 0 && fy >= 0 && fx < fW && fy < fH) {
                    char cmd[64];
                    snprintf(cmd, sizeof cmd, "click %d %d", fx, fy);
                    write_cmd(cmd);
                }
            }
        }
    }

    void MessageReceived(BMessage *msg) {
        if (msg->what == B_MOUSE_WHEEL_CHANGED) {
            float dy = 0;
            if (msg->FindFloat("be:wheel_delta_y", &dy) == B_OK) {
                if (dy > 0) fPendZoom += 1;
                else if (dy < 0) fPendZoom -= 1;
            }
            return;
        }
        BView::MessageReceived(msg);
    }

    void KeyDown(const char *bytes, int32 numBytes) {
        if (numBytes < 1 || !bytes) return;
        unsigned char ch = (unsigned char)bytes[0];
        uint32 mods = modifiers();
        if (ch == B_ESCAPE || ch == 'q' || ch == 'Q') {
            write_cmd("quit");
            Window()->PostMessage(B_QUIT_REQUESTED);
            return;
        }
        if (ch == B_ENTER) { write_cmd("open"); return; }
        if (ch == B_TAB) { write_cmd("mode"); return; }
        if (ch == B_DOWN_ARROW) { write_cmd("j"); return; }
        if (ch == B_UP_ARROW) { write_cmd("i"); return; }
        if (ch == '[' || ch == '-') { write_cmd("hdec"); return; }
        if (ch == ']' || ch == '+' || ch == '=') { write_cmd("hinc"); return; }
        if (ch == '.') { write_cmd("tool_point"); return; }
        if (ch >= 'A' && ch <= 'Z') ch = (unsigned char)(ch - 'A' + 'a');
        switch (ch) {
        case 'r': write_cmd("repad"); break;
        case 'u': write_cmd("cut"); break;
        case 'o': write_cmd("reload"); break;
        case 'p': write_cmd("p"); break;
        case 'g': write_cmd("g"); break;
        case 'f': write_cmd("f"); break;
        case 'j': write_cmd("j"); break;
        case 'i': write_cmd("i"); break;
        case 'k': write_cmd("k"); break;
        case 'w': write_cmd("wire"); break;
        case 's': write_cmd("step"); break;
        case 'b': write_cmd("bmp"); break;
        case 'm': write_cmd("mode"); break;
        case 'l': write_cmd("tool_line"); break;
        case 'e': write_cmd("tool_rect"); break;
        case 'c': write_cmd("tool_circ"); break;
        case 'a': write_cmd("tool_arc"); break;
        case 'z': write_cmd("solve"); break;
        case 'y': write_cmd("y"); break;
        case 'n': write_cmd("newdoc"); break;
        case 'x': write_cmd("dxf"); break;
        case '1': write_cmd("view0"); break;
        case '2': write_cmd("view1"); break;
        case '3': write_cmd("view2"); break;
        default:
            BView::KeyDown(bytes, numBytes);
            break;
        }
        (void)mods;
    }

    void FlushPending() {
        if (cmd_busy()) return;
        if (fPendOx || fPendOy) {
            char cmd[64];
            snprintf(cmd, sizeof cmd, "orbit %d %d", fPendOx, fPendOy);
            write_cmd(cmd);
            fPendOx = fPendOy = 0;
        } else if (fPendPanX || fPendPanY) {
            char cmd[64];
            snprintf(cmd, sizeof cmd, "pan %d %d", fPendPanX, fPendPanY);
            write_cmd(cmd);
            fPendPanX = fPendPanY = 0;
        } else if (fPendZoom) {
            char cmd[64];
            snprintf(cmd, sizeof cmd, "zoom %d", fPendZoom);
            write_cmd(cmd);
            fPendZoom = 0;
        } else if (fPendHover) {
            char cmd[64];
            snprintf(cmd, sizeof cmd, "hover %d %d", fHoverX, fHoverY);
            write_cmd(cmd);
            fPendHover = 0;
        }
    }

    int fW, fH, fPitch;
    int fOx, fOy;
private:
    BBitmap *fBitmap;
    uint8_t *fPix;
    int fDragging, fMoved, fPan;
    int fDownX, fDownY, fLastX, fLastY;
    int fClickPending, fClickSent, fClickSh;
    int fPendOx, fPendOy, fPendZoom;
    int fPendPanX, fPendPanY;
    int fPendHover, fHoverX, fHoverY;
    int fLastHoverX, fLastHoverY;
    struct timespec fDownTs;
};

class CadWindow : public BWindow {
public:
    CadWindow(BRect frame)
        : BWindow(frame, "AILang CAD — Haiku", B_TITLED_WINDOW,
                  B_QUIT_ON_WINDOW_CLOSE | B_ASYNCHRONOUS_CONTROLS),
          fLastGen(-1) {
        BRect mbR(0, 0, Bounds().right, 19);
        fMenu = new BMenuBar(mbR, "menubar");
        BMenu *file = new BMenu("File");
        file->AddItem(new BMenuItem("List", cmd_msg("f"), 'F'));
        file->AddItem(new BMenuItem("Open", cmd_msg("g"), 'G'));
        file->AddItem(new BMenuItem("Save", cmd_msg("p"), 'S'));
        file->AddItem(new BMenuItem("New", cmd_msg("newdoc"), 'N'));
        file->AddItem(new BMenuItem("Close", cmd_msg("k")));
        file->AddItem(new BMenuItem("Reload DXF", cmd_msg("reload")));
        file->AddSeparatorItem();
        file->AddItem(new BMenuItem("Export STEP", cmd_msg("step")));
        file->AddItem(new BMenuItem("Export BMP", cmd_msg("bmp")));
        file->AddSeparatorItem();
        file->AddItem(new BMenuItem("Quit", cmd_msg("quit"), 'Q'));
        fMenu->AddItem(file);

        BMenu *sk = new BMenu("Sketch");
        sk->AddItem(new BMenuItem("Sketch / 3D", cmd_msg("mode"), 'M'));
        sk->AddSeparatorItem();
        sk->AddItem(new BMenuItem("Line", cmd_msg("tool_line"), 'L'));
        sk->AddItem(new BMenuItem("Rect", cmd_msg("tool_rect"), 'E'));
        sk->AddItem(new BMenuItem("Circle", cmd_msg("tool_circ"), 'C'));
        sk->AddItem(new BMenuItem("Arc", cmd_msg("tool_arc"), 'A'));
        sk->AddItem(new BMenuItem("Point", cmd_msg("tool_point")));
        sk->AddItem(new BMenuItem("Trim", cmd_msg("tool_trim")));
        sk->AddItem(new BMenuItem("Pick", cmd_msg("tool_pick")));
        sk->AddItem(new BMenuItem("Fillet 2D", cmd_msg("tool_fillet")));
        sk->AddSeparatorItem();
        sk->AddItem(new BMenuItem("Profiles", cmd_msg("profiles")));
        sk->AddItem(new BMenuItem("Next profile", cmd_msg("y")));
        sk->AddItem(new BMenuItem("Solve", cmd_msg("solve"), 'Z'));
        sk->AddItem(new BMenuItem("Cancel", cmd_msg("cancel")));
        fMenu->AddItem(sk);

        BMenu *feat = new BMenu("Feature");
        feat->AddItem(new BMenuItem("Pad", cmd_msg("repad"), 'R'));
        feat->AddItem(new BMenuItem("Revolve", cmd_msg("revolve")));
        feat->AddItem(new BMenuItem("Cut", cmd_msg("cut"), 'U'));
        feat->AddSeparatorItem();
        feat->AddItem(new BMenuItem("H 5", cmd_msg("height 5")));
        feat->AddItem(new BMenuItem("H 10", cmd_msg("height 10")));
        feat->AddItem(new BMenuItem("H 20", cmd_msg("height 20")));
        feat->AddItem(new BMenuItem("H+", cmd_msg("hinc")));
        feat->AddItem(new BMenuItem("H-", cmd_msg("hdec")));
        fMenu->AddItem(feat);

        BMenu *view = new BMenu("View");
        view->AddItem(new BMenuItem("Iso", cmd_msg("view0"), '1'));
        view->AddItem(new BMenuItem("Top", cmd_msg("view1"), '2'));
        view->AddItem(new BMenuItem("Front", cmd_msg("view2"), '3'));
        view->AddItem(new BMenuItem("Wire", cmd_msg("wire"), 'W'));
        view->AddSeparatorItem();
        view->AddItem(new BMenuItem("XY plane", cmd_msg("plane_xy")));
        view->AddItem(new BMenuItem("XZ plane", cmd_msg("plane_xz")));
        view->AddItem(new BMenuItem("YZ plane", cmd_msg("plane_yz")));
        fMenu->AddItem(view);

        AddChild(fMenu);

        float mbh = fMenu->Frame().Height() + 1;
        BRect b = Bounds();
        float tools_h = 28;
        BRect toolsR(0, mbh, b.right, mbh + tools_h);
        fTools = new BView(toolsR, "tools", B_FOLLOW_LEFT_RIGHT | B_FOLLOW_TOP,
                           B_WILL_DRAW);
        fTools->SetViewUIColor(B_PANEL_BACKGROUND_COLOR);
        AddChild(fTools);
        AddTool(fTools, 4, "Sketch", "mode");
        AddTool(fTools, 68, "Line", "tool_line");
        AddTool(fTools, 120, "Rect", "tool_rect");
        AddTool(fTools, 172, "Circ", "tool_circ");
        AddTool(fTools, 224, "Pad", "repad");
        AddTool(fTools, 276, "Cut", "cut");
        AddTool(fTools, 328, "Wire", "wire");
        AddTool(fTools, 380, "Iso", "view0");
        AddTool(fTools, 432, "Quit", "quit");

        float st_h = 22;
        BRect viewR(0, mbh + tools_h + 1, b.right, b.bottom - st_h);
        fView = new CadView(viewR);
        AddChild(fView);

        BRect stR(0, b.bottom - st_h + 1, b.right, b.bottom);
        fStatus = new BStringView(stR, "status",
            "waiting for kernel — LMB orbit, scroll zoom, q quit");
        fStatus->SetResizingMode(B_FOLLOW_LEFT_RIGHT | B_FOLLOW_BOTTOM);
        fStatus->SetViewUIColor(B_PANEL_BACKGROUND_COLOR);
        AddChild(fStatus);

        BMessage poll(MSG_POLL);
        fPulse = new BMessageRunner(BMessenger(this), &poll, 16000);
        fView->MakeFocus(true);
    }

    ~CadWindow() {
        delete fPulse;
    }

    void AddTool(BView *parent, float x, const char *lab, const char *cmd) {
        BRect r(x, 2, x + 60, 26);
        BButton *b = new BButton(r, lab, lab, cmd_msg(cmd));
        b->SetResizingMode(B_FOLLOW_LEFT | B_FOLLOW_TOP);
        parent->AddChild(b);
    }

    bool QuitRequested() {
        write_cmd("quit");
        return true;
    }

    void MessageReceived(BMessage *msg) {
        switch (msg->what) {
        case MSG_CMD: {
            const char *cmd = NULL;
            if (msg->FindString("cmd", &cmd) == B_OK && cmd) {
                if (strcmp(cmd, "quit") == 0) {
                    write_cmd("quit");
                    PostMessage(B_QUIT_REQUESTED);
                } else {
                    write_cmd(cmd);
                }
            }
            if (fView) fView->MakeFocus(true);
            break;
        }
        case MSG_POLL:
            OnPoll();
            break;
        default:
            BWindow::MessageReceived(msg);
            break;
        }
    }

    void OnPoll() {
        if (fView) fView->FlushPending();
        int gen = read_gen();
        if (gen >= 0 && gen != fLastGen) {
            uint8_t *pix = NULL;
            int w, h, pitch;
            if (load_frame(&pix, &w, &h, &pitch) == 0) {
                if (fView->AdoptFrame(pix, w, h, pitch)) {
                    fLastGen = gen;
                    char st[256];
                    read_line_file(path_status, st, sizeof st);
                    char title[320];
                    if (st[0])
                        snprintf(title, sizeof title, "AILang CAD — %s", st);
                    else
                        snprintf(title, sizeof title, "AILang CAD — gen %d", gen);
                    SetTitle(title);
                    fStatus->SetText(st[0] ? st : title);
                    fprintf(stderr, "cad_shell_haiku: frame gen=%d %dx%d pitch=%d\n",
                            gen, w, h, pitch);
                }
            }
        }
    }

private:
    BMenuBar *fMenu;
    BView *fTools;
    CadView *fView;
    BStringView *fStatus;
    BMessageRunner *fPulse;
    int fLastGen;
};

class CadApp : public BApplication {
public:
    CadApp()
        : BApplication("application/x-vnd.Ailang-CADShell") {}

    void ReadyToRun() {
        mkdir(g_dir, 0755);
        BScreen screen;
        BRect s = screen.Frame();
        float w = 960, h = 720;
        BRect r(80, 50, 80 + w, 50 + h);
        if (s.Width() < w + 40) r.right = s.right - 20;
        if (s.Height() < h + 40) r.bottom = s.bottom - 40;
        CadWindow *win = new CadWindow(r);
        win->Show();
        fprintf(stderr,
            "cad_shell_haiku: %s\n"
            "  native app_server blit (BBitmap B_RGB32)\n"
            "  3D: LMB orbit | scroll zoom | click pick\n"
            "  Sketch: click | hold 1s+drag=pan | scroll zoom\n",
            g_dir);
    }
};

int main(int argc, char **argv) {
    const char *dir = getenv("CAD_APP_STATE");
    if (!dir || !dir[0]) dir = "/tmp/cad_app";
    if (argc > 1 && argv[1] && argv[1][0] == '/') dir = argv[1];
    else if (argc > 1 && argv[1] && argv[1][0] != '-') dir = argv[1];
    paths_init(dir);
    CadApp app;
    app.Run();
    return 0;
}
