/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.vte;

import std.experimental.logger;
import std.format;

import vte.Version;

/**
 * Check if the VTE version is the same or higher then requested
 */
bool checkVTEVersionNumber(uint major, uint minor) {
    return (major > vteMajorVersion || (major == vteMajorVersion && minor <= vteMinorVersion));
}

private:

uint vteMajorVersion = 0;
uint vteMinorVersion = 42;

static this() {
    try {
        vteMajorVersion = Version.getMajorVersion();
        vteMinorVersion = Version.getMinorVersion();
    }
    catch (Error e) {
        //Ignore, means VTE doesn't support version API, default to 42
    }
}