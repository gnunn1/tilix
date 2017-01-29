/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.bookmark.bmeditor;

import std.conv;
import std.experimental.logger;
import std.signals;

import glib.Util;

import gobject.ObjectG;
import gobject.ParamSpec;

import gtk.Box;
import gtk.ComboBox;
import gtk.Dialog;
import gtk.Entry;
import gtk.FileChooserButton;
import gtk.Grid;
import gtk.HeaderBar;
import gtk.Label;
import gtk.Separator;
import gtk.Stack;
import gtk.StackSwitcher;
import gtk.Widget;
import gtk.Window;

import gx.gtk.util;
import gx.i18n.l10n;

import gx.terminix.bookmark.manager;
import gx.terminix.common;


/**
 * Dialog for editing bookmarks
 */
class BookmarkEditor: Dialog {

private:
    Stack stEditors;
    StackSwitcher ssEditors;

    void createUI(Bookmark bm) {
        Box bContent = new Box(Orientation.VERTICAL, 6);
        setAllMargins(bContent, 18);

        stEditors = new Stack();
        stEditors.addOnNotify(delegate(ParamSpec, ObjectG) {
            updateUI();
        },"visible-child");

        // Adding a new bookmark or editing one?
        if (bm !is null) {
            // Add only the editor we need to edit this one bookmark
            stEditors.addTitled(createTypeEditor(bm.type, bm), to!string(bm.type), bmMgr.localize(bm.type));
        } else {
            //Add all editors
            foreach(bt; [BookmarkType.FOLDER, BookmarkType.PATH]) {
                BaseEditor be = createTypeEditor(bt, bm);
                be.onValidChanged.connect(&validateChanged);
                stEditors.addTitled(be, to!string(bt), bmMgr.localize(bt));
            }
            ssEditors = new StackSwitcher();
            ssEditors.setMarginBottom(12);
            ssEditors.setStack(stEditors);
            bContent.add(ssEditors);
        }
        bContent.add(stEditors);
        getContentArea().add(bContent);
        updateUI();
    }

    BaseEditor getEditor() {
        return cast(BaseEditor)stEditors.getVisibleChild();
    }

    void validateChanged(BaseEditor be, bool valid) {
        if (be == getEditor()) {
            setResponseSensitive(ResponseType.OK, valid);
        }
    }

    void updateUI() {
        if (getEditor() !is null) {
            setResponseSensitive(ResponseType.OK, getEditor().validate());
        }
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
        BookmarkType type = to!BookmarkType(stEditors.getVisibleChildName());
        Bookmark bm = bmMgr.createBookmark(type);
        BaseEditor editor = cast(BaseEditor)stEditors.getVisibleChild();
        editor.update(bm);
        return bm;
    }

    void update(Bookmark bm) {
        BaseEditor editor = to!(BaseEditor)(stEditors.getVisibleChild());
        editor.update(bm);
    }
}

private:

BaseEditor createTypeEditor(BookmarkType bt, Bookmark bm = null) {
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

abstract class BaseEditor: Grid {
private:
    Entry eName;

protected:
    int row = 0;

public:

    this(Bookmark bm) {
        super();
        setColumnSpacing(12);
        setRowSpacing(6);

        Label lblName = new Label(_("Name"));
        lblName.setHalign(Align.END);
        attach(lblName, 0, row, 1, 1);

        eName = new Entry();
        eName.setHexpand(true);
        eName.addOnChanged(delegate(EditableIF) {
            onValidChanged.emit(this, validate);
        });
        attach(eName, 1, row, 1, 1);
        row++;

        if (bm !is null) {
            eName.setText(bm.name);
        }
    }

    /**
     * Update the bookmark. An editor should be able to update
     * any bookmark type but only update the fields it understands,
     * typically just the name.
     */
    void update(Bookmark bm) {
        bm.name = eName.getText();
    }

    /**
     * Whether the editor is in a valid state
     */
    bool validate() {
        return eName.getText().length > 0;
    }

    /**
     * Fired when the valid state of the editor changed
     */
    GenericEvent!(BaseEditor, bool) onValidChanged;

}

class FolderEditor: BaseEditor {

    this(Bookmark bm) {
        super(bm);
    }
}

class PathEditor: BaseEditor {
private:
    FileChooserButton fcbPath;

public:
    this(Bookmark bm) {
        super(bm);

        Label lblPath = new Label(_("Path"));
        lblPath.setHalign(Align.END);
        attach(lblPath, 0, row, 1, 1);

        fcbPath = new FileChooserButton(_("Select Path"), FileChooserAction.SELECT_FOLDER);
        fcbPath.setHexpand(true);
        fcbPath.setFilename(Util.getHomeDir());
        attach(fcbPath, 1, row, 1, 1);
        row++;

        if (bm !is null) {
            eName.setText(bm.name);
            PathBookmark pb = cast(PathBookmark) bm;
            if (pb !is null) {
                fcbPath.setFilename(pb.path);
            }
        }
    }

    override void update(Bookmark bm) {
        super.update(bm);
        PathBookmark pb = cast(PathBookmark) bm;
        if (pb !is null) {
            pb.path = fcbPath.getFilename();
        }
    }

    override bool validate() {
        return super.validate() && (fcbPath.getFilename().length > 0);
    }
}