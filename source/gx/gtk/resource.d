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

import gdk.screen;
import gdk.types;

import glib.bytes;
import glib.error;
import glib.global;

import gio.resource;

import gtk.css_provider;
import gtk.types;
import gtk.style_context;
import gtk.types;

import gio.c.types;

/**
 * Defined here since not defined in GtkD
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
    import gio.global : resourcesRegister;

    string[] tried;

    void tryPath(string fullpath) {
        tried ~= fullpath;
        trace("looking for resource " ~ fullpath);
        if (exists(fullpath)) {
            Resource resource = Resource.load(fullpath);
            if (register && resource !is null) {
                trace("Resource found and registered " ~ fullpath);
                resourcesRegister(resource);
            }
            // Early-exit via exception-free control flow: caller checks return.
            throw new Exception(fullpath);
        }
    }

    // Development convenience: allow running from the build tree without installing.
    // In the repo, the compiled resource is located at `data/resources/tilix.gresource`.
    auto resourceFile = baseName(resourcePath);
    try {
        tryPath(resourcePath);
        tryPath(buildPath("data", "resources", resourceFile));
        tryPath(buildPath("..", "data", "resources", resourceFile));

        // Try relative to the executable location.
        import std.file : thisExePath;
        auto exeDir = dirName(thisExePath());
        tryPath(buildPath(exeDir, resourcePath));
        tryPath(buildPath(exeDir, "..", "data", "resources", resourceFile));
    } catch (Exception e) {
        // We use the exception message as the found path.
        auto fullpath = e.msg;
        if (exists(fullpath)) {
            Resource resource = Resource.load(fullpath);
            if (register && resource !is null) {
                trace("Resource found and registered " ~ fullpath);
                resourcesRegister(resource);
            }
            return resource;
        }
    }

    // Installed locations (XDG data dirs).
    foreach (path; getSystemDataDirs()) {
        auto fullpath = buildPath(path, resourcePath);
        trace("looking for resource " ~ fullpath);
        if (exists(fullpath)) {
            Resource resource = Resource.load(fullpath);
            if (register && resource !is null) {
                trace("Resource found and registered " ~ fullpath);
                resourcesRegister(resource);
            }
            return resource;
        }
        tried ~= fullpath;
    }

    errorf("Resource %s could not be found (tried: %s)", resourcePath, tried.join(", "));
    return null;
}

CssProvider createCssProvider(string filename, string[string] variables = null) {
    try {
        CssProvider provider = new CssProvider();
        string css = getResource(filename, variables);
        if (css.length > 0) {
            if (provider.loadFromData(cast(ubyte[])css)) {
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
                StyleContext.addProviderForScreen(Screen.getDefault(), provider, priority);
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
    import gio.global : resourcesLookupData;
    import gio.types : ResourceLookupFlags;
    Bytes bytes;
    try {
        bytes = resourcesLookupData(filename, ResourceLookupFlags.None);
    } catch (ErrorWrap ge) {
        return null;
    }
    if (bytes is null || bytes.getSize() == 0) return null;
    else {
        string contents = to!string(cast(char*)bytes.getData());
        if (variables !is null) {
            foreach(variable; variables.byKeyValue()) {
                contents = contents.replace(variable.key, variable.value);
            }
        }
        return contents;
    }
}
