/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.bookmark.bmeditor;

import std.conv;
import std.experimental.logger;
import std.signals;
import std.string;
import std.traits;

import glib.Util;

import gobject.ObjectG;
import gobject.ParamSpec;

import gtk.Box;
import gtk.Button;
import gtk.ComboBox;
import gtk.Dialog;
import gtk.Entry;
import gtk.FileChooserButton;
import gtk.Grid;
import gtk.HeaderBar;
import gtk.Label;
import gtk.Separator;
import gtk.SpinButton;
import gtk.Stack;
import gtk.StackSwitcher;
import gtk.Widget;
import gtk.Window;

import gx.gtk.util;
import gx.i18n.l10n;

import gx.tilix.bookmark.bmchooser;
import gx.tilix.bookmark.manager;
import gx.tilix.bookmark.bmtreeview;
import gx.tilix.common;


enum BookmarkEditorMode {ADD, EDIT}

/**
 * Dialog for adding or editing a single bookmark. This dialog
 * works by using a Stack of editors where each editor is specific
 * to a particular bookmark type.
 */
class BookmarkEditor: Dialog {

private:
    Stack stEditors;
    StackSwitcher ssEditors;
    BookmarkEditorMode mode;

    Entry eFolder;
    FolderBookmark _folder;

    void createUI(Bookmark bm, bool folderPicker) {
        Box bContent = new Box(Orientation.VERTICAL, 6);
        setAllMargins(bContent, 18);

        if (folderPicker) {
            Box bPicker = new Box(Orientation.HORIZONTAL, 0);
            bPicker.getStyleContext().addClass("linked");
            eFolder = new Entry();
            eFolder.setPlaceholderText(_("Select Folder"));
            eFolder.setEditable(false);
            eFolder.setHexpand(true);
            bPicker.add(eFolder);

            Button btnFolderPicker = new Button("folder-symbolic", IconSize.BUTTON);
            btnFolderPicker.setTooltipText(_("Select folder"));
            btnFolderPicker.addOnClicked(delegate(Button) {
                BookmarkChooser bc = new BookmarkChooser(this, BMSelectionMode.FOLDER);
                scope(exit) {bc.destroy();}
                bc.showAll();
                if (bc.run() == ResponseType.OK) {
                    folder = cast(FolderBookmark) bc.bookmark;
                }
            });
            bPicker.add(btnFolderPicker);

            Button btnClearFolder = new Button("edit-clear-symbolic", IconSize.BUTTON);
            btnClearFolder.setTooltipText(_("Clear folder"));
            btnClearFolder.addOnClicked(delegate(Button) {
                _folder = null;
                eFolder.setText("");
            });
            bPicker.add(btnClearFolder);
            bContent.add(bPicker);
        }

        stEditors = new Stack();
        stEditors.addOnNotify(delegate(ParamSpec, ObjectG) {
            updateUI();
            BaseEditor be = cast(BaseEditor)stEditors.getVisibleChild();
            if (be !is null) {
                be.focusEditor();
            }
        },"visible-child", ConnectFlags.AFTER);

        // Adding a new bookmark or editing one?
        if (mode == BookmarkEditorMode.EDIT) {
            // Add only the editor we need to edit this one bookmark
            stEditors.addTitled(createTypeEditor(bm.type, bm), to!string(bm.type), bmMgr.localize(bm.type));
        } else {
            //Add all editors
            foreach(bt; EnumMembers!BookmarkType) {
                BaseEditor be = createTypeEditor(bt, bm);
                be.onValidChanged.connect(&validateChanged);
                stEditors.addTitled(be, to!string(bt), bmMgr.localize(bt));
            }
            ssEditors = new StackSwitcher();
            ssEditors.setMarginBottom(12);
            ssEditors.setStack(stEditors);
            if (bm !is null) {
                // Need to show here for visible name to work
                stEditors.showAll();
                stEditors.setVisibleChildName(to!string(bm.type));
            }
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

    this(Window parent, BookmarkEditorMode mode, Bookmark bm = null, bool folderPicker = false) {
        string title = (mode == BookmarkEditorMode.ADD)? _("Add Bookmark"):_("Edit Bookmark");
        super(title, parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("OK"), _("Cancel")], [GtkResponseType.OK, GtkResponseType.CANCEL]);
        setTransientFor(parent);
        setDefaultResponse(GtkResponseType.OK);
        this.mode = mode;
        createUI(bm, folderPicker);
        this.addOnShow(delegate(Widget) {
            BaseEditor be = cast(BaseEditor)stEditors.getVisibleChild();
            be.focusEditor();
        });
    }

    /**
     * Creates the type of bookmark associated with the current editor
     * and populates it from the editor. Used primarily when adding a bookmark.
     */
    Bookmark create() {
        BookmarkType type = to!BookmarkType(stEditors.getVisibleChildName());
        Bookmark bm = bmMgr.createBookmark(type);
        BaseEditor editor = cast(BaseEditor)stEditors.getVisibleChild();
        editor.update(bm);
        return bm;
    }

    /**
     * Update a bookmark with the values from the current editor. Used
     * editing a bookmark.
     */
    void update(Bookmark bm) {
        BaseEditor editor = to!(BaseEditor)(stEditors.getVisibleChild());
        editor.update(bm);
    }

    @property FolderBookmark folder() {
        if (_folder is null) return bmMgr.root;
        else return _folder;
    }

    @property void folder(FolderBookmark fb) {
        if (eFolder !is null) {
            _folder = fb;
            eFolder.setText(fb.name);
        }
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
            return new CommandEditor(bm);
        case BookmarkType.REMOTE:
            return new RemoteEditor(bm);
    }
}

abstract class BaseEditor: Grid {
private:
    Entry eName;

protected:
    int row = 0;

    Label createLabel(string text) {
        Label result = new Label(text);
        result.setHalign(Align.END);
        return result;
    }

public:

    this(Bookmark bm) {
        super();
        setColumnSpacing(12);
        setRowSpacing(6);

        attach(createLabel(_("Name")), 0, row, 1, 1);

        eName = new Entry();
        eName.setHexpand(true);
        eName.addOnChanged(delegate(EditableIF) {
            onValidChanged.emit(this, validate);
        });
        attach(eName, 1, row, 1, 1);
        row++;

        if (bm !is null && bm.name.length > 0) {
            eName.setText(bm.name);
        }
    }

    void focusEditor() {
        eName.grabFocus();
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
        if (eName !is null) {
            return eName.getText().length > 0;
        } else {
            return false;
        }
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

        attach(createLabel(_("Path")), 0, row, 1, 1);

        fcbPath = new FileChooserButton(_("Select Path"), FileChooserAction.SELECT_FOLDER);
        fcbPath.setHexpand(true);
        fcbPath.setFilename(Util.getHomeDir());
        attach(fcbPath, 1, row, 1, 1);
        row++;

        if (bm !is null) {
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
        if (fcbPath !is null) {
            return super.validate() && (fcbPath.getFilename().length > 0);
        } else {
            return false;
        }
    }
}

class CommandEditor: BaseEditor {
private:
    Entry eCommand;

public:
    this(Bookmark bm) {
        super(bm);

        attach(createLabel(_("Command")), 0, row, 1, 1);

        eCommand = new Entry();
        eCommand.addOnChanged(delegate(EditableIF) {
            onValidChanged.emit(this, validate);
        });
        eCommand.setHexpand(true);
        attach(eCommand, 1, row, 1, 1);
        row++;

        if (bm !is null) {
            CommandBookmark cb = cast(CommandBookmark) bm;
            if (cb !is null && cb.command.length > 0) {
                eCommand.setText(cb.command);
            }
        }
    }

    override void update(Bookmark bm) {
        super.update(bm);
        CommandBookmark cb = cast(CommandBookmark) bm;
        if (cb !is null) {
            cb.command = eCommand.getText();
        }
    }

    override bool validate() {
        if (eCommand !is null) {
            return super.validate() && (eCommand.getText().length > 0);
        } else {
            return false;
        }
    }
}

class RemoteEditor: BaseEditor {
private:
    Entry eHost;
    SpinButton sPort;
    Entry eUser;
    Entry eParams;
    ComboBox cbProtocol;
    Entry eCommand;

public:
    this(Bookmark bm) {
        super(bm);

        // Protocol
        attach(createLabel(_("Protocol")), 0, row, 1, 1);

        string[string] protocols;
        foreach(protocol; EnumMembers!ProtocolType) {
            protocols[to!string(protocol)] = to!string(protocol);
        }

        cbProtocol = createNameValueCombo(protocols);
        cbProtocol.setActiveId(to!string(ProtocolType.SSH));
        cbProtocol.addOnChanged(delegate(ComboBox) {
            eCommand.setSensitive(cbProtocol.getActiveId() == to!string(ProtocolType.SSH));
        });
        attach(cbProtocol, 1, row, 1, 1);
        row++;

        // Host and Port
        attach(createLabel(_("Host")), 0, row, 1, 1);
        Box bHost = new Box(Orientation.HORIZONTAL, 6);
        eHost = new Entry();
        eHost.addOnChanged(delegate(EditableIF) {
            onValidChanged.emit(this, validate);
        });
        eHost.setHexpand(true);
        bHost.add(eHost);
        bHost.add(new Label(":"));
        sPort = new SpinButton(0, 65535, 1);
        sPort.setValue(0);
        bHost.add(sPort);
        attach(bHost, 1, row, 1, 1);
        row++;

        // User
        attach(createLabel(_("User")), 0, row, 1, 1);
        eUser = new Entry();
        eUser.setHexpand(true);
        attach(eUser, 1, row, 1, 1);
        row++;

        //Params
        attach(createLabel(_("Parameters")), 0, row, 1, 1);
        eParams = new Entry();
        eParams.setHexpand(true);
        attach(eParams, 1, row, 1, 1);
        row++;

        //Command
        attach(createLabel(_("Command")), 0, row, 1, 1);
        eCommand = new Entry();
        eCommand.setHexpand(true);
        attach(eCommand, 1, row, 1, 1);
        row++;

        if (bm !is null) {
            RemoteBookmark rb = cast(RemoteBookmark) bm;
            if (rb !is null) {
                cbProtocol.setActiveId(to!string(rb.protocolType));
                if (rb.host.length > 0) {
                    eHost.setText(rb.host);
                }
                sPort.setValue(rb.port);
                if (rb.user.length > 0) {
                    eUser.setText(rb.user);
                }
                if (rb.params.length > 0) {
                    eParams.setText(rb.params);
                }
                if (rb.command.length > 0) {
                    eCommand.setText(rb.command);
                }
            }
        }
    }

    override void update(Bookmark bm) {
        super.update(bm);
        RemoteBookmark rb = cast(RemoteBookmark) bm;
        if (rb !is null) {
            rb.host = eHost.getText();
            rb.port = sPort.getValueAsInt();
            rb.user = eUser.getText();
            rb.params = eParams.getText();
            rb.command = eCommand.getText();
        }
    }

    override bool validate() {
        if (eHost !is null) {
            return super.validate() && (eHost.getText().length > 0);
        } else {
            return false;
        }
    }
}
