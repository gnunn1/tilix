/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.clipboard;

// GID imports - gdk
import gdk.atom : Atom;

/* Clipboard Atoms */
Atom GDK_SELECTION_CLIPBOARD;
Atom GDK_SELECTION_PRIMARY;
Atom GDK_SELECTION_SECONDARY;

static this() {
    GDK_SELECTION_CLIPBOARD = Atom.intern("CLIPBOARD", true);
    GDK_SELECTION_PRIMARY = Atom.intern("PRIMARY", true);
    GDK_SELECTION_SECONDARY = Atom.intern("SECONDARY", true);
}