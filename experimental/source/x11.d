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