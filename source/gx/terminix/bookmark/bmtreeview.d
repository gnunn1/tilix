/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.bookmark.bmtreeview;

import std.conv;
import std.experimental.logger;
import std.string;

import gdk.DragContext;
import gdk.Pixbuf;

import gobject.Value;

import gtk.CellRendererPixbuf;
import gtk.CellRendererText;
import gtk.TreeViewColumn;
import gtk.TreeIter;
import gtk.TreeModel;
import gtk.TreeModelIF;
import gtk.TreeModelFilter;
import gtk.TreePath;
import gtk.TreeStore;
import gtk.TreeView;
import gtk.Widget;

import gx.i18n.l10n;

import gx.terminix.bookmark.manager;

enum Columns : uint {
    ICON = 0,
    NAME = 1,
    UUID = 2,
    FILTER = 3
}

TreeStore createBMTreeModel(bool foldersOnly) {
    Pixbuf[] icons = getBookmarkIcons();
    TreeStore ts = new TreeStore([Pixbuf.getType(), GType.STRING, GType.STRING, GType.BOOLEAN]);
    loadBookmarks(ts, null, bmMgr.root, foldersOnly, icons);
    return ts;
}

class BMTreeView: TreeView {
private:
    TreeStore ts;
    TreeModelFilter filter;
    string _filterText;
    Pixbuf[] icons;

    bool ignoreOperationFlag = false;
    string deletedBookmarkUUID;

    void createColumns() {
        CellRendererPixbuf crp = new CellRendererPixbuf();
        crp.setProperty("stock-size", 16);
        TreeViewColumn column = new TreeViewColumn(_("Icon"), crp, "pixbuf", Columns.ICON);
        appendColumn(column);

        column = new TreeViewColumn(_("Name"), new CellRendererText(), "text", Columns.NAME);
        column.setExpand(true);
        appendColumn(column);

        column = new TreeViewColumn("UUID", new CellRendererText(), "text", Columns.UUID);
        column.setVisible(false);
        appendColumn(column);

        column = new TreeViewColumn("Filter", new CellRendererText(), "text", Columns.FILTER);
        column.setVisible(false);
        appendColumn(column);
    }

    FolderBookmark getParentBookmark(Bookmark bm, out TreeIter parent) {
        parent = getSelectedIter();
        if (parent is null) return null;
        if (!getModel().iterHasChild(parent)) {
            if (!getModel().iterParent(parent, parent)) {
                parent = null;
                return bmMgr.root;
            }
        }
        return cast(FolderBookmark) bmMgr.get(getModel().getValueString(parent, Columns.UUID));
    }

    void updateFilter() {

        void checkFilter(TreeIter iter) {
            string name = getModel().getValueString(iter, Columns.NAME);
            bool visible = filterText.length == 0 || name.indexOf(filterText) >= 0;
            ts.setValue(iter, Columns.FILTER, visible);
            if (visible) {
                TreeIter parent;
                getModel().iterParent(parent, iter);
                Value value = new Value();
                while (parent !is null) {
                    // has parent visibility already been set?
                    value = getModel().getValue(parent, Columns.FILTER, value);
                    if (value.getBoolean()) break;
                    ts.setValue(parent, Columns.FILTER, true);
                    if (!getModel().iterParent(parent, parent)) break;
                }
            }
            if (getModel().iterHasChild(iter)) {
                TreeIter child;
                getModel().iterChildren(child, iter);
                while (child !is null) {
                    checkFilter(child);
                    if (!getModel().iterNext(child)) break;
                }
            }
        }

         TreeIter iter;
         getModel().getIterFirst(iter);
         while (iter !is null) {
            checkFilter(iter);
            if (!getModel().iterNext(iter)) break;
        }
    }

    bool isDragAllowed(int x, int y) {
        TreePath path;
        TreeViewDropPosition tvdp;
        getDestRowAtPos(x, y, path, tvdp);
        TreeIter iter;
        if (ts.getIter(iter, path)) {
            string uuid = ts.getValueString(iter, Columns.UUID);
            FolderBookmark fb = cast(FolderBookmark) bmMgr.get(uuid);
            return (fb !is null);
        } else {
            return false;
        }
    }

    bool onDragDrop(DragContext dc, int x, int y, uint time, Widget widget) {
        return isDragAllowed(x, y);
    }

    bool onDragMotion(DragContext dc, int x, int y, uint time, Widget widget) {
        return isDragAllowed(x, y);
    }

public:
    this(bool enableFilter = false, bool foldersOnly = false) {
        super();
        icons = getBookmarkIcons();
        ts = createBMTreeModel(foldersOnly);

        if (enableFilter) {
            filter = new TreeModelFilter(ts, null);
            filter.setVisibleColumn(Columns.FILTER);
            //filter.setVisibleFunc(cast(GtkTreeModelFilterVisibleFunc) &filterBookmark, cast(void*)this, null);
            setModel(filter);
        } else {
            setModel(ts);
        }
        createColumns();
    }

    Bookmark getSelectedBookmark() {
        TreeIter selected = getSelectedIter();
        if (selected is null) return null;
        return bmMgr.get(getModel().getValueString(selected, Columns.UUID));
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
            fbm = bmMgr.root;
        }
        bmMgr.add(fbm, bm);
        ignoreOperationFlag = true;
        addBookmarktoParent(ts, parent, bm, icons);
        ignoreOperationFlag = false;
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
            fbm = bmMgr.root;
        }
        bmMgr.remove(fbm, bm);
        ignoreOperationFlag = true;
        ts.remove(selected);
        ignoreOperationFlag = false;
    }

    /**
     * Update the selected bookmark.
     */
    void updateBookmark(Bookmark bm) {
        TreeIter selected = getSelectedIter();
        if (selected is null || ts.getValueString(selected, Columns.UUID) != bm.uuid) return;
        ts.setValue(selected, Columns.NAME, bm.name);
    }

    @property string filterText() {
        return _filterText;
    }

    @property void filterText(string value) {
        if (filter is null) {
            error("Cannot filter treeview, filter not created");
            return;
        }

        if (_filterText != value) {
            _filterText = value;
            updateFilter();
            trace("Refilter");
            filter.refilter();
            expandAll();
        }
    }
}

private:

void loadBookmarks(TreeStore ts, TreeIter current, FolderBookmark parent, bool foldersOnly, Pixbuf[] icons) {
    foreach(bm; parent) {
        FolderBookmark fm = cast(FolderBookmark)bm;
        if (foldersOnly && fm is null) {
            continue;
        }
        TreeIter childIter = addBookmarktoParent(ts, current, bm, icons);
        if (fm !is null) {
            loadBookmarks(ts, childIter, fm, foldersOnly, icons);
        }
    }
}

TreeIter addBookmarktoParent(TreeStore ts, TreeIter parent, Bookmark bm, Pixbuf[] icons) {
    TreeIter result = ts.createIter(parent);
    ts.setValue(result, Columns.ICON, icons[cast(uint)bm.type()]);
    ts.setValue(result, Columns.NAME, bm.name);
    ts.setValue(result, Columns.UUID, bm.uuid);
    ts.setValue(result, Columns.FILTER,  true);
    return result;
}