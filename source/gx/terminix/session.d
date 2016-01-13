/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.session;

import std.conv;
import std.experimental.logger;
import std.format;
import std.json;
import std.uuid;

import gdk.Atom;
import gdk.Event;

import glib.Util;

import gtk.Application;
import gtk.Box;
import gtk.Button;
import gtk.Container;
import gtk.Clipboard;
import gtk.ComboBox;
import gtk.Dialog;
import gtk.Entry;
import gtk.Grid;
import gtk.Label;
import gtk.Main;
import gtk.Menu;
import gtk.MenuItem;
import gtk.Paned;
import gtk.Widget;
import gtk.Window;

import gx.gtk.util;
import gx.i18n.l10n;
import gx.util.array;

import gx.terminix.application;
import gx.terminix.common;
import gx.terminix.preferences;
import gx.terminix.terminal.terminal;

/**
 * An event that occurs when the session closes, the application window
 * listens to this event and removes the session when received.
 */
alias OnSessionClose = void delegate(Session session);

alias OnSessionDetach = void delegate(Session session, int x, int y, bool isNewSession);

/**
 * An exception that is thrown when a session cannot be created, typically
 * when a failure indeserialization occurs.
 */
class SessionCreationException : Exception {
    this(string msg) {
        super(msg);
    }

    this(string msg, Throwable next) {
        super(msg, next);
    }

    this(Throwable next) {
        super(next.msg, next);
    }
}

/**
 * The session is used to represent a grouping of tiled terminals. It is
 * responsible for managing the layout, de/serialization and session level
 * actions. Note that the Terminal widgets managed by the session are not the
 * actual GTK+ VTE widget but rather a composite widget that includes a title bar,
 * VTE and some overlays. The session does not have direct access to the VTE widget
 * and this design should not change in order to maintain the separation of concerns.
 *
 * From a GTK point of view, a session is just a Box which is used displayed in a
 * GTK Notebook. As a result the application supports multiple sessions at the same
 * time with each one being a separate page. Note that tabs are not shown as it
 * takes too much vertical space and I'll like the UI in Builder which also doesn't do this
 * and which inspired this application.
 */
class Session : Box {

private:

    // mixin for managing is action allowed event delegates
    mixin IsActionAllowedHandler;
    
    // mixin for managing process notification event delegates     
    mixin ProcessNotificationHandler;

    OnSessionDetach[] sessionDetachDelegates;
    OnSessionClose[] sessionCloseDelegates;

    Terminal[] terminals;
    string _name;
    bool _synchronizeInput;

    string _sessionUUID;
    
    Terminal lastFocused;
    /**
     * Creates the session user interface
     */
    void createUI(string profileUUID, string workingDir, bool firstRun) {
        // Fix transparency bugs on ubuntu where background-color 
        // for widgets don't seem to take
        getStyleContext().addClass("terminix-notebook-page");
        Terminal terminal = createTerminal(profileUUID);
        add(terminal);
        terminal.initTerminal(workingDir, firstRun);
        lastFocused = terminal;
    }

    void createUI(Terminal terminal) {
        add(terminal);
        lastFocused = terminal;
    }

    void notifySessionClose() {
        foreach (dlg; sessionCloseDelegates) {
            dlg(this);
        }
    }

    void notifySessionDetach(Session session, int x, int y, bool isNewSession) {
        foreach (dlg; sessionDetachDelegates) {
            dlg(session, x, y, isNewSession);
        }
    }

    void sequenceTerminalID() {
        foreach (i, terminal; terminals) {
            terminal.terminalID = i;
        }
    }
    
    /**
     * Create a Paned widget and modify some properties to
     * make it look somewhat attractive on Ubuntu and non Adwaita themes.
     */
    Paned createPaned(Orientation orientation) {
        Paned result = new Paned(orientation);
        result.setWideHandle(false);
        return result;
    }

    /**
     * Creates the terminal widget and wires the various
     * event handlers. Note the terminal widget is a composite
     * widget and not the actual VTE widget provided by GTK.
     *
     * The VTE widget is not exposed to the session.
     */
    Terminal createTerminal(string profileUUID) {
        Terminal terminal = new Terminal(profileUUID);
        addTerminal(terminal);
        return terminal;
    }
    
    /**
     * Adds a new terminal to the session, usually this is a newly
     * created terminal but can also be one attached to this session
     * from another session via DND
     */
    void addTerminal(Terminal terminal) {
        terminal.addOnTerminalClose(&onTerminalClose);
        terminal.addOnTerminalRequestDetach(&onTerminalRequestDetach);
        terminal.addOnTerminalRequestSplit(&onTerminalRequestSplit);
        terminal.addOnTerminalRequestMove(&onTerminalRequestMove);
        terminal.addOnTerminalInFocus(&onTerminalInFocus);
        terminal.addOnTerminalKeyPress(&onTerminalKeyPress);
        terminal.addOnProcessNotification(&onTerminalProcessNotification);
        terminal.addOnIsActionAllowed(&onTerminalIsActionAllowed);
        terminals ~= terminal;
        terminal.terminalID = terminals.length - 1;
        terminal.synchronizeInput = synchronizeInput;
    }
    
    /**
     * Closes the terminal and removes it from the session. This can be
     * called when a terminal is closed naturally or when a terminal
     * is removed from the session completely.
     */
    void removeTerminal(Terminal terminal) {
        trace("Removing terminal from session");
        if (lastFocused == terminal)
            lastFocused = null;
        //Remove delegates
        terminal.removeOnTerminalClose(&onTerminalClose);
        terminal.removeOnTerminalRequestDetach(&onTerminalRequestDetach);
        terminal.removeOnTerminalRequestSplit(&onTerminalRequestSplit);
        terminal.removeOnTerminalRequestMove(&onTerminalRequestMove);
        terminal.removeOnTerminalInFocus(&onTerminalInFocus);
        terminal.removeOnTerminalKeyPress(&onTerminalKeyPress);
        terminal.removeOnProcessNotification(&onTerminalProcessNotification);
        terminal.removeOnIsActionAllowed(&onTerminalIsActionAllowed);
        //unparent the terminal
        unparentTerminal(terminal);
        //Remove terminal
        gx.util.array.remove(terminals, terminal);
        //Only one terminal open, close session
        trace(format("There are %d terminals left", terminals.length));
        if (terminals.length == 0) {
            trace("No more terminals, requesting session be closed");
            notifySessionClose();
            return;
        }
        //Update terminal IDs to fill in hole
        sequenceTerminalID();
        showAll();
    }

    /**
     * Find a terminal based on it's UUID
     */
    Terminal findTerminal(string terminalUUID) {
        foreach (terminal; terminals) {
            if (terminal.terminalUUID == terminalUUID)
                return terminal;
        }
        return null;
    }

    /**
     * Splits the terminal into two by removing the existing terminal, add
     * a Paned (i.e. Splitter) and then placing the original terminal and a 
     * new terminal in the new Paned.
     *
     * Note that we do not insert the Terminal widget directly into a Paned,
     * instead a Box is added first as a shim. This is required so that if the
     * user splits the terminal again, the box forces the parent Paned to keep
     * it's layout while we remove the terminal and insert a new Paned in it's
     * spot. Without this shim the layout becomes screwed up.
     *
     * If there is some magic way in GTK to do this without the extra Box shim
     * it would be nice to eliminate this. 
     */
    void onTerminalRequestSplit(Terminal terminal, Orientation orientation) {
        trace("Splitting Terminal");
        Terminal newTerminal = createTerminal(terminal.profileUUID);
        trace("Inserting terminal");
        insertTerminal(terminal, newTerminal, orientation, 2);
        trace("Intializing terminal");
        newTerminal.initTerminal(terminal.currentDirectory, false);
    }

    /**
     * Removes a terminal from it's parent and cleans up splitter if necessary
     * Note that this does not unset event handlers or do any other cleanup as
     * this method is used both when moving and closing terminals.
     *
     * This is a bit convoluted since we are using Box as a shim to 
     * preserve spacing. Every child widget is embeded in a Box which
     * is then embeded in a Paned. So an example heirarchy qouls be as follows:
     *
     * Session (Box) -> Paned -> Box -> Terminal
     *                        -> Box -> Paned -> Box -> Terminal
     *                                        -> Box -> Terminal
     */
    void unparentTerminal(Terminal terminal) {

        /**
        * Given a terminal, find the other child in the splitter.
        * Note the other child could be either a terminal or 
        * another splitter. In either case a Box will be the immediate
        * child hence we return that since this function is called
        * in preparation to remove the other child and replace the
        * splitter with it.
        */
        Box findOtherChild(Terminal terminal, Paned paned) {
            Box box1 = cast(Box) paned.getChild1();
            Box box2 = cast(Box) paned.getChild2();

            Widget widget1 = gx.gtk.util.getChildren(box1)[0];
            Widget widget2 = gx.gtk.util.getChildren(box2)[0];

            Terminal terminal1 = cast(Terminal) widget1;
            Terminal terminal2 = cast(Terminal) widget2;

            int result = terminal == terminal1 ? 1 : 2;
            return (result == 1 ? box2 : box1);
        }

        Paned paned = cast(Paned) terminal.getParent().getParent();
        // If no paned this means there is only one terminal left
        // Just unparent the terminal and carry on
        if (paned is null) {
            Box box = cast(Box) terminal.getParent();
            box.remove(terminal);
            return;
        }
        Box otherBox = findOtherChild(terminal, paned);
        paned.remove(otherBox);

        Box parent = cast(Box) paned.getParent();
        parent.remove(paned);

        //Need to add the widget in the box not the box itself since the Paned we removed is already in a Box
        //Fixes segmentation fault where when added box we created another layer of Box which caused the cast
        //to Paned to fail
        //Get child widget, could be Terminal or Paned       
        Widget widget = gx.gtk.util.getChildren(otherBox)[0];
        //Remove widget from original Box parent
        otherBox.remove(widget);
        //Add widget to new parent
        parent.add(widget);
        //Clean up terminal parent
        Box box = cast(Box) terminal.getParent();
        box.remove(terminal);
    }
    
    /**
     * Inserts a source terminal into a destination by creating the necessary
     * splitters and box shims
     */
    void insertTerminal(Terminal dest, Terminal src, Orientation orientation, int child) {
        Box parent = cast(Box) dest.getParent();
        int height = parent.getAllocatedHeight();
        int width = parent.getAllocatedWidth();

        Box b1 = new Box(Orientation.VERTICAL, 0);
        Box b2 = new Box(Orientation.VERTICAL, 0);

        Paned paned = new Paned(orientation);
        paned.pack1(b1, true, true);
        paned.pack2(b2, true, true);

        parent.remove(dest);
        parent.showAll();
        if (child == 1) {
            b1.add(src);
            b2.add(dest);
        } else {
            b1.add(dest);
            b2.add(src);
        }

        final switch (orientation) {
        case Orientation.HORIZONTAL:
            paned.setPosition(width / 2);
            break;
        case Orientation.VERTICAL:
            paned.setPosition(height / 2);
            break;
        }
        parent.add(paned);
        parent.showAll();
    }
    
    void onTerminalRequestMove(string srcUUID, Terminal dest, DragQuadrant dq) {
        
        Session getSession(Terminal terminal) {
            Widget widget = terminal.getParent();
            while (widget !is null) {
                Session result = cast(Session) widget;
                if (result !is null) return result;
                widget = widget.getParent();
            }
            return null;
        }
            
        trace(format("Moving terminal %d to quadrant %d", dest.terminalID, dq));
        Terminal src = findTerminal(srcUUID);
        // If terminal is not null, its from this session. If it
        // is null then dropped from a different session, maybe different window
        if (src !is null) {
            unparentTerminal(src);
        } else {
            trace("Moving terminal from different session");
            src = cast(Terminal) terminix.findWidgetForUUID(srcUUID);
            if (src is null) {
                showErrorDialog(cast(Window) this.getToplevel(), _("Could not locate dropped terminal"));
                return;    
            }
            Session session = getSession(src);
            if (session is null) {
                showErrorDialog(cast(Window) this.getToplevel(), _("Could not locate session for dropped terminal"));
                return;    
            }
            trace("Removing Terminal from other session");
            session.removeTerminal(src);
            //Add terminal to this one
            addTerminal(src);
        }
        Orientation orientation = (dq == DragQuadrant.TOP || dq == DragQuadrant.BOTTOM) ? Orientation.VERTICAL : Orientation.HORIZONTAL;
        int child = (dq == DragQuadrant.TOP || dq == DragQuadrant.LEFT) ? 1 : 2;
        //Inserting terminal
        //trace(format("Inserting terminal orient=$d, child=$d", orientation, child));
        insertTerminal(dest, src, orientation, child);
    }

    /**
     * Event handler that get's called when Terminal is closed
	 */
    void onTerminalClose(Terminal terminal) {
        removeTerminal(terminal);
    }
    
    void onTerminalProcessNotification(string summary, string _body, string terminalUUID, string sessionUUID = null) {
        notifyProcessNotification(summary, _body, terminalUUID, _sessionUUID);
    }    

    bool onTerminalIsActionAllowed(ActionType actionType) {
        switch (actionType) {
        case ActionType.DETACH:
            //Ok this is a bit weird but we only only a terminal to be detached
            //if a session has more then one terminal in it OR the application
            //has multiple sessions. 
            return terminals.length > 1 || notifyIsActionAllowed(ActionType.DETACH);
        default:
            return false;
        }
    }

    /**
     * Request from the terminal to detach itself into a new window,
     * typically a result of a drag operation
     */
    void onTerminalRequestDetach(Terminal terminal, int x, int y) {
        trace("Detaching session");
        //Only one terminal, just detach session as a whole
        if (terminals.length == 1) {
            notifySessionDetach(this, x, y, false);
        } else {
            removeTerminal(terminal);
            Session session = new Session(this._name, terminal);
            notifySessionDetach(session, x, y, true);

            //Update terminal IDs to fill in hole
            sequenceTerminalID();
            showAll();
        }
    }

    void onTerminalInFocus(Terminal terminal) {
        //trace("Focus noted");
        lastFocused = terminal;
    }

    void onTerminalKeyPress(Terminal originator, Event event) {
        trace("Got key press");
        foreach (terminal; terminals) {
            if (originator.getWidgetStruct() != terminal.getWidgetStruct() && terminal.synchronizeInput) {
                trace("sending key press, sendEvent = " ~ to!string(event.key.sendEvent));
                Event newEvent = event.copy();
                /*
                Event newEvent = new Event(EventType.KEY_PRESS);
                newEvent.key.hardwareKeycode = event.key.hardwareKeycode;
                newEvent.key.keyval = event.key.keyval;
                newEvent.key.state = event.key.state;
                newEvent.key.type = event.key.type;
                */
                newEvent.key.sendEvent = 1;
                terminal.echoKeyPressEvent(newEvent);
            }
        }
    }

/************************************************
 * De/Serialization code in this private block
 ************************************************/
private:

    string _filename;

    enum NODE_TYPE = "type";
    enum NODE_NAME = "name";
    enum NODE_ORIENTATION = "orientation";
    enum NODE_SCALED_POSITION = "position";
    enum NODE_CHILD = "child";
    enum NODE_CHILD1 = "child1";
    enum NODE_CHILD2 = "child2";
    enum NODE_DIRECTORY = "directory";
    enum NODE_PROFILE = "profile";
    enum NODE_WIDTH = "width";
    enum NODE_HEIGHT = "height";

    /** 
     * Widget Types which are serialized
     */
    enum WidgetType : string {
        SESSION = "Session",
        PANED = "Paned",
        TERMINAL = "Terminal",
        OTHER = "Other"
    }

    /**
     * Determine the widget type, we only need to serialize the
     * Paned and TerminalPane widgets. The Box used as a shim does
     * not need to be serialized.
     */
    public WidgetType getSerializedType(Widget widget) {
        if (cast(Session) widget !is null)
            return WidgetType.SESSION;
        else if (cast(Terminal) widget !is null)
            return WidgetType.TERMINAL;
        else if (cast(Paned) widget !is null)
            return WidgetType.PANED;
        else
            return WidgetType.OTHER;
    }

    /**
     * Serialize a widget depending on it's type
     */
    JSONValue serializeWidget(Widget widget, SessionSizeInfo sizeInfo) {
        JSONValue value = [NODE_TYPE : getSerializedType(widget)];
        WidgetType wt = getSerializedType(widget);
        switch (wt) {
        case WidgetType.PANED:
            serializePaned(value, cast(Paned) widget, sizeInfo);
            break;
        case WidgetType.TERMINAL:
            serializeTerminal(value, cast(Terminal) widget);
            break;
        default:
            trace("Unknown Widget, can't serialize");
        }
        return value;
    }

    /**
     * Serialize the Paned widget
     */
    JSONValue serializePaned(JSONValue value, Paned paned, SessionSizeInfo sizeInfo) {
        value[NODE_ORIENTATION] = JSONValue(paned.getOrientation());
        value[NODE_SCALED_POSITION] = JSONValue(sizeInfo.scalePosition(paned.getPosition, paned.getOrientation()));
        value[NODE_TYPE] = WidgetType.PANED;
        Box box1 = cast(Box) paned.getChild1();
        Box box2 = cast(Box) paned.getChild2();
        value.object[NODE_CHILD1] = serializeWidget(gx.gtk.util.getChildren(box1)[0], sizeInfo);
        value.object[NODE_CHILD2] = serializeWidget(gx.gtk.util.getChildren(box2)[0], sizeInfo);
        return value;
    }

    /**
     * Serialize the TerminalPane widget
     */
    JSONValue serializeTerminal(JSONValue value, Terminal terminal) {
        value[NODE_PROFILE] = terminal.profileUUID;
        value[NODE_DIRECTORY] = terminal.currentDirectory;
        value[NODE_WIDTH] = JSONValue(terminal.getAllocatedWidth());
        value[NODE_HEIGHT] = JSONValue(terminal.getAllocatedHeight());
        return value;
    }

    /**
     * Parse a node and determine whether it is it a Terminal or Paned
     * child that needs de-serialization
     */
    Widget parseNode(JSONValue value, SessionSizeInfo sizeInfo) {
        if (value[NODE_TYPE].str() == WidgetType.TERMINAL)
            return parseTerminal(value);
        else
            return parsePaned(value, sizeInfo);
    }

    /**
     * De-serialize a TerminalPane widget
     */
    Terminal parseTerminal(JSONValue value) {
        trace("Loading terminal");
        //TODO Check that the profile exists and use default if it doesn't
        string profileUUID = value[NODE_PROFILE].str();
        Terminal terminal = createTerminal(profileUUID);
        terminal.initTerminal(value[NODE_DIRECTORY].str(), false);
        return terminal;
    }

    /**
     * De-serialize a Paned widget
     */
    Paned parsePaned(JSONValue value, SessionSizeInfo sizeInfo) {
        trace("Loading paned");
        Orientation orientation = cast(Orientation) value[NODE_ORIENTATION].integer();
        Paned paned = createPaned(orientation);
        Box b1 = new Box(Orientation.VERTICAL, 0);
        b1.add(parseNode(value[NODE_CHILD1], sizeInfo));
        Box b2 = new Box(Orientation.VERTICAL, 0);
        b2.add(parseNode(value[NODE_CHILD2], sizeInfo));
        paned.pack1(b1, true, true);
        paned.pack2(b2, true, true);
        paned.setPosition(sizeInfo.getPosition(value[NODE_SCALED_POSITION].floating(), orientation));
        return paned;
    }

    /**
     * De-serialize a session
     */
    void parseSession(JSONValue value, SessionSizeInfo sizeInfo) {
        _name = value[NODE_NAME].str();
        long savedWidth = value[NODE_WIDTH].integer();
        long savedHeight = value[NODE_HEIGHT].integer();
        JSONValue child = value[NODE_CHILD];
        trace(child.toPrettyString());
        add(parseNode(child, sizeInfo));
    }

private:

    /**
     * Creates a new session with the specified terminal
     */
    this(string sessionName, Terminal terminal) {
        super(Orientation.VERTICAL, 0);
        _sessionUUID = randomUUID().toString();
        _name = sessionName;
        addTerminal(terminal);
        createUI(terminal);
    }

public:

    /**
     * Creates a new session
     * 
     * Params:
     *  name        = The name of the session
     *  profileUUID = The profile to use when creating the initial terminal for the session
     *  workingDir  = The working directory to use in the initial terminal
     *  firstRun    = A flag to indicate this is the first session for the app, used to determine if geometry is set based on profile
     */
    this(string name, string profileUUID, string workingDir, bool firstRun) {
        super(Orientation.VERTICAL, 0);
        _sessionUUID = randomUUID().toString();
        _name = name;
        createUI(profileUUID, workingDir, firstRun);
    }

    /**
     * Creates a new session by de-serializing a session from JSON
     *
     * TODO Determine whether we need to support concept of firstRun for loading session
     * 
     * Params:
     *  value       = The root session node of the JSON block used to for deserialization
     *  filename    = The filename corresponding to the JSON block
     *  width       = The expected width and height of the session, used to scale Paned positions
     *  firstRun    = A flag to indicate this is the first session for the app, used to determine if geometry is set based on profile
     */
    this(JSONValue value, string filename, int width, int height, bool firstRun) {
        super(Orientation.VERTICAL, 0);
        _sessionUUID = randomUUID().toString();
        try {
            parseSession(value, SessionSizeInfo(width, height));
            _filename = filename;
        }
        catch (Exception e) {
            throw new SessionCreationException("Session could not be created due to error: " ~ e.msg, e);
        }
    }
    
    /**
     * Finds the widget matching a specific UUID, typically
     * a Session or Terminal
     */
    Widget findWidgetForUUID(string uuid) {
        trace("Searching terminals " ~ uuid);
        return findTerminal(uuid);
    }

    /**
     * Serialize the session
     *
     * Returns:
     *  The JSON representation of the session
     */
    JSONValue serialize() {
        JSONValue root = ["version" : "1.0"];
        root.object[NODE_NAME] = _name;
        root.object[NODE_WIDTH] = JSONValue(getAllocatedWidth());
        root.object[NODE_HEIGHT] = JSONValue(getAllocatedHeight());
        SessionSizeInfo sizeInfo = SessionSizeInfo(getAllocatedWidth(), getAllocatedHeight());
        root.object[NODE_CHILD] = serializeWidget(gx.gtk.util.getChildren(this)[0], sizeInfo);
        root[NODE_TYPE] = WidgetType.SESSION;
        return root;
    }

    /**
     * The name of the session
     */
    @property string name() {
        return _name;
    }

    @property void name(string value) {
        if (value.length > 0) {
            _name = value;
        }
    }

    /**
     * Unique and immutable session ID
     */
    @property string sessionUUID() {
        return _sessionUUID;
    }

    /**
     * If the session was created via de-serialization the filename used, otherwise null
     */
    @property string filename() {
        return _filename;
    }

    @property void filename(string value) {
        _filename = value;
    }

    /**
     * Whether the input for all terminals is synchronized
     */
    @property bool synchronizeInput() {
        return _synchronizeInput;
    }

    @property void synchronizeInput(bool value) {
        _synchronizeInput = value;
        foreach (terminal; terminals) {
            terminal.synchronizeInput = value;
        }
    }

    /**
     * Whether any terminals in the session have a child process running
     */
    bool isProcessRunning() {
        foreach (terminal; terminals) {
            if (terminal.isProcessRunning())
                return true;
        }
        return false;
    }

    /**
     * Restore focus to the terminal that last had focus in the session
     */
    void focusRestore() {
        if (lastFocused !is null) {
            lastFocused.focusTerminal();
        }
    }

    /**
     * Focus the next terminal in the session
     */
    void focusNext() {
        ulong id = 0;
        if (lastFocused !is null) {
            id = lastFocused.terminalID + 1;
            if (id >= terminals.length)
                id = 0;
        }
        focusTerminal(id);
    }

    /**
     * Focus the previous terminal in the session
     */
    void focusPrevious() {
        ulong id = 0;
        if (lastFocused !is null) {
            id = lastFocused.terminalID - 1;
            if (id < 0)
                id = terminals.length - 1;
        }
        focusTerminal(id);
    }

    /**
     * Focus the terminal designated by the ID
     */
    bool focusTerminal(ulong terminalID) {
        if (terminalID >= 0 && terminalID < terminals.length) {
            terminals[terminalID].focusTerminal();
            return true;
        }
        return false;
    }

    /**
     * Focus the terminal designated by the UUID
     */
    bool focusTerminal(string terminalUUID) {
        foreach(terminal; terminals) {
            if (terminal.terminalUUID == terminalUUID) {
                terminal.focusTerminal();
                return true;
            }
        }
        return false;
    }

    void addOnSessionClose(OnSessionClose dlg) {
        sessionCloseDelegates ~= dlg;
    }

    void removeOnSessionClose(OnSessionClose dlg) {
        gx.util.array.remove(sessionCloseDelegates, dlg);
    }

    void addOnSessionDetach(OnSessionDetach dlg) {
        sessionDetachDelegates ~= dlg;
    }

    void removeOnSessionDetach(OnSessionDetach dlg) {
        gx.util.array.remove(sessionDetachDelegates, dlg);
    }
}

/**
 * Class used to prompt user for session name and profile to use when
 * adding a new session.
 */
package class SessionProperties : Dialog {

private:
    Entry eName;
    ComboBox cbProfile;

    void createUI(string name, string profileUUID) {

        Grid grid = new Grid();
        grid.setColumnSpacing(12);
        grid.setRowSpacing(6);
        grid.setMarginTop(18);
        grid.setMarginBottom(18);
        grid.setMarginLeft(18);
        grid.setMarginRight(18);

        Label label = new Label(format("<b>%s</b>", _("Name")));
        label.setUseMarkup(true);
        label.setHalign(Align.END);
        grid.attach(label, 0, 0, 1, 1);

        eName = new Entry();
        eName.setText(name);
        eName.setMaxWidthChars(30);
        eName.setActivatesDefault(true);
        grid.attach(eName, 1, 0, 1, 1);

        label = new Label(format("<b>%s</b>", _("Profile")));
        label.setUseMarkup(true);
        label.setHalign(Align.END);
        grid.attach(label, 0, 1, 1, 1);

        ProfileInfo[] profiles = prfMgr.getProfiles();
        string[] names = new string[profiles.length];
        string[] uuid = new string[profiles.length];
        foreach (i, profile; profiles) {
            names[i] = profile.name;
            uuid[i] = profile.uuid;
        }
        cbProfile = createNameValueCombo(names, uuid);
        cbProfile.setActiveId(profileUUID);
        cbProfile.setHexpand(true);
        grid.attach(cbProfile, 1, 1, 1, 1);

        getContentArea().add(grid);
    }

public:

    this(Window parent, string name, string profileUUID) {
        super(_("New Session"), parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [StockID.CANCEL, StockID.OK], [ResponseType.CANCEL, ResponseType.OK]);
        setDefaultResponse(ResponseType.OK);
        createUI(name, profileUUID);
    }

    @property string name() {
        return eName.getText();
    }

    @property string profileUUID() {
        return cbProfile.getActiveId();
    }
}

private:

/**
 * used during session serialization to store any width/height/position elements
 * as scaled entities so that if restoring a session in a smaller/larger space
 * everything stays proportional
 */
struct SessionSizeInfo {
    int width;
    int height;

    double scalePosition(int position, Orientation orientation) {
        final switch (orientation) {
        case Orientation.HORIZONTAL:
            return to!double(position) / to!double(width);
        case Orientation.VERTICAL:
            return to!double(position) / to!double(height);
        }
    }

    int getPosition(double scaledPosition, Orientation orientation) {
        final switch (orientation) {
        case Orientation.HORIZONTAL:
            return to!int(scaledPosition * width);
        case Orientation.VERTICAL:
            return to!int(scaledPosition * height);
        }
    }
} 
