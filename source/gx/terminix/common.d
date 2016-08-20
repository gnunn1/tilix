/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.common;

import std.algorithm;
import std.experimental.logger;
import std.string;

import gx.util.array;

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
    DETACH
}

/**
 * Certain actions to be percolated up the widget heirarchy with
 * every level having to sign off on the action before it can be 
 * performed. This delegate is for that purpose.
 */
alias OnIsActionAllowed = bool delegate(ActionType actionType);

/**
 * Mixin to handle the boiler plate of IsActionAllowed event 
 * handlers
 */
mixin template IsActionAllowedHandler() {

private:
    OnIsActionAllowed[] isActionAllowedDelegates;

    bool notifyIsActionAllowed(ActionType actionType) {
        foreach (dlg; isActionAllowedDelegates) {
            if (!dlg(actionType))
                return false;
        }
        return true;
    }

public:

    void addOnIsActionAllowed(OnIsActionAllowed dlg) {
        isActionAllowedDelegates ~= dlg;
    }

    void removeOnIsActionAllowed(OnIsActionAllowed dlg) {
        gx.util.array.remove(isActionAllowedDelegates, dlg);
    }
}

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
alias OnProcessNotification = void delegate(string summary, string _body, string terminalUUID, string sessionUUID = null);

/**
 * Mixin to handle the boiler plate of OnProcessNotification event 
 * handlers
 */
mixin template ProcessNotificationHandler() {

private:
    OnProcessNotification[] processNotificationDelegates;

    void notifyProcessNotification(string summary, string _body, string terminalUUID, string sessionUUID = null) {
        foreach (dlg; processNotificationDelegates) {
            dlg(summary, _body, terminalUUID, sessionUUID);
        }
    }

public:

    void addOnProcessNotification(OnProcessNotification dlg) {
        processNotificationDelegates ~= dlg;
    }

    void removeOnProcessNotification(OnProcessNotification dlg) {
        gx.util.array.remove(processNotificationDelegates, dlg);
    }
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

interface IIdentifiable {

    /**
     * The immutable unique identifier for a terminal
     */
    //string getUUID();

    @property string uuid();

}

interface ITerminal : IIdentifiable {

    /**
     * Toggles the terminal find
     */
    void toggleFind();

    /**
     * Returns the current directory of the terminal, may be
     * null if information is not available due to VTE
     * configuration issue
     */
    @property string currentLocalDirectory();

}