/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.shortcuts;

import std.algorithm;
import std.experimental.logger;
import std.path;
import std.typecons : Yes;

import gio.settings : Settings;

import gobject.c.functions : g_object_new;
import gobject.c.types : GObject;

import gtk.builder : Builder;
import gtk.shortcuts_group : ShortcutsGroup;
import gtk.shortcuts_shortcut : ShortcutsShortcut;
import gtk.shortcuts_window : ShortcutsWindow;

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
    Settings gsShortcuts = new Settings(SETTINGS_KEY_BINDINGS_ID);
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

    // Add Profile shortcuts to window
    ShortcutsGroup sgProfile = cast(ShortcutsGroup) builder.getObject("profile");
    if (sgProfile !is null) {
        string[] uuids = prfMgr.getProfileUUIDs();
        foreach (uuid; uuids) {
            Settings gsProfile = prfMgr.getProfileSettings(uuid);
            if (gsProfile !is null) {
                string accelName = gsProfile.getString(SETTINGS_PROFILE_SHORTCUT_KEY);
                if (accelName == SHORTCUT_DISABLED) accelName.length = 0;
                trace("Create ShortcutShortcut");
                // Create ShortcutsShortcut via C API and wrap with GID
                GObject* cObj = g_object_new(ShortcutsShortcut._getGType(), null);
                ShortcutsShortcut ss = new ShortcutsShortcut(cast(void*)cObj, Yes.Take);
                ss.title = gsProfile.getString(SETTINGS_PROFILE_VISIBLE_NAME_KEY);
                ss.accelerator = accelName;
                if (ss !is null) {
                    sgProfile.add(ss);
                } else {
                    trace("Profile ShortcutShortcut is null");
                }
            }
        }
    } else {
        trace("Didn't find profile ShortcutGroup");
    }

    return cast(ShortcutsWindow) builder.getObject("shortcuts-tilix");
}