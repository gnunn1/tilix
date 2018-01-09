/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.session;

import core.stdc.locale;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.format;
import std.json;
import std.string;
import std.uuid;

import cairo.Context;
import cairo.ImageSurface;

import gdkpixbuf.Pixbuf;

import gdk.Atom;
import gdk.Cairo;
import gdk.Event;

import gio.Settings : GSettings = Settings;

import glib.Util;

import gobject.ObjectG;
import gobject.ParamSpec;
import gobject.Value;

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
import gtk.Stack;
import gtk.Version;
import gtk.Widget;
import gtk.Window;

import gx.gtk.cairo;
import gx.gtk.dialog;
import gx.gtk.threads;
import gx.gtk.util;
import gx.i18n.l10n;
import gx.util.array;

import gx.tilix.application;
import gx.tilix.appwindow;
import gx.tilix.common;
import gx.tilix.constants;
import gx.tilix.preferences;
import gx.tilix.terminal.terminal;


enum SessionStateChange {
    TERMINAL_MAXIMIZED,
    TERMINAL_RESTORED,
    TERMINAL_FOCUSED,
    TERMINAL_TITLE,
    SESSION_TITLE
};

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
class Session : Stack, IIdentifiable {

private:

    // mixin for managing is action allowed event delegates
    mixin IsActionAllowedHandler;

    // mixin for managing process notification event delegates
    mixin ProcessNotificationHandler;

    Terminal[] terminals;
    string _name;
    bool _synchronizeInput;

    string _sessionUUID;

    enum STACK_GROUP_NAME = "group";
    enum STACK_MAX_NAME = "maximized";

    //A box in the stack used as the page where terminals reside
    Box stackGroup;
    //A box in the stack used to hold a maximized terminal
    Box stackMaximized;
    //A box under stackGroup, used to hold the terminals and panes
    Box groupChild;
    MaximizedInfo maximizedInfo;

    Terminal currentTerminal;
    Terminal[] mruTerminals;

    GSettings gsSettings;

    /**
     * Creates the session user interface
     */
    void createUI(string profileUUID, string workingDir, bool firstRun) {
        Terminal terminal = createTerminal(profileUUID);
        createUI(terminal);
        terminal.initTerminal(workingDir, firstRun);
    }

    void createUI(Terminal terminal) {
        groupChild.add(terminal);
        currentTerminal = terminal;
    }

    void createBaseUI() {
        stackGroup = new Box(Orientation.VERTICAL, 0);
        stackGroup.getStyleContext().addClass("tilix-background");
        addNamed(stackGroup, STACK_GROUP_NAME);
        stackMaximized = new Box(Orientation.VERTICAL, 0);
        stackMaximized.getStyleContext().addClass("tilix-background");
        addNamed(stackMaximized, STACK_MAX_NAME);
        groupChild = new Box(Orientation.VERTICAL, 0);
        stackGroup.add(groupChild);
        // Need this to switch the stack in case we loaded a layout
        // with a maximized terminal since stack can't be switched until realized
        addOnRealize(delegate(Widget) {
            if (maximizedInfo.isMaximized) {
                setVisibleChild(stackMaximized);
            }
        });
    }

    void notifySessionClose() {
        onClose.emit(this);
    }

    void notifySessionDetach(Session session, int x, int y, bool isNewSession) {
        onDetach.emit(session, x, y, isNewSession);
    }

    void notifySessionStateChange(SessionStateChange stateChange) {
        onStateChange.emit(this, stateChange);
    }

    void sequenceTerminalID() {
        foreach (i, terminal; terminals) {
            terminal.terminalID = i + 1;
        }
    }

    /**
     * Create a Paned widget and modify some properties to
     * make it look somewhat attractive on Ubuntu and non Adwaita themes.
     */
    TerminalPaned createPaned(Orientation orientation) {
        TerminalPaned result = new TerminalPaned(orientation);
        if (Version.checkVersion(3, 16, 0).length == 0) {
            result.setWideHandle(gsSettings.getBoolean(SETTINGS_ENABLE_WIDE_HANDLE_KEY));
        }
        result.addOnButtonPress(delegate(Event event, Widget w) {
            if (event.button.window == result.getHandleWindow().getWindowStruct() && event.getEventType() == EventType.DOUBLE_BUTTON_PRESS && event.button.button == MouseButton.PRIMARY) {
                redistributePanes(cast(Paned) w);
                return true;
            }
            return false;
        });
        result.setProperty("position-set", true);
        return result;
    }

    /**
     * Tries to evenly space all Paned of the same orientation.
     * Uses a binary tree to model the panes and calculate the
     * sizes and then sets the sizes from outer to inner. See comments
     * later in file for PanedModel for more info how this
     * works.
     */
    void redistributePanes(Paned paned) {

        /**
         * Find the root pane of the same orientation
         * by walking up the parent-child heirarchy
         */
        Paned getRootPaned() {
            Paned result = paned;
            Container parent = cast(Container) paned.getParent();
            while (parent !is null) {
                Paned p = cast(Paned) parent;
                if (p !is null) {
                    if (p.getOrientation() == paned.getOrientation()) {
                        result = p;
                    } else {
                        break;
                    }
                }
                parent = cast(Container) parent.getParent();
            }
            return result;
        }

        Paned root = getRootPaned();
        if (root is null)
            return;
        PanedModel model = new PanedModel(root);
        // Model count should never be 0 since root is not null but just in case...
        if (model.count == 0) {
            tracef("Only %d pane, not redistributing", model.count);
            return;
        }
        Value handleSize = new Value(0);
        root.styleGetProperty("handle-size", handleSize);
        tracef("Handle size is %d", handleSize.getInt());

        int size = root.getOrientation() == Orientation.HORIZONTAL ? root.getAllocatedWidth() : root.getAllocatedHeight();
        int baseSize = (size - (handleSize.getInt() * model.count)) / (model.count + 1);
        tracef("Redistributing %d terminals with pos %d out of total size %d", model.count + 1, baseSize, size);

        model.calculateSize(baseSize);
        model.resize();
    }

    /**
     * Creates the terminal widget and wires the various
     * event handlers. Note the terminal widget is a composite
     * widget and not the actual VTE widget provided by GTK.
     *
     * The VTE widget is not exposed to the session.
     */
    Terminal createTerminal(string profileUUID, string uuid = null) {
        // Check that profile exists, if it doesn't use default
        string[] profileUUIDs = prfMgr.getProfileUUIDs();
        string realUUID;
        foreach(pUUID; profileUUIDs) {
            if (pUUID == profileUUID) {
                realUUID = pUUID;
                break;
            }
        }
        if (realUUID.length == 0) {
            warningf("Warning, the profile %s does not exist, using default profile instead", profileUUID);
            realUUID = prfMgr.getDefaultProfile();
        }
        Terminal terminal = new Terminal(realUUID, uuid);
        addTerminal(terminal);
        return terminal;
    }

    /**
     * Adds a new terminal to the session, usually this is a newly
     * created terminal but can also be one attached to this session
     * from another session via DND
     */
    void addTerminal(Terminal terminal) {
        terminal.onClose.connect(&onTerminalClose);
        terminal.onFocusIn.connect(&onTerminalFocusIn);
        terminal.onRequestDetach.connect(&onTerminalRequestDetach);
        terminal.onRequestMove.connect(&onTerminalRequestMove);
        terminal.onSyncInput.connect(&onTerminalSyncInput);
        terminal.onRequestStateChange.connect(&onTerminalRequestStateChange);
        terminal.onTitleChange.connect(&onTerminalTitleChange);
        terminal.onProcessNotification.connect(&onTerminalProcessNotification);
        terminal.onIsActionAllowed.connect(&onTerminalIsActionAllowed);
        terminal.onSessionAttach.connect(&onTerminalSessionAttach);
        terminals ~= terminal;
        terminal.terminalID = terminals.length;
        terminal.synchronizeInput = synchronizeInput;

        foreach (t; terminals) {
            t.isSingleTerminal = (terminals.length == 1);
        }
    }

    /**
     * Closes the terminal and removes it from the session. This can be
     * called when a terminal is closed naturally or when a terminal
     * is removed from the session completely.
     */
    void removeTerminal(Terminal terminal) {
        int id = to!int(terminal.terminalID);
        trace("Removing terminal " ~ terminal.uuid);
        removeTerminalReferences(terminal);
        //If a terminal is maximized restore it before removing
        // so all the parenting can be detected
        Terminal maximizedTerminal;
        if (maximizedInfo.isMaximized) {
            if (maximizedInfo.terminal != terminal) {
                maximizedTerminal = maximizedInfo.terminal;
            }
            restoreTerminal(terminal);
        }
        //unparent the terminal
        unparentTerminal(terminal);
        //Only one terminal open, close session
        tracef("There are %d terminals left", terminals.length);
        if (terminals.length == 0) {
            trace("No more terminals, requesting session be closed");
            notifySessionClose();
            return;
        }

        foreach (t; terminals) {
            t.isSingleTerminal = (terminals.length == 1);
        }

        //Update terminal IDs to fill in hole
        sequenceTerminalID();
        if (mruTerminals.length > 0) {
            focusTerminal(mruTerminals[$-1]);
        } else {
            if (id >= terminals.length)
                id = to!int(terminals.length);
            if (id > 0 && id <= terminals.length) {
                focusTerminal(id);
            }
        }

        if (maximizedTerminal !is null) {
            maximizeTerminal(terminal);
        }
        showAll();
    }

    /**
     * Removes all references to the terminal from the session
     */
    void removeTerminalReferences(Terminal terminal) {
        if (currentTerminal == terminal)
            currentTerminal = null;
        //Remove terminal
        gx.util.array.remove(terminals, terminal);
        gx.util.array.remove(mruTerminals, terminal);

        //Remove delegates
        terminal.onClose.disconnect(&onTerminalClose);
        terminal.onFocusIn.disconnect(&onTerminalFocusIn);
        terminal.onRequestDetach.disconnect(&onTerminalRequestDetach);
        terminal.onRequestMove.disconnect(&onTerminalRequestMove);
        terminal.onSyncInput.disconnect(&onTerminalSyncInput);
        terminal.onRequestStateChange.disconnect(&onTerminalRequestStateChange);
        terminal.onTitleChange.disconnect(&onTerminalTitleChange);
        terminal.onProcessNotification.disconnect(&onTerminalProcessNotification);
        terminal.onIsActionAllowed.disconnect(&onTerminalIsActionAllowed);
        terminal.onSessionAttach.disconnect(&onTerminalSessionAttach);
    }

    /**
     * Find a terminal based on it's UUID
     */
    Terminal findTerminal(string uuid) {
        foreach (terminal; terminals) {
            if (terminal.uuid == uuid)
                return terminal;
        }
        return null;
    }

    /**
     * Adds a new terminal into an existing terminal, by adding
     * a Paned (i.e. Splitter) and then placing the original terminal and a
     * new terminal in the new Paned.
     *
     * Note that we do not insert the Terminal widget directly into a Paned,
     * instead a Box is added first as a shim. This is required so that if the
     * user adds a new terminal again, the box forces the parent Paned to keep
     * it's layout while we remove the terminal and insert a new Paned in it's
     * spot. Without this shim the layout becomes screwed up.
     *
     * If there is some magic way in GTK to do this without the extra Box shim
     * it would be nice to eliminate this.
     */
    void addNewTerminal(Terminal terminal, Orientation orientation) {
        trace("Splitting Terminal " ~ to!string(terminal.terminalID));
        Terminal newTerminal = createTerminal(terminal.defaultProfileUUID);
        trace("Inserting terminal");
        insertTerminal(terminal, newTerminal, orientation, 2);
        trace("Initializing terminal with " ~ terminal.currentLocalDirectory);
        newTerminal.initTerminal(terminal.currentLocalDirectory, false);
    }

    /**
     * Removes a terminal from it's parent and cleans up splitter if necessary
     * Note that this does not unset event handlers or do any other cleanup as
     * this method is used both when moving and closing terminals.
     *
     * This is a bit convoluted since we are using Box as a shim to
     * preserve spacing. Every child widget is embeded in a Box which
     * is then embeded in a Paned. So an example heirarchy would be as follows:
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

            //If terminal is maximized we can short-circuit check since
            // we know terminal's parent already
            if (maximizedInfo.isMaximized) {
                return equal(box1, maximizedInfo.parent) ? box2 : box1;
            }

            Widget widget1 = gx.gtk.util.getChildren!(Widget)(box1, false)[0];

            Terminal terminal1 = cast(Terminal) widget1;

            int result = terminal == terminal1 ? 1 : 2;
            return (result == 1 ? box2 : box1);
        }

        Paned paned;
        if (maximizedInfo.isMaximized && terminal.uuid == maximizedInfo.terminal.uuid) {
            paned = cast(Paned) maximizedInfo.parent.getParent();
        } else {
            paned = cast(Paned) terminal.getParent().getParent();
        }
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
        Widget widget = gx.gtk.util.getChildren!(Widget)(otherBox, false)[0];
        //Remove widget from original Box parent
        otherBox.remove(widget);
        //Add widget to new parent
        parent.add(widget);
        //Clean up terminal parent, use container as base class since
        //terminal can be parented to either Box or Stack which both
        //descend from Container
        Container container = cast(Container) terminal.getParent();
        container.remove(terminal);
        container.destroy();
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

        Paned paned = createPaned(orientation);
        paned.pack1(b1, PANED_RESIZE_MODE, PANED_SHRINK_MODE);
        paned.pack2(b2, PANED_RESIZE_MODE, PANED_SHRINK_MODE);

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
        //Fix for issue #33
        focusTerminal(src.terminalID);
    }

    void onTerminalRequestMove(string srcUUID, Terminal dest, DragQuadrant dq) {

        Session getSession(Terminal terminal) {

            Widget widget = terminal.getParent();
            while (widget !is null) {
                Session result = cast(Session) widget;
                if (result !is null)
                    return result;
                widget = widget.getParent();
            }
            return null;
        }

        tracef("Moving terminal %d to quadrant %d", dest.terminalID, dq);
        Terminal src = findTerminal(srcUUID);
        // If terminal is not null, its from this session. If it
        // is null then dropped from a different session, maybe different window
        if (src !is null) {
            unparentTerminal(src);
        } else {
            trace("Moving terminal from different session");
            src = cast(Terminal) tilix.findWidgetForUUID(srcUUID);
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

    void closeTerminal(Terminal terminal) {
        removeTerminal(terminal);
        terminal.finalizeTerminal();
        //Try to avoid destroying things explicitly due to GtkD issue
        terminal.destroy();
    }

    /**
     * Event handler that get's called when Terminal is closed
	 */
    void onTerminalClose(Terminal terminal) {
        closeTerminal(terminal);
    }

    void onTerminalProcessNotification(string summary, string _body, string uuid, string sessionUUID = null) {
        notifyProcessNotification(summary, _body, uuid, _sessionUUID);
    }

    void onTerminalIsActionAllowed(ActionType actionType, CumulativeResult!bool result) {
        switch (actionType) {
        case ActionType.DETACH_TERMINAL:
            //Ok this is a bit weird but we only allow a terminal to be detached
            //if a session has more then one terminal in it OR the application
            //has multiple sessions.
            result.addResult(terminals.length > 1 || notifyIsActionAllowed(ActionType.DETACH_TERMINAL));
            break;
        default:
            result.addResult(false);
            break;
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

    void onTerminalSessionAttach(Terminal terminal, string sessionUUID) {
        onAttach.emit(sessionUUID);
    }

    void onTerminalFocusIn(Terminal terminal) {
        //trace("Focus noted");
        currentTerminal = terminal;
        gx.util.array.remove(mruTerminals, terminal);
        mruTerminals ~= terminal;
        notifySessionStateChange(SessionStateChange.TERMINAL_FOCUSED);
    }

    void onTerminalSyncInput(Terminal originator, SyncInputEvent event) {
        //trace("Got sync input event");
        foreach (terminal; terminals) {
            if (terminal.synchronizeInput && terminal.uuid != event.senderUUID) {
                terminal.handleSyncInput(event);
            }
        }
    }

    /**
     * Catch terminal title change events to propagate up to to application so
     * it can set it's title.
     */
    void onTerminalTitleChange(Terminal terminal) {
        if (terminal == currentTerminal) {
            onStateChange.emit(this, SessionStateChange.TERMINAL_TITLE);
        }
    }

    /**
     * Catch session title change events to propagate up to to application so
     * it can set it's title.
     */
    void onSessionTitleChange() {
        trace("Session title changed");
        onStateChange.emit(this, SessionStateChange.SESSION_TITLE);
    }

    bool maximizeTerminal(Terminal terminal) {
        if (terminals.length == 1) {
            trace("Only one terminal in session, ignoring maximize request");
            return false;
        }
        //Already have a maximized terminal
        if (maximizedInfo.isMaximized) {
            error("A Terminal is already maximized, ignoring");
            return false;
        }
        trace("Maximizing terminal");
        maximizedInfo.terminal = terminal;
        maximizedInfo.parent = cast(Box) terminal.getParent();
        maximizedInfo.isMaximized = true;
        maximizedInfo.parent.remove(terminal);
        stackMaximized.add(terminal);
        trace("Switching stack to maximized page");
        terminal.show();
        setVisibleChild(stackMaximized);
        notifySessionStateChange(SessionStateChange.TERMINAL_MAXIMIZED);
        return true;
    }

    /**
     * Swaps the maximized terminal for a new one
     */
    bool swapMaximized(Terminal terminal) {
        if (!maximizedInfo.isMaximized) {
            error("No terminal is not maximized, ignoring");
            return false;
        }
        if (maximizedInfo.terminal == terminal) {
            error("The terminal is already maximized, ignoring");
            return false;
        }
        //Restore old terminal
        maximizedInfo.terminal.toggleMaximize;
        terminal.toggleMaximize;
        return true;
    }

    bool restoreTerminal(Terminal terminal) {
        if (!maximizedInfo.isMaximized) {
            error("No terminal is not maximized, ignoring");
            return false;
        }
        if (maximizedInfo.terminal != terminal) {
            error("A different Terminal is maximized, ignoring");
            return false;
        }
        trace("Restoring terminal");
        stackMaximized.remove(maximizedInfo.terminal);
        maximizedInfo.parent.add(maximizedInfo.terminal);
        maximizedInfo.isMaximized = false;
        maximizedInfo.parent = null;
        maximizedInfo.terminal = null;
        setVisibleChild(stackGroup);
        notifySessionStateChange(SessionStateChange.TERMINAL_RESTORED);
        return true;
    }

    /**
     * Manages changing a terminal from maximized to normal
     */
    void onTerminalRequestStateChange(Terminal terminal, TerminalWindowState state, CumulativeResult!bool results) {
        trace("Changing window state");
        bool result;
        if (state == TerminalWindowState.MAXIMIZED) {
            result = maximizeTerminal(terminal);
        } else {
            result = restoreTerminal(terminal);
        }
        terminal.focusTerminal();
        results.addResult(result);
    }

    void applyPreference(string key) {
        switch (key) {
            case SETTINGS_ENABLE_WIDE_HANDLE_KEY:
                if (Version.checkVersion(3, 16, 0).length == 0) {
                    updateWideHandle(gsSettings.getBoolean(SETTINGS_ENABLE_WIDE_HANDLE_KEY));
                }
                break;
            case SETTINGS_SESSION_NAME_KEY:
                name = gsSettings.getString(SETTINGS_SESSION_NAME_KEY);
                onStateChange.emit(this, SessionStateChange.SESSION_TITLE);
                break;
            default:
                break;
        }
    }

/************************************************
 * De/Serialization code in this private block
 ************************************************/
private:

    string _filename;
    string maximizedUUID;

    enum NODE_TYPE = "type";
    enum NODE_NAME = "name";
    enum NODE_ORIENTATION = "orientation";
    enum NODE_SCALED_POSITION = "position";
    enum NODE_CHILD = "child";
    enum NODE_CHILD1 = "child1";
    enum NODE_CHILD2 = "child2";
    enum NODE_DIRECTORY = "directory";
    enum NODE_PROFILE = "profile";
    enum NODE_MAXIMIZED = "maximized";
    enum NODE_WIDTH = "width";
    enum NODE_HEIGHT = "height";
    enum NODE_SYNCHRONIZED_INPUT = "synchronizedInput";
    enum NODE_RATIO = "ratio";
    enum NODE_UUID = "uuid";

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
        else if (cast(TerminalPaned) widget !is null)
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
            serializePaned(value, cast(TerminalPaned) widget, sizeInfo);
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
    JSONValue serializePaned(JSONValue value, TerminalPaned paned, SessionSizeInfo sizeInfo) {

        /**
         * Added to check for maximized state and grab right terminal
         */
        void serializeBox(string node, Box box) {
            Widget[] widgets = gx.gtk.util.getChildren!(Widget)(box, false);
            if (widgets.length == 0 && maximizedInfo.isMaximized && equal(box, maximizedInfo.parent)) {
                value.object[node] = serializeWidget(maximizedInfo.terminal, sizeInfo);
            } else {
                value.object[node] = serializeWidget(widgets[0], sizeInfo);
            }
        }

        value[NODE_ORIENTATION] = JSONValue(paned.getOrientation());
        //Switch to integer to fix Issue #49 and work around D std.json bug
        int positionPercent = to!int(sizeInfo.scalePosition(paned.getPosition, paned.getOrientation()) * 100);
        value[NODE_SCALED_POSITION] = JSONValue(positionPercent);
        value[NODE_TYPE] = WidgetType.PANED;
        value[NODE_RATIO] = JSONValue(paned.ratio);
        Box box1 = cast(Box) paned.getChild1();
        serializeBox(NODE_CHILD1, box1);
        Box box2 = cast(Box) paned.getChild2();
        serializeBox(NODE_CHILD2, box2);
        return value;
    }

    /**
     * Serialize the TerminalPane widget
     */
    JSONValue serializeTerminal(JSONValue value, Terminal terminal) {
        value[NODE_PROFILE] = terminal.defaultProfileUUID;
        value[NODE_DIRECTORY] = terminal.currentLocalDirectory;
        value[NODE_WIDTH] = JSONValue(terminal.getAllocatedWidth());
        value[NODE_HEIGHT] = JSONValue(terminal.getAllocatedHeight());
        value[NODE_UUID] = terminal.uuid;
        if (maximizedInfo.isMaximized && equal(terminal, maximizedInfo.terminal)) {
            value[NODE_MAXIMIZED] = JSONValue(true);
        }
        return terminal.serialize(value);
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
        string uuid;
        if (NODE_UUID in value) {
            uuid = value[NODE_UUID].str();
        }
        Terminal terminal = createTerminal(profileUUID, uuid);
        terminal.deserialize(value);
        terminal.initTerminal(value[NODE_DIRECTORY].str(), false);
        if (NODE_MAXIMIZED in value && value[NODE_MAXIMIZED].type == JSON_TYPE.TRUE) {
            maximizedUUID = terminal.uuid;
        }
        return terminal;
    }

    /**
     * De-serialize a Paned widget
     */
    Paned parsePaned(JSONValue value, SessionSizeInfo sizeInfo) {
        trace("Loading paned");
        Orientation orientation = cast(Orientation) value[NODE_ORIENTATION].integer();
        TerminalPaned paned = createPaned(orientation);
        Box b1 = new Box(Orientation.VERTICAL, 0);
        b1.add(parseNode(value[NODE_CHILD1], sizeInfo));
        Box b2 = new Box(Orientation.VERTICAL, 0);
        b2.add(parseNode(value[NODE_CHILD2], sizeInfo));
        paned.pack1(b1, PANED_RESIZE_MODE, PANED_SHRINK_MODE);
        paned.pack2(b2, PANED_RESIZE_MODE, PANED_SHRINK_MODE);
        // Fix for issue #49
        JSONValue position = value[NODE_SCALED_POSITION];
        double percent;
        if (position.type == JSON_TYPE.FLOAT) {
            percent = value[NODE_SCALED_POSITION].floating();
        } else {
            percent = to!double(value[NODE_SCALED_POSITION].integer) / 100.0;
        }
        int pos = sizeInfo.getPosition(percent, orientation);
        if (NODE_RATIO in value) {
            double ratio = value[NODE_RATIO].floating;
            paned.ratio = ratio;
        } else {
            paned.ignoreRatio = true;
        }
        tracef("Paned position %f percent, %d px, %f ratio", percent, pos, paned.ratio);
        paned.setPosition(pos);
        return paned;
    }

    /**
     * De-serialize a session
     */
    void parseSession(JSONValue value, SessionSizeInfo sizeInfo) {
        maximizedUUID.length = 0;
        _name = value[NODE_NAME].str();
        if (NODE_SYNCHRONIZED_INPUT in value) {
            _synchronizeInput = value[NODE_SYNCHRONIZED_INPUT].type == JSON_TYPE.TRUE;
        }
        if (NODE_UUID in value) {
            _sessionUUID = value[NODE_UUID].str();
        }
        JSONValue child = value[NODE_CHILD];
        trace(child.toPrettyString());
        groupChild.add(parseNode(child, sizeInfo));

        if (maximizedUUID.length > 0) {
            Terminal terminal = findTerminal(maximizedUUID);
            if (terminal !is null) {
                trace("Maximizing terminal " ~ maximizedUUID);
                terminal.toggleMaximize();
            }
        }
    }

private:

    /**
     * Creates a new session with the specified terminal
     */
    this(string sessionName, Terminal terminal) {
        super();
        initSession();
        createBaseUI();
        _sessionUUID = randomUUID().toString();
        _name = sessionName;
        addTerminal(terminal);
        createUI(terminal);
    }

    void initSession() {

        gsSettings = new GSettings(SETTINGS_ID);
        gsSettings.addOnChanged(delegate(string key, GSettings) {
            applyPreference(key);
        });
        getStyleContext.addClass("tilix-background");

        addOnDraw(&onDraw);
    }

    bool onDraw(Scoped!Context cr, Widget w) {
        AppWindow window = cast(AppWindow)getToplevel();
        if (window is null) return false;
        Container child = cast(Container) getVisibleChild();
        if (child is null) return false;

        //Cached render
        ImageSurface isBGImage = window.getBackgroundImage(child);
        if (isBGImage is null) return false;

        cr.save();
        cr.setSourceSurface(isBGImage, 0, 0);
        // Line below was causing issue for #83-, doesn't seem to be any ill effect removing it
        //cr.setOperator(cairo_operator_t.SOURCE);
        cr.paint();

        //Draw child onto temporary image so it doesn't overdraw background
        ImageSurface isChildSurface = ImageSurface.create(cairo_format_t.ARGB32, child.getAllocatedWidth(), child.getAllocatedHeight());
        Context crChild = Context.create(isChildSurface);
        scope (exit) {
            crChild.destroy();
            isChildSurface.destroy();
        }
        propagateDraw(child, crChild);
        cr.setSourceSurface(isChildSurface, 0, 0);
        cr.setOperator(cairo_operator_t.OVER);
        cr.paint();

        cr.restore();
        return true;
    }

    void updateWideHandle(bool value) {
        if (Version.checkVersion(3, 16, 0).length == 0) {
            Paned[] all = gx.gtk.util.getChildren!(Paned)(stackGroup, true);
            tracef("Updating wide handle for %d paned", all.length);
            foreach (paned; all) {
                paned.setWideHandle(value);
            }
        }
    }

public:

    /**
     * Creates a new session
     *
     * Params:
     *  name        = The name of the session
     */
    this(string name) {
        super();
        initSession();
        createBaseUI();
        _sessionUUID = randomUUID().toString();
        _name = name;

        this.addOnDestroy(delegate(Widget) {
            // Never use experimental logging in destructors, causes
            // memory exceptions on GC for some reason

            //Clean up terminal references
            foreach(terminal; terminals) {
                //trace("Removing terminal reference");
                removeTerminalReferences(terminal);
            }

            terminals.length = 0;
            mruTerminals.length = 0;

            gsSettings.destroy();
            gsSettings = null;
        });
    }

    debug(Destructors) {
        ~this() {
            import std.stdio: writeln;
            writeln("********** Session destructor");
        }
    }

    /**
     * Initializes a new session
     *
     * Params:
     *  name        = The name of the session
     *  profileUUID = The profile to use when creating the initial terminal for the session
     *  workingDir  = The working directory to use in the initial terminal
     *  firstRun    = A flag to indicate this is the first session for the app, used to determine if geometry is set based on profile
     */
    void initSession(string profileUUID, string workingDir, bool firstRun) {
        createUI(profileUUID, workingDir, firstRun);
    }

    /**
     * Initializes a new session by de-serializing a session from JSON
     *
     * TODO Determine whether we need to support concept of firstRun for loading session
     *
     * Params:
     *  value       = The root session node of the JSON block used to for deserialization
     *  filename    = The filename corresponding to the JSON block
     *  width       = The expected width and height of the session, used to scale Paned positions
     *  firstRun    = A flag to indicate this is the first session for the app, used to determine if geometry is set based on profile
     */
    void initSession(JSONValue value, string filename, int width, int height, bool firstRun) {
        try {
            tracef("Parsing session %s with dimensions %d,%d", filename, width, height);
            parseSession(value, SessionSizeInfo(width, height));
            _filename = filename;
        }
        catch (Exception e) {
            error("Session could not be created due to error", e);
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

    ITerminal getActiveTerminal() {
        if (currentTerminal !is null)
            return currentTerminal;
        else
            return null;
    }

    /**
     * Called when the session becomes active,
     * i.e. is visible to the user
     *
     * Can't rely on events like map or realized because
     * thumbnail drawing triggers them.
     */
    void notifyActive() {
        foreach (terminal; terminals) {
            terminal.notifySessionActive();
        }
    }

    /**
     * Serialize the session
     *
     * Returns:
     *  The JSON representation of the session
     */
    JSONValue serialize() {

        // Force all Paned to update their ratios, needed when upgrading from pre-ratio files
        TerminalPaned[] panes = gx.gtk.util.getChildren!TerminalPaned(stackGroup, true);
        foreach(paned; panes) {
            trace("Updating paned position after session load");
            paned.updateRatio();
        }

        // Make sure that generated JSON won't be locale-specific
        setlocale(LC_ALL, "C");
        JSONValue root = ["version" : "1.0"];
        root.object[NODE_NAME] = _name;
        root.object[NODE_SYNCHRONIZED_INPUT] = _synchronizeInput;
        root.object[NODE_WIDTH] = JSONValue(getAllocatedWidth());
        root.object[NODE_HEIGHT] = JSONValue(getAllocatedHeight());
        SessionSizeInfo sizeInfo = SessionSizeInfo(getAllocatedWidth(), getAllocatedHeight());
        root.object[NODE_CHILD] = serializeWidget(gx.gtk.util.getChildren!(Widget)(groupChild, false)[0], sizeInfo);
        root.object[NODE_UUID] = _sessionUUID;
        root[NODE_TYPE] = WidgetType.SESSION;
        setlocale(LC_ALL, null);
        return root;
    }

    static void getPersistedSessionSize(JSONValue value, out int width, out int height) {
        try {
            width = to!int(value[NODE_WIDTH].integer());
            height = to!int(value[NODE_HEIGHT].integer());
        }
        catch (Exception e) {
            throw new SessionCreationException("Session could not be created due to error: " ~ e.msg, e);
        }
    }

    /**
     * Takes a string with tokens/variables like ${title} and
     * performs the substitution to get the displayed title.
     *
     * This is public because the window can use it to resolve these variables
     * for the active terminal for it's own name shown in the sidebar.
     */
    string getDisplayText(string text) {
        string result = text;
        result = result.replace(VARIABLE_TERMINAL_COUNT, to!string(terminals.length));

        if (currentTerminal !is null) {
            result = result.replace(VARIABLE_ACTIVE_TERMINAL_TITLE, currentTerminal.title);
            result = result.replace(VARIABLE_TERMINAL_NUMBER, to!string(currentTerminal.terminalID));
            result = currentTerminal.getDisplayText(result);
        } else {
            result = result.replace(VARIABLE_TERMINAL_NUMBER, "");
            result = result.replace(VARIABLE_ACTIVE_TERMINAL_TITLE, "");
        }
        return result;
    }

    @property string displayName() {
        string result;
        if (currentTerminal is null) result = name;
        else result = currentTerminal.getDisplayText(name);
        // If it is using Default from preferences localize it
        if (result == "Default") return _("Default");
        else return result;
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
            onSessionTitleChange();
        }
    }

    /**
     * Unique and immutable session ID
     */
    @property string uuid() {
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
     * Used to support re-parenting to enable a thumbnail
     * image to be drawn off screen
     */
    @property Widget drawable() {
        if (maximizedInfo.isMaximized) {
            return maximizedInfo.terminal;
        } else {
            return groupChild;
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
     * Returns information about any running processes in the terminal.
     */
    ProcessInformation getProcessInformation() {
        ProcessInformation result = ProcessInformation(ProcessInfoSource.SESSION, displayName, uuid, []);
        foreach (terminal; terminals) {
            string name;
            if (terminal.isProcessRunning(name)) {
                result.children ~= ProcessInformation(ProcessInfoSource.TERMINAL,
                                                      (name.length > 0? name:terminal.getDisplayText(name)),
                                                      terminal.uuid,
                                                      []);
            }
        }
        return result;
    }

    /**
     * Resize terminal based on direction
     */
    void resizeTerminal(string direction) {
        Terminal terminal = currentTerminal;
        if (terminal !is null) {
            Container parent = cast(Container) terminal;
            int increment = 10;
            if (direction == "up" || direction == "left")
                increment = -increment;
            while (parent !is null) {
                TerminalPaned paned = cast(TerminalPaned) parent;
                trace("Testing Paned");
                if (paned !is null) {
                    if ((direction == "up" || direction == "down") && paned.getOrientation() == Orientation.VERTICAL) {
                        trace("Resizing " ~ direction);
                        paned.setPosition(paned.getPosition() + increment);
                        paned.updateRatio();
                        return;
                    } else if ((direction == "left" || direction == "right") && paned.getOrientation() == Orientation.HORIZONTAL) {
                        trace("Resizing " ~ direction);
                        paned.setPosition(paned.getPosition() + increment);
                        paned.updateRatio();
                        return;
                    }
                }
                parent = cast(Container) parent.getParent();
            }
        }
    }

    /**
     * Restore focus to the terminal that last had focus in the session
     */
    void focusRestore() {
        if (currentTerminal !is null) {
            trace("Restoring focus to terminal");
            currentTerminal.focusTerminal();
        }
    }

    /**
     * Focus the next terminal in the session
     */
    void focusNext() {
        size_t id = 1;
        if (currentTerminal !is null) {
            id = currentTerminal.terminalID + 1;
            if (id > terminals.length)
                id = 1;
        }
        focusTerminal(id);
    }

    /**
     * Focus the previous terminal in the session
     */
    void focusPrevious() {
        size_t id = 1;
        if (currentTerminal !is null) {
            id = currentTerminal.terminalID;
            if (id == 1)
                id = terminals.length;
            else
                id--;
        }
        focusTerminal(id);
    }

    /**
     * Focus terminal in the session by direction
     */
    void focusDirection(string direction) {
        trace("Focusing ", direction);

        Widget appWindow = currentTerminal.getToplevel();
        GtkAllocation appWindowAllocation;
        appWindow.getClip(appWindowAllocation);

        // Start at the top left of the current terminal
        int xPos, yPos;
        currentTerminal.translateCoordinates(appWindow, 0, 0, xPos, yPos);
        //Offset 5 pixels to avoid edge matches
        xPos = xPos + 5;
        yPos = yPos + 5;

        // While still in the application window, move 20 pixels per loop
        while (xPos >= 0 && xPos < appWindowAllocation.width && yPos >= 0 && yPos < appWindowAllocation.height) {
            switch (direction) {
            case "up":
                yPos -= 20;
                break;
            case "down":
                yPos += 20;
                break;
            case "left":
                xPos -= 20;
                break;
            case "right":
                xPos += 20;
                break;
            default:
                break;
            }

            // If the x/y position lands in another terminal, focus it
            foreach (terminal; terminals) {
                if (terminal == currentTerminal)
                    continue;

                int termX, termY;
                terminal.translateCoordinates(appWindow, 0, 0, termX, termY);

                GtkAllocation termAllocation;
                terminal.getClip(termAllocation);

                if (xPos >= termX && yPos >= termY && xPos <= (termX + termAllocation.width) && yPos <= (termY + termAllocation.height)) {
                    focusTerminal(terminal);
                    return;
                }
            }
        }
    }

    bool focusTerminal(Terminal terminal) {
        if (maximizedInfo.isMaximized && maximizedInfo.terminal != terminal) {
            return swapMaximized(terminal);
        }
        terminal.focusTerminal();
        return true;
    }

    /**
     * Focus the terminal designated by the ID
     */
    bool focusTerminal(size_t terminalID) {
        if (terminalID > 0 && terminalID <= terminals.length) {
            return focusTerminal(terminals[terminalID - 1]);
        }
        return false;
    }

    /**
     * Focus the terminal designated by the UUID
     */
    bool focusTerminal(string uuid) {
        foreach (terminal; terminals) {
            if (terminal.uuid == uuid) {
                return focusTerminal(terminal);
            }
        }
        return false;
    }

    void toggleTerminalFind() {
        if (currentTerminal !is null) {
            currentTerminal.toggleFind();
        }
    }

    /**
     * Adds a new terminal to the currently focused terminal
     */
    void addTerminal(Orientation orientation) {
        if (currentTerminal !is null) {
            addNewTerminal(currentTerminal, orientation);
        }
    }

    @property bool maximized() {
        return maximizedInfo.isMaximized;
    }

//Events
public:

    /**
    * An event that occurs when the session closes, the application window
    * listens to this event and removes the session when received.
    */
    GenericEvent!(Session) onClose;

    /**
     * Occurs when a terminal is detached.
     *
     * Params:
     *  Session = The session that is being detached
     *  x = x position where to detach
     *  y = y position where to detach
     *  isNewSession = Whether this is a new session
     */
    GenericEvent!(Session, int, int, bool) onDetach;

    /**
     * Occurs when a session requests to be attached
     *
     * Params:
     *  sessionUUID = The UUID of the session to be attached
     */
    GenericEvent!(string) onAttach;

    /**
     * Triggered when state changes, such as title, occur
     */
    GenericEvent!(Session, SessionStateChange) onStateChange;

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

immutable bool PANED_RESIZE_MODE = false;
immutable bool PANED_SHRINK_MODE = false;

/**
 * Subclass of Paned that maintains a precise ratio split between
 * children as the Paned is re-size (i.e. resizing the window the Paned is
 * a part of. GTK seems to grow one side versus the other for a slight amount
 * without this compensation in place.
 */
class TerminalPaned : Paned {

private:
    double _ratio = 0.5;
    int lastWidth, lastHeight;
    bool _ignoreRatio;

public:
    this(Orientation orientation) {
        super(orientation);
        addOnSizeAllocate(delegate(GdkRectangle* rect, Widget) {
            updatePosition();
        });

        addOnButtonRelease(delegate(Event event, Widget w) {
            updateRatio();
            return false;
        });

        addOnAcceptPosition(delegate(Paned) {
            updateRatio();
            return false;
        });
    }

    void updateRatio() {
        //trace("Updating ratio");
        double newRatio = ratio;
        if (getOrientation() == Orientation.HORIZONTAL) {
            newRatio = to!double(getChild1().getAllocatedWidth()) / to!double(getAllocatedWidth());
            //tracef("Child1 Width=%d, Paned Width=%d, newRatio=%f",getChild1().getAllocatedWidth(),getAllocatedWidth(), newRatio);
        } else {
            newRatio = to!double(getChild1().getAllocatedHeight()) / to!double(getAllocatedHeight());
            //tracef("Child1 Height=%d, Paned Height=%d, newRatio=%f",getChild1().getAllocatedHeight(),getAllocatedHeight(), newRatio);
        }
        if (newRatio > 0.0 && newRatio < 1.0) {
            ratio = newRatio;
            //tracef("New TerminalPaned ratio %f", ratio);
        }
    }

    void updatePosition(bool force = false) {
        if (ignoreRatio) return;
        //tracef("TerminalPaned Size allocated, ratio %f", ratio);
        if (getOrientation() == Orientation.HORIZONTAL) {
            if (force || lastWidth != getAllocatedWidth()) {
                int position = to!int(to!double(getAllocatedWidth()) * ratio);
                setPosition(position);
                //tracef("Ratio=%f, Position=%d, lastWidth=%d, AllocatedWidth=%d", ratio, position, lastWidth, getAllocatedWidth());
                lastWidth = getAllocatedWidth();

            }
        } else {
            if (force || lastHeight != getAllocatedHeight()) {
                setPosition(to!int(getAllocatedHeight() * ratio));
                lastHeight = getAllocatedHeight();
            }
        }
    }

    @property double ratio() {
        return _ratio;
    }

    @property void ratio(double value) {
        _ratio = value;
    }

    /**
     * This gets set when an older serialized session file
     * is loaded without the ratio property in the JSON.
     * If the user saves it again it gets upgraded to includes
     * the ratio automatically.
     *
     * When set the paned position is not updated based on the
     * ratio, so pre-tilix 1.4.0 behavior. See issue #613
     */
    @property bool ignoreRatio() {
        return _ignoreRatio;
    }

    @property ignoreRatio(bool value) {
        _ignoreRatio = value;
    }
}

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

/**
 * When a terminal is maximized, this remembers where
 * the terminal was parented as well as any other useful
 * info.
 */
struct MaximizedInfo {
    bool isMaximized;
    Box parent;
    Terminal terminal;
}

/**
 * The PanedModel is a binary tree used to calculate sizing model for redistributing GTKPaned used
 * in a session evenly. Since GTKPaned only supports two children, the session creates a nested
 * heirarchy of GTKPaned widgets embedded within each other. Each child of the Paned (child1/child2) can
 * be either a Paned or a Terminal.
 *
 * In the model if a child is a terminal it is simply represented as a null. Once we have the model,
 * we can simply walk recursively to calculate the size of each pane and the position of the splitter. The first
 * step is calculate the base size, this is simply the available space divided by the number of panes.
 * The position of each pane is calculated by looking at the size of the children.
 */
class PanedModel {

private:

    PanedNode root;
    int _count = 0;

    PanedNode createModel(Paned node) {
        _count++;
        PanedNode result = new PanedNode(node);
        Box box1 = cast(Box) node.getChild1();
        Box box2 = cast(Box) node.getChild2();
        Paned[] paned1 = gx.gtk.util.getChildren!(Paned)(box1, false);
        Paned[] paned2 = gx.gtk.util.getChildren!(Paned)(box2, false);
        if (paned1.length > 0 && paned1[0].getOrientation() == node.getOrientation())
            result.child[0] = createModel(paned1[0]);
        if (paned2.length > 0 && paned2[0].getOrientation() == node.getOrientation())
            result.child[1] = createModel(paned2[0]);
        return result;
    }

    /**
     * Return the height (i.e. depth) of the tree
     */
    int getHeight(PanedNode node) {
        if (node is null) {
            return 0;
        } else {
            int[2] heights;
            foreach (i, childNode; node.child) {
                heights[i] = childNode is null ? 0 : getHeight(childNode);
            }
            return max(heights[0], heights[1]) + 1;
        }
    }

    /**
     * Itertate over the tree recursively and calculate the size
     * for each branch
     */
    void calculateSize(PanedNode node, int baseSize) {
        if (node is null)
            return;
        int size = 0;
        foreach (i, childNode; node.child) {
            if (childNode is null)
                size = size + baseSize;
            else {
                calculateSize(childNode, baseSize);
                size = size + childNode.size;
            }
        }
        node.size = size;
        node.pos = (node.child[0] is null ? baseSize : node.child[0].size);
    }

    /**
     * Get all branches at a specific level
     */
    PanedNode[] getBranch(PanedNode node, int level) {
        PanedNode[] result;
        if (node is null)
            return result;
        if (level == 0) {
            return [node];
        } else {
            foreach (childNode; node.child) {
                result ~= getBranch(childNode, level - 1);
            }
        }
        return result;
    }

    /**
     * Perform the resize by iterating over the tree from the highest branch (0) to
     * the lowest (X). This follows the pattern of the outermost pane to the innermost which
     * you have to do since inner panes may not have space for their size allocation until
     * outer ones are re-sized first.
     */
    void resize(PanedNode node) {
        trace("Resizing panes for redistribution");
        for (int i = 0; i < height; i++) {
            PanedNode[] nodes = getBranch(root, i);
            tracef("Branch %d has %d nodes", i, nodes.length);
            foreach (n; nodes) {
                tracef("    1st pass, Node set to pos %d from pos %d", n.pos, n.paned.getPosition());
                n.paned.setPosition(n.pos);
                // Add idle handler to reset child properties and take one more stab at setting position. GTKPaned
                // is annoying about doing things behind your back
                threadsAddIdleDelegate(delegate() {
                    tracef("    2nd pass, Node set to pos %d from pos %d", n.pos, n.paned.getPosition());
                    n.paned.setPosition(n.pos);
                    n.paned.childSetProperty(n.paned.getChild1(), "resize", new Value(PANED_RESIZE_MODE));
                    n.paned.childSetProperty(n.paned.getChild2(), "resize", new Value(PANED_RESIZE_MODE));
                    return false;
                });
            }
        }
    }

    void updateResizeProperty(PanedNode node) {
        trace("Updating resize property");
        //Thanks to tip from egmontkob, see issue https://github.com/gnunn1/tilix/issues/161
        node.paned.childSetProperty(node.paned.getChild1(), "resize", new Value(false));
        node.paned.childSetProperty(node.paned.getChild2(), "resize", new Value(true));
        foreach(child; node.child) {
            if (child !is null) {
                updateResizeProperty(child);
            }
        }
    }

    void updateIgnoreRatio(PanedNode node, bool value) {
        TerminalPaned paned = cast(TerminalPaned)node.paned;
        if (paned !is null) {
            paned.ignoreRatio = value;
            if (!value) paned.updateRatio();
        }
        foreach(child; node.child) {
            if (child !is null) {
                updateIgnoreRatio(child, value);
            }
        }
    }

public:

    this(Paned paned) {
        this.root = createModel(paned);
    }

    void calculateSize(int baseSize) {
        calculateSize(root, baseSize);
    }

    void resize() {
        //updateIgnoreRatio(root, true);
        updateResizeProperty(root);
        resize(root);
        //updateIgnoreRatio(root, false);
    }

    @property int height() {
        return getHeight(root);
    }

    @property int count() {
        return _count;
    }
}

/**
 * Represents a single Paned widget, or branch in the model
 */
class PanedNode {
    Paned paned;
    int size;
    int pos;
    PanedNode[2] child;

    this(Paned paned) {
        this.paned = paned;
    }
}
