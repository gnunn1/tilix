/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.shortcuts;

import std.algorithm;
import std.experimental.logger;
import std.path;

import gio.Settings;

import gobject.Value;

import gtkc.gobject;

import gtk.Builder;
import gtk.ShortcutsShortcut;
import gtk.ShortcutsWindow;

import gx.gtk.actions;
import gx.i18n.l10n;

import gx.tilix.constants;
import gx.tilix.preferences;

public:

ShortcutsWindow getShortcutWindow() {
    Builder builder = new Builder();
    builder.setTranslationDomain(TILIX_DOMAIN);
    if (!builder.addFromResource(SHORTCUT_UI_RESOURCE)) {
        error("Could not load shortcuts from " ~ SHORTCUT_UI_RESOURCE);
        return null;
    }
    Settings gsShortcuts = new Settings(SETTINGS_PROFILE_KEY_BINDINGS_ID);
    string[] keys = gsShortcuts.listKeys();
    foreach(key; keys) {
        ShortcutsShortcut ss = cast(ShortcutsShortcut) builder.getObject(key);
        if (ss !is null) {
            string accelName = gsShortcuts.getString(key);
            if (accelName == SHORTCUT_DISABLED) accelName.length = 0;
            ss.setProperty("accelerator", accelName);
        } else {
            trace("Could not find shortcut for " ~ key);
        }
    }

    return cast(ShortcutsWindow) builder.getObject("shortcuts-tilix");
}