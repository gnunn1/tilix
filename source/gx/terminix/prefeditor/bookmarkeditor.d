/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.prefeditor.bookmarkeditor;

import std.experimental.logger;

import gdk.Pixbuf;

import gtk.Box;
import gtk.Button;
import gtk.CellRendererPixbuf;
import gtk.CellRendererText;
import gtk.ScrolledWindow;
import gtk.TreeViewColumn;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeStore;
import gtk.TreeView;
import gtk.Window;

import gx.i18n.l10n;

import gx.gtk.util;

import gx.terminix.bookmark.bmeditor;
import gx.terminix.bookmark.manager;

/**
 * Editor for globally managing bookmarks as part of the preferences dialog. Should not
 * be used outside this context.
 */
class GlobalBookmarkEditor: Box {

private:
    TreeView tv;
    TreeStore ts;
    ScrolledWindow sw;
    Pixbuf[] icons;

    Button btnEdit;
    Button btnDelete;

    void createUI() {
        ts = new TreeStore([Pixbuf.getType(), GType.STRING, GType.STRING]);
        loadBookmarks(null, bmMgr.root);
        tv = new TreeView(ts);
        tv.setActivateOnSingleClick(false);
        tv.setHeadersVisible(false);
        tv.getSelection().setMode(SelectionMode.SINGLE);
        tv.addOnCursorChanged(delegate(TreeView) {
            updateUI();
        });

        CellRendererPixbuf crp = new CellRendererPixbuf();
        crp.setProperty("stock-size", 16);
        TreeViewColumn column = new TreeViewColumn(_("Icon"), crp, "pixbuf", COLUMNS.ICON);
        tv.appendColumn(column);

        column = new TreeViewColumn(_("Name"), new CellRendererText(), "text", COLUMNS.NAME);
        column.setExpand(true);
        tv.appendColumn(column);

        column = new TreeViewColumn("UUID", new CellRendererText(), "text", COLUMNS.UUID);
        column.setVisible(false);
        tv.appendColumn(column);

        ScrolledWindow sw = new ScrolledWindow(tv);
        sw.setShadowType(ShadowType.ETCHED_IN);
        sw.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sw.setHexpand(true);
        sw.setVexpand(true);

        add(sw);

        Box bButtons = new Box(Orientation.VERTICAL, 6);

        Button btnAdd = new Button(_("Add"));
        btnAdd.addOnClicked(&addBookmark);
        bButtons.add(btnAdd);

        btnEdit = new Button(_("Edit"));
        btnEdit.addOnClicked(&editBookmark);
        bButtons.add(btnEdit);

        btnDelete = new Button(_("Delete"));
        btnDelete.addOnClicked(&deleteBookmark);
        bButtons.add(btnDelete);

        add(bButtons);
        updateUI();
    }

    void updateUI() {
        TreeIter selected = tv.getSelectedIter();
        btnEdit.setSensitive(selected !is null);
        btnDelete.setSensitive(selected !is null);
    }

    TreeIter addBookmarktoParent(TreeIter parent, Bookmark bm) {
        TreeIter result = ts.createIter(parent);
        ts.setValue(result, COLUMNS.ICON, icons[cast(uint)bm.type()]);
        ts.setValue(result, COLUMNS.NAME, bm.name);
        ts.setValue(result, COLUMNS.UUID, bm.uuid);
        return result;
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

    void addBookmark(Button button) {
        BookmarkEditor be = new BookmarkEditor(cast(Window)getToplevel(), null);
        scope(exit) {
            be.destroy();
        }
        be.showAll();
        if (be.run() == ResponseType.OK) {
            Bookmark bm = be.create();
            TreeIter selected = tv.getSelectedIter();
            FolderBookmark fbm = bmMgr.root();
            if (selected !is null) {
                FolderBookmark sfbm = cast(FolderBookmark) bmMgr.get(selected.getValueString(COLUMNS.UUID));
                if (sfbm !is null) {
                    fbm = sfbm;
                    tracef("FBM Name is %s", fbm.name);
                } else {
                    trace("sfbm is null");
                }
            }
            if (fbm is null) trace("FBM is null!");
            bmMgr.add(fbm, bm);
            TreeIter childIter = addBookmarktoParent(selected, bm);
        }
    }

    void editBookmark(Button button) {
        TreeIter selected = tv.getSelectedIter();
        if (selected is null) return;

        Bookmark bm = bmMgr.get(selected.getValueString(COLUMNS.UUID));
        BookmarkEditor be = new BookmarkEditor(cast(Window)getToplevel(), bm);
        scope(exit) {
            be.destroy();
        }
        be.showAll();
        if (be.run() == ResponseType.OK) {
            be.update(bm);
            ts.setValue(selected, COLUMNS.NAME, bm.name);
        }
    }

    void deleteBookmark(Button button) {
        TreeIter selected = tv.getSelectedIter();
        if (selected is null) return;
        Bookmark bm = bmMgr.get(selected.getValueString(COLUMNS.UUID));
        if (bm !is null) {
            FolderBookmark fbm = null;
            TreeIter parent = selected.getParent();
            if (parent is null) {
                fbm = bmMgr.root;
            } else {
                fbm = cast(FolderBookmark) bmMgr.get(parent.getValueString(COLUMNS.UUID));
            }
            if (fbm !is null) {
                bmMgr.remove(fbm, bm);
                ts.remove(selected);
            } else {
                error("Could not find folder bookmark");
            }
        }
    }

public:
    this() {
        super(Orientation.HORIZONTAL, 6);
        setAllMargins(this, 18);
        icons = getBookmarkIcons();
        createUI();
    }
}

private:
    enum COLUMNS : uint {
        ICON = 0,
        NAME = 1,
        UUID = 2
    }
