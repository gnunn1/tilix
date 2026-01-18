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

import gdk.atom : Atom;
import gdk.drag_context;
import gdk.types : DragAction, ModifierType;
import gdkpixbuf.pixbuf;

import gobject.value;

import gx.gtk.util : GTypes;

import gtk.cell_renderer_pixbuf : CellRendererPixbuf;
import gtk.cell_renderer_text : CellRendererText;
import gtk.selection_data;
import gtk.target_entry;
import gtk.tree_view_column : TreeViewColumn;
import gtk.tree_iter;
import gtk.tree_model;
import gtk.tree_model_filter;
import gtk.tree_path;
import gtk.tree_store;
import gtk.tree_view;
import gtk.types : TargetFlags, TreeViewDropPosition;
import gtk.widget;

import gx.i18n.l10n;

import gx.tilix.bookmark.manager;

enum Columns : uint {
    ICON = 0,
    NAME = 1,
    UUID = 2,
    FILTER = 3
}

TreeStore createBMTreeModel(Pixbuf[] icons, bool foldersOnly) {
    TreeStore ts = TreeStore.new_([Pixbuf._getGType(), GTypes.STRING, GTypes.STRING, GTypes.BOOLEAN]);
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
        TreeViewColumn column = new TreeViewColumn();
        column.setTitle(_("Icon"));
        column.packStart(crp, true);
        column.addAttribute(crp, "pixbuf", cast(int)Columns.ICON);
        appendColumn(column);

        CellRendererText crtName = new CellRendererText();
        column = new TreeViewColumn();
        column.setTitle(_("Name"));
        column.packStart(crtName, true);
        column.addAttribute(crtName, "text", cast(int)Columns.NAME);
        column.setExpand(true);
        appendColumn(column);

        CellRendererText crtUuid = new CellRendererText();
        column = new TreeViewColumn();
        column.setTitle("UUID");
        column.packStart(crtUuid, true);
        column.addAttribute(crtUuid, "text", cast(int)Columns.UUID);
        column.setVisible(false);
        appendColumn(column);

        CellRendererText crtFilter = new CellRendererText();
        column = new TreeViewColumn();
        column.setTitle("Filter");
        column.packStart(crtFilter, true);
        column.addAttribute(crtFilter, "text", cast(int)Columns.FILTER);
        column.setVisible(false);
        appendColumn(column);
    }

    TreeIter getSelectedIter() {
        TreeModel model;
        TreeIter iter;
        if (getSelection().getSelected(model, iter)) {
            return iter;
        }
        return null;
    }

    string getValueString(TreeModel model, TreeIter iter, int column) {
        Value val;
        model.getValue(iter, column, val);
        return val.getString();
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
        return cast(FolderBookmark) bmMgr.get(getValueString(getModel(), parent, cast(int)Columns.UUID));
    }

    /**
     * Updates the filter and returns the TreePath
     * of the node that should be focused.
     */
    void updateFilter() {
        void checkFilter(TreeIter iter) {
            string name = getValueString(ts, iter, cast(int)Columns.NAME);
            bool visible = filterText.length == 0 || name.indexOf(filterText, No.caseSensitive) >= 0;
            ts.setValue(iter, cast(int)Columns.FILTER, new Value(visible));
            if (visible) {
                TreeIter parent = iter;
                Value value;
                // Walk up the parent hierarchy and set it's visibility to true
                while (ts.iterParent(parent, parent)) {
                    // has parent visibility already been set?
                    ts.getValue(parent, cast(int)Columns.FILTER, value);
                    if (value.getBoolean()) break;
                    ts.setValue(parent, cast(int)Columns.FILTER, new Value(true));
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
            string uuid = getValueString(filter, iter, cast(int)Columns.UUID);
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
            string path = ts.getPath(iter).toString();
            ubyte[] buffer = cast(ubyte[])(path ~ '\0').dup;
            data.set(Atom.intern(BOOKMARK_DND, false), 8, buffer);
        }
    }

    void onDragDataReceived(DragContext dc, int x, int y, SelectionData data, uint info, uint time, Widget widget) {
        if (info != DropTargets.BOOKMARK) return;

        TreePath pathTarget;
        TreeViewDropPosition tvdp;
        if (!getDestRowAtPos(x, y, pathTarget, tvdp)) return;
        TreeIter target = new TreeIter();
        ts.getIter(target, pathTarget);

        string dataPath = cast(string)(data.getData()[0 .. $ - 1]);
        tracef("Data received %s", dataPath);
        TreePath pathSource = TreePath.newFromString(dataPath);
        TreeIter source = new TreeIter();
        ts.getIter(source, pathSource);

        //Move bookmark first
        Bookmark bmTarget = bmMgr.get(getValueString(ts, target, cast(int)Columns.UUID));
        Bookmark bmSource = bmMgr.get(getValueString(ts, source, cast(int)Columns.UUID));
        try {
            switch (tvdp) {
                case TreeViewDropPosition.Before:
                    bmMgr.moveBefore(bmTarget, bmSource);
                    break;
                case TreeViewDropPosition.After:
                    bmMgr.moveAfter(bmTarget, bmSource);
                    break;
                case TreeViewDropPosition.IntoOrBefore:
                ..
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
            Value val;
            ts.getValue(source, cast(int)column, val);
            ts.setValue(iter, cast(int)column, val);
        }
        ts.remove(source);
    }

    void setupDragAndDrop() {
        TargetEntry bmEntry = new TargetEntry(BOOKMARK_DND, TargetFlags.SameWidget, DropTargets.BOOKMARK);
        TargetEntry[] targets = [bmEntry];
        enableModelDragDest(targets, DragAction.Move);
        enableModelDragSource(ModifierType.Button1Mask, targets, DragAction.Move);
        connectDragDataGet(&onDragDataGet);
        connectDragDataReceived(&onDragDataReceived);
    }

public:
    this(bool enableFilter = false, bool foldersOnly = false, bool reorganizeable = false) {
        super();
        icons = getBookmarkIcons(this);
        ts = createBMTreeModel(icons, foldersOnly);

        if (enableFilter) {
            filter = cast(TreeModelFilter) ts.filterNew(null);
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
        return bmMgr.get(getValueString(getModel(), selected, cast(int)Columns.UUID));
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
        if (selected is null || getValueString(ts, selected, cast(int)Columns.UUID) != bm.uuid) return;
        ts.setValue(selected, cast(int)Columns.NAME, new Value(bm.name));
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
    TreeIter result;
    ts.append(result, parent);
    ts.setValue(result, cast(int)Columns.ICON, new Value(icons[cast(uint)bm.type()]));
    ts.setValue(result, cast(int)Columns.NAME, new Value(bm.name));
    ts.setValue(result, cast(int)Columns.UUID, new Value(bm.uuid));
    ts.setValue(result, cast(int)Columns.FILTER, new Value(true));
    return result;
}