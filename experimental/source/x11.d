/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

module gx.gtk.x11;

import gtkc.glibtypes;

import gtkc.Loader;
import gtkc.paths;

import x11.X: Atom, XWindow=Window;
import x11.Xlib;

shared static this()
{
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

/*
void activateWindow(Window window) {
    if (window.isActive()) return;

    if (isWayland(window)) {
        window.present();
    } else {
        XClientMessageEvent event;
        event.type = ClientMessage;
        event.window = getXid(window.getWindow());
        const(char*) name = toStringz("_NET_ACTIVE_WINDOW");
        event.message_type = gdk_x11_get_xatom_by_name(name);
        event.format = 32;
        event.data.l[0] = 0;
        tracef("Event: window: %d; Message type %d", event.window, event.message_type);

        trace("Get display");
        Display* display = gdk_x11_get_default_xdisplay();
        trace("Get root window");
        XWindow root = gdk_x11_get_default_root_xwindow();    

        Gdk.errorTrapPush();
        trace("Send Event");
        XSendEvent(display, root, false, StructureNotifyMask, cast(XEvent*) &event); 
        Gdk.flush;
        if (Gdk.errorTrapPop() != 0) {
            error("Failed to focus window");
        }
    }
}
*/
