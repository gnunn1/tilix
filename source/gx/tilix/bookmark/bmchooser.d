/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.bookmark.bmchooser;

import gdk.event;
// GID does not provide gdk.keysyms, define required key constants locally
private enum GdkKeysyms {
    GDK_Escape = 0xff1b,
    GDK_Return = 0xff0d,
}

import gdk.event_key : EventKey;

import gio.settings: GSettings = Settings;
import gio.types : SettingsBindFlags;

import gtk.box;
import gtk.check_button : CheckButton;
import gtk.dialog;
import gtk.scrolled_window;
import gtk.search_entry : SearchEntry;
import gtk.tree_path : TreePath;
import gtk.tree_view : TreeView;
import gtk.tree_view_column : TreeViewColumn;
import gtk.types : DialogFlags, Orientation, PolicyType, ResponseType, SelectionMode, ShadowType;
import gtk.widget;
import gtk.window;

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
        tv.getSelection().setMode(SelectionMode.Browse);
        tv.connectCursorChanged(delegate(TreeView v) {
            updateUI();
        });
        tv.connectRowActivated(delegate(TreePath p, TreeViewColumn c, TreeView v) {
            response(ResponseType.Ok);
        });
        tv.connectKeyPressEvent(&checkKeyPress);

        ScrolledWindow sw = new ScrolledWindow(null, null);
        sw.add(tv);
        sw.setShadowType(ShadowType.EtchedIn);
        sw.setPolicy(PolicyType.Never, PolicyType.Automatic);
        sw.setHexpand(true);
        sw.setVexpand(true);
        sw.setSizeRequest(-1, 200);

        SearchEntry se = new SearchEntry();
        se.connectSearchChanged(delegate(SearchEntry entry) {
            tv.filterText = se.getText();
            updateUI();
        });
        se.connectKeyPressEvent(&checkKeyPress);

        Box box = new Box(Orientation.Vertical, 6);
        setAllMargins(box, 18);
        box.add(se);
        box.add(sw);

        if (mode != BMSelectionMode.FOLDER) {
            gsSettings = new GSettings(SETTINGS_ID);
            CheckButton cbIncludeEnter = CheckButton.newWithLabel(_("Include return character with bookmark"));
            gsSettings.bind(SETTINGS_BOOKMARK_INCLUDE_RETURN_KEY, cbIncludeEnter, "active", SettingsBindFlags.Default);
            box.add(cbIncludeEnter);
        }

        getContentArea().add(box);
    }

    void updateUI() {
        setResponseSensitive(ResponseType.Ok, isSelectEnabled());
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

    bool checkKeyPress(EventKey event, Widget w) {
        if (event is null) return false;
        uint keyval = event.keyval;
        if (keyval == GdkKeysyms.GDK_Escape) {
            response(ResponseType.Cancel);
            return true;
        }
        if (keyval == GdkKeysyms.GDK_Return) {
            if (isSelectEnabled()) {
                response(ResponseType.Ok);
                return true;
            }
        }
        return false;
    }

public:
    this(Window parent, BMSelectionMode mode) {
        super();
        string title = mode == BMSelectionMode.FOLDER? _("Select Folder"):_("Select Bookmark");
        setTitle(title);
        setTransientFor(parent);
        setModal(true);
        addButton(_("Cancel"), ResponseType.Cancel);
        addButton(_("OK"), ResponseType.Ok);
        setDefaultResponse(ResponseType.Ok);
        this.mode = mode;
        createUI();
        updateUI();
    }

    @property Bookmark bookmark() {
        return tv.getSelectedBookmark();
    }
}

