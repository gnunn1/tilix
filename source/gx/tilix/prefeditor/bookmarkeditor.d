/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.prefeditor.bookmarkeditor;

import std.experimental.logger;

import gtk.Box;
import gtk.Button;
import gtk.ScrolledWindow;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.Window;

import gx.i18n.l10n;

import gx.gtk.util;

import gx.tilix.bookmark.bmeditor;
import gx.tilix.bookmark.bmtreeview;
import gx.tilix.bookmark.manager;

/**
 * Editor for globally managing bookmarks as part of the preferences dialog. Should not
 * be used outside this context.
 */
class GlobalBookmarkEditor: Box {

private:
    BMTreeView tv;
    ScrolledWindow sw;

    Button btnEdit;
    Button btnDelete;
    Button btnUnselect;

    void createUI() {
        tv = new BMTreeView(false, false, true);
        tv.setActivateOnSingleClick(false);
        tv.setHeadersVisible(false);
        tv.getSelection().setMode(SelectionMode.SINGLE);
        tv.addOnCursorChanged(delegate(TreeView) {
            updateUI();
        });
        tv.addOnRowActivated(delegate(TreePath, TreeViewColumn, TreeView) {
            editBookmark(btnEdit);
        });

        ScrolledWindow sw = new ScrolledWindow(tv);
        sw.setShadowType(ShadowType.ETCHED_IN);
        sw.setPolicy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        sw.setHexpand(true);
        sw.setVexpand(true);

        add(sw);

        Box bButtons = new Box(Orientation.HORIZONTAL, 0);
        bButtons.getStyleContext().addClass("linked");

        Button btnAdd = new Button("list-add-symbolic", IconSize.BUTTON);
        btnAdd.setTooltipText(_("Add bookmark"));
        btnAdd.addOnClicked(&addBookmark);
        bButtons.add(btnAdd);

        btnEdit = new Button("input-tablet-symbolic", IconSize.BUTTON);
        btnEdit.setTooltipText(_("Edit bookmark"));
        btnEdit.addOnClicked(&editBookmark);
        bButtons.add(btnEdit);

        btnDelete = new Button("list-remove-symbolic", IconSize.BUTTON);
        btnDelete.setTooltipText(_("Delete bookmark"));
        btnDelete.addOnClicked(&deleteBookmark);
        bButtons.add(btnDelete);

        btnUnselect = new Button("edit-clear-symbolic", IconSize.BUTTON);
        btnUnselect.setTooltipText(_("Unselect bookmark"));
        btnUnselect.addOnClicked(&unselectBookmark);
        bButtons.add(btnUnselect);

        add(bButtons);

        updateUI();
    }

    void updateUI() {
        TreeIter selected = tv.getSelectedIter();
        btnEdit.setSensitive(selected !is null);
        btnDelete.setSensitive(selected !is null);
        btnUnselect.setSensitive(selected !is null);
    }

    void addBookmark(Button button) {
        BookmarkEditor be = new BookmarkEditor(cast(Window)getToplevel(), BookmarkEditorMode.ADD, null);
        scope(exit) {
            be.destroy();
        }
        be.showAll();
        if (be.run() == ResponseType.OK) {
            Bookmark bm = be.create();
            tv.addBookmark(bm);
        }
    }

    void editBookmark(Button button) {
        Bookmark bm = tv.getSelectedBookmark();
        if (bm is null) return;
        BookmarkEditor be = new BookmarkEditor(cast(Window)getToplevel(), BookmarkEditorMode.EDIT, bm);
        scope(exit) {
            be.destroy();
        }
        be.showAll();
        if (be.run() == ResponseType.OK) {
            be.update(bm);
            tv.updateBookmark(bm);
        }
    }

    void deleteBookmark(Button button) {
        tv.removeBookmark();
    }

    void unselectBookmark(Button button) {
        tv.getSelection().unselectIter(tv.getSelectedIter());
    }

public:
    this() {
        super(Orientation.VERTICAL, 6);
        setAllMargins(this, 18);
        setMarginBottom(6);
        createUI();
    }
}