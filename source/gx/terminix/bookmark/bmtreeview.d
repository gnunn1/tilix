/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.bookmark.bmtreeview;

import std.conv;
import std.experimental.logger;
import std.string;

import gdk.Pixbuf;

import gtk.CellRendererPixbuf;
import gtk.CellRendererText;
import gtk.TreeViewColumn;
import gtk.TreeIter;
import gtk.TreeModel;
import gtk.TreeModelFilter;
import gtk.TreeStore;
import gtk.TreeView;

import gx.i18n.l10n;

import gx.terminix.bookmark.manager;

class BMTreeView: TreeView {
private:
    TreeStore ts;
    TreeModelFilter filter;
    string _filterText;
    Pixbuf[] icons;

    enum COLUMNS : uint {
        ICON = 0,
        NAME = 1,
        UUID = 2
    }

    void loadBookmarks(TreeIter current, FolderBookmark parent) {
        foreach(bm; parent) {
            tracef("Loading bookmark %s", bm.name);
            TreeIter childIter = addBookmarktoParent(current, bm);
            FolderBookmark fm = cast(FolderBookmark)bm;
            if (fm !is null) {
                loadBookmarks(childIter, fm);
            }
        }
    }

    TreeIter addBookmarktoParent(TreeIter parent, Bookmark bm) {
        TreeIter result = ts.createIter(parent);
        ts.setValue(result, COLUMNS.ICON, icons[cast(uint)bm.type()]);
        ts.setValue(result, COLUMNS.NAME, bm.name);
        ts.setValue(result, COLUMNS.UUID, bm.uuid);
        return result;
    }

    void createColumns() {
        CellRendererPixbuf crp = new CellRendererPixbuf();
        crp.setProperty("stock-size", 16);
        TreeViewColumn column = new TreeViewColumn(_("Icon"), crp, "pixbuf", COLUMNS.ICON);
        appendColumn(column);

        column = new TreeViewColumn(_("Name"), new CellRendererText(), "text", COLUMNS.NAME);
        column.setExpand(true);
        appendColumn(column);

        column = new TreeViewColumn("UUID", new CellRendererText(), "text", COLUMNS.UUID);
        column.setVisible(false);
        appendColumn(column);
    }

    FolderBookmark getParentBookmark(Bookmark bm, out TreeIter parent) {
        parent = getSelectedIter();
        if (parent is null) return null;
        if (!ts.iterHasChild(parent)) {
            parent = parent.getParent();
        }
        return cast(FolderBookmark) bmMgr.get(parent.getValueString(COLUMNS.UUID));
    }

    static extern(C) int filterBookmark(GtkTreeModel* gtkModel, GtkTreeIter* gtkIter, void* data) {
        BMTreeView tv = cast(BMTreeView) data;

        TreeModel model = new TreeModel(gtkModel, false);
        TreeIter iter = new TreeIter(gtkIter, false);

        string name = to!string(model.getValue(iter, COLUMNS.NAME));
        //import std.string: No;
        return (name.indexOf(tv.filterText) >= 0);
     }

public:
    this() {
        super();
        icons = getBookmarkIcons();
        ts = new TreeStore([Pixbuf.getType(), GType.STRING, GType.STRING]);
        loadBookmarks(null, bmMgr.root);

        filter = new TreeModelFilter(ts, null);
        filter.setVisibleFunc(cast(GtkTreeModelFilterVisibleFunc) &filterBookmark, cast(void*)this, null);

        setModel(filter);
        createColumns();
    }

    Bookmark getSelectedBookmark() {
        TreeIter selected = getSelectedIter();
        if (selected is null) return null;
        return bmMgr.get(selected.getValueString(COLUMNS.UUID));
    }

    /**
     * Adds a bookmark to the treeview based on the selected
     * bookmark. Returns the FolderBookmark to which the
     * bookmark was added.
     */
    FolderBookmark addBookmark(Bookmark bm) {
        TreeIter parent;
        FolderBookmark fbm = getParentBookmark(bm, parent);
        if (fbm is null) {
            error("Unexpected error adding bookmark, could not locate parent FolderBookmark");
            return null;
        }
        bmMgr.add(fbm, bm);
        addBookmarktoParent(parent, bm);
        return fbm;
    }

    /**
     * Removes selected bookmark.
     */
    void removeBookmark() {
        TreeIter selected = getSelectedIter();
        Bookmark bm = getSelectedBookmark();
        if (selected is null || bm is null) return;

        TreeIter parent;
        FolderBookmark fbm = getParentBookmark(bm, parent);
        if (fbm is null) {
            error("Unexpected error adding bookmark, could not locate parent FolderBookmark");
            return;
        }
        bmMgr.remove(fbm, bm);
        ts.remove(selected);
    }

    /**
     * Update the selected bookmark.
     */
    void updateBookmark(Bookmark bm) {
        TreeIter selected = getSelectedIter();
        if (selected is null || selected.getValueString(COLUMNS.UUID) != bm.uuid) return;
        ts.setValue(selected, COLUMNS.NAME, bm.name);
    }

    @property string filterText() {
        return _filterText;
    }

    @property void filterText(string value) {
        if (_filterText != value) {
            _filterText = value;
            filter.refilter();
        }
    }
}