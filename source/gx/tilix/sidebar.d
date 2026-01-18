/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.sidebar;

import std.algorithm;
import std.conv;
import std.format;
import std.experimental.logger;

import gdk.atom : Atom;
import gdk.drag_context : DragContext;
import gdk.event : Event;
import gdk.event_button : EventButton;
import gdk.event_key : EventKey;
import gdk.screen : Screen;
import gdk.window : GdkWindow = Window;

import gdkpixbuf.pixbuf : Pixbuf;

import gio.settings : GSettings = Settings;

import glib.c.types : gulong;

import gobject.global : signalHandlerDisconnect;

import gtk.adjustment : Adjustment;
import gtk.aspect_frame : AspectFrame;
import gtk.box : Box;
import gtk.button : Button;
import gtk.global : dragSetIconWidget;
import gtk.event_box : EventBox;
import gtk.frame : Frame;
import gtk.grid : Grid;
import gtk.image : Image;
import gtk.label : Label;
import gtk.list_box : ListBox;
import gtk.list_box_row : ListBoxRow;
import gtk.overlay : Overlay;
import gtk.revealer : Revealer;
import gtk.scrolled_window : ScrolledWindow;
import gtk.selection_data : SelectionData;
import gtk.target_entry : TargetEntry;
import gtk.types : DestDefaults, Align, IconSize, Orientation, PolicyType, ReliefStyle, RevealerTransitionType, SelectionMode, ShadowType, TargetFlags;
import gtk.c.types : GtkDragResult, GtkWindowType;
import gdk.types : DragAction, ModifierType;
import gdk.c.types : GdkModifierType;
import gid.gid : No, Yes;
import pango.types : EllipsizeMode;
import gtk.widget : Widget;
import gtk.window : Window;

// GID does not provide gdk.keysyms, so define the required key constants locally
private enum GdkKeysyms {
    GDK_Escape = 0xff1b,
    GDK_Page_Up = 0xff55,
    GDK_Page_Down = 0xff56,
    GDK_0 = 0x030,
    GDK_9 = 0x039,
}

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

    bool onButtonPress(EventButton event) {
        trace("** Sidebar button press");
        if (event is null) return false;
        // If button press happened outside of sidebar close it
        // Modified since DND uses eventbox so additional windows in play
        GdkWindow eventWindow = event.window;
        GdkWindow lbWindow = lbSessions.getWindow();
        if (eventWindow !is null && lbWindow !is null) {
            if (eventWindow is getWindow() || eventWindow is lbWindow) {
                return false;
            }
            GdkWindow[] windows = lbWindow.getChildren();
            foreach(w; windows) {
                if (eventWindow is w) {
                    return false;
                }
            }
        }
        trace("Close on button press");
        notifySessionSelected(null);
        return false;
    }

public:
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

    void addSession(Session session) {
        import gx.tilix.session : Session;
        if (session is null) return;
        // Create a new row for this session
        SideBarRow row = new SideBarRow(this, session, null, 200, 150);
        lbSessions.add(row);
        reindexSessions();
    }

    //Re-number the indexes, used after a delete
    void reindexSessions() {
        SideBarRow[] rows = gx.gtk.util.findChildren!SideBarRow(lbSessions, false);
        foreach(i, row; rows) {
            row.sessionIndex = i + 1;
        }
    }

    /**
     * Update the recent files list in the sidebar
     * Called when recent session files list changes
     */
    void updateRecentFiles(string[] recentFiles) {
        // TODO: Implement recent files UI update in sidebar
        // For now this is a stub to allow compilation
        trace("updateRecentFiles called with " ~ to!string(recentFiles.length) ~ " files");
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
            if (index == lbSessions.getChildren().length -1) {
                lbSessions.add(source);
            } else {
                lbSessions.insert(source, index + 1);
            }
        }
        reindexSessions();
        lbSessions.selectRow(source);
    }

    bool onKeyPress(EventKey event) {
        if (event is null) return false;
        uint keyval = event.keyval;
        auto state = event.state;
        switch (keyval) {
        case GdkKeysyms.GDK_Page_Up:
            if (state & ModifierType.ControlMask) {
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
            if (state & ModifierType.ControlMask) {
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
        return false;
    }

    bool onKeyRelease(EventKey event) {
        if (event is null) return false;
        uint keyval = event.keyval;
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
        return false;
    }

    /*
     * Attempt to wrap navigation when hitting edges, works but subsequent navigation becomes wonky
     */
    /*
    bool onKeyNavFailed(GtkDirectionType direction, Widget) {
        trace("OnKeyNavFailed called");
        SideBarRow[] rows = gx.gtk.util.findChildren!(SideBarRow)(lbSessions, false);
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
        SideBarRow[] rows = gx.gtk.util.findChildren!SideBarRow(lbSessions, false);
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

        gsSettings = new GSettings(SETTINGS_ID);
        gsSettings.connectChanged(null, delegate(string key) {
            if (key == SETTINGS_SIDEBAR_RIGHT) {
                setSidebarPosition();
            }
        });

        connectButtonPressEvent(delegate(EventButton event) {
            return onButtonPress(event);
        });
        connectKeyReleaseEvent(delegate(EventKey event) {
            return onKeyRelease(event);
        });
        connectKeyPressEvent(delegate(EventKey event) {
            return onKeyPress(event);
        });

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

        sw.connectUnmap(delegate() {
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
                if (value + increment > adj.getValue() + adj.getPageSize) {
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

        SideBarRow[] rows = gx.gtk.util.findChildren!SideBarRow(lbSessions, false);

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

    void reveal(bool revealChild) {
        setRevealChild(revealChild);
    }

    void showSessionSwitcher() {
        setRevealChild(true);
    }

    void updateNotifications(SessionNotification[string] notifications) {
        // Update notification badges for sessions
        // Placeholder implementation
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

    /**
     * Event when a session file is selected from recent files
     */
    GenericEvent!(string) onFileSelected;

    /**
     * Event when a session file should be removed from recent files
     */
    GenericEvent!(string) onFileRemoved;

    /**
     * Event when a session is selected to be opened
     */
    GenericEvent!(string) onOpenSelected;

    /**
     * Event when a session should be attached
     */
    GenericEvent!(string) onSessionAttach;

    /**
     * Event that requests session reorder
     */
    GenericEvent!(string, string, bool, CumulativeResult!bool) onSessionReorder;
}

private:

class SideBarRow : ListBoxRow {
private:
    string _sessionUUID;
    Label lblIndex;
    SideBar sidebar;
    Window dragImage;
    EventBox eb;
    Button btnClose;
    Image img;
    Label lblName;
    Label lblNCount;
    EventBox evNotification;
    AspectFrame afNotification;

    gulong[] ebEventHandlerId;
    gulong closeButtonHandler;

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
        Pixbuf pb = getWidgetImage(session.drawable, 0.20, width, height);
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
        Box b = new Box(Orientation.Horizontal, 4);
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
        btnClose = Button.newFromIconName("window-close-symbolic", IconSize.Menu);
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
        TargetEntry[] targets = [new TargetEntry(SESSION_DND, TargetFlags.SameApp, 0)];
        eb.dragSourceSet(ModifierType.Button1Mask, targets, DragAction.Move);
        eb.dragDestSet(DestDefaults.All, targets, DragAction.Move);
        ebEventHandlerId ~= eb.connectDragDataGet(&onRowDragDataGet);
        ebEventHandlerId ~= eb.connectDragDataReceived(&onRowDragDataReceived);
        ebEventHandlerId ~= eb.connectDragBegin(&onRowDragBegin);
        ebEventHandlerId ~= eb.connectDragEnd(&onRowDragEnd);
        ebEventHandlerId ~= eb.connectDragFailed(&onRowDragFailed);

        add(eb);

        closeButtonHandler = btnClose.connectClicked(delegate() {
            if (sidebar !is null) sidebar.removeSession(_sessionUUID);
        });
    }

    void updateUI(Session session, SessionNotification[string] notifications, int width, int height) {
        Pixbuf pb = getWidgetImage(session.drawable, 0.20, width, height);
        scope(exit) {
            pb.destroy();
        }
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

        dragImage = new Window(GtkWindowType.Popup);
        dragImage.add(image);
        dragSetIconWidget(dc, dragImage, 0, 0);
    }

    void onRowDragEnd(DragContext dc, Widget widget) {
        if (isRootWindow && sidebar.notifyIsActionAllowed(ActionType.DETACH_SESSION)) {
            detachSessionOnDrop(dc);
        }

        dragImage.destroy();
        dragImage = null;

        // Under Wayland needed to fix cursor sticking due to
        // GTK binding holding reference to GTK DragContext
        dc.destroy();
    }

    /**
     * Called when drag failed, used this to detach a session into a new window
     */
    bool onRowDragFailed(DragContext dc, GtkDragResult dr, Widget widget) {
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
        Atom targetAtom = data.getTarget();
        string atomName = targetAtom.name();
        if (atomName == "application/x-rootwindow-drop") {
            trace("onRowDragDataGet Root window drop");
            isRootWindow = true;
        } else {
            tracef("onRowDragDataGet atom: %s", atomName);
            isRootWindow = false;
        }
        ubyte[] buffer = cast(ubyte[])(sessionUUID ~ '\0').dup;
        data.set(Atom.intern(SESSION_DND, false), 8, buffer);

    }

    void onRowDragDataReceived(DragContext dc, int x, int y, SelectionData data, uint info, uint time, Widget widget) {
        ubyte[] rawData = data.getData();
        string sourceUUID = cast(string)(rawData[0 .. $ - 1]);
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
            signalHandlerDisconnect(eb, id);
        }
        signalHandlerDisconnect(btnClose, closeButtonHandler);
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