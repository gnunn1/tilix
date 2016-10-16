/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.vte;

import std.experimental.logger;
import std.format;

import gobject.Signals: Signals;

import vte.Terminal;
import vte.Version;

/**
 * Check if the VTE version is the same or higher then requested
 */
bool checkVTEVersionNumber(uint major, uint minor) {
    return (major > vteMajorVersion || (major == vteMajorVersion && minor <= vteMinorVersion));
}

string getVTEVersion() {
    return format("%d:%d", vteMajorVersion, vteMinorVersion);
}

enum TerminalFeature {
    EVENT_NOTIFICATION,
    EVENT_SCREEN_CHANGED,
    DISABLE_BACKGROUND_DRAW
}

/**
 * Determine which terminal features are supported.
 */
bool checkVTEFeature(TerminalFeature feature) {
    // Initialized features if not done yet, can't do it statically
    // due to need for GTK to load first
    if (!featuresInitialized) {
        // Force terminal to be loaded if not done already
        Terminal terminal = new Terminal();
        scope(exit) {terminal.destroy();}

        // Check if patched events are available
        string[] events = ["notification-received", "terminal-screen-changed"];
        foreach(i, event; events) {
            bool supported = (Signals.lookup(event, Terminal.getType()) != 0);
            terminalFeatures[cast(TerminalFeature) i] = supported;
        }

        // Check if disable background draw is available
        terminalFeatures[TerminalFeature.DISABLE_BACKGROUND_DRAW] = true;

        import gtkc.Loader: Linker;
        import gtkc.paths: LIBRARY;
        string[] failures = Linker.getLoadFailures(LIBRARY.VTE);

        foreach(failure; failures) {
            if (failure == "vte_terminal_get_disable_bg_draw") {
                trace("Background draw disabled");
                terminalFeatures[TerminalFeature.DISABLE_BACKGROUND_DRAW] = false;
            }
        }
        featuresInitialized = true;
    }
    if (feature in terminalFeatures) {
        return terminalFeatures[feature];
    } else {
        return false;
    }
}

private:

uint vteMajorVersion = 0;
uint vteMinorVersion = 42;

bool featuresInitialized = false;
bool[TerminalFeature] terminalFeatures;

static this() {
    // Get version numbers
    try {
        vteMajorVersion = Version.getMajorVersion();
        vteMinorVersion = Version.getMinorVersion();
    }
    catch (Error e) {
        //Ignore, means VTE doesn't support version API, default to 42
    }
}