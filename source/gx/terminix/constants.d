/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.constants;

import std.path;

import gx.i18n.l10n;

//GTK Version required
immutable uint GTK_VERSION_MAJOR = 3;
immutable uint GTK_VERSION_MINOR = 14;
immutable uint GTK_VERSION_PATCH = 0;

/**
 * Application ID
 */
enum APPLICATION_ID = "com.gexperts.Terminix";

// Application values used in About Dialog
enum APPLICATION_NAME = "Terminix";
enum APPLICATION_VERSION = "0.31.0";
enum APPLICATION_AUTHOR = "Gerald Nunn";
enum APPLICATION_COPYRIGHT = "Copyright \xc2\xa9 2015 " ~ APPLICATION_AUTHOR;
enum APPLICATION_COMMENTS = _("A VTE based terminal emulator for Linux");
enum APPLICATION_LICENSE = _(
        "This Source Code Form is subject to the terms of the Mozilla Public " "License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at " "http://mozilla.org/MPL/2.0/.");

immutable string[] APPLICATION_AUTHORS = ["Gerald Nunn"];
immutable string[] APPLICATION_ARTISTS = [];
immutable string[] APPLICATION_DOCUMENTERS = [""];
immutable string APPLICATION_TRANSLATORS = "";

//GTK Settings
enum GTK_APP_PREFER_DARK_THEME = "gtk-application-prefer-dark-theme";

//Config Folder
enum APPLICATION_CONFIG_FOLDER = "terminix";

//RESOURCES
enum APPLICATION_RESOURCES = buildPath(APPLICATION_CONFIG_FOLDER, "resources/terminix.gresource");
enum APPLICATION_RESOURCE_ROOT = "resource:///com/gexperts/Terminix";
immutable string[] APPLICATION_CSS_RESOURCES = ["css/terminix.adwaita.css"];
