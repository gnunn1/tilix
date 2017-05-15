/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.sidebar;

import std.conv;
import std.format;
import std.experimental.logger;

import gdk.Atom;
import gdk.DragContext;
import gdk.Event;
import gdk.Keysyms;
import gdk.Screen;
import gdk.Window: GdkWindow = Window;

import gio.Settings : GSettings = Settings;

import gtk.Adjustment;
import gtk.AspectFrame;
import gtk.Box;
import gtk.Button;
import gtk.DragAndDrop;
import gtk.EventBox;
import gtk.Frame;
import gtk.Grid;
import gtk.Image;
import gtk.Label;
import gtk.ListBox;
import gtk.ListBoxRow;
import gtk.Main;
import gtk.Overlay;
import gtk.Revealer;
import gtk.ScrolledWindow;
import gtk.SelectionData;
import gtk.TargetEntry;
import gtk.Widget;
import gtk.Window;

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

    GSettings gsSettings;

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

    bool onButtonPress(Event event, Widget w) {
        trace("** Sidebar button press");
        // If button press happened outside of sidebar close it
        // Modified since DND uses eventbox so additional windows in play
        if (event.getWindow() !is null && lbSessions.getWindow() !is null) {
            if (event.getWindow().getWindowStruct() == getWindow().getWindowStruct() || event.getWindow().getWindowStruct() == lbSessions.getWindow().getWindowStruct()) {
                return false;
            }
            GdkWindow[] windows = lbSessions.getWindow().getChildren().toArray!GdkWindow();
            foreach(window; windows) {
                if (event.getWindow().getWindowStruct() == window.getWindowStruct()) {
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
            if (index == lbSessions.getChildren().length() -1) {
                lbSessions.add(source);
            } else {
                lbSessions.insert(source, index + 1);
            }
        }
        reindexSessions();
        lbSessions.selectRow(source);
    }

    bool onKeyPress(Event event, Widget w) {
        uint keyval;
        if (event.getKeyval(keyval)) {
            switch (keyval) {
            case GdkKeysyms.GDK_Page_Up:
                if (event.key.state & ModifierType.CONTROL_MASK) {
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
            case GdkKeysyms.GDK_Page_Down:
                if (event.key.state & ModifierType.CONTROL_MASK) {
                    trace("Moving row down");
                    SideBarRow source = cast(SideBarRow)lbSessions.getSelectedRow();
                    if (source is null) {
                        trace("No selected row");
                        return true;
                    }
                    int index = source.getIndex();
                    if (index < lbSessions.getChildren().length - 1) {
                        SideBarRow target = cast(SideBarRow)lbSessions.getRowAtIndex(index + 1);
                        reorderSessions(source, target, true);
                    }
                    return true;
                }
                break;
            default:
                break;
            }
        }
        return false;        
    }

    bool onKeyRelease(Event event, Widget w) {
        uint keyval;
        if (event.getKeyval(keyval)) {
            switch (keyval) {
            //If escape key is pressed, close sidebar
            case GdkKeysyms.GDK_Escape:
                notifySessionSelected(null);
                break;
            case GdkKeysyms.GDK_0:
            ..
            case GdkKeysyms.GDK_9:
                int num = keyval - GdkKeysyms.GDK_0 - 1;
                if (num == -1) num = 10;
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
        }
        return false;
    }

    /*
     * Attempt to wrap navigation when hitting edges, works but subsequent navigation becomes wonky
     */
    /*
    bool onKeyNavFailed(GtkDirectionType direction, Widget) {
        trace("OnKeyNavFailed called");
        SideBarRow[] rows = gx.gtk.util.getChildren!(SideBarRow)(lbSessions, false);
        switch (direction) {
            case GtkDirectionType.DOWN:
                if (lbSessions.getSelectedRow() == rows[rows.length - 1]) {
                    lbSessions.selectRow(rows[0]);
                    return false;
                }
                break;
            case GtkDirectionType.UP:
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
            setTransitionType(RevealerTransitionType.SLIDE_LEFT);
            setHalign(Align.END);
        } else {
            setTransitionType(RevealerTransitionType.SLIDE_RIGHT);
            setHalign(Align.START);
        }
    }

public:
    this() {
        super();

        gsSettings = new GSettings(SETTINGS_ID);
        gsSettings.addOnChanged(delegate(string key, GSettings) {
            if (key == SETTINGS_SIDEBAR_RIGHT) {
                setSidebarPosition();
            }
        });

        addOnButtonPress(&onButtonPress);
        addOnKeyRelease(&onKeyRelease);
        addOnKeyPress(&onKeyPress);

        setHexpand(false);
        setVexpand(true);
        setValign(Align.FILL);
        setSidebarPosition();

        lbSessions = new ListBox();
        lbSessions.setCanFocus(true);
        lbSessions.setSelectionMode(SelectionMode.BROWSE);
        lbSessions.getStyleContext().addClass("tilix-session-sidebar");
        lbSessions.addOnRowActivated(&onRowActivated);
        //lbSessions.addOnKeynavFailed(&onKeyNavFailed);

        sw = new ScrolledWindow(lbSessions);
        sw.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sw.setShadowType(ShadowType.IN);

        sw.addOnUnmap(delegate(Widget) {
           if (hasGrab()) {
                grabRemove();
                trace("** Unmapped, Removing Sidebar Grab");
           }
            hide();
        });
        sw.addOnMap(delegate(Widget) {
            // Need to give some time for adjustment values to catch up
            threadsAddTimeoutDelegate(20, delegate() {
                //Make sure row is visible
                Adjustment adj = sw.getVadjustment();
                double increment = adj.getUpper() / lbSessions.getChildren().length;
                double value = lbSessions.getSelectedRow().getIndex() * increment;
                tracef("Adjustment Values: Lower=%f, Upper=%f, Value=%f, Row=%f", adj.getLower(), adj.getUpper(), adj.getValue(), value);
                if (value + increment > adj.getValue() + adj.getPageSize) {
                    adj.setValue(value);
                }
                return false;
            });
        }, ConnectFlags.AFTER);

        add(sw);
    }

    void populateSessions(Session[] sessions, string currentSessionUUID, SessionNotification[string] notifications, int width, int height) {
        trace("Populating sidebar sessions");
        blockSelectedHandler = true;
        scope (exit) {
            blockSelectedHandler = false;
        }
        lbSessions.removeAll();
        foreach (i, session; sessions) {
            SideBarRow row = new SideBarRow(this, session, notifications, width, height);
            row.sessionIndex = i + 1;
            lbSessions.add(row);
            if (session.uuid == currentSessionUUID) {
                lbSessions.selectRow(row);
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
    Window dragImage;

    bool isRootWindow = false;

    AspectFrame wrapWidget(Widget widget, string cssClass) {
        AspectFrame af = new AspectFrame(null, 0.5, 0.5, 1.0, false);
        af.setShadowType(ShadowType.NONE);
        if (cssClass.length > 0) {
            af.getStyleContext().addClass(cssClass);
        }
        af.add(widget);
        return af;
    }

    void createUI(Session session, SessionNotification[string] notifications, int width, int height) {
        Overlay overlay = new Overlay();
        setAllMargins(overlay, 2);
        Frame imgframe = new Frame(new Image(getWidgetImage(session.drawable, 0.20, width, height)), null);
        imgframe.setShadowType(ShadowType.IN);
        overlay.add(imgframe);
        //Create Notification and Session Numbers
        Grid grid = new Grid();
        setAllMargins(grid, 4);

        if (session.uuid in notifications) {
            SessionNotification sn = notifications[session.uuid];
            Label lblNCount = new Label(format("%d", sn.messages.length));
            lblNCount.setUseMarkup(true);
            lblNCount.setWidthChars(2);
            string tooltip;
            foreach (j, message; sn.messages) {
                if (j > 0) {
                    tooltip ~= "\n\n";
                }
                tooltip ~= message._body;
            }
            setAllMargins(lblNCount, 4);
            EventBox ev = new EventBox();
            ev.add(lblNCount);
            AspectFrame af = wrapWidget(ev, "tilix-notification-count");
            ev.setTooltipText(tooltip);
            grid.attach(af, 0, 2, 1, 1);
        }

        Label leftSpacer = new Label("");
        leftSpacer.setWidthChars(2);
        grid.attach(wrapWidget(leftSpacer, null), 0, 1, 1, 1);

        Label midSpacer = new Label("");
        midSpacer.setHexpand(true);
        midSpacer.setVexpand(true);
        grid.attach(midSpacer, 1, 1, 1, 1);

        Label lblName = new Label(session.displayName);
        lblName.setMarginLeft(2);
        lblName.setMarginRight(2);
        lblName.setEllipsize(PangoEllipsizeMode.END);
        lblName.setHalign(Align.CENTER);
        lblName.setHexpand(true);
        lblName.setSensitive(false);
        lblName.getStyleContext().addClass("tilix-session-name");
        Box b = new Box(Orientation.HORIZONTAL, 4);
        b.setHexpand(true);
        b.add(lblName);
        grid.attach(b, 1, 2, 1, 1);

        lblIndex = new Label(format("%d", 0));
        lblIndex.setValign(Align.END);
        lblIndex.setVexpand(false);
        setAllMargins(lblIndex, 4);
        lblIndex.setWidthChars(2);
        grid.attach(wrapWidget(lblIndex, "tilix-session-index"), 2, 2, 1, 1);

        //Add Close Button
        Button btnClose = new Button("window-close-symbolic", IconSize.MENU);
        btnClose.getStyleContext().addClass("tilix-sidebar-close-button");
        btnClose.setTooltipText(_("Close"));
        btnClose.setRelief(ReliefStyle.NONE);
        btnClose.setFocusOnClick(false);
        grid.attach(btnClose, 2, 0, 1, 1);

        overlay.addOverlay(grid);

        //Setup drag and drop
        EventBox eb = new EventBox();
        eb.add(overlay);
        // Drag and Drop
        TargetEntry[] targets = [new TargetEntry(SESSION_DND, TargetFlags.SAME_APP, 0)];
        eb.dragSourceSet(ModifierType.BUTTON1_MASK, targets, DragAction.MOVE);
        eb.dragDestSet(DestDefaults.ALL, targets, DragAction.MOVE);
        eb.addOnDragDataGet(&onRowDragDataGet);
        eb.addOnDragDataReceived(&onRowDragDataReceived);
        eb.addOnDragBegin(&onRowDragBegin);
        eb.addOnDragEnd(&onRowDragEnd);
        eb.addOnDragFailed(&onRowDragFailed);

        add(eb);

        btnClose.addOnClicked(delegate(Button) {
            sidebar.removeSession(_sessionUUID);
        });
    }

    void onRowDragBegin(DragContext dc, Widget widget) {
        isRootWindow = false;
        Image image = new Image(getWidgetImage(this, 1.00));
        image.show();
        dragImage = new Window(GtkWindowType.POPUP);
        dragImage.add(image);
        DragAndDrop.dragSetIconWidget(dc, dragImage, 0, 0);
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
    bool onRowDragFailed(DragContext dc, GtkDragResult dr, Widget widget) {
        trace("Drag Failed with ", dr);
        isRootWindow = false;
        if (dr == GtkDragResult.NO_TARGET) {
            //Only allow detach if whole heirarchy agrees (application, window, session)
            if (sidebar.notifyIsActionAllowed(ActionType.DETACH_SESSION)) {
                if (detachSessionOnDrop(dc)) return true;
            }
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
        GdkAtom gdkAtom = data.getTarget();
        string name = gdk.Atom.name(gdkAtom);
        if (name == "application/x-rootwindow-drop") {
            trace("onRowDragDataGet Root window drop");
            isRootWindow = true;
        } else {
            tracef("onRowDragDataGet atom: %s", name);
            isRootWindow = false;
        }
        char[] buffer = (sessionUUID ~ '\0').dup;
        data.set(intern(SESSION_DND, false), 8, buffer);

    }

    void onRowDragDataReceived(DragContext dc, int x, int y, SelectionData data, uint info, uint time, Widget widget) {
        string sourceUUID = to!string(data.getDataWithLength()[0 .. $ - 1]);
        tracef("Session UUID %s dropped", sourceUUID);
        sidebar.reorderSessions(sourceUUID, sessionUUID);
    }

public:
    this(SideBar sidebar, Session session, SessionNotification[string] notifications, int width, int height) {
        super();
        this.sidebar = sidebar;
        _sessionUUID = session.uuid;
        createUI(session, notifications, width, height);
    }

    @property string sessionUUID() {
        return _sessionUUID;
    }

    @property void sessionIndex(ulong value) {
        lblIndex.setText(to!string(value));
    }
}
