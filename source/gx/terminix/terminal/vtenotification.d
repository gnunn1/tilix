/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.terminal.vtenotification;

import std.experimental.logger;

import gobject.Signals;

import glib.Str;

import vte.Terminal;
import vtec.vtetypes;

/**
 * Extends GtKD to support Fedora's patched VTE widget which provides
 * notifications when commands are completed. 
 *
 * TODO - Test with unpatched VTE
 */
class VTENotification : Terminal {

public:

	/**
	 * Sets our main struct and passes it to the parent class.
	 */
	public this (VteTerminal* vteTerminal, bool ownedRef = false)
	{
        super(vteTerminal, ownedRef);
	}

	/**
	 * Creates a new terminal widget.
	 *
	 * Return: a new #VteTerminal object
	 *
	 * Throws: ConstructionException GTK+ fails to create the object.
	 */
	public this()
	{
        super();
	}
    
	void delegate(string, string, Terminal)[] onNotificationReceivedListeners;
	/**
	 * Emitted whenever a command is completed.
	 *
	 * Params:
	 *     summary = 
	 *     body = 
	 */
	void addOnNotificationReceived(void delegate(string, string, Terminal) dlg, ConnectFlags connectFlags=cast(ConnectFlags)0) {
        //Check that this is the Fedora patched VTE that supports the notification-received signal
        if (Signals.lookup("notification-received", getType()) != 0) {
            if ( "notification-received" !in connectedSignals ) {
                Signals.connectData(
                    this,
                    "notification-received",
                    cast(GCallback)&callBackNotificationReceived,
                    cast(void*)this,
                    null,
                    connectFlags);
                connectedSignals["notification-received"] = 1;
            }
            onNotificationReceivedListeners ~= dlg;
        }
	}
    
	extern(C) static void callBackNotificationReceived(VteTerminal* terminalStruct, const char* _summary, const char* _body, VTENotification _terminal)	{
        string s = Str.toString(_summary);
        string b = Str.toString(_body);
		foreach ( void delegate(string, string, Terminal) dlg; _terminal.onNotificationReceivedListeners ) {
			dlg(s, b, _terminal);
		}
	}
}