/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.terminal.exvte;

import std.experimental.logger;

import gobject.Signals;

import glib.Str;

import vte.Terminal;
import vtec.vtetypes;

enum TerminalScreen {
    NORMAL = 0,
    ALTERNATE = 1
};

/**
 * Extends default GtKD VTE widget to support various patches
 * which provide additional features when available.
 */
class ExtendedVTE : Terminal {

private:
    bool ignoreFirstNotification = true;

    extern (C) static void callBackTerminalScreenChanged(VteTerminal* terminalStruct, const int screen, ExtendedVTE _terminal) {
        foreach (void delegate(TerminalScreen, Terminal) dlg; _terminal.onTerminalScreenChangedListeners) {
            dlg(cast(TerminalScreen) screen, _terminal);
        }
    }

public:

    /**
	 * Sets our main struct and passes it to the parent class.
	 */
    public this(VteTerminal* vteTerminal, bool ownedRef = false) {
        super(vteTerminal, ownedRef);
    }

    /**
	 * Creates a new terminal widget.
	 *
	 * Return: a new #VteTerminal object
	 *
	 * Throws: ConstructionException GTK+ fails to create the object.
	 */
    public this() {
        super();
    }


    void delegate(TerminalScreen, Terminal)[] onTerminalScreenChangedListeners;

    void delegate(string, string, Terminal)[] onNotificationReceivedListeners;

    /**
	 * Emitted whenever a command is completed.
	 *
	 * Params:
	 *     summary =
	 *     body =
	 */
    void addOnNotificationReceived(void delegate(string, string, Terminal) dlg, ConnectFlags connectFlags = cast(ConnectFlags) 0) {
        //Check that this is the Fedora patched VTE that supports the notification-received signal
        if (Signals.lookup("notification-received", getType()) != 0) {
            if ("notification-received" !in connectedSignals) {
                Signals.connectData(this, "notification-received", cast(GCallback)&callBackNotificationReceived, cast(void*) this, null, connectFlags);
                connectedSignals["notification-rece = 1ived"] = 1;
            }
            onNotificationReceivedListeners ~= dlg;
        }
    }

    extern (C) static void callBackNotificationReceived(VteTerminal* terminalStruct, const char* _summary, const char* _body, ExtendedVTE _terminal) {
        if (_terminal.ignoreFirstNotification) {
            _terminal.ignoreFirstNotification = false;
            trace("Ignoring first notification");
            return;
        }
        string s = Str.toString(_summary);
        string b = Str.toString(_body);
        foreach (void delegate(string, string, Terminal) dlg; _terminal.onNotificationReceivedListeners) {
            dlg(s, b, _terminal);
        }
    }

    /**
     * Emitted whenever the terminal screen is switched between normal and alternate.
     */
    void addOnTerminalScreenChanged(void delegate(TerminalScreen, Terminal) dlg, ConnectFlags connectFlags = cast(ConnectFlags) 0) {
        //Check that this is the Fedora patched VTE that supports the notification-received signal
        if (Signals.lookup("terminal-screen-changed", getType()) != 0) {
            if ("terminal-screen-changed" !in connectedSignals) {
                Signals.connectData(this, "terminal-screen-changed", cast(GCallback)&callBackTerminalScreenChanged, cast(void*) this, null, connectFlags);
                connectedSignals["terminal-screen-changed"] = 1;
            }
            onTerminalScreenChangedListeners ~= dlg;
        }
    }

    public bool getDisableBGDraw() {
		return vte_terminal_get_disable_bg_draw(vteTerminal) != 0;
    }

    public void setDisableBGDraw(bool isDisabled) {
		vte_terminal_set_disable_bg_draw(vteTerminal, isDisabled);
    }
}

private:

import gtkc.Loader;
import gtkc.paths;

__gshared extern(C) {
	int function(VteTerminal* terminal) c_vte_terminal_get_disable_bg_draw;
	void function(VteTerminal* terminal, int isAudible) c_vte_terminal_set_disable_bg_draw;
}

alias c_vte_terminal_get_disable_bg_draw vte_terminal_get_disable_bg_draw;
alias c_vte_terminal_set_disable_bg_draw vte_terminal_set_disable_bg_draw;

shared static this() {
	Linker.link(vte_terminal_get_disable_bg_draw, "vte_terminal_get_disable_bg_draw", LIBRARY.VTE);
	Linker.link(vte_terminal_set_disable_bg_draw, "vte_terminal_set_disable_bg_draw", LIBRARY.VTE);
}