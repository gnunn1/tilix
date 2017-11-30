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

import std.experimental.logger;
import std.string;

import gtkc.glibtypes;

import gtkc.Loader;
import gtkc.paths;

import gdk.Atom;
import gdk.Gdk;
import gdk.X11;

import gtk.Main;
import gtk.Window;

import x11.X: Atom, ClientMessage, StructureNotifyMask, XWindow=Window;
import x11.Xlib: Display, XClientMessageEvent, XSendEvent, XEvent;

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
    uint timestamp = Main.getCurrentEventTime();

    if (timestamp == 0)
        timestamp = gdk_x11_get_server_time(window.getWindow().getWindowStruct());

    XClientMessageEvent event;
    event.type = ClientMessage;
    event.window = getXid(window.getWindow());
    const(char*) name = toStringz("_NET_ACTIVE_WINDOW");
    event.message_type = gdk_x11_get_xatom_by_name(name);
    event.format = 32;
    event.data.l[0] = 1;
    event.data.l[1] = timestamp;
    event.data.l[2] = event.data.l[3] = event.data.l[4] = 0;

    Display* display = gdk_x11_get_default_xdisplay();
    XWindow root = gdk_x11_get_default_root_xwindow();

    Gdk.errorTrapPush();
    XSendEvent(display, root, false, StructureNotifyMask, cast(XEvent*) &event);
    Gdk.flush;
    if (Gdk.errorTrapPop() != 0) {
        error("Failed to focus window");
    }
}

private:

import gdk.c.functions;

shared static this()
{
    // Link in some extra functions not provided by GtkD
    Linker.link(gdk_x11_get_xatom_by_name, "gdk_x11_get_xatom_by_name", LIBRARY_GDK);
    Linker.link(gdk_x11_get_default_xdisplay, "gdk_x11_get_default_xdisplay", LIBRARY_GDK);
    Linker.link(gdk_x11_get_default_root_xwindow, "gdk_x11_get_default_root_xwindow", LIBRARY_GDK);
    Linker.link(gdk_x11_get_server_time, "gdk_x11_get_server_time", LIBRARY_GDK);
}

__gshared extern(C)
{
    Atom function(const(char)* atom_name) c_gdk_x11_get_xatom_by_name;
    Display* function() c_gdk_x11_get_default_xdisplay;
    XWindow function() c_gdk_x11_get_default_root_xwindow;
    uint function(GdkWindow* window) c_gdk_x11_get_server_time;
}

alias c_gdk_x11_get_xatom_by_name gdk_x11_get_xatom_by_name;
alias c_gdk_x11_get_default_xdisplay gdk_x11_get_default_xdisplay;
alias c_gdk_x11_get_default_root_xwindow gdk_x11_get_default_root_xwindow;
alias c_gdk_x11_get_server_time gdk_x11_get_server_time;
