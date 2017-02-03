/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.terminal.bmchooser;

import gtk.Box;
import gtk.Dialog;
import gtk.ScrolledWindow;
import gtk.SearchEntry;
import gtk.Window;

import gx.gtk.util;

import gx.i18n.l10n;

import gx.terminix.bookmark.bmtreeview;
import gx.terminix.bookmark.manager;

/**
 * Dialog that allows the user to select a bookmark.
 */
class BookmarkChooser: Dialog {
private:
    BMTreeView tv;

    void createUI() {
        tv = new BMTreeView();
        tv.setActivateOnSingleClick(false);
        tv.setHeadersVisible(false);
        tv.getSelection().setMode(SelectionMode.BROWSE);
        tv.addOnCursorChanged(delegate(TreeView) {
            updateUI();
        });

        ScrolledWindow sw = new ScrolledWindow(tv);
        sw.setShadowType(ShadowType.ETCHED_IN);
        sw.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sw.setHexpand(true);
        sw.setVexpand(true);
        sw.setSizeRequest(-1, 200);

        SearchEntry se = new SearchEntry();

        Box box = new Box(Orientation.VERTICAL, 6);
        setAllMargins(box, 18);
        box.add(se);
        box.add(sw);
        getContentArea().add(box);
    }

    void updateUI() {
        Bookmark bm = tv.getSelectedBookmark();
        setResponseSensitive(ResponseType.OK, bm !is null && cast(FolderBookmark)bm is null);
    }

public:
    this(Window parent) {
        super(_("Select Bookmark"), parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("OK"), _("Cancel")], [GtkResponseType.OK, GtkResponseType.CANCEL]);
        setDefaultResponse(GtkResponseType.OK);
        createUI();
        updateUI();
    }

    @property Bookmark bookmark() {
        return tv.getSelectedBookmark();
    }
}

