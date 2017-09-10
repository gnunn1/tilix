/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.common;

import std.algorithm;
import std.experimental.logger;
import std.signals;
import std.string;

import gx.util.array;

/**************************************************************
 * This block defines some generic signal handling based on D's
 * std.Signals package. All of the internal D's signals use this
 * as a way to communicate with each other. This is new since
 * version 1.40. The old way of using delegates had a memory leak
 * issue associated with it, not sure if it's a D bug or something
 * in the code. However was wanting to switch to this for awhile so
 * made sense to change anyway.
 **************************************************************/
public:

/**
 * Generic signal struct
 */
struct GenericEvent(TArgs...) {
  mixin Signal!TArgs;
}

/**
 * D's signals and slots do not allow you to return a value. Toggles
 * workaround it, this template can be passed as a parameter to
 * the signal and then thevarious listeners can add their results to
 * it.
 */
class CumulativeResult(T) {
private:
    T[] results;

public:

    T[] getResults() {
        return results;
    }

    void addResult(T value) {
        results ~= value;
    }

    bool isAnyResult(T value) {
        foreach(result; results) {
            if (result == value) return true;
        }
        return false;
    }
}


/***********************************************************
 * Function for parsing out the username, hostname and
 * directory from a string in the format
 * 'user@hostname:directory' where the various parts are
 * optional but the delimiters are not
 ***********************************************************/

void parsePromptParts(string prompt, out string username, out string hostname, out string directory) {
    if (prompt.length == 0) return;
    ptrdiff_t userStarts = prompt.indexOf('@');
    ptrdiff_t dirStarts = prompt.indexOf(':');

    if (userStarts > 0) {
        username = prompt[0..userStarts];
    }
    if (dirStarts >= 0) {
        hostname = prompt[max(0, userStarts + 1)..dirStarts];
    } else {
        hostname = prompt[max(0, userStarts + 1)..prompt.length];
    }
    if (dirStarts >=0 ) {
        directory = prompt[max(0, dirStarts + 1)..prompt.length];
    }
}

unittest {
    string username, hostname, directory;
    // Test full prompt
    parsePromptParts("gnunn@macbook:/home/gnunn", username, hostname, directory);
    trace(format("user=%s, host=%s, dir=%s", username, hostname, directory));
    assert(username == "gnunn");
    assert(hostname == "macbook");
    assert(directory == "/home/gnunn");
    // Test username missing
    parsePromptParts("macbook:/home/gnunn", username, hostname, directory);
    trace(format("user=%s, host=%s, dir=%s", username, hostname, directory));
    assert(username.length == 0);
    assert(hostname == "macbook");
    assert(directory == "/home/gnunn");
    // Test username missing, but user delimiter present
    parsePromptParts("@macbook:/home/gnunn", username, hostname, directory);
    trace(format("user=%s, host=%s, dir=%s", username, hostname, directory));
    assert(username.length == 0);
    assert(hostname == "macbook");
    assert(directory == "/home/gnunn");
    // Test directory only
    parsePromptParts(":/home/gnunn", username, hostname, directory);
    trace(format("user=%s, host=%s, dir=%s", username, hostname, directory));
    assert(username.length == 0);
    assert(hostname.length == 0);
    assert(directory == "/home/gnunn");
    // Test username only
    parsePromptParts("gnunn@", username, hostname, directory);
    trace(format("user=%s, host=%s, dir=%s", username, hostname, directory));
    assert(username == "gnunn");
    assert(hostname.length == 0);
    assert(directory.length == 0);
    // Test host only
    parsePromptParts("@macbook", username, hostname, directory);
    trace(format("user=%s, host=%s, dir=%s", username, hostname, directory));
    assert(username.length == 0);
    assert(hostname == "macbook");
    assert(directory.length == 0);
}

/***********************************************************
 * Block handles common code for allowing actions to be
 * passed up the widget heirarchy to determine if the action
 * is allowed.
 * Right now the only action supported is detaching a terminal
 * from the session into a new window.
 ***********************************************************/
public:

enum ActionType {
    DETACH_TERMINAL,
    DETACH_SESSION
}

/**
 * Constant for sidebar DND target since both vte and terminal
 * need to handle it.
 */
enum SESSION_DND = "session";

//alias OnIsActionAllowed = bool delegate(ActionType actionType);

/**
 * Mixin to handle the boiler plate of IsActionAllowed event
 * handlers
 */
mixin template IsActionAllowedHandler() {

private:

    bool notifyIsActionAllowed(ActionType actionType) {
        CumulativeResult!bool result = new CumulativeResult!bool();
        onIsActionAllowed.emit(actionType, result);
        // If anything returned false, return false
        return !result.isAnyResult(false);
    }

public:

    /**
    * Certain actions to be percolated up the widget heirarchy with
    * every level having to sign off on the action before it can be
    * performed. This delegate is for that purpose.
    */
    GenericEvent!(ActionType, CumulativeResult!bool) onIsActionAllowed;
}

/**
 * Mixin to handle the boiler plate of OnProcessNotification event
 * handlers
 */
mixin template ProcessNotificationHandler() {

private:
    void notifyProcessNotification(string summary, string _body, string terminalUUID, string sessionUUID = null) {
        onProcessNotification.emit(summary, _body, terminalUUID, sessionUUID);
    }

public:

    /**
    * Triggered when the terminal receives a notification that a command is completed. The terminal
    * will not send the notifications if it has focus.
    *
    * Note that this functionality depends on having the Fedora patched VTE installed rather
    * then the default VTE.
    *
    * See:
    * http://pkgs.fedoraproject.org/cgit/vte291.git/tree/vte291-command-notify.patch
    * http://pkgs.fedoraproject.org/cgit/gnome-terminal.git/tree/gnome-terminal-command-notify.patch
    */
    GenericEvent!(string, string, string, string) onProcessNotification;
}

/**
 * The source of the process information
 */
enum ProcessInfoSource {APPLICATION, WINDOW, SESSION, TERMINAL}

/**
 * Returns information about the running processes. The description
 * will typically be the same as the source title.
 */
struct ProcessInformation {
    ProcessInfoSource source;
    string description;
    string uuid;
    ProcessInformation[] children;
}

// ***************************************************************************
// This block deals with session notification messages. These are messages
// that are raised after a process is completed.
// ***************************************************************************

/**
 * Represents a single process notification
 */
immutable struct ProcessNotificationMessage {
    string terminalUUID;
    string summary;
    string _body;
}

/**
 * All notifications for a given session
 */
class SessionNotification {
    string sessionUUID;
    ProcessNotificationMessage[] messages;

    this(string sessionUUID) {
        this.sessionUUID = sessionUUID;
    }
}

/**************************************************************************
 * Defines interfaces that tilix uses to reference objects without creating
 * too much coupling. Session and Terminal objects implement the identifiable
 * interface so they can be found based on a string uuid wuthout higher level
 * modules having to refer to these directly.
 */
public:

/**
 * Interface that represents an object instance that can be uniquely identified
 */
interface IIdentifiable {

    /**
     * The immutable unique identifier for a terminal
     */
    @property string uuid();

}

/**
 * Interface that represents a terminal, used to expose
 * the bare minimum functionality required by the appwindow.
 */
interface ITerminal : IIdentifiable {

    /**
     * Toggles the terminal find
     */
    void toggleFind();

    /**
     * Whether the terminal find is toggled
     */
    bool isFindToggled();

    /**
     * Focuses the terminal
     */
    void focusTerminal();

    /**
     * Returns the current directory of the terminal, may be
     * null if information is not available due to VTE
     * configuration issue
     */
    @property string currentLocalDirectory();

    /**
     * Returns the UUID of the current profile being used
     * by the terminal. The active profile can be different then
     * the default if profile switching is being used.
     */
    @property string activeProfileUUID();

    /**
     * Returns the UUID of the default profile being used
     * by the terminal.
     */
    @property string defaultProfileUUID();

}