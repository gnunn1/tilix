/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.resource;

import std.array;
import std.conv;
import std.experimental.logger;
import std.file;
import std.path;

// GID imports - gdk
import gdk.screen : Screen;

// GID imports - gio
import gio.global : resourcesLookupData, resourcesRegister;
import gio.resource : Resource;
import gio.types : ResourceLookupFlags;

// GID imports - glib
import glib.bytes : Bytes;
import glib.error : ErrorWrap;
import glib.global : getSystemDataDirs, getUserDataDir;

// GID imports - gtk
import gtk.css_provider : CssProvider;
import gtk.style_context : StyleContext;

/**
 * Provider priority values for CSS styling
 */
enum ProviderPriority : uint {
    FALLBACK = 1,
    THEME = 200,
    SETTINGS = 400,
    APPLICATION = 600,
    USER = 800
}

/**
 * Find and optionally register a resource
 */
Resource findResource(string resourcePath, bool register = true) {
    // Search in user data dir first, then system data dirs
    string[] searchPaths = [getUserDataDir()] ~ getSystemDataDirs();
    foreach (path; searchPaths) {
        auto fullpath = buildPath(path, resourcePath);
        trace("looking for resource " ~ fullpath);
        if (exists(fullpath)) {
            Resource resource = Resource.load(fullpath);
            if (register && resource) {
                trace("Resource found and registered " ~ fullpath);
                resourcesRegister(resource);
            }
            return resource;
        }
    }
    errorf("Resource %s could not be found", resourcePath);
    return null;
}

CssProvider createCssProvider(string filename, string[string] variables = null) {
    try {
        CssProvider provider = new CssProvider();
        string css = getResource(filename, variables);
        if (css.length > 0) {
            if (provider.loadFromData(cast(ubyte[]) css)) {
                return provider;
            }
        }
    } catch (ErrorWrap ge) {
        trace("Unexpected error loading css provider " ~ filename);
        trace("Error: " ~ ge.msg);
    }
    return null;
}

/**
 * Adds a CSSProvider to the default screen, if no provider is found it
 * returns null
 */
CssProvider addCssProvider(string filename, ProviderPriority priority, string[string] variables = null) {
    try {
        CssProvider provider = createCssProvider(filename, variables);
        if (provider !is null) {
            Screen screen = Screen.getDefault();
            if (screen !is null) {
                StyleContext.addProviderForScreen(screen, provider, priority);
                return provider;
            } else {
                warning("Default screen is null, no CSS provider added and as a result Tilix UI may appear incorrect");
                return null;
            }
        }
    } catch (ErrorWrap ge) {
        trace("Unexpected error loading css provider " ~ filename);
        trace("Error: " ~ ge.msg);
    }
    return null;
}

/**
 * Loads a textual resource and performs string subsitution based on key-value pairs
 */
string getResource(string filename, string[string] variables = null) {
    Bytes bytes;
    try {
        bytes = resourcesLookupData(filename, ResourceLookupFlags.None);
    } catch (ErrorWrap ge) {
        return null;
    }
    if (bytes is null || bytes.getSize() == 0) return null;
    else {
        ubyte[] data = bytes.getData();
        string contents = to!string(cast(char[]) data);
        if (variables !is null) {
            foreach(variable; variables.byKeyValue()) {
                contents = contents.replace(variable.key, variable.value);
            }
        }
        return contents;
    }
}