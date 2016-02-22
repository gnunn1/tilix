/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.i18n.l10n;

import glib.Internationalization;

/**
 * When compiled with the 'Localize' version tag all requests
 * for localization will be saved and output to  terminix.pot
 * in the same directory as the executable.
 *
 * This is frankly a cheap way to generated a .pot file since
 * xgettext does not support D at this time. It does require the
 * user to completely exercise the interface to capture all of
 * the localizations and is likely error-prone. The intent of
 * this is to use as a one-shot mechanism to generate an initial
 * .pot file though subsequent invocations may be useful for diffs
 */
version (Localize) {

    import std.experimental.logger;
    import std.file;
    import std.string;

    string[string] messages;

    void saveFile(string filename) {
        string output;
        foreach(key,value; messages) {
            if (key.indexOf("%") >= 0) {
                output ~= "#, c-format\n";
            }
            if (key.indexOf("\n") >= 0) {
                string lines;
                foreach(s;key.splitLines()) {
                    lines ~= "\"" ~ s ~ "\"\n";
                }
                output ~= ("msgid \"\"\n" ~ lines);
                output ~= ("msgstr \"\"\n" ~ lines ~ "\n");
            } else {
                output ~= "msgid \"" ~ key ~ "\"\n";
                output ~= "msgstr \"" ~ key ~ "\"\n\n";
            }
        }
        write(filename, output);
    }
}

void textdomain(string domain) {
    _textdomain = domain;
}

/**
 * Localize text using GLib integration with GNU gettext
 * and po files for translation
 */
string _(string text) {
    version (Localize) {
        trace("Capturing key " ~ text);
        messages[text] = text;
    }

    return Internationalization.dgettext(_textdomain, text);
}

/**
 * Only marks a string for translation. This is useful in situations where the
 * translated strings can't be directly used, e.g. in string array initializers.
 * To get the translated string, call _() at runtime.
 */
string N_(string text) {
    return text;
}

private:
string _textdomain;
