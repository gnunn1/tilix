module gx.terminix.sidebar;

import std.experimental.logger;

import gtk.Frame;
import gtk.Image;
import gtk.ListBox;
import gtk.ListBoxRow;
import gtk.Revealer;

import gx.gtk.cairo;

import gx.terminix.session;

alias OnSessionSelected = void delegate(string sessionUUID);

/**
 * Provides the session selecting sidebar
 */ 
class SideBar: Revealer {
private:
    ListBox lbSessions;
    
    OnSessionSelected[] sessionSelectedDelegates;
    
    void onRowSelected(ListBoxRow row, ListBox) {
        SideBarRow sr = cast(SideBarRow) row;
        if (sr !is null) {
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
        lbSessions.setSelectionMode(SelectionMode.BROWSE);
        lbSessions.addOnRowSelected(&onRowSelected);
        setHexpand(false);
        setVexpand(true);
        setHalign(Align.START);
        setValign(Align.FILL);
        
        Frame frame = new Frame(lbSessions, null);
        frame.getStyleContext().addClass("notebook");
        frame.getStyleContext().addClass("header");
        add(frame);
    }
    
    void populateSessions(Session[] sessions, string currentSessionUUID) {
        trace("Populating sidebar sessions");
        lbSessions.removeAll();
        foreach(session; sessions) {
            Image img = new Image(getWidgetImage(session.drawable, 0.10));
            SideBarRow row = new SideBarRow(session.sessionUUID);
            img.setMarginLeft(4);
            img.setMarginTop(4);
            img.setMarginBottom(4);
            img.setMarginRight(4);
            row.add(img);
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
