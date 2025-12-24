/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.sidebar;

import std.algorithm;
import std.conv;
import std.format;
import std.experimental.logger;
import std.typecons : Yes, No;

import gdk.atom;
import gdk.types;
import gdk.drag_context;
import gdk.types;
import gdk.event;
import gdk.event_button;
import gdk.event_key;
import gdk.types;
import gx.gtk.keys;
import gx.gtk.types;
import gdk.types;
import gdkpixbuf.pixbuf;
import gdk.screen;
import gdk.types;
import gdk.window;
alias Window = gdk.window.Window;

import gio.settings : Settings = Settings;

import gobject.global;
import gobject.types;
import pango.types;

import gtk.adjustment;
import gtk.types;
import gtk.aspect_frame;
import gtk.types;
import gtk.box;
import gtk.types;
import gtk.button;
import gtk.types;
import gtk.global;
import gtk.types;
import gtk.event_box;
import gtk.types;
import gtk.frame;
import gtk.types;
import gtk.grid;
import gtk.types;
import gtk.image;
import gtk.types;
import gtk.label;
import gtk.types;
import gtk.list_box;
import gtk.types;
import gtk.list_box_row;
import gtk.types;
import gtk.global;
import gtk.types;
import gtk.overlay;
import gtk.types;
import gtk.revealer;
import gtk.types;
import gtk.scrolled_window;
import gtk.types;
import gtk.selection_data;
import gtk.types;
import gtk.target_entry;
import gtk.types;
import gtk.widget;
import gtk.types;
import gtk.window;
import gtk.types;
import gtk.types;

import gx.gtk.cairo;
import gx.gtk.util;

import gx.i18n.l10n;

static import gx.util.array;
import gx.gtk.threads;

import gx.tilix.common;
import gx.tilix.preferences;
import gx.tilix.session;

/**
 * Provides the session selecting sidebar
 */
class SideBar : Revealer {
private:

    // mixin for managing is action allowed event delegates
    mixin IsActionAllowedHandler;

    Settings gsSettings;

    ListBox lbSessions;
    ScrolledWindow sw;

    bool blockSelectedHandler;

    void onRowActivated(ListBoxRow row, ListBox) {
        SideBarRow sr = cast(SideBarRow) row;
        if (sr !is null && !blockSelectedHandler) {
            notifySessionSelected(sr.sessionUUID);
        }
    }

    void notifySessionSelected(string sessionUUID) {
        onSelected.emit(sessionUUID);
    }

    void notifyRequestDetach(string sessionUUID, int x, int y) {
        onSessionDetach.emit(sessionUUID, x, y);
    }

    bool onButtonPress(EventButton event, Widget w) {
        trace("** Sidebar button press");
        // If button press happened outside of sidebar close it
        // Modified since DND uses eventbox so additional windows in play
        if (event.window !is null && lbSessions.getWindow() !is null) {
            if (event.window._cPtr(No.Dup) == getWindow()._cPtr(No.Dup) || event.window._cPtr(No.Dup) == lbSessions.getWindow()._cPtr(No.Dup)) {
                return false;
            }
            gdk.window.Window[] windows = lbSessions.getWindow().getChildren();
            foreach(window; windows) {
                if (event.window._cPtr(No.Dup) == window._cPtr(No.Dup)) {
                    return false;
                }
            }
        }
        trace("Close on button press");
        notifySessionSelected(null);
        return false;
    }

    void removeSession(string sessionUUID) {
        trace("Removing session " ~ sessionUUID);
        SideBarRow row = getRow(sessionUUID);
        if (row !is null) {
            CumulativeResult!bool result = new CumulativeResult!bool();
            onClose.emit(sessionUUID, result);
            // Don't close if listener indicates it didn't close the session
            if (result.isAnyResult(false)) return;
            lbSessions.remove(row);
            reindexSessions();
        } else {
            tracef("Row for sessionUUID %s not found", sessionUUID);
        }
    }

    //Re-number the indexes, used after a delete
    void reindexSessions() {
        SideBarRow[] rows = gx.gtk.util.getChildren!SideBarRow(lbSessions, false);
        foreach(i, row; rows) {
            row.sessionIndex = i + 1;
        }
    }

    void reorderSessions(string sourceUUID, string targetUUID, bool after = false) {
        if (sourceUUID == targetUUID) return;
        SideBarRow source = getRow(sourceUUID);
        SideBarRow target = getRow(targetUUID);
        if (source is null || target is null) {
            errorf("Unexpected error for DND, source or target row is null %s, %s", sourceUUID, targetUUID);
            return;
        }
        reorderSessions(source, target);
    }

    void reorderSessions(SideBarRow source, SideBarRow target, bool after = false) {
        if (source is null || target is null) {
            error("Unexpected error for DND, source or target row is null");
            return;
        }

        CumulativeResult!bool result = new CumulativeResult!bool();
        onRequestReorder.emit(source.sessionUUID, target.sessionUUID, after, result);
        if (result.isAnyResult(false)) return;

        lbSessions.unselectRow(source);
        lbSessions.remove(source);
        int index = target.getIndex();
        if (!after) {
            lbSessions.insert(source, index);
        } else {
            if (index == cast(int)lbSessions.getChildren().length - 1) {
                lbSessions.add(source);
            } else {
                lbSessions.insert(source, index + 1);
            }
        }
        reindexSessions();
        lbSessions.selectRow(source);
    }

    bool onKeyPress(EventKey event, Widget w) {
        uint keyval = event.keyval;
        switch (keyval) {
        case Keys.PageUp:
            if (event.state & gdk.types.ModifierType.ControlMask) {
                SideBarRow source = cast(SideBarRow)lbSessions.getSelectedRow();
                if (source is null) {
                    trace("No selected row");
                    return true;
                }
                int index = source.getIndex();
                if (index > 0) {
                    SideBarRow target = cast(SideBarRow)lbSessions.getRowAtIndex(index - 1);
                    reorderSessions(source, target);
                }
                return true;
            }
            break;
        case Keys.PageDown:
            if (event.state & gdk.types.ModifierType.ControlMask) {
                trace("Moving row down");
                SideBarRow source = cast(SideBarRow)lbSessions.getSelectedRow();
                if (source is null) {
                    trace("No selected row");
                    return true;
                }
                int index = source.getIndex();
                if (index < cast(int)lbSessions.getChildren().length - 1) {
                    SideBarRow target = cast(SideBarRow)lbSessions.getRowAtIndex(index + 1);
                    reorderSessions(source, target, true);
                }
                return true;
            }
            break;
        default:
            break;
        }
        return false;
    }

    bool onKeyRelease(EventKey event, Widget w) {
        uint keyval = event.keyval;
        switch (keyval) {
        //If escape key is pressed, close sidebar
        case Keys.Escape:
            notifySessionSelected(null);
            break;
        case Keys._0:
        case Keys._1:
        case Keys._2:
        case Keys._3:
        case Keys._4:
        case Keys._5:
        case Keys._6:
        case Keys._7:
        case Keys._8:
        case Keys._9:
            int num = keyval - Keys._0 - 1;
            if (num == -1) num = 9; // Keys._0 is 10th
            ListBoxRow row = lbSessions.getRowAtIndex(num);
            if (row !is null) {
                lbSessions.selectRow(row);
                SideBarRow sr = cast(SideBarRow) row;
                if (sr !is null && !blockSelectedHandler) {
                    notifySessionSelected(sr.sessionUUID);
                }
            }
            break;
        default:
            //Ignore other keys
        }
        return false;
    }

    /*
     * Attempt to wrap navigation when hitting edges, works but subsequent navigation becomes wonky
     */
    /*
    bool onKeyNavFailed(DirectionType direction, Widget) {
        trace("OnKeyNavFailed called");
        SideBarRow[] rows = gx.gtk.util.getChildren!(SideBarRow)(lbSessions, false);
        switch (direction) {
            case DirectionType.Down:
                if (lbSessions.getSelectedRow() == rows[rows.length - 1]) {
                    lbSessions.selectRow(rows[0]);
                    return false;
                }
                break;
            case DirectionType.Up:
                if (lbSessions.getSelectedRow() == rows[0]) {
                    lbSessions.selectRow(rows[rows.length - 1]);
                    return false;
                }
                break;
            default:
        }
        trace("OnKeyNavFailed fall through");
        return false;
    }
    */

    SideBarRow getRow(string sessionUUID) {
        SideBarRow[] rows = gx.gtk.util.getChildren!SideBarRow(lbSessions, false);
        foreach(row; rows) {
            if (row.sessionUUID == sessionUUID) {
                return row;
            }
        }
        return null;
    }

    void setSidebarPosition() {
        if (gsSettings.getBoolean(SETTINGS_SIDEBAR_RIGHT)) {
            setTransitionType(RevealerTransitionType.SlideLeft);
            setHalign(Align.End);
        } else {
            setTransitionType(RevealerTransitionType.SlideRight);
            setHalign(Align.Start);
        }
    }

public:
    this() {
        super();

        gsSettings = new Settings(SETTINGS_ID);
        gsSettings.connectChanged(null, delegate(string key, Settings s) {
            if (key == SETTINGS_SIDEBAR_RIGHT) {
                setSidebarPosition();
            }
        });

        connectButtonPressEvent(&onButtonPress);
        connectKeyReleaseEvent(&onKeyRelease);
        connectKeyPressEvent(&onKeyPress);

        setHexpand(false);
        setVexpand(true);
        setValign(Align.Fill);
        setSidebarPosition();

        lbSessions = new ListBox();
        lbSessions.setCanFocus(true);
        lbSessions.setSelectionMode(SelectionMode.Browse);
        lbSessions.getStyleContext().addClass("tilix-session-sidebar");
        lbSessions.connectRowActivated(&onRowActivated);
        //lbSessions.connectKeynavFailed(&onKeyNavFailed);

        sw = new ScrolledWindow();
        sw.add(lbSessions);
        sw.setPolicy(PolicyType.Never, PolicyType.Automatic);
        sw.setShadowType(ShadowType.In);

        sw.connectUnmap(delegate(Widget w) {
           if (hasGrab()) {
                grabRemove();
                trace("** Unmapped, Removing Sidebar Grab");
           }
            hide();
        });
        sw.connectMap(delegate(Widget w) {
            // Need to give some time for adjustment values to catch up
            threadsAddTimeoutDelegate(20, delegate() {
                //Make sure row is visible
                Adjustment adj = sw.getVadjustment();
                double increment = adj.getUpper() / lbSessions.getChildren().length;
                double value = lbSessions.getSelectedRow().getIndex() * increment;
                tracef("Adjustment Values: Lower=%f, Upper=%f, Value=%f, Row=%f", adj.getLower(), adj.getUpper(), adj.getValue(), value);
                if (value + increment > adj.getValue() + adj.getPageSize()) {
                    adj.setValue(value);
                }
                return false;
            });
        }, Yes.After);

        add(sw);
    }

    /**
     * Populate the ListBox with a list of rows that correspond to the sessions. The code here
     * tries to be smart and re-use existing rows when available and just update them as necessary.
     * If there are more rows then sessions they get removed and destroyed, if there are less rows then
     * sessions then new ones get added.
     */
    void populateSessions(Session[] sessions, string currentSessionUUID, SessionNotification[string] notifications, int width, int height) {
        trace("Populating sidebar sessions");
        blockSelectedHandler = true;
        scope (exit) {
            blockSelectedHandler = false;
        }

        SideBarRow[] rows = gx.gtk.util.getChildren!SideBarRow(lbSessions, false);

        ulong maxSessions = min(rows.length, sessions.length);
        for (size_t i; i < maxSessions; i++) {
            rows[i].updateUI(sessions[i], notifications, width, height);
            if (sessions[i].uuid == currentSessionUUID) {
                lbSessions.selectRow(rows[i]);
            }
        }

        if (rows.length > sessions.length) {
            for (size_t i = sessions.length; i < rows.length; i++ ) {
                SideBarRow row = rows[i];
                lbSessions.remove(row);

                // Releases sidebar reference so it can be GC'ed
                row.release();

                // Doesn't actually need the destroy but doesn't hurt
                // and provides extra layer of safety
                row.destroy();
            }
        } else {
            for (size_t i = rows.length; i < sessions.length; i++) {
                SideBarRow row = new SideBarRow(this, sessions[i], notifications, width, height);
                row.sessionIndex = i + 1;
                lbSessions.add(row);
                if (sessions[i].uuid == currentSessionUUID) {
                    lbSessions.selectRow(row);
                }
            }
        }
        lbSessions.showAll();
    }

    override void setRevealChild(bool revealChild) {
        super.setRevealChild(revealChild);
        if (revealChild) {
            trace("** Show sidebar");
            if (!hasGrab()) {
                grabAdd();
                trace("** Getting Sidebar Grab");
            }
            lbSessions.getSelectedRow().grabFocus();
        } else {
            trace("** Hide sidebar");
            if (hasGrab()) {
                grabRemove();
                trace("** Removing Sidebar Grab");
            }
        }
    }

    void selectSession(string sessionUUID) {
        SideBarRow row = getRow(sessionUUID);
        if (row !is null) {
            lbSessions.selectRow(row);
        }
    }

//Events
public:

    /**
    * Event used when a session is selected, if no session is selected
    * null is returned indicating the sidebar should be closed.
    *
    * Params
    *   sessionUUID = The session identifier
    */
    GenericEvent!(string) onSelected;

    /**
    * Event to request that the specified session be closed, returns
    * true if it was closed, false if not.
    *
    * Params:
    *   sessionUUID = The session identifier
    *   result = Whether the session was closed or not
    */
    GenericEvent!(string, CumulativeResult!bool) onClose;

    /**
     * Event that requests that two sessions be re-ordered, returns
     * true if the re-order was successful, false if not.
     *
     * Params:
     *   sourceUUID = The session that needs to be moved
     *   targetUUID = The target session to move in front of
     */
    GenericEvent!(string, string, bool, CumulativeResult!bool) onRequestReorder;

    /**
     * Event that is called when session requests detach from terminal
     *
     * Params:
     *   sessionUUID - Session to detach
     *   x, y - Coordinates where detach was requested
     */
    GenericEvent!(string, int, int) onSessionDetach;
}

private:

class SideBarRow : ListBoxRow {
private:
    string _sessionUUID;
    Label lblIndex;
    SideBar sidebar;
    gtk.window.Window dragImage;
    EventBox eb;
    Button btnClose;
    Image img;
    Label lblName;
    Label lblNCount;
    EventBox evNotification;
    AspectFrame afNotification;

    ulong[] ebEventHandlerId;
    ulong closeButtonHandler;

    bool isRootWindow = false;

    AspectFrame wrapWidget(Widget widget, string cssClass) {
        AspectFrame af = new AspectFrame(null, 0.5, 0.5, 1.0, false);
        af.setShadowType(ShadowType.None);
        if (cssClass.length > 0) {
            af.getStyleContext().addClass(cssClass);
        }
        af.add(widget);
        return af;
    }

    void createUI(Session session, SessionNotification[string] notifications, int width, int height) {
        Overlay overlay = new Overlay();
        setAllMargins(overlay, 2);
        gdkpixbuf.pixbuf.Pixbuf pb = getWidgetImage(session.drawable, 0.20, width, height);
        img = Image.newFromPixbuf(pb);
        scope(exit) {
            pb.destroy();
        }
        Frame imgframe = new Frame(null);
        imgframe.add(img);
        imgframe.setShadowType(ShadowType.In);
        overlay.add(imgframe);
        //Create Notification and Session Numbers
        Grid grid = new Grid();
        setAllMargins(grid, 4);

        // Label with notification count
        lblNCount = new Label("");
        lblNCount.setUseMarkup(true);
        lblNCount.setWidthChars(2);
        setAllMargins(lblNCount, 4);
        evNotification = new EventBox();
        evNotification.add(lblNCount);
        afNotification = wrapWidget(evNotification, "tilix-notification-count");
        afNotification.setNoShowAll(true);
        grid.attach(afNotification, 0, 2, 1, 1);

        Label leftSpacer = new Label("");
        leftSpacer.setWidthChars(2);
        grid.attach(wrapWidget(leftSpacer, null), 0, 1, 1, 1);

        Label midSpacer = new Label("");
        midSpacer.setHexpand(true);
        midSpacer.setVexpand(true);
        grid.attach(midSpacer, 1, 1, 1, 1);

        lblName = new Label("");
        lblName.setMarginLeft(2);
        lblName.setMarginRight(2);
        lblName.setEllipsize(EllipsizeMode.End);
        lblName.setHalign(Align.Center);
        lblName.setHexpand(true);
        lblName.setSensitive(false);
        lblName.getStyleContext().addClass("tilix-session-name");
        Box b = new Box(gtk.types.Orientation.Horizontal, 4);
        b.setHexpand(true);
        b.add(lblName);
        grid.attach(b, 1, 2, 1, 1);

        lblIndex = new Label(format("%d", 0));
        lblIndex.setValign(Align.End);
        lblIndex.setVexpand(false);
        setAllMargins(lblIndex, 4);
        lblIndex.setWidthChars(2);
        grid.attach(wrapWidget(lblIndex, "tilix-session-index"), 2, 2, 1, 1);

        //Add Close Button
        btnClose = new Button();
        btnClose.setImage(Image.newFromIconName("window-close-symbolic", IconSize.Menu));
        btnClose.getStyleContext().addClass("tilix-sidebar-close-button");
        btnClose.setTooltipText(_("Close"));
        btnClose.setRelief(ReliefStyle.None);
        btnClose.setFocusOnClick(false);
        grid.attach(btnClose, 2, 0, 1, 1);

        overlay.addOverlay(grid);

        //Setup drag and drop
        eb = new EventBox();
        eb.add(overlay);
        // Drag and Drop
        TargetEntry[] targets = [new TargetEntry(SESSION_DND, gtk.types.TargetFlags.SameApp, 0)];
        eb.dragSourceSet(gdk.types.ModifierType.Button1Mask, targets, gdk.types.DragAction.Move);
        eb.dragDestSet(DestDefaults.All, targets, gdk.types.DragAction.Move);
        ebEventHandlerId ~= eb.connectDragDataGet(&onRowDragDataGet);
        ebEventHandlerId ~= eb.connectDragDataReceived(&onRowDragDataReceived);
        ebEventHandlerId ~= eb.connectDragBegin(&onRowDragBegin);
        ebEventHandlerId ~= eb.connectDragEnd(&onRowDragEnd);
        ebEventHandlerId ~= eb.connectDragFailed(&onRowDragFailed);

        add(eb);

        closeButtonHandler = btnClose.connectClicked(delegate(Button b) {
            if (sidebar !is null) sidebar.removeSession(_sessionUUID);
        });
    }

    void updateUI(Session session, SessionNotification[string] notifications, int width, int height) {
        gdkpixbuf.pixbuf.Pixbuf pb = getWidgetImage(session.drawable, 0.20, width, height);
        img.setFromPixbuf(pb);
        // Fix #1637
        _sessionUUID = session.uuid;
        lblName.setText(session.displayName);
        if (session.uuid in notifications) {
            SessionNotification sn = notifications[session.uuid];
            lblNCount.setText(format("%d", sn.messages.length));
            string tooltip;
            foreach (j, message; sn.messages) {
                if (j > 0) {
                    tooltip ~= "\n\n";
                }
                tooltip ~= message._body;
            }
            evNotification.setTooltipText(tooltip);
            afNotification.show();
        } else {
            afNotification.hide();
        }
    }

    void onRowDragBegin(DragContext dc, Widget widget) {
        isRootWindow = false;
        Image image = Image.newFromPixbuf(getWidgetImage(this, 1.00));
        image.show();

        if (dragImage !is null) {
            trace("*** Destroying the previous dragImage");
            dragImage.destroy();
            dragImage = null;
        }

        dragImage = new gtk.window.Window(gtk.types.WindowType.Popup);
        dragImage.add(image);
        gtk.global.dragSetIconWidget(dc, dragImage, 0, 0);
    }

    void onRowDragEnd(DragContext dc, Widget widget) {
        if (isRootWindow && sidebar.notifyIsActionAllowed(ActionType.DETACH_SESSION)) {
            detachSessionOnDrop(dc);
        }

        dragImage.destroy();
        dragImage = null;

        // Under Wayland needed to fix cursor sticking due to
        // GtkD holding reference to GTK DragReference
        dc.destroy();
    }

    /**
     * Called when drag failed, used this to detach a session into a new window
     */
    bool onRowDragFailed(DragContext dc, DragResult dr, Widget widget) {
        trace("Drag Failed with ", dr);
        isRootWindow = false;
        //Only allow detach if whole hierarchy agrees (application, window, session)
        if (sidebar.notifyIsActionAllowed(ActionType.DETACH_SESSION)) {
            if (detachSessionOnDrop(dc)) return true;
        }
        return false;
    }

    bool detachSessionOnDrop(DragContext dc) {
        trace("Detaching session");
        Screen screen;
        int x, y;
        dc.getDevice().getPosition(screen, x, y);
        //Detach here
        sidebar.notifyRequestDetach(sessionUUID, x, y);
        return true;
    }

    void onRowDragDataGet(DragContext dc, SelectionData data, uint info, uint time, Widget widget) {
        Atom gdkAtom = data.getTarget();
        string name = gdkAtom.name();
        if (name == "application/x-rootwindow-drop") {
            trace("onRowDragDataGet Root window drop");
            isRootWindow = true;
        } else {
            tracef("onRowDragDataGet atom: %s", name);
            isRootWindow = false;
        }
        char[] buffer = (sessionUUID ~ '\0').dup;
        data.set(Atom.intern(SESSION_DND, false), 8, cast(ubyte[])buffer);

    }

    void onRowDragDataReceived(DragContext dc, int x, int y, SelectionData data, uint info, uint time, Widget widget) {
        string sourceUUID = to!string(cast(char[])data.getData());
        tracef("Session UUID %s dropped", sourceUUID);
        sidebar.reorderSessions(sourceUUID, sessionUUID);
    }

public:
    this(SideBar sidebar, Session session, SessionNotification[string] notifications, int width, int height) {
        super();
        this.sidebar = sidebar;
        _sessionUUID = session.uuid;
        createUI(session, notifications, width, height);
        updateUI(session, notifications, width, height);
    }

    debug(Destructors) {
        ~this() {
            import std.stdio: writeln;
            writeln("******** SideBarRow Destructor");
        }
    }

    /**
     * Cleans up references so row can be GC'ed. There was an issue with
     * with the row holding the sidebar reference preventing it from being
     * garbage collected. We disconnect the event handlers that use that reference
     * and then set the reference to null.
     */
    public void release() {
        foreach(id; ebEventHandlerId) {
            gobject.global.signalHandlerDisconnect(eb, id);
        }
        gobject.global.signalHandlerDisconnect(btnClose, closeButtonHandler);
        this.sidebar = null;
    }

    public void update(Session session, SessionNotification[string] notifications, int width, int height) {
        _sessionUUID = session.uuid;
        updateUI(session, notifications, width, height);
    }

    @property string sessionUUID() {
        return _sessionUUID;
    }

    @property void sessionIndex(ulong value) {
        lblIndex.setText(to!string(value));
    }
}