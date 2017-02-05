/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.constants;

import std.path;

import gx.i18n.l10n;

/****************************************************************
 * Compilation Flags, these are used to test various things or
 * to turn off work that is in process
 ****************************************************************/

/**
 * Whether to use a pixbuf for drag and Drop image
 */
immutable bool USE_PIXBUF_DND = false;

/**
 * Renders clipboard options as buttons in context menu
 */
immutable bool CLIPBOARD_BTN_IN_CONTEXT = false;

/**
 * All logs go to the file /tmp/terminix.log, useful
 * when debugging launchers or other spots where
 * stdout isn't easily viewed.
 */
immutable bool USE_FILE_LOGGING = false;

/**
 * When true builds the application for flatpak
 */
immutable bool FLATPAK = false;

/**************************************
 * Application Constants
 **************************************/

//GTK Version required
immutable uint GTK_VERSION_MAJOR = 3;
immutable uint GTK_VERSION_MINOR = 14;
immutable uint GTK_VERSION_PATCH = 0;

// GetText Domain
enum TERMINIX_DOMAIN = "terminix";

/**
 * Application ID
 */
enum APPLICATION_ID = "com.gexperts.Terminix";

// Application values used in About Dialog
enum APPLICATION_NAME = "Terminix";
enum APPLICATION_VERSION = "1.4.3-0.0.1";
enum APPLICATION_AUTHOR = "Gerald Nunn";
enum APPLICATION_COPYRIGHT = "Copyright \xc2\xa9 2016 " ~ APPLICATION_AUTHOR;
enum APPLICATION_COMMENTS = N_("A VTE based terminal emulator for Linux");
enum APPLICATION_LICENSE = N_("This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.");
enum APPLICATION_ICON_NAME = "com.gexperts.Terminix";

immutable string[] APPLICATION_AUTHORS = [APPLICATION_AUTHOR];
string[] APPLICATION_CREDITS = [
    N_("GTK VTE widget team, Terminix would not be possible without their work"),
    N_("GtkD for providing such an excellent GTK wrapper"),
    N_("Dlang.org for such an excellent language, D")
];
immutable string[] APPLICATION_ARTISTS = [];
immutable string[] APPLICATION_DOCUMENTERS = [""];
immutable string APPLICATION_TRANSLATORS = "MetotoSakamoto, frnogueira, dsboger, Philipp Wolfer, MingcongBai, Arthur2e5";

//GTK Settings
enum GTK_APP_PREFER_DARK_THEME = "gtk-application-prefer-dark-theme";
enum GTK_MENU_BAR_ACCEL = "gtk-menu-bar-accel";
enum GTK_ENABLE_ACCELS = "gtk-enable-accels";
enum GTK_DECORATION_LAYOUT = "gtk_decoration_layout";
enum GTK_SHELL_SHOWS_APP_MENU = "gtk-shell-shows-app-menu";
enum GTK_DOUBLE_CLICK_TIME = "gtk-double-click-time";

//Config Folder
enum APPLICATION_CONFIG_FOLDER = "terminix";

//RESOURCES
enum APPLICATION_RESOURCES = buildPath(APPLICATION_CONFIG_FOLDER, "resources/terminix.gresource");
enum APPLICATION_RESOURCE_ROOT = "/com/gexperts/Terminix";
immutable string[] APPLICATION_CSS_RESOURCES = ["css/terminix.base.css"];

immutable string SHORTCUT_UI_RESOURCE = APPLICATION_RESOURCE_ROOT ~ "/ui/shortcuts.ui";
immutable string SHORTCUT_LOCALIZATION_CONTEXT = "shortcut window";


// Constants used for the various variables permitted when defining
// the terminal title.
enum VARIABLE_TERMINAL_TITLE = "${title}";
enum VARIABLE_TERMINAL_ICON_TITLE = "${iconTitle}";
enum VARIABLE_TERMINAL_ID = "${id}";
enum VARIABLE_TERMINAL_DIR = "${directory}";
enum VARIABLE_TERMINAL_COLUMNS = "${columns}";
enum VARIABLE_TERMINAL_ROWS = "${rows}";
enum VARIABLE_TERMINAL_HOSTNAME = "${hostname}";
enum VARIABLE_TERMINAL_USERNAME = "${username}";

immutable string[] VARIABLE_TERMINAL_VALUES = [
    VARIABLE_TERMINAL_TITLE,
    VARIABLE_TERMINAL_ICON_TITLE ,
    VARIABLE_TERMINAL_ID,
    VARIABLE_TERMINAL_DIR,
    VARIABLE_TERMINAL_HOSTNAME,
    VARIABLE_TERMINAL_USERNAME,
    VARIABLE_TERMINAL_COLUMNS,
    VARIABLE_TERMINAL_ROWS
    ];

immutable string[] VARIABLE_TERMINAL_LOCALIZED = [
    N_("Title"),
    N_("Icon title"),
    N_("ID"),
    N_("Directory"),
    N_("Hostname"),
    N_("Username"),
    N_("Columns"),
    N_("Rows")
    ];

// Application Window Title tokens
enum VARIABLE_APP_NAME = "${appName}";
enum VARIABLE_SESSION_NAME = "${sessionName}";
enum VARIABLE_SESSION_NUMBER = "${sessionNumber}";

immutable string[] VARIABLE_WINDOW_VALUES = [
    VARIABLE_APP_NAME,
    VARIABLE_SESSION_NAME,
    VARIABLE_SESSION_NUMBER
];

immutable string[] VARIABLE_WINDOW_LOCALIZED = [
    N_("Application name"),
    N_("Session name"),
    N_("Session number")
];