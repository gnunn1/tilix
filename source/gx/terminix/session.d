/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.session;

import std.conv;
import std.experimental.logger;
import std.format;
import std.json;

import gdk.Atom;
import gdk.Event;

import glib.Util;

import gtk.Box;
import gtk.Container;
import gtk.Button;
import gtk.Clipboard;
import gtk.Main;
import gtk.Menu;
import gtk.MenuItem;
import gtk.Paned;
import gtk.Widget;

import gx.gtk.util;
import gx.util.array;

import gx.terminix.preferences;
import gx.terminix.terminal.pane;

alias OnSessionClose = void delegate(Session session);

class SessionCreationException: Exception {
    this(string msg) {
        super(msg) ;
    }
    
    this(string msg, Throwable next) {
        super(msg, next);
    }
    
    this(Throwable next) {
        super(next.msg, next);
    }
}

class Session : Box {

private:

	OnSessionClose[] sessionCloseDelegates;

	TerminalPane[] terminals;
	string _name;
    bool _synchronizeInput;
    
	TerminalPane lastFocused;

	void createUI(bool firstRun) {
		TerminalPane terminal = createTerminal();
		add(terminal);
		terminal.initTerminal(Util.getHomeDir(), firstRun);
		lastFocused = terminal;
	}

	void notifySessionClose() {
		foreach (OnSessionClose dlg; sessionCloseDelegates) {
			dlg(this);
		}
	}

	TerminalPane createTerminal() {
        return createTerminal(prfMgr.getDefaultProfile());
    }
    
    void sequenceTerminalID() {
        foreach(i, terminal; terminals) {
            terminal.terminalID = i;
        }
    }

	TerminalPane createTerminal(string profileUUID) {
		TerminalPane terminal = new TerminalPane(profileUUID);
		terminal.addOnTerminalClose(&onTerminalClose);
		terminal.addOnTerminalRequestSplit(&onTerminalRequestSplit);
		terminal.addOnTerminalInFocus(&onTerminalInFocus);
        terminal.addOnTerminalKeyPress(&onTerminalKeyPress);
		terminals ~= terminal;
        terminal.terminalID = terminals.length - 1;
        terminal.synchronizeInput = synchronizeInput;
		return terminal;
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
	void onTerminalRequestSplit(TerminalPane terminal, Orientation orientation) {
        trace("Splitting Terminal");
		Box parent = cast(Box) terminal.getParent();
		int height = parent.getAllocatedHeight();
		int width = parent.getAllocatedWidth();

		Box b1 = new Box(Orientation.VERTICAL, 0);
		Box b2 = new Box(Orientation.VERTICAL, 0);

		Paned paned = new Paned(orientation);
		paned.pack1(b1, true, true);
		paned.pack2(b2, true, true);

		parent.remove(terminal);
		b1.add(terminal);
		TerminalPane newTerminal = createTerminal(terminal.profileUUID);
		b2.add(newTerminal);

		switch (orientation) {
		case Orientation.HORIZONTAL:
			paned.setPosition(width / 2);
			break;
		case Orientation.VERTICAL:
			paned.setPosition(height / 2);
			break;
		default:
			assert(0);
		}

		parent.add(paned);
		parent.showAll();
        trace("Terminal current directory " ~ terminal.currentDirectory); 
		newTerminal.initTerminal(terminal.currentDirectory, false);
	}
    
	/**
	 * Given a terminal, find the other child in the splitter.
	 * Note the other child could be either a terminal or 
	 * another splitter. In either case a Box will be the immediate
	 * child hence we return that since this function is called
	 * in preparation to remove the other child and replace the
	 * splitter with it.
	 */
	Box findOtherChild(TerminalPane terminal, Paned paned) {
		Box box1 = cast(Box) paned.getChild1();
		Box box2 = cast(Box) paned.getChild2();

		Widget widget1 = gx.gtk.util.getChildren(box1)[0];
		Widget widget2 = gx.gtk.util.getChildren(box2)[0];

		TerminalPane terminal1 = cast(TerminalPane) widget1;
		TerminalPane terminal2 = cast(TerminalPane) widget2;

		int result = terminal == terminal1 ? 1 : 2;
		return (result == 1 ? box2 : box1);
	}

	/**
	 * Removes the terminal by replacing the parent splitter with
	 * the child from the other side.
	 */
	void onTerminalClose(TerminalPane terminal) {
		if (lastFocused == terminal)
			lastFocused = null;
		//Remove delegates
		terminal.removeOnTerminalClose(&onTerminalClose);
		terminal.removeOnTerminalRequestSplit(&onTerminalRequestSplit);
		terminal.removeOnTerminalInFocus(&onTerminalInFocus);
        terminal.removeOnTerminalKeyPress(&onTerminalKeyPress);

		//Only one terminal open, close session
		if (terminals.length == 1) {
			notifySessionClose();
			return;
		} 
		Paned paned = cast(Paned) terminal.getParent().getParent();
		Box box = findOtherChild(terminal, paned);
		paned.remove(box);

		Box parent = cast(Box) paned.getParent();
		parent.remove(paned);
		parent.add(box);
		parent.showAll();
    
        //Remove terminal
        gx.util.array.remove(terminals, terminal);
        //Update terminal IDs to fill in hole
        sequenceTerminalID();        
	}
    
	void onTerminalInFocus(TerminalPane terminal) {
		//trace("Focus noted");
		lastFocused = terminal;
	}
    
    void onTerminalKeyPress(Event event, TerminalPane originator) {
        trace("Got key press");
        foreach(terminal; terminals) {
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

//De/Serialization code in this private block
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
    enum WidgetType: string {
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
        if (cast(Session) widget !is null) return WidgetType.SESSION;
        else if (cast(TerminalPane) widget !is null) return WidgetType.TERMINAL;
        else if (cast(Paned) widget !is null) return WidgetType.PANED;
        else return WidgetType.OTHER;
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
                serializeTerminal(value, cast(TerminalPane) widget);
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
    JSONValue serializeTerminal(JSONValue value, TerminalPane terminal) {
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
        if (value[NODE_TYPE].str() == WidgetType.TERMINAL) return parseTerminal(value);
        else return parsePaned(value, sizeInfo);
    }
    
    /**
     * De-serialize a TerminalPane widget
     */
    TerminalPane parseTerminal(JSONValue value) {
        trace("Loading terminal");
        //TODO Check that the profile exists and use default if it doesn't
        string profileUUID = value[NODE_PROFILE].str();
        TerminalPane terminal  = createTerminal(profileUUID);
        terminal.initTerminal(value[NODE_DIRECTORY].str(), false);
        return terminal;
    }
    
    /**
     * De-serialize a Paned widget
     */
    Paned parsePaned(JSONValue value, SessionSizeInfo sizeInfo) {
        trace("Loading paned");
        Orientation orientation = cast(Orientation) value[NODE_ORIENTATION].integer();
        Paned paned = new Paned(orientation);
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
    
public:

	this(string name, bool firstRun) {
		super(Orientation.VERTICAL, 0);
		_name = name;
		createUI(firstRun);
	}
    
    //TODO Determine whether we need to support 
    //concept of firstRun for loading session
    this(JSONValue value, string filename, int width, int height, bool firstRun) {
		super(Orientation.VERTICAL, 0);
        try {
            parseSession(value, SessionSizeInfo(width, height));
            _filename = filename;
        } catch (Exception e) {
            throw new SessionCreationException("Session could not be created due to error: " ~ e.msg, e);
        }        
    }
    
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

	@property string name() {
		return _name;
	}
    
    @property void name(string value) {
        if (value.length > 0) {
            _name = value;
        }
    }
    
    @property string filename() {
        return _filename;
    }
    
    @property void filename(string value) {
        _filename = value;
    }
    
    @property bool synchronizeInput() {
        return _synchronizeInput;
    }

    @property void synchronizeInput(bool value) {
        _synchronizeInput = value;
        foreach(terminal; terminals) {
            terminal.synchronizeInput = value;
        }
    }

	bool isProcessRunning() {
		foreach (terminal; terminals) {
			if (terminal.isProcessRunning())
				return true;
		}
		return false;
	}

	void focusRestore() {
		if (lastFocused !is null) {
			lastFocused.focusTerminal();
		}
	}
    
    void focusNext() {
        ulong id = 0;
        if (lastFocused !is null) {
            id = lastFocused.terminalID + 1;
            if (id >= terminals.length) id = 0;
        }
        focusTerminal(id);
    }
    
    void focusPrevious() {
        ulong id = 0;
        if (lastFocused !is null) {
            id = lastFocused.terminalID - 1;
            if (id < 0) id = terminals.length - 1;
        }
        focusTerminal(id);
    }
    
    void focusTerminal(ulong terminalID) {
        if (terminalID >= 0 && terminalID < terminals.length) {
            terminals[terminalID].focusTerminal();
        }
    }
    
	void addOnSessionClose(OnSessionClose dlg) {
		sessionCloseDelegates ~= dlg;
	}

	void removeOnSessionClose(OnSessionClose dlg) {
		gx.util.array.remove(sessionCloseDelegates, dlg);
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
                return to!double(position)/to!double(width);
            case Orientation.VERTICAL:
                return to!double(position)/to!double(height);            
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
