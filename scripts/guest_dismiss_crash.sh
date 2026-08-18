#!/bin/sh
# Dismiss Haiku debug_server "Crashed program" / Oh no! dialogs.
# Window title is hard-coded in DebugWindow.cpp. Oh no! sends B_QUIT_REQUESTED.
# License: Public Domain / CC0 1.0 Universal
SIG=application/x-vnd.Haiku-debug_server
# Window title is hard-coded in DebugWindow.cpp. hey looks up the
# BHandler name; also try index 0 and the Oh no! button ("close").
hey "$SIG" quit of Window "Crashed program" 2>/dev/null || true
hey "$SIG" do Quit of Window "Crashed program" 2>/dev/null || true
hey "$SIG" do B_QUIT_REQUESTED of Window "Crashed program" 2>/dev/null || true
hey "$SIG" do B_QUIT_REQUESTED of View "close" of Window "Crashed program" 2>/dev/null || true
hey "$SIG" quit of Window 0 2>/dev/null || true
hey "$SIG" do B_QUIT_REQUESTED of Window 0 2>/dev/null || true
hey "$SIG" do B_QUIT_REQUESTED of View "close" of Window 0 2>/dev/null || true
hey debug_server quit of Window "Crashed program" 2>/dev/null || true
hey debug_server quit of Window 0 2>/dev/null || true
true
