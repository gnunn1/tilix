/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
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

import gtk.Window;

import x11.X: Atom, ClientMessage, StructureNotifyMask, XWindow=Window;
import x11.Xlib;

/**
 * This function activates an X11 using the _NET_ACTIVE_WINDOW
 * event for X11. Works around some edge cases with respect to
 * window focus.
 *
 * Code was translated from a C version in xfce4_terminal, see original here:
 * http://bazaar.launchpad.net/~vcs-imports/xfce4-terminal/trunk/view/head:/terminal/terminal-util.c
 */
void activateX11Window(Window window) {
    XClientMessageEvent event;
    event.type = ClientMessage;
    event.window = getXid(window.getWindow());
    const(char*) name = toStringz("_NET_ACTIVE_WINDOW");
    event.message_type = gdk_x11_get_xatom_by_name(name);
    event.format = 32;
    event.data.l[0] = 0;

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

shared static this()
{
    // Link in some extra functions not provided by GtkD
	Linker.link(gdk_x11_get_xatom_by_name, "gdk_x11_get_xatom_by_name", LIBRARY.GDK);
	Linker.link(gdk_x11_get_default_xdisplay, "gdk_x11_get_default_xdisplay", LIBRARY.GDK);
	Linker.link(gdk_x11_get_default_root_xwindow, "gdk_x11_get_default_root_xwindow", LIBRARY.GDK);
}

__gshared extern(C)
{
    Atom function(const(char)* atom_name) gdk_x11_get_xatom_by_name;
    Display* function() gdk_x11_get_default_xdisplay;
    XWindow   function() gdk_x11_get_default_root_xwindow;
}