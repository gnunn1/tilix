/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.clipboard;

import gdk.Atom;

/* Clipboard Atoms */
GdkAtom GDK_SELECTION_CLIPBOARD;
GdkAtom GDK_SELECTION_PRIMARY;
GdkAtom GDK_SELECTION_SECONDARY;

static this() {
    GDK_SELECTION_CLIPBOARD = intern("CLIPBOARD", true);
    GDK_SELECTION_PRIMARY = intern("PRIMARY", true);
    GDK_SELECTION_SECONDARY = intern("SECONDARY", true);
}