/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.colorschemes;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.file;
import std.format;
import std.json;
import std.path;
import std.uuid;

import gdk.RGBA;

import glib.Util;

import gx.gtk.util;
import gx.i18n.l10n;
import gx.terminix.constants;

enum SCHEMES_FOLDER = "schemes";

enum SCHEME_KEY_NAME = "name";
enum SCHEME_KEY_COMMENT = "comment";
enum SCHEME_KEY_FOREGROUND = "foreground-color";
enum SCHEME_KEY_BACKGROUND = "background-color";
enum SCHEME_KEY_PALETTE = "palette";
enum SCHEME_KEY_USE_THEME_COLORS = "use-theme-colors";

/**
  * A Terminix color scheme.
  *
  * Unlike gnome terminal, a color scheme in Terminix encompases both the fg/bg
  * and palette colors similar to what text editor color schemes typically
  * do.
  */
class ColorScheme {
    string id;
    string name;
    string comment;
    bool useThemeColors;
    RGBA foreground;
    RGBA background;
    RGBA[16] palette;

    this() {
        id = randomUUID().toString();
        foreground = new RGBA();
        background = new RGBA();
        for (int i = 0; i < 16; i++) {
            palette[i] = new RGBA();
        }
    }
}

/**
 * Finds a matching color scheme based on colors. This is used
 * in ProfilePreference since we don't store the selected color
 * scheme, just the colors chosen.
 */
int findSchemeByColors(ColorScheme[] schemes, bool useThemeColors, RGBA fg, RGBA bg, RGBA[16] palette) {
    foreach (pi, scheme; schemes) {
        if (useThemeColors != scheme.useThemeColors) {
            continue;
        }
        if (!useThemeColors) {
            if (!(equal(fg, scheme.foreground) && equal(bg, scheme.background)))
                continue;
        }
        bool match = true;
        foreach (i, color; palette) {
            if (!equal(color, scheme.palette[i])) {
                match = false;
                break;
            }
        }
        if (match)
            return to!int(pi);
    }
    return -1;
}

/**
 * Loads the color schemes from disk
 *
 * TODO: Cull duplicates
 */
ColorScheme[] loadColorSchemes() {
    ColorScheme[] schemes;
    string[] paths = Util.getSystemDataDirs() ~ Util.getUserConfigDir();
    foreach (path; paths) {
        auto fullpath = buildPath(path, APPLICATION_CONFIG_FOLDER, SCHEMES_FOLDER);
        trace("Loading color schemes from " ~ fullpath);
        if (exists(fullpath)) {
            DirEntry entry = DirEntry(fullpath);
            if (entry.isDir()) {
                auto files = dirEntries(fullpath, SpanMode.shallow).filter!(f => f.name.endsWith(".json"));
                foreach (string name; files) {
                    trace("Loading color scheme " ~ name);
                    try {
                        schemes ~= loadScheme(name);
                    }
                    catch (Exception e) {
                        error(format(_("File %s is not a color scheme compliant JSON file"), name));
                        error(e.msg);
                        error(e.info.toString());
                    }
                }
            }
        }
    }
    sort!("a.name < b.name")(schemes);
    return schemes;
}

/**
 * Loads a color scheme from a JSON file
 */
private ColorScheme loadScheme(string fileName) {
    ColorScheme cs = new ColorScheme();

    string content = readText(fileName);
    JSONValue root = parseJSON(content);
    cs.name = root[SCHEME_KEY_NAME].str();
    if (SCHEME_KEY_COMMENT in root) {
        cs.comment = root[SCHEME_KEY_COMMENT].str();
    }
    cs.useThemeColors = root[SCHEME_KEY_USE_THEME_COLORS].type == JSON_TYPE.TRUE ? true : false;
    if (SCHEME_KEY_FOREGROUND in root) {
        parseColor(cs.foreground, root[SCHEME_KEY_FOREGROUND].str());
    }
    if (SCHEME_KEY_BACKGROUND in root) {
        parseColor(cs.background, root[SCHEME_KEY_BACKGROUND].str());
    }
    JSONValue[] rawPalette = root[SCHEME_KEY_PALETTE].array();
    if (rawPalette.length != 16) {
        throw new Exception(_("Color scheme palette requires 16 colors"));
    }
    foreach (i, value; rawPalette) {
        parseColor(cs.palette[i], value.str());
    }
    return cs;
}

private void parseColor(RGBA rgba, string value) {
    if (value.length == 0)
        return;
    rgba.parse(value);
}
