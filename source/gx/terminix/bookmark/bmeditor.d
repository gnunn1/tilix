/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.bookmark.bmeditor;

import std.conv;
import std.experimental.logger;

import gtk.Box;
import gtk.ComboBox;
import gtk.Dialog;
import gtk.Entry;
import gtk.FileChooserButton;
import gtk.Grid;
import gtk.Label;
import gtk.Separator;
import gtk.Stack;
import gtk.Widget;
import gtk.Window;

import gx.gtk.util;
import gx.i18n.l10n;

import gx.terminix.bookmark.manager;


/**
 * Dialog for editing bookmarks
 */
class BookmarkEditor: Dialog {

private:
    ComboBox cbType;
    Stack stEditors;

    void createUI(Bookmark bm) {
        setAllMargins(getContentArea(), 18);
        Box bContent = new Box(Orientation.VERTICAL, 6);

        Box bType = new Box(Orientation.HORIZONTAL, 6);
        Label lblType = new Label(_("Type"));
        lblType.setHalign(Align.END);
        cbType = createNameValueCombo([_("Folder"), _("Path")], [to!string(BookmarkType.FOLDER), to!string(BookmarkType.PATH)]);
        cbType.setHexpand(true);
        cbType.setHalign(Align.FILL);

        bType.add(lblType);
        bType.add(cbType);

        Separator sLine = new Separator(Orientation.HORIZONTAL);
        sLine.setHexpand(true);
        sLine.setHalign(Align.FILL);
        sLine.setMarginTop(6);
        sLine.setMarginBottom(6);

        bContent.add(bType);
        bContent.add(sLine);

        stEditors = new Stack();
        foreach(bt; [BookmarkType.FOLDER, BookmarkType.PATH]) {
            stEditors.addNamed(createTypeEditor(bt, bm), to!string(bt));
        }

        bContent.add(stEditors);

        // Setup change handler
        cbType.addOnChanged(delegate(ComboBox cb) {
            if (cbType.getActive >= 0) {
                stEditors.setVisibleChildName(cbType.getActiveId());
            }
        });
        // Set active page, change handler above does this
        if (bm !is null) {
            cbType.setActiveId(to!string(bm.type));
            bType.setNoShowAll(true);
        } else {
            cbType.setActiveId(to!string(BookmarkType.FOLDER));
        }
        getContentArea().add(bContent);
    }

public:

    this(Window parent, Bookmark bm = null) {
        string title = (bm is null)? _("Add Bookmark"):_("Edit Bookmark");
        super(_("Bookmark"), parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("OK"), _("Cancel")], [GtkResponseType.OK, GtkResponseType.CANCEL]);
        setTransientFor(parent);
        setDefaultResponse(GtkResponseType.OK);
        createUI(bm);
    }

    Bookmark create() {
        if (cbType.getActive >= 0) {
            BookmarkType type = to!BookmarkType(cbType.getActiveId());
            Bookmark bm = bmMgr.createBookmark(type);
            BookmarkTypeEditor editor = cast(BookmarkTypeEditor)stEditors.getVisibleChild();
            editor.update(bm);
            return bm;
        } else {
            return null;
        }
    }

    void update(Bookmark bm) {
        if (cbType.getActive >= 0) {
            BookmarkTypeEditor editor = to!(BookmarkTypeEditor)(stEditors.getVisibleChild());
            editor.update(bm);
        }
    }
}

private:

Widget createTypeEditor(BookmarkType bt, Bookmark bm = null) {
    final switch (bt) {
        case BookmarkType.FOLDER:
            return new FolderEditor(bm);
        case BookmarkType.PATH:
            return new PathEditor(bm);
        case BookmarkType.COMMAND:
            return null;
        case BookmarkType.SSH:
            return null;
        case BookmarkType.FTP:
            return null;
    }
}

interface BookmarkTypeEditor {
    void update(Bookmark bm);
}

class FolderEditor: Grid, BookmarkTypeEditor {
private:
    Entry eName;

public:
    this(Bookmark bm) {
        super();
        setColumnSpacing(12);
        setRowSpacing(6);

        Label lblName = new Label(_("Name"));
        lblName.setHalign(Align.END);
        attach(lblName, 0, 0, 1, 1);

        eName = new Entry();
        eName.setHexpand(true);
        attach(eName, 1, 0, 1, 1);

        if (bm !is null) {
            eName.setText(bm.name);
        }
    }

    void update(Bookmark bm) {
        bm.name = eName.getText();
    }
}

class PathEditor: Grid, BookmarkTypeEditor {
private:
    Entry eName;
    FileChooserButton fcbPath;

public:
    this(Bookmark bm) {
        super();
        setColumnSpacing(12);
        setRowSpacing(6);

        Label lblName = new Label(_("Name"));
        lblName.setHalign(Align.END);
        attach(lblName, 0, 0, 1, 1);

        eName = new Entry();
        eName.setHexpand(true);
        attach(eName, 1, 0, 1, 1);

        Label lblPath = new Label(_("Path"));
        lblPath.setHalign(Align.END);
        attach(lblPath, 0, 1, 1, 1);

        fcbPath = new FileChooserButton(_("Select Path"), FileChooserAction.SELECT_FOLDER);
        fcbPath.setHexpand(true);
        attach(fcbPath, 1, 1, 1, 1);

        if (bm !is null) {
            eName.setText(bm.name);
            PathBookmark pb = cast(PathBookmark) bm;
            if (pb !is null) {
                fcbPath.setFilename(pb.path);
            }
        }
    }

    void update(Bookmark bm) {
        bm.name = eName.getText();
    }
}


