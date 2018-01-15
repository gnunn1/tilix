/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.preferences;

import std.algorithm;
import std.experimental.logger;
import std.path;
import std.range;
import std.string;
import std.uuid;

import gio.Settings : GSettings = Settings;

import glib.Variant : GVariant = Variant;

import gx.i18n.l10n;
import gx.util.array;

import gx.tilix.common;
import gx.tilix.constants;

//Gnome Desktop Settings
enum SETTINGS_DESKTOP_ID = "org.gnome.desktop.interface";
enum SETTINGS_MONOSPACE_FONT_KEY = "monospace-font-name";

//Gnome Proxy Settings
enum SETTINGS_PROXY_ID = "org.gnome.system.proxy";

//Preference Constants
enum SETTINGS_ID = "com.gexperts.Tilix.Settings";
enum SETTINGS_BASE_PATH = "/com/gexperts/Tilix";

// Settings for links and triggers that can be set at both global and profile level
enum SETTINGS_ALL_CUSTOM_HYPERLINK_KEY = "custom-hyperlinks";
enum SETTINGS_ALL_TRIGGERS_KEY = "triggers";
enum SETTINGS_TRIGGERS_LINES_KEY = "triggers-lines";
enum SETTINGS_TRIGGERS_UNLIMITED_LINES_KEY = "trigger-unlimit-lines";

// Theme Settings
enum SETTINGS_THEME_VARIANT_KEY = "theme-variant";
enum SETTINGS_THEME_VARIANT_SYSTEM_VALUE = "system";
enum SETTINGS_THEME_VARIANT_LIGHT_VALUE = "light";
enum SETTINGS_THEME_VARIANT_DARK_VALUE = "dark";
immutable string[] SETTINGS_THEME_VARIANT_VALUES = [SETTINGS_THEME_VARIANT_SYSTEM_VALUE, SETTINGS_THEME_VARIANT_LIGHT_VALUE, SETTINGS_THEME_VARIANT_DARK_VALUE];

enum SETTINGS_NEW_INSTANCE_MODE_KEY = "new-instance-mode";
enum SETTINGS_NEW_INSTANCE_MODE_NEW_WINDOW_VALUE = "new-window";
enum SETTINGS_NEW_INSTANCE_MODE_NEW_SESSION_VALUE = "new-session";
enum SETTINGS_NEW_INSTANCE_MODE_SPLIT_RIGHT_VALUE = "split-right";
enum SETTINGS_NEW_INSTANCE_MODE_SPLIT_DOWN_VALUE = "split-down";
enum SETTINGS_NEW_INSTANCE_MODE_FOCUS_WINDOW_VALUE = "focus-window";
immutable string[] SETTINGS_NEW_INSTANCE_MODE_VALUES = [SETTINGS_NEW_INSTANCE_MODE_NEW_WINDOW_VALUE, SETTINGS_NEW_INSTANCE_MODE_NEW_SESSION_VALUE, SETTINGS_NEW_INSTANCE_MODE_SPLIT_RIGHT_VALUE, SETTINGS_NEW_INSTANCE_MODE_SPLIT_DOWN_VALUE, SETTINGS_NEW_INSTANCE_MODE_FOCUS_WINDOW_VALUE];

enum SETTINGS_MENU_ACCELERATOR_KEY = "menu-accelerator-enabled";
enum SETTINGS_ACCELERATORS_ENABLED = "accelerators-enabled";

enum SETTINGS_WINDOW_STATE_KEY = "window-state";
enum SETTINGS_WINDOW_SAVE_STATE_KEY = "window-save-state";
enum SETTINGS_WINDOW_STYLE_KEY = "window-style";
immutable string[] SETTINGS_WINDOW_STYLE_VALUES = ["normal","disable-csd","disable-csd-hide-toolbar","borderless"];

enum SETTINGS_AUTO_HIDE_MOUSE_KEY = "auto-hide-mouse";
enum SETTINGS_PROMPT_ON_NEW_SESSION_KEY = "prompt-on-new-session";
enum SETTINGS_ENABLE_TRANSPARENCY_KEY = "enable-transparency";
enum SETTINGS_CLOSE_WITH_LAST_SESSION_KEY = "close-with-last-session";
enum SETTINGS_APP_TITLE_KEY = "app-title";
enum SETTINGS_CONTROL_CLICK_TITLE_KEY = "control-click-titlebar";
enum SETTINGS_INHERIT_WINDOW_STATE_KEY = "new-window-inherit-state";
enum SETTINGS_USE_OVERLAY_SCROLLBAR_KEY = "use-overlay-scrollbar";

enum SETTINGS_TERMINAL_TITLE_STYLE_KEY = "terminal-title-style";
enum SETTINGS_TERMINAL_TITLE_STYLE_VALUE_NORMAL = "normal";
enum SETTINGS_TERMINAL_TITLE_STYLE_VALUE_SMALL = "small";
enum SETTINGS_TERMINAL_TITLE_STYLE_VALUE_NONE = "none";
immutable string[] SETTINGS_TERMINAL_TITLE_STYLE_VALUES = [SETTINGS_TERMINAL_TITLE_STYLE_VALUE_NORMAL, SETTINGS_TERMINAL_TITLE_STYLE_VALUE_SMALL, SETTINGS_TERMINAL_TITLE_STYLE_VALUE_NONE];

enum SETTINGS_TERMINAL_TITLE_SHOW_WHEN_SINGLE_KEY = "terminal-title-show-when-single";

enum SETTINGS_SESSION_NAME_KEY = "session-name";

enum SETTINGS_ENABLE_WIDE_HANDLE_KEY = "enable-wide-handle";
enum SETTINGS_NOTIFY_ON_PROCESS_COMPLETE_KEY = "notify-on-process-complete";
enum SETTINGS_UNSAFE_PASTE_ALERT_KEY = "unsafe-paste-alert";
enum SETTINGS_STRIP_FIRST_COMMENT_CHAR_ON_PASTE_KEY = "paste-strip-first-char";
enum SETTINGS_PASTE_ADVANCED_DEFAULT_KEY="paste-advanced-default";
enum SETTINGS_COPY_ON_SELECT_KEY = "copy-on-select";
enum SETTINGS_WARN_VTE_CONFIG_ISSUE_KEY = "warn-vte-config-issue";
enum SETTINGS_TERMINAL_FOCUS_FOLLOWS_MOUSE_KEY = "focus-follow-mouse";
enum SETTINGS_ENCODINGS_KEY = "encodings";
enum SETTINGS_MIDDLE_CLICK_CLOSE_KEY = "middle-click-close";
enum SETTINGS_CONTROL_SCROLL_ZOOM_KEY = "control-scroll-zoom";
enum SETTINGS_PASSWORD_INCLUDE_RETURN_KEY = "password-include-return";
enum SETTINGS_BOOKMARK_INCLUDE_RETURN_KEY = "bookmark-include-return";

enum SETTINGS_SEARCH_DEFAULT_MATCH_CASE = "search-default-match-case";
enum SETTINGS_SEARCH_DEFAULT_MATCH_ENTIRE_WORD = "search-default-match-entire-word";
enum SETTINGS_SEARCH_DEFAULT_MATCH_AS_REGEX = "search-default-match-as-regex";
enum SETTINGS_SEARCH_DEFAULT_WRAP_AROUND = "search-default-wrap-around";

enum SETTINGS_BACKGROUND_IMAGE_KEY = "background-image";
enum SETTINGS_BACKGROUND_IMAGE_SCALE_KEY = "background-image-scale";
enum SETTINGS_BACKGROUND_IMAGE_MODE_KEY = "background-image-mode";
enum SETTINGS_BACKGROUND_IMAGE_MODE_SCALE_VALUE = "scale";
enum SETTINGS_BACKGROUND_IMAGE_MODE_TILE_VALUE = "tile";
enum SETTINGS_BACKGROUND_IMAGE_MODE_CENTER_VALUE = "center";
enum SETTINGS_BACKGROUND_IMAGE_MODE_STRETCH_VALUE = "stretch";
immutable string[] SETTINGS_BACKGROUND_IMAGE_MODE_VALUES = [SETTINGS_BACKGROUND_IMAGE_MODE_SCALE_VALUE,SETTINGS_BACKGROUND_IMAGE_MODE_TILE_VALUE,SETTINGS_BACKGROUND_IMAGE_MODE_CENTER_VALUE,SETTINGS_BACKGROUND_IMAGE_MODE_STRETCH_VALUE];

enum SETTINGS_SIDEBAR_RIGHT = "sidebar-on-right";
enum SETTINGS_RECENT_SESSION_FILES_KEY = "recent-session-files";

enum SETTINGS_PROMPT_ON_CLOSE_KEY = "prompt-on-close";
enum SETTINGS_PROMPT_ON_CLOSE_PROCESS_KEY = "prompt-on-close-process";
enum SETTINGS_PROMPT_ON_DELETE_PROFILE_KEY="prompt-on-delete-profile";

//Quake Settings
enum SETTINGS_QUAKE_WIDTH_PERCENT_KEY = "quake-width-percent";
enum SETTINGS_QUAKE_HEIGHT_PERCENT_KEY = "quake-height-percent";
enum SETTINGS_QUAKE_ACTIVE_MONITOR_KEY = "quake-active-monitor";
enum SETTINGS_QUAKE_SPECIFIC_MONITOR_KEY = "quake-specific-monitor";
enum SETTINGS_QUAKE_SHOW_ON_ALL_WORKSPACES_KEY = "quake-show-on-all-workspaces";
/*
enum SETTINGS_QUAKE_DISABLE_ANIMATION_KEY = "quake-disable-animation";
*/
enum SETTINGS_QUAKE_HIDE_LOSE_FOCUS_KEY = "quake-hide-lose-focus";
enum SETTINGS_QUAKE_HIDE_LOSE_FOCUS_DELAY_KEY = "quake-hide-lose-focus-delay";
enum SETTINGS_QUAKE_ALIGNMENT_KEY = "quake-alignment";
enum SETTINGS_QUAKE_ALIGNMENT_LEFT_VALUE = "left";
enum SETTINGS_QUAKE_ALIGNMENT_CENTER_VALUE = "center";
enum SETTINGS_QUAKE_ALIGNMENT_RIGHT_VALUE = "right";
enum SETTINGS_QUAKE_HIDE_HEADERBAR_KEY = "quake-hide-headerbar";
enum SETTINGS_QUAKE_TAB_POSITION_KEY = "quake-tab-position";
//enum SETTINGS_QUAKE_KEEP_ON_TOP_KEY = "quake-keep-on-top";

//Advanced Paste Settings
enum SETTINGS_ADVANCED_PASTE_REPLACE_TABS_KEY = "advanced-paste-replace-tabs";
enum SETTINGS_ADVANCED_PASTE_SPACE_COUNT_KEY = "advanced-paste-space-count";
enum SETTINGS_ADVANCED_PASTE_REPLACE_CRLF_KEY = "advanced-paste-replace-crlf";

enum SETTINGS_USE_TABS_KEY = "use-tabs";
enum SETTINGS_TAB_POSITION_KEY = "tab-position";
immutable string[] SETTINGS_TAB_POSITION_VALUES = ["left", "right", "top", "bottom"];

//Proxy Environment Variables
enum SETTINGS_SET_PROXY_ENV_KEY = "set-proxy-env";

//Profile Preference Constants
enum SETTINGS_PROFILE_LIST_ID = "com.gexperts.Tilix.ProfilesList";
enum SETTINGS_PROFILE_ID = "com.gexperts.Tilix.Profile";
enum SETTINGS_PROFILE_PATH = SETTINGS_BASE_PATH ~ "/profiles/";
enum SETTINGS_PROFILE_DEFAULT_KEY = "default";
enum SETTINGS_PROFILE_LIST_KEY = "list";
enum SETTINGS_PROFILE_VISIBLE_NAME_KEY = "visible-name";
enum SETTINGS_PROFILE_WORD_WISE_SELECT_CHARS_KEY = "select-by-word-chars";

enum SETTINGS_PROFILE_TERMINAL_BELL_KEY = "terminal-bell";
enum SETTINGS_PROFILE_TERMINAL_BELL_NONE_VALUE = "none";
enum SETTINGS_PROFILE_TERMINAL_BELL_SOUND_VALUE = "sound";
enum SETTINGS_PROFILE_TERMINAL_BELL_ICON_VALUE = "icon";
enum SETTINGS_PROFILE_TERMINAL_BELL_ICON_SOUND_VALUE = "icon-sound";
immutable string[] SETTINGS_PROFILE_TERMINAL_BELL_VALUES = [SETTINGS_PROFILE_TERMINAL_BELL_NONE_VALUE, SETTINGS_PROFILE_TERMINAL_BELL_SOUND_VALUE, SETTINGS_PROFILE_TERMINAL_BELL_ICON_VALUE, SETTINGS_PROFILE_TERMINAL_BELL_ICON_SOUND_VALUE];

enum SETTINGS_PROFILE_SIZE_COLUMNS_KEY = "default-size-columns";
enum SETTINGS_PROFILE_SIZE_ROWS_KEY = "default-size-rows";
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

enum SETTINGS_PROFILE_TEXT_BLINK_MODE_KEY = "text-blink-mode";
immutable string[] SETTINGS_PROFILE_TEXT_BLINK_MODE_VALUES = ["never", "focused", "unfocused", "always"];
enum SETTINGS_PROFILE_BOLD_IS_BRIGHT_KEY = "bold-is-bright";

enum SETTINGS_PROFILE_CELL_HEIGHT_SCALE_KEY = "cell-height-scale";
enum SETTINGS_PROFILE_CELL_WIDTH_SCALE_KEY = "cell-width-scale";

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
enum SETTINGS_PROFILE_DIM_TRANSPARENCY_KEY = "dim-transparency-percent";
enum SETTINGS_PROFILE_BOLD_COLOR_KEY = "bold-color";
enum SETTINGS_PROFILE_USE_BOLD_COLOR_KEY = "bold-color-set";

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

enum SETTINGS_PROFILE_AUTOMATIC_SWITCH_KEY = "automatic-switch";

enum SETTINGS_PROFILE_NOTIFY_SILENCE_THRESHOLD_KEY = "notify-silence-threshold";

//Shortcuts
enum SETTINGS_PROFILE_KEY_BINDINGS_ID = "com.gexperts.Tilix.Keybindings";

/**
 * The default value to use for the name of the default profile
 */
enum SETTINGS_PROFILE_DEFAULT_NAME_VALUE = "Default";

/**
 * The value to use for the name of a new profile
 */
enum SETTINGS_PROFILE_NEW_NAME_VALUE = "Unnamed";

immutable string SETTINGS_PROFILE_TRIGGER_UPDATE_STATE_VALUE = N_("UpdateState");
immutable string SETTINGS_PROFILE_TRIGGER_EXECUTE_COMMAND_VALUE = N_("ExecuteCommand");
immutable string SETTINGS_PROFILE_TRIGGER_SEND_NOTIFICATION_VALUE = N_("SendNotification");
immutable string SETTINGS_PROFILE_TRIGGER_UPDATE_TITLE_VALUE = N_("UpdateTitle");
immutable string SETTINGS_PROFILE_TRIGGER_PLAY_BELL_VALUE = N_("PlayBell");
immutable string SETTINGS_PROFILE_TRIGGER_SEND_TEXT_VALUE = N_("SendText");
immutable string SETTINGS_PROFILE_TRIGGER_INSERT_PASSWORD_VALUE = N_("InsertPassword");
immutable string SETTINGS_PROFILE_TRIGGER_UPDATE_BADGE_VALUE = N_("UpdateBadge");
immutable string SETTINGS_PROFILE_TRIGGER_RUN_PROCESS_VALUE = N_("RunProcess");

immutable string[] SETTINGS_PROFILE_TRIGGER_ACTION_VALUES = [SETTINGS_PROFILE_TRIGGER_UPDATE_STATE_VALUE,
                                                             SETTINGS_PROFILE_TRIGGER_EXECUTE_COMMAND_VALUE,
                                                             SETTINGS_PROFILE_TRIGGER_SEND_NOTIFICATION_VALUE,
                                                             SETTINGS_PROFILE_TRIGGER_UPDATE_TITLE_VALUE,
                                                             SETTINGS_PROFILE_TRIGGER_PLAY_BELL_VALUE,
                                                             SETTINGS_PROFILE_TRIGGER_SEND_TEXT_VALUE,
                                                             SETTINGS_PROFILE_TRIGGER_INSERT_PASSWORD_VALUE,
                                                             SETTINGS_PROFILE_TRIGGER_UPDATE_BADGE_VALUE,
                                                             SETTINGS_PROFILE_TRIGGER_RUN_PROCESS_VALUE];

//Badges
enum SETTINGS_PROFILE_BADGE_TEXT_KEY = "badge-text";
enum SETTINGS_PROFILE_BADGE_COLOR_KEY = "badge-color";
enum SETTINGS_PROFILE_USE_BADGE_COLOR_KEY = "badge-color-set";
enum SETTINGS_PROFILE_BADGE_POSITION_KEY = "badge-position";

enum SETTINGS_QUADRANT_NW_VALUE = "northwest";
enum SETTINGS_QUADRANT_NE_VALUE = "northeast";
enum SETTINGS_QUADRANT_SW_VALUE = "southwest";
enum SETTINGS_QUADRANT_SE_VALUE = "southeast";

immutable string[] SETTINGS_QUADRANT_VALUES = [SETTINGS_QUADRANT_NW_VALUE, SETTINGS_QUADRANT_NE_VALUE, SETTINGS_QUADRANT_SW_VALUE, SETTINGS_QUADRANT_SE_VALUE];

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

    GSettings createProfile(string uuid, string profileName, bool isDefault) {
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
        return gsProfile;
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
        createProfile(uuid, profileName, isDefault);
        return ProfileInfo(isDefault, uuid, profileName);
    }

    /**
     * Clones an existing profile
     */
    ProfileInfo cloneProfile(ProfileInfo sourceInfo) {
        GSettings sourceProfile = getProfileSettings(sourceInfo.uuid);
        string uuid = randomUUID().toString();
        string profileName = format(_("%s (Copy)"), sourceProfile.getString(SETTINGS_PROFILE_VISIBLE_NAME_KEY));
        GSettings targetProfile = createProfile(uuid, profileName, false);
        targetProfile.setString(SETTINGS_PROFILE_VISIBLE_NAME_KEY, profileName);

        string[] keys = sourceProfile.listKeys();
        //Update each key in turn
        foreach(key; keys) {
            // Do not copy profile name
            if (key == SETTINGS_PROFILE_VISIBLE_NAME_KEY) continue;
            GVariant value = sourceProfile.getValue(key);
            targetProfile.setValue(key, value);
        }
        return ProfileInfo(false, uuid, profileName);
    }

    /**
	 * Deletes the specified profile in GSettings
	 *
	 * @param uuid the identifier of the profile to delete
	 */
    void deleteProfile(string uuid) {
        string[] ps = gsProfileList.getStrv(SETTINGS_PROFILE_LIST_KEY);
        gx.util.array.remove(ps, uuid);
        gsProfileList.setStrv(SETTINGS_PROFILE_LIST_KEY, ps);
        if (uuid == getDefaultProfile() && ps.length > 0) {
            //Update default profile to be the first one
            gsProfileList.setString(SETTINGS_PROFILE_DEFAULT_KEY, ps[0]);
        }
        onDelete.emit(uuid);
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
     * Finds the profile that matches the current hostname and directory
     */
    string findProfileForState(string username, string hostname, string directory) {
        string[] uuids = getProfileUUIDs();
        foreach (uuid; uuids) {
            GSettings settings = getProfileSettings(uuid);
            string[] matches = settings.getStrv(SETTINGS_PROFILE_AUTOMATIC_SWITCH_KEY);
            foreach (match; matches) {
                //is there a tilde in the directory right after the first colon?
                auto isTilde = match.indexOf(":~");
                if (isTilde >= 0) {
                    string path = match[(isTilde + 1) .. $];
                    path = expandTilde(path);
                    match = match[0 .. isTilde] ~ ":" ~ path;
                }
                //trace("Testing match " ~ match);

                string matchHostname, matchUsername, matchDirectory;
                parsePromptParts(match, matchUsername, matchHostname, matchDirectory);
                if (matchDirectory.startsWith("~")) {
                    matchDirectory = expandTilde(matchDirectory);
                }
                if ((matchUsername.length == 0 || matchUsername == username) &&
                   (matchHostname.length == 0 || matchHostname == hostname) &&
                   (matchDirectory.length == 0 || directory.startsWith(matchDirectory))) {
                    return uuid;
                }
            }
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

    /**
     * Event to signal a profile was deleted, the uuid of the
     * deleted profile is passed.
     */
    GenericEvent!(string) onDelete;
    
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
