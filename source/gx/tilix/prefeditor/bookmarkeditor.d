/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.prefeditor.bookmarkeditor;

import std.experimental.logger;

import gtk.box;
import gtk.button;
import gtk.scrolled_window;
import gtk.tree_iter;
import gtk.tree_path;
import gtk.tree_view : TreeView;
import gtk.tree_view_column : TreeViewColumn;
import gtk.types : IconSize, Orientation, PolicyType, ResponseType, SelectionMode, ShadowType;
import gtk.window;

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
        tv.getSelection().setMode(SelectionMode.Single);
        tv.connectCursorChanged(delegate(TreeView v) {
            updateUI();
        });
        tv.connectRowActivated(delegate(TreePath p, TreeViewColumn c, TreeView v) {
            editBookmark(btnEdit);
        });

        ScrolledWindow sw = new ScrolledWindow(null, null);
        sw.add(tv);
        sw.setShadowType(ShadowType.EtchedIn);
        sw.setPolicy(PolicyType.Automatic, PolicyType.Automatic);
        sw.setHexpand(true);
        sw.setVexpand(true);

        add(sw);

        Box bButtons = new Box(Orientation.Horizontal, 0);
        bButtons.getStyleContext().addClass("linked");

        Button btnAdd = Button.newFromIconName("list-add-symbolic", IconSize.Button);
        btnAdd.setTooltipText(_("Add bookmark"));
        btnAdd.connectClicked(&addBookmark);
        bButtons.add(btnAdd);

        btnEdit = Button.newFromIconName("input-tablet-symbolic", IconSize.Button);
        btnEdit.setTooltipText(_("Edit bookmark"));
        btnEdit.connectClicked(&editBookmark);
        bButtons.add(btnEdit);

        btnDelete = Button.newFromIconName("list-remove-symbolic", IconSize.Button);
        btnDelete.setTooltipText(_("Delete bookmark"));
        btnDelete.connectClicked(&deleteBookmark);
        bButtons.add(btnDelete);

        btnUnselect = Button.newFromIconName("edit-clear-symbolic", IconSize.Button);
        btnUnselect.setTooltipText(_("Unselect bookmark"));
        btnUnselect.connectClicked(&unselectBookmark);
        bButtons.add(btnUnselect);

        add(bButtons);

        updateUI();
    }

    void updateUI() {
        Bookmark selected = tv.getSelectedBookmark();
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
        if (be.run() == ResponseType.Ok) {
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
        if (be.run() == ResponseType.Ok) {
            be.update(bm);
            tv.updateBookmark(bm);
        }
    }

    void deleteBookmark(Button button) {
        tv.removeBookmark();
    }

    void unselectBookmark(Button button) {
        tv.getSelection().unselectAll();
    }

public:
    this() {
        super(Orientation.Vertical, 6);
        setAllMargins(this, 18);
        setMarginBottom(6);
        createUI();
    }
}