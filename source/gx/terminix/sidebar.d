module gx.terminix.sidebar;

import std.conv;
import std.format;
import std.experimental.logger;

import gdk.Event;
import gdk.Keysyms;

import gtk.Box;
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

import gx.terminix.session;

/**
 * Event used when a session is selected, if no session is selected
 * null is returned indicating the sidebar should be closed.
 */
alias OnSessionSelected = void delegate(string sessionUUID);

/**
 * Provides the session selecting sidebar
 */ 
class SideBar: Revealer {
private:
    Frame frame;
    ListBox lbSessions;
    
    OnSessionSelected[] sessionSelectedDelegates;
    
    bool blockSelectedHandler;
    
    void onRowSelected(ListBoxRow row, ListBox) {
        SideBarRow sr = cast(SideBarRow) row;
        if (sr !is null && !blockSelectedHandler) {
            notifySessionSelected(sr.sessionUUID);
        }        
    }
    
    void notifySessionSelected(string sessionUUID) {
        foreach(sessionSelected; sessionSelectedDelegates) {
            sessionSelected(sessionUUID);
        }
    }
    
    bool onButtonPress(Event event, Widget w) {
        //If button press happened outside of sidebar close it
        if (event.getWindow().getWindowStruct() != frame.getWindow().getWindowStruct() &&
            event.getWindow().getWindowStruct() != lbSessions.getWindow().getWindowStruct()) {
            notifySessionSelected(null);
        }
        return false;
    }
    
    bool onKeyRelease(Event event, Widget w) {
        uint keyval;
        //If escape key is pressed, close sidebar
        if (event.getKeyval(keyval) && keyval == GdkKeysyms.GDK_Escape)
            notifySessionSelected(null);
        return false;
    }

public:
    this() {
        super();
        addOnButtonPress(&onButtonPress);
        addOnKeyRelease(&onKeyRelease);
        setTransitionType(RevealerTransitionType.SLIDE_RIGHT);
        lbSessions = new ListBox();
        lbSessions.getStyleContext().addClass("notebook");
        lbSessions.getStyleContext().addClass("header");

        lbSessions.setSelectionMode(SelectionMode.BROWSE);
        lbSessions.addOnRowSelected(&onRowSelected);
        setHexpand(false);
        setVexpand(true);
        setHalign(Align.START);
        setValign(Align.FILL);
        
        ScrolledWindow sw = new ScrolledWindow(lbSessions);
        sw.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sw.setHexpand(true);
        sw.setVexpand(true);
        
        Box b = new Box(Orientation.VERTICAL, 0);
        b.add(sw);

        frame = new Frame(b, null);
        add(frame);
    }
    
    void populateSessions(Session[] sessions, string currentSessionUUID) {
        trace("Populating sidebar sessions");
        blockSelectedHandler = true;
        scope(exit) {blockSelectedHandler = false;}
        lbSessions.removeAll();
        foreach(i, session; sessions) {
            Overlay overlay = new Overlay();
            Image img = new Image(getWidgetImage(session.drawable, 0.15));
            setAllMargins(img, 1);
            overlay.add(img);
            Label label = new Label(to!string(i));
            label.setHalign(Align.END);
            label.setValign(Align.END);
            label.setMargins(0, 0, 6, 2);
            overlay.addOverlay(label);
            SideBarRow row = new SideBarRow(session.sessionUUID);
            setAllMargins(row, 4);
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
            grabAdd();
        } else {
            grabRemove();
        }
    }
    
    void addOnSessionSelected(OnSessionSelected dlg) {
        sessionSelectedDelegates ~= dlg;
    }

    void removeOnSessionSelected(OnSessionSelected dlg) {
        gx.util.array.remove(sessionSelectedDelegates, dlg);
    }
}

private:

class SideBarRow: ListBoxRow {
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
