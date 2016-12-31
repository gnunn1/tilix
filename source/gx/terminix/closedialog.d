/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.closedialog;

import std.experimental.logger;
import std.format;

import gdkpixbuf.Pixbuf;

import gdk.Event;
import gdk.Keysyms;

import gtk.Box;
import gtk.CellRendererPixbuf;
import gtk.CellRendererText;
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

import gx.terminix.common;

public:

/**
 * Prompts the user to confirm that processes can be closed
 */
bool promptCanCloseProcesses(Window window, ProcessInformation pi) {
    CloseDialog dialog = new CloseDialog(window, pi);
    scope(exit) { dialog.destroy();}
    dialog.showAll();
    bool cancelClose = (dialog.run() != ResponseType.OK);
    return !cancelClose;
}

private:

/**
 * Dialog that is used to close object when running processes are detected
 */
class CloseDialog: Dialog {

private:
    ProcessInformation processes;

    TreeStore ts;
    TreeView tv;

    Pixbuf pbTerminal;

    void createUI() {
        // Create icons
        IconTheme iconTheme = new IconTheme();
        IconInfo iconInfo = iconTheme.lookupIcon("utilities-terminal", IconSize.BUTTON, cast(IconLookupFlags) 0);
        pbTerminal = iconInfo.loadIcon();
        tracef("Pixbuf width,height = %d,%d", pbTerminal.getWidth(), pbTerminal.getHeight());

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

        TreeViewColumn column = new TreeViewColumn(_("Title"), new CellRendererText(), "text", COLUMNS.NAME);
        column.setExpand(true);
        tv.appendColumn(column);

        CellRendererPixbuf crp = new CellRendererPixbuf();
        crp.setProperty("stock-size", IconSize.BUTTON);
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

}

private:
    enum COLUMNS : uint {
        NAME = 0,
        ICON = 1,
        UUID = 2
    }
