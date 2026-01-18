/*-
 * Copyright (c) 2005-2007 Benedikt Meurer <benny@xfce.org>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

module gx.gtk.x11;

import core.sys.posix.dlfcn : dlopen, dlsym, RTLD_NOW, RTLD_GLOBAL;
import std.experimental.logger;
import std.string;

// GID imports - gdk
import gdk.global : errorTrapPop, errorTrapPush, flush;
import gdk.window : GdkWindow = Window;
import gdk.c.types : GdkWindow_ = GdkWindow;

// GID imports - gtk
import gtk.global : getCurrentEventTime;
import gtk.window : Window;

import gid.gid : No;

import x11.X : Atom, ClientMessage, StructureNotifyMask, XWindow = Window;
import x11.Xlib : Display, XClientMessageEvent, XSendEvent, XEvent;

/**
 * This function activates an X11 using the _NET_ACTIVE_WINDOW
 * event for X11. Works around some edge cases with respect to
 * window focus.
 *
 * Code was translated from a C version in xfce4_terminal, see original here:
 * http://bazaar.launchpad.net/~vcs-imports/xfce4-terminal/trunk/view/head:/terminal/terminal-util.c
 *
 * The original xfce code was licensed under GPL and that license remains in effect for this method only,
 * since code translations are considered a derived work under GPL.
 */
void activateX11Window(Window window) {
    if (!x11FunctionsLoaded) {
        warning("X11 functions not available, cannot activate window");
        return;
    }

    uint timestamp = getCurrentEventTime();

    GdkWindow gdkWin = window.getWindow();
    if (gdkWin is null) {
        warning("GdkWindow is null, cannot activate X11 window");
        return;
    }

    if (timestamp == 0)
        timestamp = gdk_x11_get_server_time(cast(GdkWindow_*) gdkWin._cPtr(No.Dup));

    XClientMessageEvent event;
    event.type = ClientMessage;
    event.window = getXid(gdkWin);
    const(char*) name = toStringz("_NET_ACTIVE_WINDOW");
    event.message_type = gdk_x11_get_xatom_by_name(name);
    event.format = 32;
    event.data.l[0] = 1;
    event.data.l[1] = timestamp;
    event.data.l[2] = event.data.l[3] = event.data.l[4] = 0;

    Display* display = gdk_x11_get_default_xdisplay();
    XWindow root = gdk_x11_get_default_root_xwindow();

    errorTrapPush();
    XSendEvent(display, root, false, StructureNotifyMask, cast(XEvent*) &event);
    flush();
    if (errorTrapPop() != 0) {
        error("Failed to focus window");
    }
}

/**
 * Get the X11 window ID from a GdkWindow
 */
XWindow getXid(GdkWindow gdkWin) {
    if (!x11FunctionsLoaded || gdkWin is null) {
        return 0;
    }
    return gdk_x11_window_get_xid(cast(GdkWindow_*) gdkWin._cPtr(No.Dup));
}

/**
 * Get the GType for X11 windows
 */
import gobject.c.types : GType;
GType getX11WindowType() {
    if (!x11FunctionsLoaded) {
        return 0;
    }
    return gdk_x11_window_get_type();
}

private:

// Flag to check if X11 functions are loaded
bool x11FunctionsLoaded = false;

// Function pointer types for X11-specific GDK functions
extern (C) {
    alias gdk_x11_get_xatom_by_name_func = Atom function(const(char)* atom_name);
    alias gdk_x11_get_default_xdisplay_func = Display* function();
    alias gdk_x11_get_default_root_xwindow_func = XWindow function();
    alias gdk_x11_get_server_time_func = uint function(GdkWindow_* window);
    alias gdk_x11_window_get_xid_func = XWindow function(GdkWindow_* window);
    alias gdk_x11_window_get_type_func = GType function();
}

// Function pointers
__gshared gdk_x11_get_xatom_by_name_func gdk_x11_get_xatom_by_name;
__gshared gdk_x11_get_default_xdisplay_func gdk_x11_get_default_xdisplay;
__gshared gdk_x11_get_default_root_xwindow_func gdk_x11_get_default_root_xwindow;
__gshared gdk_x11_get_server_time_func gdk_x11_get_server_time;
__gshared gdk_x11_window_get_xid_func gdk_x11_window_get_xid;
__gshared gdk_x11_window_get_type_func gdk_x11_window_get_type;

shared static this() {
    // Try to load X11-specific GDK functions dynamically
    void* handle = dlopen("libgdk-3.so.0", RTLD_NOW | RTLD_GLOBAL);
    if (handle is null) {
        handle = dlopen("libgdk-3.so", RTLD_NOW | RTLD_GLOBAL);
    }

    if (handle is null) {
        trace("Could not load libgdk-3.so for X11 functions");
        return;
    }

    gdk_x11_get_xatom_by_name = cast(gdk_x11_get_xatom_by_name_func) dlsym(handle, "gdk_x11_get_xatom_by_name");
    gdk_x11_get_default_xdisplay = cast(gdk_x11_get_default_xdisplay_func) dlsym(handle, "gdk_x11_get_default_xdisplay");
    gdk_x11_get_default_root_xwindow = cast(gdk_x11_get_default_root_xwindow_func) dlsym(handle, "gdk_x11_get_default_root_xwindow");
    gdk_x11_get_server_time = cast(gdk_x11_get_server_time_func) dlsym(handle, "gdk_x11_get_server_time");
    gdk_x11_window_get_xid = cast(gdk_x11_window_get_xid_func) dlsym(handle, "gdk_x11_window_get_xid");
    gdk_x11_window_get_type = cast(gdk_x11_window_get_type_func) dlsym(handle, "gdk_x11_window_get_type");

    // Check if all functions were loaded
    x11FunctionsLoaded = (gdk_x11_get_xatom_by_name !is null &&
                          gdk_x11_get_default_xdisplay !is null &&
                          gdk_x11_get_default_root_xwindow !is null &&
                          gdk_x11_get_server_time !is null &&
                          gdk_x11_window_get_xid !is null &&
                          gdk_x11_window_get_type !is null);

    if (x11FunctionsLoaded) {
        trace("X11 GDK functions loaded successfully");
    } else {
        trace("Some X11 GDK functions could not be loaded");
    }
}