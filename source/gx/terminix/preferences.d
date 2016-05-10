/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.preferences;

import std.experimental.logger;
import std.format;
import std.range;
import std.uuid;

import gio.Settings : GSettings = Settings;

import gx.i18n.l10n;
import gx.util.array;

//Gnome Desktop Settings
enum SETTINGS_DESKTOP_ID = "org.gnome.desktop.interface";
enum SETTINGS_MONOSPACE_FONT_KEY = "monospace-font-name";

//Preference Constants
enum SETTINGS_ID = "com.gexperts.Terminix.Settings";
enum SETTINGS_BASE_PATH = "/com/gexperts/Terminix";

enum SETTINGS_THEME_VARIANT_KEY = "theme-variant";
enum SETTINGS_THEME_VARIANT_SYSTEM_VALUE = "system";
enum SETTINGS_THEME_VARIANT_LIGHT_VALUE = "light";
enum SETTINGS_THEME_VARIANT_DARK_VALUE = "dark";
immutable string[] SETTINGS_THEME_VARIANT_VALUES = [SETTINGS_THEME_VARIANT_SYSTEM_VALUE, SETTINGS_THEME_VARIANT_LIGHT_VALUE, SETTINGS_THEME_VARIANT_DARK_VALUE];

enum SETTINGS_NEW_INSTANCE_MODE_KEY = "new-instance-mode";
immutable string[] SETTINGS_NEW_INSTANCE_MODE_VALUES = ["new-window", "new-session", "split-right", "split-down", "focus-window"];

enum SETTINGS_MENU_ACCELERATOR_KEY = "menu-accelerator-enabled";
enum SETTINGS_DISABLE_CSD_KEY = "disable-csd";
enum SETTINGS_AUTO_HIDE_MOUSE_KEY = "auto-hide-mouse";
enum SETTINGS_PROMPT_ON_NEW_SESSION_KEY = "prompt-on-new-session";
enum SETTINGS_ENABLE_TRANSPARENCY_KEY = "enable-transparency";

enum SETTINGS_TERMINAL_TITLE_STYLE_KEY = "terminal-title-style";
enum SETTINGS_TERMINAL_TITLE_STYLE_VALUE_NORMAL = "normal";
enum SETTINGS_TERMINAL_TITLE_STYLE_VALUE_SMALL = "small";
enum SETTINGS_TERMINAL_TITLE_STYLE_VALUE_NONE = "none";
immutable string[] SETTINGS_TERMINAL_TITLE_STYLE_VALUES = [SETTINGS_TERMINAL_TITLE_STYLE_VALUE_NORMAL, SETTINGS_TERMINAL_TITLE_STYLE_VALUE_SMALL, SETTINGS_TERMINAL_TITLE_STYLE_VALUE_NONE];

enum SETTINGS_ENABLE_WIDE_HANDLE_KEY = "enable-wide-handle";
enum SETTINGS_NOTIFY_ON_PROCESS_COMPLETE_KEY = "notify-on-process-complete";
enum SETTINGS_UNSAFE_PASTE_ALERT_KEY = "unsafe-paste-alert";
enum SETTINGS_STRIP_FIRST_COMMENT_CHAR_ON_PASTE_KEY = "paste-strip-first-char";
enum SETTINGS_WARN_VTE_CONFIG_ISSUE_KEY = "warn-vte-config-issue";
enum SETTINGS_TERMINAL_FOCUS_FOLLOWS_MOUSE_KEY = "focus-follow-mouse";
enum SETTINGS_ENCODINGS_KEY = "encodings";

enum SETTINGS_SEARCH_DEFAULT_MATCH_CASE = "search-default-match-case";
enum SETTINGS_SEARCH_DEFAULT_MATCH_ENTIRE_WORD = "search-default-match-entire-word";
enum SETTINGS_SEARCH_DEFAULT_MATCH_AS_REGEX = "search-default-match-as-regex";
enum SETTINGS_SEARCH_DEFAULT_WRAP_AROUND = "search-default-wrap-around";

//Profile Preference Constants
enum SETTINGS_PROFILE_LIST_ID = "com.gexperts.Terminix.ProfilesList";
enum SETTINGS_PROFILE_ID = "com.gexperts.Terminix.Profile";
enum SETTINGS_PROFILE_PATH = SETTINGS_BASE_PATH ~ "/profiles/";
enum SETTINGS_PROFILE_DEFAULT_KEY = "default";
enum SETTINGS_PROFILE_LIST_KEY = "list";
enum SETTINGS_PROFILE_VISIBLE_NAME_KEY = "visible-name";

enum SETTINGS_PROFILE_SIZE_COLUMNS_KEY = "default-size-columns";
enum SETTINGS_PROFILE_SIZE_ROWS_KEY = "default-size-rows";
enum SETTINGS_PROFILE_AUDIBLE_BELL_KEY = "audible-bell";
enum SETTINGS_PROFILE_ALLOW_BOLD_KEY = "allow-bold";
enum SETTINGS_PROFILE_REWRAP_KEY = "rewrap-on-resize";

enum SETTINGS_PROFILE_CURSOR_SHAPE_KEY = "cursor-shape";
enum SETTINGS_PROFILE_CURSOR_SHAPE_BLOCK_VALUE = "block";
enum SETTINGS_PROFILE_CURSOR_SHAPE_IBEAM_VALUE = "ibeam";
enum SETTINGS_PROFILE_CURSOR_SHAPE_UNDERLINE_VALUE = "underline";
enum SETTINGS_PROFILE_CURSOR_BLINK_MODE_KEY = "cursor-blink-mode";
immutable string[] SETTINGS_PROFILE_CURSOR_BLINK_MODE_VALUES = ["system", "on", "off"];
enum SETTINGS_PROFILE_USE_SYSTEM_FONT_KEY = "use-system-font";
enum SETTINGS_PROFILE_FONT_KEY = "font";

enum SETTINGS_PROFILE_BG_COLOR_KEY = "background-color";
enum SETTINGS_PROFILE_FG_COLOR_KEY = "foreground-color";
enum SETTINGS_PROFILE_BG_TRANSPARENCY_KEY = "background-transparency-percent";
enum SETTINGS_PROFILE_PALETTE_COLOR_KEY = "palette";
enum SETTINGS_PROFILE_USE_THEME_COLORS_KEY = "use-theme-colors";
enum SETTINGS_PROFILE_USE_HIGHLIGHT_COLOR_KEY = "highlight-colors-set";
enum SETTINGS_PROFILE_HIGHLIGHT_FG_COLOR_KEY = "highlight-foreground-color";
enum SETTINGS_PROFILE_HIGHLIGHT_BG_COLOR_KEY = "highlight-background-color";
enum SETTINGS_PROFILE_USE_CURSOR_COLOR_KEY = "cursor-colors-set";
enum SETTINGS_PROFILE_CURSOR_FG_COLOR_KEY = "cursor-foreground-color";
enum SETTINGS_PROFILE_CURSOR_BG_COLOR_KEY = "cursor-background-color";
enum SETTINGS_PROFILE_USE_DIM_COLOR_KEY = "dim-color-set";
enum SETTINGS_PROFILE_DIM_COLOR_KEY = "dim-color";
enum SETTINGS_PROFILE_DIM_TRANSPARENCY_KEY = "dim-transparency-percent";

enum SETTINGS_PROFILE_SHOW_SCROLLBAR_KEY = "show-scrollbar";
enum SETTINGS_PROFILE_SCROLL_ON_OUTPUT_KEY = "scroll-on-output";
enum SETTINGS_PROFILE_SCROLL_ON_INPUT_KEY = "scroll-on-keystroke";
enum SETTINGS_PROFILE_UNLIMITED_SCROLL_KEY = "scrollback-unlimited";
enum SETTINGS_PROFILE_SCROLLBACK_LINES_KEY = "scrollback-lines";

enum SETTINGS_PROFILE_BACKSPACE_BINDING_KEY = "backspace-binding";
immutable string[] SETTINGS_PROFILE_ERASE_BINDING_VALUES = ["auto", "ascii-backspace", "ascii-delete", "delete-sequence", "tty"];
enum SETTINGS_PROFILE_DELETE_BINDING_KEY = "delete-binding";
enum SETTINGS_PROFILE_ENCODING_KEY = "encoding";
enum SETTINGS_PROFILE_CJK_WIDTH_KEY = "cjk-utf8-ambiguous-width";
immutable string[] SETTINGS_PROFILE_CJK_WIDTH_VALUES = ["narrow", "wide"];

enum SETTINGS_PROFILE_EXIT_ACTION_KEY = "exit-action";
enum SETTINGS_PROFILE_EXIT_ACTION_CLOSE_VALUE = "close";
enum SETTINGS_PROFILE_EXIT_ACTION_RESTART_VALUE = "restart";
enum SETTINGS_PROFILE_EXIT_ACTION_HOLD_VALUE = "hold";
immutable string[] SETTINGS_PROFILE_EXIT_ACTION_VALUES = [
    SETTINGS_PROFILE_EXIT_ACTION_CLOSE_VALUE, SETTINGS_PROFILE_EXIT_ACTION_RESTART_VALUE, SETTINGS_PROFILE_EXIT_ACTION_HOLD_VALUE
];
enum SETTINGS_PROFILE_LOGIN_SHELL_KEY = "login-shell";
enum SETTINGS_PROFILE_USE_CUSTOM_COMMAND_KEY = "use-custom-command";
enum SETTINGS_PROFILE_CUSTOM_COMMAND_KEY = "custom-command";

enum SETTINGS_PROFILE_TITLE_KEY = "terminal-title";

//Shortcuts
enum SETTINGS_PROFILE_KEY_BINDINGS_ID = "com.gexperts.Terminix.Keybindings";

/**
 * The default value to use for the name of the default profile
 */
enum SETTINGS_PROFILE_DEFAULT_NAME_VALUE = "Default";

/**
 * The value to use for the name of a new profile
 */
enum SETTINGS_PROFILE_NEW_NAME_VALUE = "Unnamed";

/**
 * Structure that represents a Profile in GSettings
 */
struct ProfileInfo {
    /**
	 * Whether this is the default profile
	 */
    bool isDefault;

    /**
	 * The UUID that uniquely identifies this profile
	 */
    string uuid;

    /**
	 * The human readable name for the profile
	 */
    string name;
}

/**
 * A class for managing terminal profiles. This is a singleton which
 * is initialized by the application and set to the PfrMgr global
 * variable below.
 */
class ProfileManager {

private:

    enum GSETTINGS_DEFAULT_UUID = "2b7c4080-0ddd-46c5-8f23-563fd3ba789d";

    GSettings gsProfileList;

    string getProfilePath(string uuid) {
        return SETTINGS_PROFILE_PATH ~ uuid ~ "/";
    }

package:
    /**
	 * Creates and initializes the ProfileManager. If no default
	 * profile exists one is created automatically when this is
	 * constructed.
	 */
    this() {
        gsProfileList = new GSettings(SETTINGS_PROFILE_LIST_ID);
    }

public:

    /**
	 * Creates a profile in GSettings and optionally sets it as the default.
	 */
    ProfileInfo createProfile(string profileName, bool isDefault = false) {
        string uuid = randomUUID().toString();
        /*
		scope(failure) {
			error(format("Failed to create profile %s", uuid));
			return ProfileInfo(false, null, null);
		}
		*/
        //Create Profile
        GSettings gsProfile = getProfileSettings(uuid);
        trace("Got profile settings for " ~ uuid);
        gsProfile.setString(SETTINGS_PROFILE_VISIBLE_NAME_KEY, profileName);
        trace("Set profile name " ~ profileName);

        string[] ps = gsProfileList.getStrv(SETTINGS_PROFILE_LIST_KEY);
        trace("Get list of profiles");

        ps ~= uuid;
        gsProfileList.setStrv(SETTINGS_PROFILE_LIST_KEY, ps);
        trace("Update list to include new profile");
        if (isDefault) {
            gsProfileList.setString(SETTINGS_PROFILE_DEFAULT_KEY, uuid);
        }
        return ProfileInfo(isDefault, uuid, profileName);
    }

    /**
	 * Deletes the specified profile in GSettings
	 *
	 * @param uuid the identifier of the profile to delete
	 */
    void deleteProfile(string uuid) {
        string[] ps = gsProfileList.getStrv(SETTINGS_PROFILE_LIST_KEY);
        remove(ps, uuid);
        gsProfileList.setStrv(SETTINGS_PROFILE_LIST_KEY, ps);
        if (uuid == getDefaultProfile() && ps.length > 0) {
            //Update default profile to be the first one
            gsProfileList.setString(SETTINGS_PROFILE_DEFAULT_KEY, ps[0]);
        }
        //TODO - Need to figure out a way to remove path from GSettings
        //GSettings has no API to do this, terminal is using dconf API directly
        //This delete removes the profile in the sense it is no longer in the list
        //but otherwise it stays in dconf, try resetting it to see if resetting to default
        //effectively removes it
        GSettings gsProfile = getProfileSettings(uuid);
        string[] keys = gsProfile.listKeys();
        foreach (string key; keys) {
            gsProfile.reset(key);
        }
    }

    /**
	 * Returns information about the specified profile. Note there is
	 * no point calling this if you just are going to the Profile Settings
	 * object anyway, just get the settings object and retrieve the information
	 * you need from that.
	 *
	 * @param uuid The identifier of the profile to retrieve
	 */
    ProfileInfo getProfile(string uuid) {
        GSettings gsProfile = getProfileSettings(uuid);
        string name = gsProfile.getString(SETTINGS_PROFILE_VISIBLE_NAME_KEY);
        // Because the default profile name is 'unnamed', if we run the
        // app for the first time the name says Unnamed instead of Default
        // so check for this here by comparing name to Unnamed and uuid to default
        if (GSETTINGS_DEFAULT_UUID == uuid && name == _(SETTINGS_PROFILE_NEW_NAME_VALUE)) {
            gsProfile.setString(SETTINGS_PROFILE_VISIBLE_NAME_KEY, _(SETTINGS_PROFILE_DEFAULT_NAME_VALUE));
            name = SETTINGS_PROFILE_DEFAULT_NAME_VALUE;
        }
        trace(format("Getting profile '%s', default profile is '%s'", uuid, getDefaultProfile()));
        return ProfileInfo(uuid == getDefaultProfile(), uuid, name);
    }

    /**
	 * Returns a list of profiles
	 */
    ProfileInfo[] getProfiles() {
        ProfileInfo[] results;
        string[] ps = gsProfileList.getStrv(SETTINGS_PROFILE_LIST_KEY);
        foreach (string uuid; ps) {
            results ~= getProfile(uuid);
        }
        return results;
    }

    string[] getProfileUUIDs() {
        return gsProfileList.getStrv(SETTINGS_PROFILE_LIST_KEY);
    }

    string getProfileUUIDFromName(string profileName) {
        ProfileInfo[] profiles = getProfiles();
        foreach (profile; profiles) {
            if (profile.name == profileName)
                return profile.uuid;
        }
        return null;
    }

    /**
	 * Returns the GSettings object that corresponds to a specific profile. This
	 * object should not be shared between multiple classes. Also note that GtkD
	 * does not allow you to remove event handlers thus care should be taken to only
	 * connect from objects which will have a similar lifecycle as the settings.
	 *
	 * @param uuid The identifier of the profile
	 */
    GSettings getProfileSettings(string uuid) {
        return new GSettings(SETTINGS_PROFILE_ID, getProfilePath(uuid));
    }

    /**
	 * Returns the UUID of the default profile.
	 */
    string getDefaultProfile() {
        return gsProfileList.getString(SETTINGS_PROFILE_DEFAULT_KEY);
    }

    void setDefaultProfile(string uuid) {
        gsProfileList.setString(SETTINGS_PROFILE_DEFAULT_KEY, uuid);
    }
}

void initProfileManager() {
    prfMgr = new ProfileManager();
}

/**
 * Instance variable for the ProfileManager. It is the responsibility of the
 * application to initialize this. Debated about using a Java like singleton pattern
 * but let's keep it simple for now.
 *
 * Also note that this variable is meant to be accessed only from the GTK main thread
 * and hence is not declared as shared.
 */
ProfileManager prfMgr;

unittest {
    ProfileInfo pi1 = ProfileInfo(false, "1234", "test");
    ProfileInfo pi2 = ProfileInfo(false, "1234", "test");
    assert(pi1 == pi2);
}
