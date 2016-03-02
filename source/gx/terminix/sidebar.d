/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.sidebar;

import std.conv;
import std.format;
import std.experimental.logger;

import gdk.Event;
import gdk.Keysyms;

import gtk.AspectFrame;
import gtk.Box;
import gtk.EventBox;
import gtk.Frame;
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

import gx.terminix.common;
import gx.terminix.session;

/**
 * Event used when a session is selected, if no session is selected
 * null is returned indicating the sidebar should be closed.
 */
alias OnSessionSelected = void delegate(string sessionUUID);

/**
 * Provides the session selecting sidebar
 */
class SideBar : Revealer {
private:
    ListBox lbSessions;

    OnSessionSelected[] sessionSelectedDelegates;

    bool blockSelectedHandler;

    void onRowActivated(ListBoxRow row, ListBox) {
        SideBarRow sr = cast(SideBarRow) row;
        if (sr !is null && !blockSelectedHandler) {
            notifySessionSelected(sr.sessionUUID);
        }
    }

    void notifySessionSelected(string sessionUUID) {
        foreach (sessionSelected; sessionSelectedDelegates) {
            sessionSelected(sessionUUID);
        }
    }

    bool onButtonPress(Event event, Widget w) {
        //If button press happened outside of sidebar close it
        if (event.getWindow().getWindowStruct() != getWindow().getWindowStruct() && event.getWindow().getWindowStruct() != lbSessions.getWindow().getWindowStruct()) {
            notifySessionSelected(null);
        }
        return false;
    }

    bool onKeyRelease(Event event, Widget w) {
        uint keyval;
        //If escape key is pressed, close sidebar
        if (event.getKeyval(keyval)) {
            switch (keyval) {
            case GdkKeysyms.GDK_Escape:
                notifySessionSelected(null);
                break;
            default:
                //Ignore other keys    
            }
        }
        return false;
    }

public:
    this() {
        super();
        addOnButtonPress(&onButtonPress);
        addOnKeyRelease(&onKeyRelease);
        setTransitionType(RevealerTransitionType.SLIDE_RIGHT);
        setHexpand(false);
        setVexpand(true);
        setHalign(Align.START);
        setValign(Align.FILL);

        lbSessions = new ListBox();
        lbSessions.setCanFocus(true);
        lbSessions.setSelectionMode(SelectionMode.BROWSE);
        lbSessions.getStyleContext().addClass("notebook");
        lbSessions.getStyleContext().addClass("header");
        lbSessions.addOnRowActivated(&onRowActivated);

        ScrolledWindow sw = new ScrolledWindow(lbSessions);
        sw.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sw.setShadowType(ShadowType.IN);

        add(sw);
    }

    void populateSessions(Session[] sessions, string currentSessionUUID, SessionNotification[string] notifications, int width, int height) {

        AspectFrame wrapWidget(Widget widget, string cssClass) {
            AspectFrame af = new AspectFrame(null, 0.5, 0.5, 1.0, false);
            af.setShadowType(ShadowType.NONE);
            af.getStyleContext().addClass(cssClass);
            af.add(widget);
            return af;
        }

        trace("Populating sidebar sessions");
        blockSelectedHandler = true;
        scope (exit) {
            blockSelectedHandler = false;
        }
        lbSessions.removeAll();
        foreach (i, session; sessions) {
            Overlay overlay = new Overlay();
            setAllMargins(overlay, 2);
            Frame imgframe = new Frame(new Image(getWidgetImage(session.drawable, 0.20, width, height)), null);
            imgframe.setShadowType(ShadowType.IN);
            overlay.add(imgframe);
            Box b = new Box(Orientation.HORIZONTAL, 4);
            b.setHalign(Align.FILL);
            b.setValign(Align.END);

            if (session.sessionUUID in notifications) {
                SessionNotification sn = notifications[session.sessionUUID];
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
                AspectFrame af = wrapWidget(ev, "terminix-notification-count");
                ev.setTooltipText(tooltip);
                b.packStart(af, false, false, 4);
            }

            Label lblIndex = new Label(format("%d", (i+1)));
            setAllMargins(lblIndex, 4);
            lblIndex.setWidthChars(2);
            b.packEnd(wrapWidget(lblIndex, "terminix-session-index"), false, false, 4);
            setAllMargins(b, 4);
            overlay.addOverlay(b);
            SideBarRow row = new SideBarRow(session.sessionUUID);
            row.add(overlay);
            lbSessions.add(row);
            if (session.sessionUUID == currentSessionUUID) {
                lbSessions.selectRow(row);
            }
        }
        lbSessions.showAll();
    }

    override void setRevealChild(bool revealChild) {
        super.setRevealChild(revealChild);
        if (revealChild) {
            trace("Show sidebar");
            grabAdd();
        } else {
            trace("Hide sidebar");
            grabRemove();
        }
        lbSessions.getSelectedRow().grabFocus();
    }

    void addOnSessionSelected(OnSessionSelected dlg) {
        sessionSelectedDelegates ~= dlg;
    }

    void removeOnSessionSelected(OnSessionSelected dlg) {
        gx.util.array.remove(sessionSelectedDelegates, dlg);
    }
}

private:

class SideBarRow : ListBoxRow {
private:
    string _sessionUUID;

public:
    this(string sessionUUID) {
        super();
        _sessionUUID = sessionUUID;
    }

    @property string sessionUUID() {
        return _sessionUUID;
    }
}
