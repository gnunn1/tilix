/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.closedialog;

import std.experimental.logger;
import std.format;
import std.typecons : Yes;

import gdkpixbuf.pixbuf : Pixbuf;

import gdk.event : Event;
import gdk.event_key : EventKey;

import gio.settings : GSettings = Settings;

import gobject.c.types : GType;
import gobject.value : Value;

import gtk.box : Box;
import gtk.cell_renderer_pixbuf : CellRendererPixbuf;
import gtk.cell_renderer_text : CellRendererText;
import gtk.check_button : CheckButton;
import gtk.dialog : Dialog;
import gtk.icon_info : IconInfo;
import gtk.icon_theme : IconTheme;
import gtk.label : Label;
import gtk.scrolled_window : ScrolledWindow;
import gtk.tree_iter : TreeIter;
import gtk.tree_store : TreeStore;
import gtk.tree_view : TreeView;
import gtk.tree_view_column : TreeViewColumn;
import gtk.types : Align, DialogFlags, ResponseType, IconLookupFlags, Orientation, PolicyType, ShadowType;
import pango.types : EllipsizeMode;
import gtk.widget : Widget;
import gtk.window : Window;

// GID does not provide gdk.keysyms, so define the required key constants locally
private enum GdkKeysyms {
    GDK_Escape = 0xff1b,
    GDK_Return = 0xff0d,
}

import gx.i18n.l10n;
import gx.gtk.util : GTypes, setAllMargins;

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
    if (result == ResponseType.Ok && dialog.futureIgnore) {
        gsSettings.setBoolean(SETTINGS_PROMPT_ON_CLOSE_PROCESS_KEY, false);
    }

    // Weird looking code, exists because of the way hotkeys get interpreted into results, it's
    // easier to check if the result is not OK
    bool cancelClose = (result != ResponseType.Ok);
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
        Box box = new Box(Orientation.Vertical, 6);

        Label lbl = new Label("There are processes still running as shown below, close anyway?");
        lbl.setHalign(Align.Start);
        lbl.setMarginBottom(6);
        box.add(lbl);

        ts = TreeStore.new_([GTypes.STRING, Pixbuf._getGType(), GTypes.STRING]);
        loadProcesses();
        tv = new TreeView();
        tv.setModel(ts);
        tv.connectKeyReleaseEvent(delegate(EventKey event, Widget w) {
            uint keyval = event.keyval;
            switch (keyval) {
                case GdkKeysyms.GDK_Escape:
                    response(ResponseType.Cancel);
                    break;
                case GdkKeysyms.GDK_Return:
                    response(ResponseType.Ok);
                    break;
                default:
            }
            return false;
        });
        tv.setHeadersVisible(false);

        CellRendererText crt = new CellRendererText();
        crt.setProperty("ellipsize", new Value(EllipsizeMode.End));

        TreeViewColumn column = new TreeViewColumn();
        column.setTitle(_("Title"));
        column.packStart(crt, true);
        column.addAttribute(crt, "text", cast(int)COLUMNS.NAME);
        column.setExpand(true);
        tv.appendColumn(column);

        CellRendererPixbuf crp = new CellRendererPixbuf();
        crp.setProperty("stock-size", 16);
        column = new TreeViewColumn();
        column.setTitle(_("Icon"));
        column.packStart(crp, true);
        column.addAttribute(crp, "pixbuf", cast(int)COLUMNS.ICON);
        column.setExpand(true);
        tv.appendColumn(column);

        ScrolledWindow sw = new ScrolledWindow(null, null);
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
        TreeIter current;
        ts.append(current, parent);
        if (pi.source == ProcessInfoSource.TERMINAL) {
            ts.setValue(current, cast(int)COLUMNS.ICON, new Value(pbTerminal));
        }
        switch (pi.source) {
            case ProcessInfoSource.WINDOW:
                ts.setValue(current, cast(int)COLUMNS.NAME, new Value(format(_("Window (%s)"), pi.description)));
                break;
            case ProcessInfoSource.SESSION:
                ts.setValue(current, cast(int)COLUMNS.NAME, new Value(format(_("Session (%s)"), pi.description)));
                break;
            default:
                ts.setValue(current, cast(int)COLUMNS.NAME, new Value(pi.description));
                break;
        }
        ts.setValue(current, cast(int)COLUMNS.UUID, new Value(pi.uuid));

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
        addButton(_("Cancel"), ResponseType.Cancel);
        addButton(_("OK"), ResponseType.Ok);
        this.processes = processes;
        setDefaultResponse(ResponseType.Ok);
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
