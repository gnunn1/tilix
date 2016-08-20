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

enum TerminalFeature {
    EVENT_NOTIFICATION,
    EVENT_SCREEN_CHANGED,
    EVENT_BACKGROUND_DRAW
}

/**
 * Determine which terminal features are supported.
 */
bool checkVTEFeature(TerminalFeature feature) {
    // Initialized features if not done yet, can't do it statically
    // due to need for GTK to load first
    if (!featuresInitialized) {
        string[] events = ["notification-received", "terminal-screen-changed", "background-draw"];
        foreach(i, event; events) {
            bool supported = (Signals.lookup(event, Terminal.getType()) != 0);
            terminalFeatures[cast(TerminalFeature) i] = supported;
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