/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.bookmark.bmeditor;

import gtk.Box;
import gtk.ComboBox;
import gtk.Dialog;
import gtk.Entry;
import gtk.FileChooserButton;
import gtk.Grid;
import gtk.Label;
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

    void createUI(BaseBookmark bm) {
        setAllMargins(getContentArea(), 18);
        Box bContent = new Box(Orientation.VERTICAL, 6);

        Box bType = new Box(Orientation.HORIZONTAL, 6);
        Label lblType = new Label(_("Type"));
        lblType.setHalign(Align.END);
        cbType = createNameValueCombo([_("Folder"), _("Type")], [BookmarkType.FOLDER, BookmarkType.PATH]);

        bType.add(lblType);
        bType.add(cbType);

        bContent.add(bType);

        Stack stEditors = new Stack();
        foreach(bt; [BookmarkType.FOLDER, BookmarkType.PATH]) {
            stEditors.addNamed(getTypeEditor(bt, bm), bt);
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
            cbType.setActiveId(bm.type);
            bType.setNoShowAll(true);
        } else {
            cbType.setActiveId(BookmarkType.FOLDER);
        }
        getContentArea().add(bContent);
    }

public:

    this(Window parent, BaseBookmark bm = null) {
        string title = (bm is null)? _("Add Bookmark"):_("Edit Bookmark");
        super(_("Bookmark"), parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("OK"), _("Cancel")], [GtkResponseType.OK, GtkResponseType.CANCEL]);
        setTransientFor(parent);
        setDefaultResponse(GtkResponseType.OK);
        createUI(bm);
    }
}

private:

Widget getTypeEditor(BookmarkType bt, BaseBookmark bm = null) {
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
    void update(BaseBookmark bm);
}

class FolderEditor: Grid, BookmarkTypeEditor {
private:
    Entry eName;

public:
    this(BaseBookmark bm) {
        super();
        setColumnSpacing(12);
        setRowSpacing(6);

        Label lblName = new Label(_("Name"));
        lblName.setHalign(Align.END);
        attach(lblName, 0, 0, 1, 1);

        eName = new Entry();
        attach(eName, 1, 0, 1, 1);

        if (bm !is null) {
            eName.setText(bm.name);
        }
    }

    void update(BaseBookmark bm) {
        bm.name = eName.getText();
    }
}

class PathEditor: Grid, BookmarkTypeEditor {
private:
    Entry eName;
    FileChooserButton fcbPath;

public:
    this(BaseBookmark bm) {
        super();
        setColumnSpacing(12);
        setRowSpacing(6);

        Label lblName = new Label(_("Name"));
        lblName.setHalign(Align.END);
        attach(lblName, 0, 0, 1, 1);

        eName = new Entry();
        attach(eName, 1, 0, 1, 1);

        Label lblPath = new Label(_("Path"));
        lblPath.setHalign(Align.END);
        attach(lblPath, 0, 1, 1, 1);

        fcbPath = new FileChooserButton(_("Select Path"), FileChooserAction.SELECT_FOLDER);
        attach(fcbPath, 1, 1, 1, 1);

        if (bm !is null) {
            eName.setText(bm.name);
            PathBookmark pb = cast(PathBookmark) bm;
            if (pb !is null) {
                fcbPath.setFilename(pb.path);
            }
        }
    }

    void update(BaseBookmark bm) {
        bm.name = eName.getText();
    }
}


