/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.exvte;

import core.sys.posix.unistd;

import std.algorithm;
import std.experimental.logger;
import std.typecons : Flag, No, Yes;

import gdk.event;
import gdk.rgba;

import gobject.global : signalLookup;
import gobject.c.functions : g_signal_connect_data;
import gobject.c.types : GCallback, GClosure, GClosureNotify, GConnectFlags, GObject, GType;

import std.string : fromStringz;
import glib.c.types : gulong;

import vte.terminal;
import vte.c.types;
import vte.c.functions : vte_terminal_get_type;

import gx.tilix.constants;
import gx.tilix.terminal.util;

enum TerminalScreen {
    NORMAL = 0,
    ALTERNATE = 1
};

/**
 * Extends default GID VTE widget to support various patches
 * which provide additional features when available.
 */
class ExtendedVTE : Terminal {

private:
    bool ignoreFirstNotification = true;

public:

    /**
	 * Sets our main struct and passes it to the parent class.
	 */
    this(VteTerminal* vteTerminal, Flag!"Take" take = No.Take) {
        super(cast(void*) vteTerminal, take);
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
		GConnectFlags flags;
		this(void delegate(string, string, Terminal) dlg, gulong handlerId, GConnectFlags flags)
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
	gulong connectNotificationReceived(void delegate(string, string, Terminal) dlg, GConnectFlags connectFlags=cast(GConnectFlags)0)
	{
		GType gtype = vte_terminal_get_type();
		if (signalLookup("notification-received", gtype) != 0) {
			onNotificationReceivedListeners ~= new OnNotificationReceivedDelegateWrapper(dlg, 0, connectFlags);
			onNotificationReceivedListeners[onNotificationReceivedListeners.length - 1].handlerId = g_signal_connect_data(
				cast(GObject*) _cPtr,
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
		wrapper.dlg(fromStringz(summary).idup, fromStringz(bod).idup, wrapper.outer);
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
		GConnectFlags flags;
		this(void delegate(int, Terminal) dlg, gulong handlerId, GConnectFlags flags)
		{
			this.dlg = dlg;
			this.handlerId = handlerId;
			this.flags = flags;
		}
	}
	protected OnTerminalScreenChangedDelegateWrapper[] onTerminalScreenChangedListeners;

	/** */
	gulong connectTerminalScreenChanged(void delegate(int, Terminal) dlg, GConnectFlags connectFlags=cast(GConnectFlags)0)
	{
		GType gtype = vte_terminal_get_type();
		if (signalLookup("terminal-screen-changed", gtype) != 0) {
			onTerminalScreenChangedListeners ~= new OnTerminalScreenChangedDelegateWrapper(dlg, 0, connectFlags);
			onTerminalScreenChangedListeners[onTerminalScreenChangedListeners.length - 1].handlerId = g_signal_connect_data(
				cast(GObject*) _cPtr,
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

    public bool getDisableBGDraw() {
		return vte_terminal_get_disable_bg_draw(cast(VteTerminal*) _cPtr) != 0;
    }

    public void setDisableBGDraw(bool isDisabled) {
		vte_terminal_set_disable_bg_draw(cast(VteTerminal*) _cPtr, isDisabled);
    }

static if (COMPILE_VTE_BACKGROUND_COLOR) {
    public void getColorBackgroundForDraw(RGBA background) {
		vte_terminal_get_color_background_for_draw(cast(VteTerminal*) _cPtr, background is null ? null : cast(GdkRGBA*) background._cPtr);
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
			if (getPty() is null)
            	return false;
        	return tcgetpgrp(getPty().getFd());
		}
    }
}

private:

import core.sys.posix.dlfcn;
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

private void* linkFunc(void* handle, const(char)* name) {
    return dlsym(handle, name);
}

shared static this() {
    void* handle = dlopen(null, RTLD_NOW);
    if (handle !is null) {
        c_vte_terminal_get_disable_bg_draw = cast(typeof(c_vte_terminal_get_disable_bg_draw)) linkFunc(handle, "vte_terminal_get_disable_bg_draw");
        c_vte_terminal_set_disable_bg_draw = cast(typeof(c_vte_terminal_set_disable_bg_draw)) linkFunc(handle, "vte_terminal_set_disable_bg_draw");

        static if (COMPILE_VTE_BACKGROUND_COLOR) {
            c_vte_terminal_get_color_background_for_draw = cast(typeof(c_vte_terminal_get_color_background_for_draw)) linkFunc(handle, "vte_terminal_get_color_background_for_draw");
        }
    }
}
