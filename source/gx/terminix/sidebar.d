module gx.terminix.sidebar;

import std.conv;
import std.experimental.logger;

import gtk.Box;
import gtk.Frame;
import gtk.Image;
import gtk.Label;
import gtk.ListBox;
import gtk.ListBoxRow;
import gtk.Overlay;
import gtk.Revealer;
import gtk.ScrolledWindow;

import gx.gtk.cairo;
import gx.gtk.util;

import gx.terminix.session;

alias OnSessionSelected = void delegate(string sessionUUID);

/**
 * Provides the session selecting sidebar
 */ 
class SideBar: Revealer {
private:
    ListBox lbSessions;
    
    OnSessionSelected[] sessionSelectedDelegates;
    
    bool blockSelectedHandler;
    
    void onRowSelected(ListBoxRow row, ListBox) {
        SideBarRow sr = cast(SideBarRow) row;
        if (sr !is null && !blockSelectedHandler) {
            foreach(sessionSelected; sessionSelectedDelegates) {
                sessionSelected(sr.sessionUUID);
            }
        }        
    }

public:
    this() {
        super();
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

        Frame frame = new Frame(b, null);
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
