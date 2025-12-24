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

import gdk.atom;
import gdk.types;
import gdk.drag_context;
import gdk.types;
import gdkpixbuf.pixbuf;

import gobject.value;
import gobject.types;

import gtk.cell_renderer_pixbuf;
import gtk.types;
import gtk.cell_renderer_text;
import gtk.types;
import gtk.selection_data;
import gtk.types;
import gtk.target_entry;
import gtk.types;
import gtk.tree_view_column;
import gtk.types;
import gtk.tree_iter;
import gtk.types;
import gtk.tree_model;
import gtk.types;
import gtk.tree_model_filter;
import gtk.types;
import gtk.tree_path;
import gtk.types;
import gtk.tree_store;
import gtk.types;
import gtk.tree_view;
import gtk.types;
import gtk.widget;
import gtk.types;

import gx.gtk.types;
import gx.i18n.l10n;

import gx.tilix.bookmark.manager;

enum Columns : uint {
    ICON = 0,
    NAME = 1,
    UUID = 2,
    FILTER = 3
}

TreeStore createBMTreeModel(gdkpixbuf.pixbuf.Pixbuf[] icons, bool foldersOnly) {
    TreeStore ts = TreeStore.new_([cast(GType)gdkpixbuf.pixbuf.Pixbuf._getGType(), cast(GType)GTypeEnum.String, cast(GType)GTypeEnum.String, cast(GType)GTypeEnum.Boolean]);
    loadBookmarks(ts, null, bmMgr.root, foldersOnly, icons);
    return ts;
}

class BMTreeView: TreeView {
private:
    TreeStore ts;
    TreeModelFilter filter;
    string _filterText;
    gdkpixbuf.pixbuf.Pixbuf[] icons;

    bool ignoreOperationFlag = false;
    string deletedBookmarkUUID;

    enum BOOKMARK_DND = "bookmark";

    enum DropTargets {
        BOOKMARK
    };


    void createColumns() {
        CellRendererPixbuf crp = new CellRendererPixbuf();
        crp.setProperty("stock-size", new Value(16));
        TreeViewColumn column = new TreeViewColumn();
        column.setTitle(_("Icon"));
        column.packStart(crp, false);
        column.addAttribute(crp, "pixbuf", Columns.ICON);
        appendColumn(column);

        column = new TreeViewColumn();
        column.setTitle(_("Name"));
        CellRendererText crt = new CellRendererText();
        column.packStart(crt, true);
        column.addAttribute(crt, "text", Columns.NAME);
        column.setExpand(true);
        appendColumn(column);

        column = new TreeViewColumn();
        column.setTitle("UUID");
        crt = new CellRendererText();
        column.packStart(crt, true);
        column.addAttribute(crt, "text", Columns.UUID);
        column.setVisible(false);
        appendColumn(column);

        column = new TreeViewColumn();
        column.setTitle("Filter");
        crt = new CellRendererText();
        column.packStart(crt, true);
        column.addAttribute(crt, "text", Columns.FILTER);
        column.setVisible(false);
        appendColumn(column);
    }

public:
    TreeIter getSelectedIter() {
        TreeIter iter;
        TreeModel model;
        if (getSelection().getSelected(model, iter)) {
            return iter;
        }
        return null;
    }

    string getValueString(TreeModel model, TreeIter iter, uint column) {
        Value val = new Value();
        model.getValue(iter, cast(int)column, val);
        return val.getString();
    }

    FolderBookmark getParentBookmark(Bookmark bm, TreeIter parent) {
        parent = getSelectedIter();
        if (parent is null) return null;
        if (!getModel().iterHasChild(parent)) {
            if (!getModel().iterParent(parent, parent)) {
                parent = null;
                return bmMgr.root;
            }
        }
        return cast(FolderBookmark) bmMgr.get(getValueString(getModel(), parent, Columns.UUID));
    }

    /**
     * Updates the filter and returns the TreePath
     * of the node that should be focused.
     */
    void updateFilter() {

        void checkFilter(TreeIter iter) {
            string name = getValueString(ts, iter, Columns.NAME);
            bool visible = filterText.length == 0 || name.indexOf(filterText, No.caseSensitive) >= 0;
            ts.setValue(iter, Columns.FILTER, new Value(visible));
            if (visible) {
                TreeIter parent = iter;
                Value value = new Value();
                // Walk up the parent hierarchy and set it's visibility to true
                while (ts.iterParent(parent, parent)) {
                    // has parent visibility already been set?
                    ts.getValue(parent, Columns.FILTER, value);
                    if (value.getBoolean()) break;
                    ts.setValue(parent, Columns.FILTER, new Value(true));
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
            string uuid = getValueString(filter, iter, Columns.UUID);
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

    void onDragDataGet(DragContext dc, SelectionData data, uint info, uint time, Widget w) {
        TreeIter iter = getSelectedIter();
        if (iter !is null) {
            //string uuid = getValueString(ts, iter, Columns.UUID);
            string path = getModel().getPath(iter).toString();
            char[] buffer = (path ~ '\0').dup;
            data.set(Atom.intern(BOOKMARK_DND, false), 8, cast(ubyte[])buffer);
        }
    }

    void onDragDataReceived(DragContext dc, int x, int y, SelectionData data, uint info, uint time, Widget widget) {
        if (info != DropTargets.BOOKMARK) return;

        TreePath pathTarget;
        TreeViewDropPosition tvdp;
        if (!getDestRowAtPos(x, y, pathTarget, tvdp)) return;
        TreeIter target;
        ts.getIter(target, pathTarget);

        string dataPath = to!string(cast(char[])data.getData());
        tracef("Data received %s", dataPath);
        TreePath pathSource = TreePath.newFromString(dataPath);
        TreeIter source;
        ts.getIter(source, pathSource);

        //Move bookmark first
        Bookmark bmTarget = bmMgr.get(getValueString(ts, target, Columns.UUID));
        Bookmark bmSource = bmMgr.get(getValueString(ts, source, Columns.UUID));
        try {
            switch (tvdp) {
                case TreeViewDropPosition.Before:
                    bmMgr.moveBefore(bmTarget, bmSource);
                    break;
                case TreeViewDropPosition.After:
                    bmMgr.moveAfter(bmTarget, bmSource);
                    break;
                case TreeViewDropPosition.IntoOrBefore:
                case TreeViewDropPosition.IntoOrAfter:
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
            error("Could not perform operation, error occurred");
            error(e);
            return;
        }

        TreeIter iter;
        final switch (tvdp) {
            case TreeViewDropPosition.Before:
                TreeIter iterParent;
                if (!ts.iterParent(iterParent, target)) {
                    iterParent = null;
                }
                ts.insertBefore(iter, iterParent, target);
                break;
            case TreeViewDropPosition.After:
                TreeIter iterParent;
                if (!ts.iterParent(iterParent, target)) {
                    iterParent = null;
                }
                ts.insertAfter(iter, iterParent, target);
                break;
            case TreeViewDropPosition.IntoOrBefore:
                ts.append(iter, target);
                break;
            case TreeViewDropPosition.IntoOrAfter:
                ts.append(iter, target);
                break;
        }

        foreach(column; EnumMembers!Columns) {
            Value v = new Value();
            ts.getValue(source, cast(int)column, v);
            ts.setValue(iter, cast(int)column, v);
        }
        ts.remove(source);
    }

    void setupDragAndDrop() {
        TargetEntry bmEntry = new TargetEntry(BOOKMARK_DND, gtk.types.TargetFlags.SameWidget, DropTargets.BOOKMARK);
        TargetEntry[] targets = [bmEntry];
        enableModelDragDest(targets, gdk.types.DragAction.Move);
        enableModelDragSource(gdk.types.ModifierType.Button1Mask, targets, gdk.types.DragAction.Move);
        connectDragDataGet(&onDragDataGet);
        connectDragDataReceived(&onDragDataReceived);
    }

public:
    this(bool enableFilter = false, bool foldersOnly = false, bool reorganizeable = false) {
        super();
        icons = getBookmarkIcons(this);
        ts = createBMTreeModel(icons, foldersOnly);

        if (enableFilter) {
            filter = cast(TreeModelFilter)ts.filterNew(null);
            filter.setVisibleColumn(cast(int)Columns.FILTER);
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
        return bmMgr.get(getValueString(getModel(), selected, Columns.UUID));
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
            expandRow(ts.getPath(parent), false);
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
        if (selected is null || getValueString(ts, selected, Columns.UUID) != bm.uuid) return;
        ts.setValue(selected, Columns.NAME, new Value(bm.name));
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

void loadBookmarks(TreeStore ts, TreeIter current, FolderBookmark parent, bool foldersOnly, gdkpixbuf.pixbuf.Pixbuf[] icons) {
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

TreeIter addBookmarktoParent(TreeStore ts, TreeIter parent, Bookmark bm, gdkpixbuf.pixbuf.Pixbuf[] icons) {
    TreeIter result;
    ts.append(result, parent);
    ts.setValue(result, Columns.ICON, new Value(icons[cast(uint)bm.type()]));
    ts.setValue(result, Columns.NAME, new Value(bm.name));
    ts.setValue(result, Columns.UUID, new Value(bm.uuid));
    ts.setValue(result, Columns.FILTER,  new Value(true));
    return result;
}