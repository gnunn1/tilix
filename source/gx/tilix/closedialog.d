/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.closedialog;

import std.experimental.logger;
import std.format;

import gdkpixbuf.pixbuf;

import gdk.event;
import gdk.event_key;
import gdk.types;
import gdk.types;

import gio.settings: Settings = Settings;

import gobject.value;
import gobject.types;

import gtk.box;
import gtk.types;
import gtk.cell_renderer_pixbuf;
import gtk.types;
import gtk.cell_renderer_text;
import gtk.types;
import gtk.check_button;
import gtk.types;
import gtk.dialog;
import gtk.types;
import gtk.icon_info;
import gtk.types;
import gtk.icon_theme;
import gtk.types;
import gtk.label;
import gtk.types;
import gtk.scrolled_window;
import gtk.types;
import gtk.tree_iter;
import gtk.types;
import gtk.tree_store;
import gtk.types;
import gtk.tree_view;
import gtk.types;
import gtk.tree_view_column;
import gtk.types;
import gtk.widget;
import gtk.window;
import gtk.types;

import pango.types;

import gx.gtk.keys;
import gx.i18n.l10n;
import gx.gtk.util;

import gx.tilix.common;
import gx.tilix.preferences;

public:

/**
 * Prompts the user to confirm that processes can be closed
 */
bool promptCanCloseProcesses(Settings gsSettings, Window window, ProcessInformation pi) {
    if (!gsSettings.getBoolean(SETTINGS_PROMPT_ON_CLOSE_PROCESS_KEY)) return true;

    CloseDialog dialog = new CloseDialog(window, pi);
    scope(exit) { dialog.destroy();}
    dialog.showAll();
    int result =  dialog.run();
    if (result == gtk.types.ResponseType.Ok && dialog.futureIgnore) {
        gsSettings.setBoolean(SETTINGS_PROMPT_ON_CLOSE_PROCESS_KEY, false);
    }

    // Weird looking code, exists because of the way hotkeys get interpreted into results, it's
    // easier to check if the result is not Ok
    bool cancelClose = (result != gtk.types.ResponseType.Ok);
    return !cancelClose;
}

private:

/**
 * Dialog that is used to close object when running processes are detected
 */
class CloseDialog: Dialog {

private:
    enum MAX_DESCRIPTION = 120;

    ProcessInformation processes;

    TreeStore ts;
    TreeView tv;
    CheckButton cbIgnore;

    gdkpixbuf.pixbuf.Pixbuf pbTerminal;

    void createUI() {
        // Create icons
        IconTheme iconTheme = IconTheme.getDefault();
        IconInfo iconInfo = iconTheme.lookupIcon("utilities-terminal", 16, cast(IconLookupFlags) 0);
        if (iconInfo !is null) {
            pbTerminal = iconInfo.loadIcon();
            tracef("gdkpixbuf.pixbuf.Pixbuf width,height = %d,%d", pbTerminal.getWidth(), pbTerminal.getHeight());
        } else {
            warning("Could not load icon for 'utilities-terminal'");
        }
        setAllMargins(getContentArea(), 18);
        Box box = new Box(gtk.types.Orientation.Vertical, 6);

        Label lbl = new Label("There are processes still running as shown below, close anyway?");
        lbl.setHalign(Align.Start);
        lbl.setMarginBottom(6);
        box.add(lbl);

        ts = TreeStore.new_([cast(GType)GTypeEnum.String, cast(GType)gdkpixbuf.pixbuf.Pixbuf._getGType(), cast(GType)GTypeEnum.String]);
        loadProcesses();

        tv = new TreeView();
        tv.setModel(ts);
        tv.connectKeyReleaseEvent(delegate(EventKey event, Widget w) {
            uint keyval = event.keyval;
            switch (keyval) {
                case Keys.Escape:
                    response(gtk.types.ResponseType.Cancel);
                    break;
                case Keys.Return:
                    response(gtk.types.ResponseType.Ok);
                    break;
                default:
            }
            return false;

        });
        tv.setHeadersVisible(false);

        CellRendererText crt = new CellRendererText();
        crt.setProperty("ellipsize", new Value(pango.types.EllipsizeMode.End));

        TreeViewColumn column = new TreeViewColumn();
        column.setTitle(_("Title"));
        column.packStart(crt, true);
        column.addAttribute(crt, "text", COLUMNS.NAME);
        column.setExpand(true);
        tv.appendColumn(column);

        CellRendererPixbuf crp = new CellRendererPixbuf();
        crp.setProperty("stock-size", new Value(16));
        column = new TreeViewColumn();
        column.setTitle(_("Icon"));
        column.packStart(crp, true);
        column.addAttribute(crp, "pixbuf", COLUMNS.ICON);
        column.setExpand(true);
        tv.appendColumn(column);

        ScrolledWindow sw = new ScrolledWindow();
        sw.add(tv);
        sw.setShadowType(ShadowType.EtchedIn);
        sw.setPolicy(PolicyType.Never, PolicyType.Automatic);
        sw.setHexpand(true);
        sw.setVexpand(true);
        sw.setSizeRequest(-1, 300);

        box.add(sw);
        tv.expandAll();

        cbIgnore = CheckButton.newWithLabel(_("Do not show this again"));
        box.add(cbIgnore);

        (cast(Box)getContentArea()).add(box);
    }

    /**
     * Load list of processes into treeview, never show Application
     * as root, just windows.
     */
    void loadProcesses() {
        if (processes.source == ProcessInfoSource.APPLICATION) {
            foreach(child; processes.children) {
                loadProcess(null, child);
            }
        } else {
            loadProcess(null, processes);
        }
    }

    void loadProcess(TreeIter parent, ProcessInformation pi) {
        TreeIter current;
        ts.append(current, parent);
        if (pi.source == ProcessInfoSource.TERMINAL) {
            ts.setValue(current, COLUMNS.ICON, new Value(pbTerminal));
        }
        switch (pi.source) {
            case ProcessInfoSource.WINDOW:
                ts.setValue(current, COLUMNS.NAME, new Value(format(_("Window (%s)"), pi.description)));
                break;
            case ProcessInfoSource.SESSION:
                ts.setValue(current, COLUMNS.NAME, new Value(format(_("Session (%s)"), pi.description)));
                break;
            default:
                ts.setValue(current, COLUMNS.NAME, new Value(pi.description));
                break;
        }
        ts.setValue(current, COLUMNS.UUID, new Value(pi.uuid));

        foreach(child; pi.children) {
            loadProcess(current, child);
        }
    }

    static string getTitle(ProcessInfoSource source) {
        final switch (source) {
            case ProcessInfoSource.APPLICATION:
                return _("Close Application");
            case ProcessInfoSource.WINDOW:
                return _("Close Window");
            case ProcessInfoSource.SESSION:
                return _("Close Session");
            case ProcessInfoSource.TERMINAL:
                return _("Close Session");
        }
    }

public:

    this(Window parent, ProcessInformation processes) {
        super();
        setTitle(getTitle(processes.source));
        setTransientFor(parent);
        setModal(true);
        addButton(_("Ok"), gtk.types.ResponseType.Ok);
        addButton(_("Cancel"), gtk.types.ResponseType.Cancel);
        this.processes = processes;
        setDefaultResponse(gtk.types.ResponseType.Ok);
        createUI();
    }

    @property bool futureIgnore() {
        return cbIgnore.getActive();
    }

}

private:
    enum COLUMNS : uint {
        NAME = 0,
        ICON = 1,
        UUID = 2
    }
