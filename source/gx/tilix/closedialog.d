/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.closedialog;

import std.experimental.logger;
import std.format;

import gdkpixbuf.Pixbuf;

import gdk.Event;
import gdk.Keysyms;

import gio.Settings: GSettings = Settings;

import gobject.Value;

import gtk.Box;
import gtk.CellRendererPixbuf;
import gtk.CellRendererText;
import gtk.CheckButton;
import gtk.Dialog;
import gtk.IconInfo;
import gtk.IconTheme;
import gtk.Label;
import gtk.ScrolledWindow;
import gtk.TreeIter;
import gtk.TreeStore;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Window;

import gx.i18n.l10n;
import gx.gtk.util;

import gx.tilix.common;
import gx.tilix.preferences;

public:

/**
 * Prompts the user to confirm that processes can be closed
 */
bool promptCanCloseProcesses(GSettings gsSettings, Window window, ProcessInformation pi) {
    if (!gsSettings.getBoolean(SETTINGS_PROMPT_ON_CLOSE_PROCESS_KEY)) return true;

    CloseDialog dialog = new CloseDialog(window, pi);
    scope(exit) { dialog.destroy();}
    dialog.showAll();
    int result =  dialog.run();
    if (result == ResponseType.OK && dialog.futureIgnore) {
        gsSettings.setBoolean(SETTINGS_PROMPT_ON_CLOSE_PROCESS_KEY, false);
    }

    // Weird looking code, exists because of the way hotkeys get interpreted into results, it's
    // easier to check if the result is not OK
    bool cancelClose = (result != ResponseType.OK);
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

    Pixbuf pbTerminal;

    void createUI() {
        // Create icons
        IconTheme iconTheme = new IconTheme();
        IconInfo iconInfo = iconTheme.lookupIcon("utilities-terminal", 16, cast(IconLookupFlags) 0);
        if (iconInfo !is null) {
            pbTerminal = iconInfo.loadIcon();
            tracef("Pixbuf width,height = %d,%d", pbTerminal.getWidth(), pbTerminal.getHeight());
        } else {
            warning("Could not load icon for 'utilities-terminal'");
        }
        setAllMargins(getContentArea(), 18);
        Box box = new Box(Orientation.VERTICAL, 6);

        Label lbl = new Label("There are processes still running as shown below, close anyway?");
        lbl.setHalign(Align.START);
        lbl.setMarginBottom(6);
        box.add(lbl);

        ts = new TreeStore([GType.STRING, Pixbuf.getType(), GType.STRING]);
        loadProcesses();

        tv = new TreeView(ts);
        tv.addOnKeyRelease(delegate(Event event, Widget) {
            uint keyval;
            if (event.getKeyval(keyval)) {
                switch (keyval) {
                    case GdkKeysyms.GDK_Escape:
                        response(GtkResponseType.CANCEL);
                        break;
                    case GdkKeysyms.GDK_Return:
                        response(GtkResponseType.OK);
                        break;
                    default:
                }
            }
            return false;

        });
        tv.setHeadersVisible(false);

        CellRendererText crt = new CellRendererText();
        crt.setProperty("ellipsize", new Value(PangoEllipsizeMode.END));

        TreeViewColumn column = new TreeViewColumn(_("Title"), crt, "text", COLUMNS.NAME);
        column.setExpand(true);
        tv.appendColumn(column);

        CellRendererPixbuf crp = new CellRendererPixbuf();
        crp.setProperty("stock-size", 16);
        column = new TreeViewColumn(_("Icon"), crp, "pixbuf", COLUMNS.ICON);
        column.setExpand(true);
        tv.appendColumn(column);

        ScrolledWindow sw = new ScrolledWindow(tv);
        sw.setShadowType(ShadowType.ETCHED_IN);
        sw.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sw.setHexpand(true);
        sw.setVexpand(true);
        sw.setSizeRequest(-1, 300);

        box.add(sw);
        tv.expandAll();

        cbIgnore = new CheckButton(_("Do not show this again"));
        box.add(cbIgnore);

        getContentArea().add(box);
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
        TreeIter current = ts.createIter(parent);
        if (pi.source == ProcessInfoSource.TERMINAL) {
            ts.setValue(current, COLUMNS.ICON, pbTerminal);
        }
        switch (pi.source) {
            case ProcessInfoSource.WINDOW:
                ts.setValue(current, COLUMNS.NAME, format(_("Window (%s)"), pi.description));
                break;
            case ProcessInfoSource.SESSION:
                ts.setValue(current, COLUMNS.NAME, format(_("Session (%s)"), pi.description));
                break;
            default:
                ts.setValue(current, COLUMNS.NAME, pi.description);
                break;
        }
        ts.setValue(current, COLUMNS.UUID, pi.uuid);

        foreach(child; pi.children) {
            loadProcess(current, child);
        }
    }

public:

    this(Window parent, ProcessInformation processes) {
        this.processes = processes;
        string title;
        final switch (processes.source) {
            case ProcessInfoSource.APPLICATION:
                title = _("Close Application");
                break;
            case ProcessInfoSource.WINDOW:
                title = _("Close Window");
                break;
            case ProcessInfoSource.SESSION:
                title = _("Close Session");
                break;
            case ProcessInfoSource.TERMINAL:
                title = _("Close Session");
                break;
        }
        super(title, parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("OK"), _("Cancel")], [GtkResponseType.OK, GtkResponseType.CANCEL]);
        setDefaultResponse(GtkResponseType.OK);
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
