/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.bookmark.bmchooser;

import gdk.Event;
import gdk.Keysyms;

import gio.Settings: GSettings = Settings;

import gtk.Box;
import gtk.CheckButton;
import gtk.Dialog;
import gtk.ScrolledWindow;
import gtk.SearchEntry;
import gtk.Widget;
import gtk.Window;

import gx.gtk.util;

import gx.i18n.l10n;

import gx.tilix.bookmark.bmtreeview;
import gx.tilix.bookmark.manager;
import gx.tilix.preferences;

/**
 * Selection mode dialog should used
 */
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

    GSettings gsSettings;

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
        tv.addOnKeyPress(&checkKeyPress);

        ScrolledWindow sw = new ScrolledWindow(tv);
        sw.setShadowType(ShadowType.ETCHED_IN);
        sw.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sw.setHexpand(true);
        sw.setVexpand(true);
        sw.setSizeRequest(-1, 200);

        SearchEntry se = new SearchEntry();
        se.addOnSearchChanged(delegate(SearchEntry) {
            tv.filterText = se.getText();
            updateUI();
        });
        se.addOnKeyPress(&checkKeyPress);

        Box box = new Box(Orientation.VERTICAL, 6);
        setAllMargins(box, 18);
        box.add(se);
        box.add(sw);

        if (mode != BMSelectionMode.FOLDER) {
            gsSettings = new GSettings(SETTINGS_ID);
            CheckButton cbIncludeEnter = new CheckButton(_("Include return character with bookmark"));
            gsSettings.bind(SETTINGS_BOOKMARK_INCLUDE_RETURN_KEY, cbIncludeEnter, "active", GSettingsBindFlags.DEFAULT);
            box.add(cbIncludeEnter);
        }

        getContentArea().add(box);
    }

    void updateUI() {
        setResponseSensitive(ResponseType.OK, isSelectEnabled());
    }

    bool isSelectEnabled() {
        Bookmark bm = tv.getSelectedBookmark();
        bool enabled = bm !is null;
        switch (mode) {
            case BMSelectionMode.FOLDER:
                enabled = enabled && (cast(FolderBookmark)bm !is null);
                break;
            case BMSelectionMode.LEAF:
                enabled = enabled && (cast(FolderBookmark)bm is null);
                break;
            default:
                break;
        }
        return enabled;
    }

    bool checkKeyPress(Event event, Widget w) {
        uint keyval;
        if (event.getKeyval(keyval)) {
            if (keyval == GdkKeysyms.GDK_Escape) {
                response = ResponseType.CANCEL;
                return true;
            }
            if (keyval == GdkKeysyms.GDK_Return) {
                if (isSelectEnabled()) {
                    response = ResponseType.OK;
                    return true;
                }
            }
        }
        return false;
    }

public:
    this(Window parent, BMSelectionMode mode) {
        string title = mode == BMSelectionMode.FOLDER? _("Select Folder"):_("Select Bookmark");
        super(title, parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("OK"), _("Cancel")], [GtkResponseType.OK, GtkResponseType.CANCEL]);
        setDefaultResponse(GtkResponseType.OK);
        this.mode = mode;
        createUI();
        updateUI();
    }

    @property Bookmark bookmark() {
        return tv.getSelectedBookmark();
    }
}

