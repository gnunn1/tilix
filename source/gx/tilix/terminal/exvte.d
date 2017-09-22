/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.exvte;

import core.sys.posix.unistd;

import std.algorithm;
import std.experimental.logger;

import gdk.Event;

import gobject.Signals;

import glib.Str;

import vte.Terminal;
import vtec.vtetypes;

import gx.tilix.constants;

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

public:

    /**
	 * Sets our main struct and passes it to the parent class.
	 */
    this(VteTerminal* vteTerminal, bool ownedRef = false) {
        super(vteTerminal, ownedRef);
    }

    /**
	 * Creates a new terminal widget.
	 *
	 * Return: a new #VteTerminal object
	 *
	 * Throws: ConstructionException GTK+ fails to create the object.
	 */
    this() {
        super();
    }

    debug(Destructors) {
        ~this() {
            import std.stdio: writeln;
            writeln("******** VTE Destructor");
        }
    }

	protected class OnNotificationReceivedDelegateWrapper
	{
		void delegate(string, string, Terminal) dlg;
		gulong handlerId;
		ConnectFlags flags;
		this(void delegate(string, string, Terminal) dlg, gulong handlerId, ConnectFlags flags)
		{
			this.dlg = dlg;
			this.handlerId = handlerId;
			this.flags = flags;
		}
	}
	protected OnNotificationReceivedDelegateWrapper[] onNotificationReceivedListeners;

	/**
	 * Emitted when a process running in the terminal wants to
	 * send a notification to the desktop environment.
	 *
	 * Params:
	 *     summary = The summary
	 *     bod = Extra optional text
	 */
	gulong addOnNotificationReceived(void delegate(string, string, Terminal) dlg, ConnectFlags connectFlags=cast(ConnectFlags)0)
	{
		if (Signals.lookup("notification-received", getType()) != 0) {
			onNotificationReceivedListeners ~= new OnNotificationReceivedDelegateWrapper(dlg, 0, connectFlags);
			onNotificationReceivedListeners[onNotificationReceivedListeners.length - 1].handlerId = Signals.connectData(
				this,
				"notification-received",
				cast(GCallback)&callBackNotificationReceived,
				cast(void*)onNotificationReceivedListeners[onNotificationReceivedListeners.length - 1],
				cast(GClosureNotify)&callBackNotificationReceivedDestroy,
				connectFlags);
			return onNotificationReceivedListeners[onNotificationReceivedListeners.length - 1].handlerId;
		} else {
			return 0;
		}
	}

	extern(C) static void callBackNotificationReceived(VteTerminal* terminalStruct, char* summary, char* bod,OnNotificationReceivedDelegateWrapper wrapper)
	{
		wrapper.dlg(Str.toString(summary), Str.toString(bod), wrapper.outer);
	}

	extern(C) static void callBackNotificationReceivedDestroy(OnNotificationReceivedDelegateWrapper wrapper, GClosure* closure)
	{
		wrapper.outer.internalRemoveOnNotificationReceived(wrapper);
	}

	protected void internalRemoveOnNotificationReceived(OnNotificationReceivedDelegateWrapper source)
	{
		foreach(index, wrapper; onNotificationReceivedListeners)
		{
			if (wrapper.dlg == source.dlg && wrapper.flags == source.flags && wrapper.handlerId == source.handlerId)
			{
				onNotificationReceivedListeners[index] = null;
				onNotificationReceivedListeners = std.algorithm.remove(onNotificationReceivedListeners, index);
				break;
			}
		}
	}

	protected class OnTerminalScreenChangedDelegateWrapper
	{
		void delegate(int, Terminal) dlg;
		gulong handlerId;
		ConnectFlags flags;
		this(void delegate(int, Terminal) dlg, gulong handlerId, ConnectFlags flags)
		{
			this.dlg = dlg;
			this.handlerId = handlerId;
			this.flags = flags;
		}
	}
	protected OnTerminalScreenChangedDelegateWrapper[] onTerminalScreenChangedListeners;

	/** */
	gulong addOnTerminalScreenChanged(void delegate(int, Terminal) dlg, ConnectFlags connectFlags=cast(ConnectFlags)0)
	{
		if (Signals.lookup("terminal-screen-changed", getType()) != 0) {
			onTerminalScreenChangedListeners ~= new OnTerminalScreenChangedDelegateWrapper(dlg, 0, connectFlags);
			onTerminalScreenChangedListeners[onTerminalScreenChangedListeners.length - 1].handlerId = Signals.connectData(
				this,
				"terminal-screen-changed",
				cast(GCallback)&callBackTerminalScreenChanged,
				cast(void*)onTerminalScreenChangedListeners[onTerminalScreenChangedListeners.length - 1],
				cast(GClosureNotify)&callBackTerminalScreenChangedDestroy,
				connectFlags);
			return onTerminalScreenChangedListeners[onTerminalScreenChangedListeners.length - 1].handlerId;
		} else {
			return 0;
		}
	}

	extern(C) static void callBackTerminalScreenChanged(VteTerminal* terminalStruct, int object,OnTerminalScreenChangedDelegateWrapper wrapper)
	{
		wrapper.dlg(object, wrapper.outer);
	}

	extern(C) static void callBackTerminalScreenChangedDestroy(OnTerminalScreenChangedDelegateWrapper wrapper, GClosure* closure)
	{
		wrapper.outer.internalRemoveOnTerminalScreenChanged(wrapper);
	}

	protected void internalRemoveOnTerminalScreenChanged(OnTerminalScreenChangedDelegateWrapper source)
	{
		foreach(index, wrapper; onTerminalScreenChangedListeners)
		{
			if (wrapper.dlg == source.dlg && wrapper.flags == source.flags && wrapper.handlerId == source.handlerId)
			{
				onTerminalScreenChangedListeners[index] = null;
				onTerminalScreenChangedListeners = std.algorithm.remove(onTerminalScreenChangedListeners, index);
				break;
			}
		}
	}

	protected class OnHyperlinkHoverUriDelegateWrapper
	{
		void delegate(string, Terminal) dlg;
		gulong handlerId;
		ConnectFlags flags;
		this(void delegate(string, Terminal) dlg, gulong handlerId, ConnectFlags flags)
		{
			this.dlg = dlg;
			this.handlerId = handlerId;
			this.flags = flags;
		}
	}

	protected OnHyperlinkHoverUriDelegateWrapper[] onHyperlinkHoverUriListeners;

	/**
	 * Emitted to track a hyperlink uri change
	 *
	 * Params:
	 *     uri = The URI of the hyperlink
	 */
	gulong addOnHyperlinkHoverUri(void delegate(string, Terminal) dlg, ConnectFlags connectFlags=cast(ConnectFlags)0)
	{
		if (Signals.lookup("hyperlink-hover-uri", getType()) != 0) {
			onHyperlinkHoverUriListeners ~= new OnHyperlinkHoverUriDelegateWrapper(dlg, 0, connectFlags);
			onHyperlinkHoverUriListeners[onHyperlinkHoverUriListeners.length - 1].handlerId = Signals.connectData(
				this,
				"hyperlink-hover-uri",
				cast(GCallback)&callBackHyperlinkHoverUri,
				cast(void*)onHyperlinkHoverUriListeners[onHyperlinkHoverUriListeners.length - 1],
				cast(GClosureNotify)&callBackHyperlinkHoverUriDestroy,
				connectFlags);
			return onHyperlinkHoverUriListeners[onHyperlinkHoverUriListeners.length - 1].handlerId;
		} else {
			return 0;
		}
	}

	extern(C) static void callBackHyperlinkHoverUri(VteTerminal* terminalStruct, char* uri, OnHyperlinkHoverUriDelegateWrapper wrapper)
	{
		wrapper.dlg(Str.toString(uri), wrapper.outer);
	}

	extern(C) static void callBackHyperlinkHoverUriDestroy(OnHyperlinkHoverUriDelegateWrapper wrapper, GClosure* closure)
	{
		wrapper.outer.internalRemoveOnHyperlinkHoverUri(wrapper);
	}

	protected void internalRemoveOnHyperlinkHoverUri(OnHyperlinkHoverUriDelegateWrapper source)
	{
		foreach(index, wrapper; onHyperlinkHoverUriListeners)
		{
			if (wrapper.dlg == source.dlg && wrapper.flags == source.flags && wrapper.handlerId == source.handlerId)
			{
				onHyperlinkHoverUriListeners[index] = null;
				onHyperlinkHoverUriListeners = std.algorithm.remove(onHyperlinkHoverUriListeners, index);
				break;
			}
		}
	}

	public bool getAllowHyperlink() {
		return vte_terminal_get_allow_hyperlink(vteTerminal) != 0;
	}

	public void setAllowHyperlink(bool enabled) {
		vte_terminal_set_allow_hyperlink(vteTerminal, enabled);
	}

	public string hyperlinkCheckEvent(Event event) {
		return Str.toString(vte_terminal_hyperlink_check_event(vteTerminal, (event is null) ? null : event.getEventStruct()));
	}

    public bool getDisableBGDraw() {
		return vte_terminal_get_disable_bg_draw(vteTerminal) != 0;
    }

    public void setDisableBGDraw(bool isDisabled) {
		vte_terminal_set_disable_bg_draw(vteTerminal, isDisabled);
    }

    /**
     * Returns the child pid running in the terminal or -1
     * if no child pid is running. May also return the VTE gpid
     * as well which also indicates no child process.
     */
    pid_t getChildPid() {
        // TODO: be correct for flatpak sandbox
		static if (FLATPAK) {
			return -1;
		} else {
			if (getPty() is null)
            	return false;
        	return tcgetpgrp(getPty().getFd());
		}
    }

}

private:

import gtkc.Loader;
import gtkc.paths;

__gshared extern(C) {
	int function(VteTerminal* terminal) c_vte_terminal_get_disable_bg_draw;
	void function(VteTerminal* terminal, int isAudible) c_vte_terminal_set_disable_bg_draw;

	// Custom hyperlink
	int function(VteTerminal *terminal) c_vte_terminal_get_allow_hyperlink;
	void function(VteTerminal *terminal, int allow_hyperlink) c_vte_terminal_set_allow_hyperlink;
	char* function (VteTerminal *terminal, GdkEvent *event) c_vte_terminal_hyperlink_check_event;
}

alias c_vte_terminal_get_disable_bg_draw vte_terminal_get_disable_bg_draw;
alias c_vte_terminal_set_disable_bg_draw vte_terminal_set_disable_bg_draw;

alias c_vte_terminal_get_allow_hyperlink vte_terminal_get_allow_hyperlink;
alias c_vte_terminal_set_allow_hyperlink vte_terminal_set_allow_hyperlink;
alias c_vte_terminal_hyperlink_check_event vte_terminal_hyperlink_check_event;

shared static this() {
	Linker.link(vte_terminal_get_disable_bg_draw, "vte_terminal_get_disable_bg_draw", LIBRARY.VTE);
	Linker.link(vte_terminal_set_disable_bg_draw, "vte_terminal_set_disable_bg_draw", LIBRARY.VTE);

	Linker.link(vte_terminal_set_allow_hyperlink, "vte_terminal_get_allow_hyperlink", LIBRARY.VTE);
	Linker.link(vte_terminal_set_allow_hyperlink, "vte_terminal_set_allow_hyperlink", LIBRARY.VTE);
	Linker.link(vte_terminal_hyperlink_check_event, "vte_terminal_hyperlink_check_event", LIBRARY.VTE);
}
