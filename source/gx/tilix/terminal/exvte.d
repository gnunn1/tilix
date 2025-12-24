/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.exvte;

import core.sys.posix.unistd;

import std.algorithm;
import std.experimental.logger;
import std.string;
import std.typecons : Flag, No, Yes;

import gdk.event;
import gdk.types;
import gdk.rgba;
import gdk.types;

import gobject.global;
import gobject.types;



import vte.terminal;
import vte.pty;
import vte.c.types;

import gx.tilix.constants;
import gx.tilix.terminal.util;

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
    this(void* vteTerminal, Flag!"Take" ownedRef = No.Take) {
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
		ulong handlerId;
		Flag!"After" after;
		this(void delegate(string, string, Terminal) dlg, ulong handlerId, Flag!"After" after)
		{
			this.dlg = dlg;
			this.handlerId = handlerId;
			this.after = after;
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
	ulong connectNotificationReceived(void delegate(string, string, Terminal) dlg, Flag!"After" after=No.After)
	{
        import gobject.c.functions : g_signal_lookup, g_signal_connect_data;
        import gobject.c.types : GObject, GCallback, GClosureNotify, GConnectFlags;
		if (g_signal_lookup(toStringz("notification-received"), Terminal._getGType()) != 0) {
			onNotificationReceivedListeners ~= new OnNotificationReceivedDelegateWrapper(dlg, 0, after);
			onNotificationReceivedListeners[onNotificationReceivedListeners.length - 1].handlerId = g_signal_connect_data(
				cast(GObject*)this._cPtr,
				toStringz("notification-received"),
				cast(GCallback)&callBackNotificationReceived,
				cast(void*)onNotificationReceivedListeners[onNotificationReceivedListeners.length - 1],
				cast(GClosureNotify)&callBackNotificationReceivedDestroy,
				after ? GConnectFlags.After : cast(GConnectFlags)0);
			return onNotificationReceivedListeners[onNotificationReceivedListeners.length - 1].handlerId;
		} else {
			return 0;
		}
	}

	extern(C) static void callBackNotificationReceived(void* terminalStruct, char* summary, char* bod,OnNotificationReceivedDelegateWrapper wrapper)
	{
        import std.conv : to;
		wrapper.dlg(to!string(summary), to!string(bod), wrapper.outer);
	}

	extern(C) static void callBackNotificationReceivedDestroy(OnNotificationReceivedDelegateWrapper wrapper, GClosure* closure)
	{
		wrapper.outer.internalRemoveOnNotificationReceived(wrapper);
	}

	protected void internalRemoveOnNotificationReceived(OnNotificationReceivedDelegateWrapper source)
	{
		foreach(index, wrapper; onNotificationReceivedListeners)
		{
			if (wrapper.dlg == source.dlg && wrapper.after == source.after && wrapper.handlerId == source.handlerId)
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
		ulong handlerId;
		Flag!"After" after;
		this(void delegate(int, Terminal) dlg, ulong handlerId, Flag!"After" after)
		{
			this.dlg = dlg;
			this.handlerId = handlerId;
			this.after = after;
		}
	}
	protected OnTerminalScreenChangedDelegateWrapper[] onTerminalScreenChangedListeners;

	/** */
	ulong connectTerminalScreenChanged(void delegate(int, Terminal) dlg, Flag!"After" after=No.After)
	{
        import gobject.c.functions : g_signal_lookup, g_signal_connect_data;
        import gobject.c.types : GObject, GCallback, GClosureNotify, GConnectFlags;
		if (g_signal_lookup(toStringz("terminal-screen-changed"), Terminal._getGType()) != 0) {
			onTerminalScreenChangedListeners ~= new OnTerminalScreenChangedDelegateWrapper(dlg, 0, after);
			onTerminalScreenChangedListeners[onTerminalScreenChangedListeners.length - 1].handlerId = g_signal_connect_data(
				cast(GObject*)this._cPtr,
				toStringz("terminal-screen-changed"),
				cast(GCallback)&callBackTerminalScreenChanged,
				cast(void*)onTerminalScreenChangedListeners[onTerminalScreenChangedListeners.length - 1],
				cast(GClosureNotify)&callBackTerminalScreenChangedDestroy,
				after ? GConnectFlags.After : cast(GConnectFlags)0);
			return onTerminalScreenChangedListeners[onTerminalScreenChangedListeners.length - 1].handlerId;
		} else {
			return 0;
		}
	}

	extern(C) static void callBackTerminalScreenChanged(void* terminalStruct, int object,OnTerminalScreenChangedDelegateWrapper wrapper)
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
			if (wrapper.dlg == source.dlg && wrapper.after == source.after && wrapper.handlerId == source.handlerId)
			{
				onTerminalScreenChangedListeners[index] = null;
				onTerminalScreenChangedListeners = std.algorithm.remove(onTerminalScreenChangedListeners, index);
				break;
			}
		}
	}

    public bool getDisableBGDraw() {
        import vte.c.functions;
        static if (__traits(hasMember, vte.c.functions, "vte_terminal_get_disable_bg_draw")) {
            return vte_terminal_get_disable_bg_draw(cast(VteTerminal*)_cPtr()) != 0;
        } else {
            return false;
        }
    }

    public void setDisableBGDraw(bool isDisabled) {
        import vte.c.functions;
        static if (__traits(hasMember, vte.c.functions, "vte_terminal_set_disable_bg_draw")) {
            vte_terminal_set_disable_bg_draw(cast(VteTerminal*)_cPtr(), isDisabled);
        }
    }

    public bool onButtonPressEvent(gdk.c.types.GdkEventButton* buttonEvent) {
        import gdk.event : Event;
        import std.typecons : No;
        import gobject.object : ObjectWrap;
        Event ev = ObjectWrap._getDObject!(Event)(cast(gdk.c.types.GdkEvent*)buttonEvent, No.Take);
        return event(ev);
    }

    public void feedChild(string text, bool isAddedToHistory = true) {
        import vte.c.functions : vte_terminal_feed_child;
        vte_terminal_feed_child(cast(VteTerminal*)_cPtr(), cast(const(ubyte)*)toStringz(text), cast(ptrdiff_t)text.length);
    }

static if (COMPILE_VTE_BACKGROUND_COLOR) {
    public void getColorBackgroundForDraw(RGBA background) {
		vte_terminal_get_color_background_for_draw(cast(VteTerminal*)_cPtr(), background is null? null: cast(GdkRGBA*)background._cPtr());
    }
}

    /**
     * Returns the child pid running in the terminal or -1
     * if no child pid is running. May also return the VTE gpid
     * as well which also indicates no child process.
     */
    pid_t getChildPid() {
		if (isFlatpak()) {
            warning("getChildPid should not be called from a Flatpak environment.");
			return -1;
		} else {
            Pty pty = getPty();
			if (pty is null)
            	return -1;
        	return tcgetpgrp(pty.getFd());
		}
    }
}

private:


import vte.c.functions;

__gshared extern(C) {
	int function(VteTerminal* terminal) c_vte_terminal_get_disable_bg_draw;
	void function(VteTerminal* terminal, int isAudible) c_vte_terminal_set_disable_bg_draw;

	static if (COMPILE_VTE_BACKGROUND_COLOR) {
		void function(VteTerminal* terminal, GdkRGBA* color) c_vte_terminal_get_color_background_for_draw;
	}
}

alias vte_terminal_get_disable_bg_draw = c_vte_terminal_get_disable_bg_draw;
alias vte_terminal_set_disable_bg_draw = c_vte_terminal_set_disable_bg_draw;

static if (COMPILE_VTE_BACKGROUND_COLOR) {
	alias vte_terminal_get_color_background_for_draw = c_vte_terminal_get_color_background_for_draw;
}

shared static this() {
// 	Linker.link(vte_terminal_get_disable_bg_draw, "vte_terminal_get_disable_bg_draw", LIBRARY_VTE);
// 	Linker.link(vte_terminal_set_disable_bg_draw, "vte_terminal_set_disable_bg_draw", LIBRARY_VTE);

	static if (COMPILE_VTE_BACKGROUND_COLOR) {
// 		Linker.link(vte_terminal_get_color_background_for_draw, "vte_terminal_get_color_background_for_draw", LIBRARY_VTE);
	}
}
