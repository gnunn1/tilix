/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.bookmark.bmchooser;

import gtk.Box;
import gtk.Dialog;
import gtk.ScrolledWindow;
import gtk.SearchEntry;
import gtk.Window;

import gx.gtk.util;

import gx.i18n.l10n;

import gx.terminix.bookmark.bmtreeview;
import gx.terminix.bookmark.manager;


enum BMSelectionMode {ANY, LEAF, FOLDER}

/**
 * Dialog that allows the user to select a bookmark. Not actually used
 * at the moment as the GTK TreeModelFilter is too limited when dealing with
 * heirarchal data.
 */
class BookmarkChooser: Dialog {
private:
    BMTreeView tv;
    BMSelectionMode mode;

    void createUI() {
        tv = new BMTreeView(true, mode == BMSelectionMode.FOLDER);
        tv.setActivateOnSingleClick(false);
        tv.setHeadersVisible(false);
        tv.getSelection().setMode(SelectionMode.BROWSE);
        tv.addOnCursorChanged(delegate(TreeView) {
            updateUI();
        });
        tv.addOnRowActivated(delegate(TreePath, TreeViewColumn, TreeView) {
            response(ResponseType.OK);
        });

        ScrolledWindow sw = new ScrolledWindow(tv);
        sw.setShadowType(ShadowType.ETCHED_IN);
        sw.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sw.setHexpand(true);
        sw.setVexpand(true);
        sw.setSizeRequest(-1, 200);

        SearchEntry se = new SearchEntry();
        se.addOnSearchChanged(delegate(SearchEntry) {
            tv.filterText = se.getText();
        });

        Box box = new Box(Orientation.VERTICAL, 6);
        setAllMargins(box, 18);
        box.add(se);
        box.add(sw);
        getContentArea().add(box);
    }

    void updateUI() {
        Bookmark bm = tv.getSelectedBookmark();
        bool enabled = bm !is null;
        switch (mode) {
            case BMSelectionMode.FOLDER:
                enabled = enabled && cast(FolderBookmark)bm !is null;
                break;
            case BMSelectionMode.LEAF:
                enabled = enabled && cast(FolderBookmark)bm is null;
                break;
            default:
                break;
        }
        setResponseSensitive(ResponseType.OK, enabled);
    }

public:
    this(Window parent, BMSelectionMode mode) {
        string title = mode == BMSelectionMode.FOLDER? _("Select Folder"):_("Select Bookmark");
        super(title, parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("OK"), _("Cancel")], [GtkResponseType.OK, GtkResponseType.CANCEL]);
        setDefaultResponse(GtkResponseType.OK);
        this.mode = mode;
        createUI();
        tv.expandAll();
        updateUI();
    }

    @property Bookmark bookmark() {
        return tv.getSelectedBookmark();
    }
}

