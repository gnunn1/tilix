/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.sidebar;

import std.conv;
import std.format;
import std.experimental.logger;

import gdk.Event;
import gdk.Keysyms;

import gio.Settings : GSettings = Settings;

import gtk.Adjustment;
import gtk.AspectFrame;
import gtk.Box;
import gtk.Button;
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
import gtk.Widget;

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

    bool onButtonPress(Event event, Widget w) {
        trace("** Sidebar button press");
        //If button press happened outside of sidebar close it
        if (event.getWindow() !is null && lbSessions.getWindow() !is null) {
            if (event.getWindow().getWindowStruct() != getWindow().getWindowStruct() && event.getWindow().getWindowStruct() != lbSessions.getWindow().getWindowStruct()) {
                notifySessionSelected(null);
            }
        }
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
}

private:

class SideBarRow : ListBoxRow {
private:
    string _sessionUUID;
    Label lblIndex;
    SideBar sidebar;

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
        add(overlay);

        btnClose.addOnClicked(delegate(Button) {
            sidebar.removeSession(_sessionUUID);
        });
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
