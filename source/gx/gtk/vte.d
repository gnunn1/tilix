/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.vte;

import std.experimental.logger;
import std.format;

import gdk.Keysyms;

import gobject.Signals: Signals;

import vte.Terminal;
import vte.Version;

// Constants used to version VTE features
int[2] VTE_VERSION_COPY_AS_HTML = [0, 49];
int[2] VTE_VERSION_HYPERLINK = [0, 49];
int[2] VTE_VERSION_REGEX = [0, 46];
int[2] VTE_VERSION_REGEX_MULTILINE = [0, 44];
int[2] VTE_VERSION_BACKGROUND_OPERATOR = [0, 51];
int[2] VTE_VERSION_CURSOR_COLOR = [0, 44];
int[2] VTE_VERSION_TEXT_BLINK_MODE = [0, 51];
int[2] VTE_VERSION_BOLD_IS_BRIGHT = [0, 51];
int[2] VTE_VERSION_CELL_SCALE = [0, 51];

/**
 * PCRE2 constants for VTE Regex
 */
enum PCRE2Flags : uint {
    ALLOW_EMPTY_CLASS   = 0x00000001u,  /* C       */
    ALT_BSUX            = 0x00000002u,  /* C       */
    PCRE2_AUTO_CALLOUT  = 0x00000004u,  /* C       */
    CASELESS            = 0x00000008u,  /* C       */
    DOLLAR_ENDONLY      = 0x00000010u,  /*   J M D */
    DOTALL              = 0x00000020u,  /* C       */
    DUPNAMES            = 0x00000040u,  /* C       */
    EXTENDED            = 0x00000080u,  /* C       */
    FIRSTLINE           = 0x00000100u,  /*   J M D */
    MATCH_UNSET_BACKREF = 0x00000200u,  /* C J M   */
    MULTILINE           = 0x00000400u,  /* C       */
    NEVER_UCP           = 0x00000800u,  /* C       */
    NEVER_UTF           = 0x00001000u,  /* C       */
    NO_AUTO_CAPTURE     = 0x00002000u,  /* C       */
    NO_AUTO_POSSESS     = 0x00004000u,  /* C       */
    NO_DOTSTAR_ANCHOR   = 0x00008000u,  /* C       */
    NO_START_OPTIMIZE   = 0x00010000u,  /*   J M D */
    UCP                 = 0x00020000u,  /* C J M D */
    UNGREEDY            = 0x00040000u,  /* C       */
    UTF                 = 0x00080000u,  /* C J M D */
    ANCHORED            = 0x80000000u,
    NO_UTF_CHECK        = 0x40000000u
}

/**
 * Determines if the key value and modifier represent a hard coded key sequence
 * that VTE handles internally.
 */
bool isVTEHandledKeystroke(uint keyval, GdkModifierType modifier) {
    if ((keyval == GdkKeysyms.GDK_Page_Up ||
        keyval == GdkKeysyms.GDK_Page_Down ||
        keyval == GdkKeysyms.GDK_Home ||
        keyval == GdkKeysyms.GDK_End) && (GdkModifierType.SHIFT_MASK & modifier)) {
            return true;
        }
    if ((keyval == GdkKeysyms.GDK_Up ||
        keyval == GdkKeysyms.GDK_Down) &&
        (GdkModifierType.SHIFT_MASK & modifier) &&
        (GdkModifierType.CONTROL_MASK & modifier)) {
            return true;
        }
    return false;
}

/**
 * Check if the VTE version is the same or higher then requested
 */
bool checkVTEVersionNumber(uint major, uint minor) {
    return (major > vteMajorVersion || (major == vteMajorVersion && minor <= vteMinorVersion));
}

/**
 * Check version number where first element of array is major and second is minor
 */
bool checkVTEVersion(int[2] versionNum) {
    return checkVTEVersionNumber(versionNum[0], versionNum[1]);
}

string getVTEVersion() {
    return format("%d.%d", vteMajorVersion, vteMinorVersion);
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
        import vte.c.functions;
        string[] failures = Linker.getLoadFailures(LIBRARY_VTE);

        foreach(failure; failures) {
            if (failure == "vte_terminal_get_disable_bg_draw") {
                trace("Background draw disabled");
                terminalFeatures[TerminalFeature.DISABLE_BACKGROUND_DRAW] = false;
            }
            tracef("VTE function %s could not be linked", failure);
        }
        featuresInitialized = true;
    }
    if (feature in terminalFeatures) {
        return terminalFeatures[feature];
    } else {
        return false;
    }
}

bool isVTEBackgroundDrawEnabled() {
    return checkVTEFeature(TerminalFeature.DISABLE_BACKGROUND_DRAW) || checkVTEVersion(VTE_VERSION_BACKGROUND_OPERATOR);
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