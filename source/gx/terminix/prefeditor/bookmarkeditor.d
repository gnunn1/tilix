/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.prefeditor.bookmarkeditor;

import gtk.Box;
import gtk.Button;
import gtk.ScrolledWindow;
import gtk.TreeIter;
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

    void createUI() {
        ts = new TreeStore([GType.STRING]);
        loadBookmarks(null, bmMgr.root);
        tv = new TreeView(ts);
        tv.setActivateOnSingleClick(false);

        ScrolledWindow sw = new ScrolledWindow(tv);
        sw.setShadowType(ShadowType.ETCHED_IN);
        sw.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sw.setHexpand(true);
        sw.setVexpand(true);

        add(sw);

        Box bButtons = new Box(Orientation.VERTICAL, 6);

        Button btnAdd = new Button(_("Add"));
        btnAdd.addOnClicked(delegate(Button) {
            addBookmark();
        });

        bButtons.add(btnAdd);

        Button btnEdit = new Button(_("Edit"));
        bButtons.add(btnEdit);

        Button btnDelete = new Button(_("Delete"));
        bButtons.add(btnDelete);

        add(bButtons);

    }

    void loadBookmarks(TreeIter current, FolderBookmark parent) {
        foreach(bm; parent) {
            TreeIter childIter = appendValues(ts, current, [bm.name]);
            childIter.userData(cast(void*) bm);
            FolderBookmark fm = cast(FolderBookmark)bm;
            if (fm !is null) {
                loadBookmarks(childIter, fm);
            }
        }
    }

    void addBookmark() {
        TreeIter selected = tv.getSelectedIter();
        BaseBookmark bm = null;
        if (selected !is null) {
            bm = cast(BaseBookmark)selected.userData();
        }
        BookmarkEditor be = new BookmarkEditor(cast(Window)getToplevel(), bm);
        scope(exit) {
            be.destroy();
        }
        be.showAll();
        if (be.run() == ResponseType.OK) {

        }
    }

public:
    this() {
        super(Orientation.HORIZONTAL, 6);
        setAllMargins(this, 18);
        createUI();
    }
}