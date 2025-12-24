/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.prefeditor.bookmarkeditor;

import std.experimental.logger;

import gtk.box;
import gtk.types;
import gtk.button;
import gtk.types;
import gtk.image;
import gtk.scrolled_window;
import gtk.types;
import gtk.tree_iter;
import gtk.types;
import gtk.tree_path;
import gtk.types;
import gtk.tree_view;
import gtk.tree_view_column;
import gtk.types;
import gtk.widget;
import gtk.types;
import gtk.window;
import gtk.types;

import gx.gtk.types;
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
        tv.connectCursorChanged(delegate(TreeView tv) {
            updateUI();
        });
        tv.connectRowActivated(delegate(TreePath path, TreeViewColumn col, TreeView tv) {
            editBookmark(btnEdit);
        });

        ScrolledWindow sw = new ScrolledWindow();
        sw.add(tv);
        sw.setShadowType(ShadowType.EtchedIn);
        sw.setPolicy(PolicyType.Automatic, PolicyType.Automatic);
        sw.setHexpand(true);
        sw.setVexpand(true);

        add(sw);

        Box bButtons = new Box(gtk.types.Orientation.Horizontal, 0);
        bButtons.getStyleContext().addClass("linked");

        Button btnAdd = new Button();
        btnAdd.setImage(Image.newFromIconName("list-add-symbolic", IconSize.Button));
        btnAdd.setTooltipText(_("Add bookmark"));
        btnAdd.connectClicked(&addBookmark);
        bButtons.add(btnAdd);

        btnEdit = new Button();
        btnEdit.setImage(Image.newFromIconName("input-tablet-symbolic", IconSize.Button));
        btnEdit.setTooltipText(_("Edit bookmark"));
        btnEdit.connectClicked(&editBookmark);
        bButtons.add(btnEdit);

        btnDelete = new Button();
        btnDelete.setImage(Image.newFromIconName("list-remove-symbolic", IconSize.Button));
        btnDelete.setTooltipText(_("Delete bookmark"));
        btnDelete.connectClicked(&deleteBookmark);
        bButtons.add(btnDelete);

        btnUnselect = new Button();
        btnUnselect.setImage(Image.newFromIconName("edit-clear-symbolic", IconSize.Button));
        btnUnselect.setTooltipText(_("Unselect bookmark"));
        btnUnselect.connectClicked(&unselectBookmark);
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
        if (be.run() == gtk.types.ResponseType.Ok) {
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
        if (be.run() == gtk.types.ResponseType.Ok) {
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
        super(gtk.types.Orientation.Vertical, 6);
        setAllMargins(this, 18);
        setMarginBottom(6);
        createUI();
    }
}