/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.i18n.l10n;

import glib.Internationalization;

void textdomain(string domain) {
    _textdomain = domain;
}

/**
 * Localize text using GLib integration with GNU gettext
 * and po files for translation
 */
string _(string text) {
    return Internationalization.dgettext(_textdomain, text);
}

/**
 * Uses gettext to get the translation for text in the given context.
 * This is mainly useful for short strings which may need different
 * translations, depending on the context in which they are used.
 */
string C_(string context, string text) {
    return Internationalization.dpgettext2(_textdomain, context, text);
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
