/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.colorschemes;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.file;
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
enum SCHEME_KEY_DIM_COLOR = "dim-color";
enum SCHEME_KEY_USE_DIM_COLOR = "use-dim-color";
enum SCHEME_KEY_USE_HIGHLIGHT_COLOR = "use-highlight-color";
enum SCHEME_KEY_USE_CURSOR_COLOR = "use-cursor-color";
enum SCHEME_KEY_HIGHLIGHT_FG = "highlight-foreground-color";
enum SCHEME_KEY_HIGHLIGHT_BG = "highlight-background-color";
enum SCHEME_KEY_CURSOR_FG = "cursor-foreground-color";
enum SCHEME_KEY_CURSOR_BG = "cursor-background-color";

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
    bool useHighlightColor;
    bool useCursorColor;
    bool useDimColor;
    RGBA foreground;
    RGBA background;
    RGBA highlightFG;
    RGBA highlightBG;
    RGBA cursorFG;
    RGBA cursorBG;
    RGBA dimColor;
    RGBA[16] palette;

    this() {
        id = randomUUID().toString();
        foreground = new RGBA();
        background = new RGBA();
        highlightFG = new RGBA();
        highlightBG = new RGBA();
        cursorFG = new RGBA();
        cursorBG = new RGBA();
        dimColor = new RGBA();

        for (int i = 0; i < 16; i++) {
            palette[i] = new RGBA();
        }
    }

    bool equalColor(ColorScheme scheme) {
        if (useThemeColors != scheme.useThemeColors) {
            return false;
        }
        if (!useThemeColors) {
            if (!(equal(foreground, scheme.foreground) && equal(background, scheme.background)))
                return false;
            if (useCursorColor) {
                if (!(equal(cursorFG, scheme.cursorFG) && equal(cursorBG, scheme.cursorBG)))
                    return false;
            }
            if (useHighlightColor) {
                if (!(equal(highlightFG, scheme.highlightFG) && equal(highlightBG, scheme.highlightBG)))
                    return false;
            }
            if (useDimColor) {
                if (!(equal(dimColor, scheme.dimColor)))
                    return false;
            }
        }
        bool match = true;
        foreach (i, color; palette) {
            if (!equal(color, scheme.palette[i])) {
                match = false;
                break;
            }
        }
        return match;
    }

    override bool opEquals(Object o) {

        import gx.gtk.util: equal;

        if (auto scheme = cast(ColorScheme) o)
            return scheme.id == id &&
                   scheme.name == name &&
                   scheme.comment == comment &&
                   scheme.useThemeColors == useThemeColors &&
                   scheme.useHighlightColor == useHighlightColor &&
                   scheme.useCursorColor == useCursorColor &&
                   equal(scheme.background, this.background) &&
                   equal(scheme.foreground, this.foreground) &&
                   equal(scheme.highlightFG, this.highlightFG) &&
                   equal(scheme.highlightBG, this.highlightBG) &&
                   equal(scheme.cursorFG, this.cursorFG) &&
                   equal(scheme.cursorBG, this.cursorBG) &&
                   equal(scheme.dimColor, this.dimColor);
        else
            return false;
   }
}

/**
 * Finds a matching color scheme based on colors. This is used
 * in ProfilePreference since we don't store the selected color
 * scheme, just the colors chosen.
 */
int findSchemeByColors(ColorScheme[] schemes, ColorScheme scheme) {
    foreach (pi, s; schemes) {
        if (scheme.equalColor(s))
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
                        errorf(_("File %s is not a color scheme compliant JSON file"), name);
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
    if (SCHEME_KEY_USE_DIM_COLOR in root) {
        cs.useDimColor = root[SCHEME_KEY_USE_DIM_COLOR].type == JSON_TYPE.TRUE ? true : false;
    }
    if (SCHEME_KEY_USE_HIGHLIGHT_COLOR in root) {
        cs.useHighlightColor = root[SCHEME_KEY_USE_HIGHLIGHT_COLOR].type == JSON_TYPE.TRUE ? true : false;
    }
    if (SCHEME_KEY_USE_CURSOR_COLOR in root) {
        cs.useCursorColor = root[SCHEME_KEY_USE_CURSOR_COLOR].type == JSON_TYPE.TRUE ? true : false;
    }
    if (SCHEME_KEY_HIGHLIGHT_FG in root) {
        parseColor(cs.highlightFG, root[SCHEME_KEY_HIGHLIGHT_FG].str());
    }
    if (SCHEME_KEY_HIGHLIGHT_BG in root) {
        parseColor(cs.highlightBG, root[SCHEME_KEY_HIGHLIGHT_BG].str());
    }
    if (SCHEME_KEY_CURSOR_FG in root) {
        parseColor(cs.cursorFG, root[SCHEME_KEY_CURSOR_FG].str());
    }
    if (SCHEME_KEY_CURSOR_BG in root) {
        parseColor(cs.cursorBG, root[SCHEME_KEY_CURSOR_BG].str());
    }
    if (SCHEME_KEY_DIM_COLOR in root) {
        parseColor(cs.dimColor, root[SCHEME_KEY_DIM_COLOR].str());
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
