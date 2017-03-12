/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.bookmark.bmtreeview;

import std.conv;
import std.experimental.logger;
import std.string;
import std.traits;
import std.typecons : No;

import gdk.Atom;
import gdk.DragContext;
import gdk.Pixbuf;

import gobject.Value;

import gtk.CellRendererPixbuf;
import gtk.CellRendererText;
import gtk.SelectionData;
import gtk.TargetEntry;
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

import gx.tilix.bookmark.manager;

enum Columns : uint {
    ICON = 0,
    NAME = 1,
    UUID = 2,
    FILTER = 3
}

TreeStore createBMTreeModel(Pixbuf[] icons, bool foldersOnly) {
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

    enum BOOKMARK_DND = "bookmark";

    enum DropTargets {
        BOOKMARK
    };


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

    /**
     * Updates the filter and returns the TreePath
     * of the node that should be focused.
     */
    void updateFilter() {

        void checkFilter(TreeIter iter) {
            string name = ts.getValueString(iter, Columns.NAME);
            bool visible = filterText.length == 0 || name.indexOf(filterText, No.caseSensitive) >= 0;
            ts.setValue(iter, Columns.FILTER, visible);
            if (visible) {
                TreeIter parent = iter;
                Value value = new Value();
                // Walk up the parent heirarchy and set it's visibility to true
                while (ts.iterParent(parent, parent)) {
                    // has parent visibility already been set?
                    value = ts.getValue(parent, Columns.FILTER, value);
                    if (value.getBoolean()) break;
                    ts.setValue(parent, Columns.FILTER, true);
                    //if (!ts.iterParent(parent, parent)) break;
                }
            }
            if (ts.iterHasChild(iter)) {
                TreeIter child;
                ts.iterChildren(child, iter);
                while (child !is null) {
                    checkFilter(child);
                    if (!ts.iterNext(child)) break;
                }
            }
        }

         TreeIter iter;
         if (ts.getIterFirst(iter)) {
            while (iter !is null) {
                checkFilter(iter);
                if (!ts.iterNext(iter)) break;
            }
         }
    }

    void selectFirstFilteredLeaf() {
        bool focusLeaf(TreeIter iter) {
            string uuid = filter.getValueString(iter, Columns.UUID);
            FolderBookmark bm = cast(FolderBookmark) bmMgr.get(uuid);
            if (bm is null) {
                getSelection().selectIter(iter);
                return true;
            }
            if (filter.iterHasChild(iter)) {
                TreeIter child;
                filter.iterChildren(child, iter);
                while (child !is null) {
                    if (focusLeaf(child)) return true;
                    if (!filter.iterNext(child)) break;
                }
            }
            return false;
        }

        TreeIter iter;
        if (filter.getIterFirst(iter)) {
            while (iter !is null) {
                if (focusLeaf(iter)) return;
                if (!filter.iterNext(iter)) break;
            }
        }
    }

// Drag and drop functionality
private:

    void onDragDataGet(DragContext dc, SelectionData data, uint x, uint y, Widget) {
        TreeIter iter = getSelectedIter();
        if (iter !is null) {
            //string uuid = ts.getValueString(iter, Columns.UUID);
            string path = iter.getTreePath().toString();
            char[] buffer = (path ~ '\0').dup;
            data.set(intern(BOOKMARK_DND, false), 8, buffer);
        }
    }

    void onDragDataReceived(DragContext dc, int x, int y, SelectionData data, uint info, uint time, Widget widget) {
        if (info != DropTargets.BOOKMARK) return;

        TreePath pathTarget;
        TreeViewDropPosition tvdp;
        if (!getDestRowAtPos(x, y, pathTarget, tvdp)) return;
        TreeIter target = new TreeIter();
        ts.getIter(target, pathTarget);

        string dataPath = to!string(data.getDataWithLength()[0 .. $ - 1]);
        tracef("Data received %s", dataPath);
        TreePath pathSource = new TreePath(dataPath);
        TreeIter source = new TreeIter();
        ts.getIter(source, pathSource);

        //Move bookmark first
        Bookmark bmTarget = bmMgr.get(ts.getValueString(target, Columns.UUID));
        Bookmark bmSource = bmMgr.get(ts.getValueString(source, Columns.UUID));
        try {
            switch (tvdp) {
                case TreeViewDropPosition.BEFORE:
                    bmMgr.moveBefore(bmTarget, bmSource);
                    break;
                case TreeViewDropPosition.AFTER:
                    bmMgr.moveAfter(bmTarget, bmSource);
                    break;
                case TreeViewDropPosition.INTO_OR_BEFORE:
                ..
                case TreeViewDropPosition.INTO_OR_AFTER:
                    FolderBookmark fb = cast(FolderBookmark) bmTarget;
                    if (fb is null) {
                        error("Unexpected, not a folder bookmark, bookmark not moved");
                        return;
                    }
                    bmMgr.moveInto(fb, bmSource);
                    break;
                default:
                    error("Unexpected value for TreeViewDropPosition, should never get here");
                    return;

            }
        } catch (Exception e) {
            error("Could not perform operation, error occured");
            error(e);
            return;
        }

        TreeIter iter;
        final switch (tvdp) {
            case TreeViewDropPosition.BEFORE:
                TreeIter iterParent;
                if (!ts.iterParent(iterParent, target)) {
                    iterParent = null;
                }
                ts.insertBefore(iter, iterParent, target);
                break;
            case TreeViewDropPosition.AFTER:
                TreeIter iterParent;
                if (!ts.iterParent(iterParent, target)) {
                    iterParent = null;
                }
                ts.insertAfter(iter, iterParent, target);
                break;
            case TreeViewDropPosition.INTO_OR_BEFORE:
                iter = ts.append(target);
                break;
            case TreeViewDropPosition.INTO_OR_AFTER:
                iter = ts.append(target);
                break;
        }

        foreach(column; EnumMembers!Columns) {
            ts.setValue(iter, column, ts.getValue(source, column));
        }
        ts.remove(source);
    }

    void setupDragAndDrop() {
        TargetEntry bmEntry = new TargetEntry(BOOKMARK_DND, TargetFlags.SAME_WIDGET, DropTargets.BOOKMARK);
        TargetEntry[] targets = [bmEntry];
        enableModelDragDest(targets, DragAction.MOVE);
        enableModelDragSource(ModifierType.BUTTON1_MASK, targets, DragAction.MOVE);
        addOnDragDataGet(&onDragDataGet);
        addOnDragDataReceived(&onDragDataReceived);
    }

public:
    this(bool enableFilter = false, bool foldersOnly = false, bool reorganizeable = false) {
        super();
        icons = getBookmarkIcons(this);
        ts = createBMTreeModel(icons, foldersOnly);

        if (enableFilter) {
            filter = new TreeModelFilter(ts, null);
            filter.setVisibleColumn(Columns.FILTER);
            setModel(filter);
        } else {
            setModel(ts);
            if (reorganizeable) {
                setupDragAndDrop();
            }
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
        FolderBookmark fbm = cast(FolderBookmark) getSelectedBookmark();
        if (fbm is null) {
            fbm = getParentBookmark(bm, parent);
            if (fbm is null) {
                fbm = bmMgr.root;
            }
        } else {
            parent = getSelectedIter();
        }

        bmMgr.add(fbm, bm);
        ignoreOperationFlag = true;
        TreeIter iter = addBookmarktoParent(ts, parent, bm, icons);
        ignoreOperationFlag = false;
        if (parent !is null) {
            expandRow(parent, ts, false);
        }
        getSelection().selectIter(iter);
        return fbm;
    }

    /**
     * Removes selected bookmark.
     */
    void removeBookmark() {
        TreeIter selected = getSelectedIter();
        Bookmark bm = getSelectedBookmark();
        if (selected is null || bm is null) return;

        bmMgr.remove(bm);
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
            selectFirstFilteredLeaf();
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