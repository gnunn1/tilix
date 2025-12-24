/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.bookmark.bmchooser;

import gdk.event;
import gdk.event_key;
import gdk.types;
import gx.gtk.keys;
import gx.gtk.types;

import gio.settings: Settings = Settings;
import gio.types;

import gtk.box;
import gtk.types;
import gtk.check_button;
import gtk.types;
import gtk.dialog;
import gtk.types;
import gtk.scrolled_window;
import gtk.tree_path;
import gtk.tree_view;
import gtk.tree_view_column;
import gtk.types;
import gtk.search_entry;
import gtk.types;
import gtk.widget;
import gtk.types;
import gtk.window;
import gtk.types;

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

    Settings gsSettings;

    void createUI() {
        tv = new BMTreeView(true, mode == BMSelectionMode.FOLDER);
        tv.setActivateOnSingleClick(false);
        tv.setHeadersVisible(false);
        tv.getSelection().setMode(SelectionMode.Browse);
        tv.connectCursorChanged(delegate(TreeView tv) {
            updateUI();
        });
        tv.connectRowActivated(delegate(TreePath p, TreeViewColumn c, TreeView t) {
            response(gtk.types.ResponseType.Ok);
        });
        tv.connectKeyPressEvent(&checkKeyPress);

        ScrolledWindow sw = new ScrolledWindow();
        sw.add(tv);
        sw.setShadowType(ShadowType.EtchedIn);
        sw.setPolicy(PolicyType.Never, PolicyType.Automatic);
        sw.setHexpand(true);
        sw.setVexpand(true);
        sw.setSizeRequest(-1, 200);

        SearchEntry se = new SearchEntry();
        se.connectSearchChanged(delegate(SearchEntry se) {
            tv.filterText = se.getText();
            updateUI();
        });
        se.connectKeyPressEvent(&checkKeyPress);

        Box box = new Box(gtk.types.Orientation.Vertical, 6);
        setAllMargins(box, 18);
        box.add(se);
        box.add(sw);

        if (mode != BMSelectionMode.FOLDER) {
            gsSettings = new Settings(SETTINGS_ID);
            CheckButton cbIncludeEnter = CheckButton.newWithLabel(_("Include return character with bookmark"));
            gsSettings.bind(SETTINGS_BOOKMARK_INCLUDE_RETURN_KEY, cbIncludeEnter, "active", SettingsBindFlags.Default);
            box.add(cbIncludeEnter);
        }

        (cast(Box)getContentArea()).add(box);
    }

    void updateUI() {
        setResponseSensitive(gtk.types.ResponseType.Ok, isSelectEnabled());
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
        uint keyval = event.keyval;
        if (keyval == Keys.Escape) {
            response(gtk.types.ResponseType.Cancel);
            return true;
        }
        if (keyval == Keys.Return) {
            if (isSelectEnabled()) {
                response(gtk.types.ResponseType.Ok);
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
        addButton(_("Ok"), gtk.types.ResponseType.Ok);
        addButton(_("Cancel"), gtk.types.ResponseType.Cancel);
        setDefaultResponse(gtk.types.ResponseType.Ok);
        this.mode = mode;
        createUI();
        updateUI();
    }

    @property Bookmark bookmark() {
        return tv.getSelectedBookmark();
    }
}

