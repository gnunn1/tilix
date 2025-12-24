/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.clipboard;

import gdk.atom;
import gdk.types;

/* Clipboard Atoms */
Atom SELECTION_CLIPBOARD;
Atom SELECTION_PRIMARY;
Atom SELECTION_SECONDARY;

static this() {
    SELECTION_CLIPBOARD = Atom.intern("CLIPBOARD", true);
    SELECTION_PRIMARY = Atom.intern("PRIMARY", true);
    SELECTION_SECONDARY = Atom.intern("SECONDARY", true);
}