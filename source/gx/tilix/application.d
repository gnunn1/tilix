/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.application;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.file;
import std.format;
import std.path;
import std.process;
import std.stdio;
import std.string;
import std.typecons;
import std.variant;

import cairo.surface;
import cairo.global;

import gdk.screen;
import gdk.types;

import gdkpixbuf.pixbuf;

import gio.action_group;
import gio.action_map;
import gio.application;
import gio.application_command_line;
import gio.menu;
import gio.menu_model;
import gio.settings : Settings = Settings;
import gio.simple_action;
import gio.types;

import glib.error;


import glib.variant : Variant = Variant;
import glib.variant_dict : VariantDict = VariantDict;
import glib.variant_type : VariantType = VariantType;

import gobject.object;
import gobject.param_spec;
import gobject.value;
import gobject.types;

import gtk.c.functions;

import gtk.about_dialog;
import gtk.application;
alias Application = gtk.application.Application;
import gtk.c.functions;
import gtk.c.types;
import gtk.check_button;
import gtk.container;
import gtk.css_provider;
import gtk.dialog;
import gtk.image;
import gtk.label;
import gtk.link_button;
import gtk.global;
import gtk.message_dialog;
import gtk.settings;
import gtk.style_context;
import gtk.widget;
import gtk.window;
import gtk.types;

import gx.gtk.actions;
import gx.gtk.cairo;
import gx.gtk.resource;
import gx.gtk.util;
import gx.gtk.vte;
import gx.i18n.l10n;

import gx.tilix.appwindow;
import gx.tilix.closedialog;
import gx.tilix.cmdparams;
import gx.tilix.common;
import gx.tilix.constants;
import gx.tilix.preferences;
import gx.tilix.shortcuts;

import gx.tilix.bookmark.manager;

import gx.tilix.prefeditor.prefdialog;

static import gx.util.array;


/**
 * Global variable to application
 */
Tilix tilix;

/**
 * The GTK Application used by Tilix.
 */
class Tilix : gtk.application.Application {

private:

    enum ACTION_NEW_SESSION = "new-session";
    enum ACTION_ACTIVATE_SESSION = "activate-session";
    enum ACTION_ACTIVATE_TERMINAL = "activate-terminal";
    enum ACTION_QUIT = "quit";
    enum ACTION_COMMAND = "command";

    enum THEME_AMBIANCE = "Ambiance";

    enum MAX_BG_WIDTH = 3840;
    enum MAX_BG_HEIGHT = 2160;

    Settings gsDesktop;
    Settings gsShortcuts;
    Settings gsGeneral;
    Settings gsProxy;

    Value defaultMenuAccel;

    CommandParameters cp;

    AppWindow[] appWindows;
    PreferenceDialog preferenceDialog;

    //Background Image for terminals, store it here as singleton instance
    Surface isFullBGImage;

    bool warnedVTEConfigIssue = false;

    bool useTabs = false;

    bool _processMonitor = false;

    CssProvider themeCssProvider;

    /**
     * Load and register binary resource file and add css files as providers
     */
    void loadResources() {
        //Load resources
        if (findResource(APPLICATION_RESOURCES, true)) {
            foreach (cssFile; APPLICATION_CSS_RESOURCES) {
                string cssURI = APPLICATION_RESOURCE_ROOT ~ "/" ~ cssFile;
                if (!addCssProvider(cssURI, ProviderPriority.APPLICATION)) {
                    warningf("Could not load CSS %s", cssURI);
                } else {
                    tracef("Loaded %s css file", cssURI);
                }
            }
            foreach (cssFile; THEME_CSS_RESOURCES) {
                string cssURI = APPLICATION_RESOURCE_ROOT ~ "/" ~ cssFile;
                if (!addCssProvider(cssURI, ProviderPriority.THEME)) {
                    warningf("Could not load CSS %s", cssURI);
                } else {
                    tracef("Loaded %s css file", cssURI);
                }
            }

            //Check if tilix has a theme specific CSS file to load
            string theme = getGtkTheme();
            string cssURI = APPLICATION_RESOURCE_ROOT ~ "/css/tilix." ~ theme ~ ".css";
            themeCssProvider = addCssProvider(cssURI, ProviderPriority.APPLICATION);
            if (!themeCssProvider) {
                tracef("No specific CSS found %s", cssURI);
            }
        }
    }

    /**
     * Registers the primary menu actions.
     *
	 * This code adapted from grestful (https://github.com/Gert-dev/grestful)
     */
    void setupPrimaryMenuActions() {
        /**
         * Action used to support notifications, when a notification it has this action associated with it
         * along with the sessionUUID
         */
        registerAction(this, ACTION_PREFIX_APP, ACTION_ACTIVATE_SESSION, null, delegate(Variant value, SimpleAction sa) {
            string sessionUUID = value.getString();
            tracef("activate-session triggered for session %s", sessionUUID);
            foreach (window; appWindows) {
                if (window.activateSession(sessionUUID)) {
                    activateWindow(window);
                    break;
                }
            }
        }, new VariantType("s"));

        /**
         * Action used to support notifications, when a notification it has this action associated with it
         * along with the terminalUUID
         */
        registerAction(this, ACTION_PREFIX_APP, ACTION_ACTIVATE_TERMINAL, null, delegate(Variant value, SimpleAction sa) {
            string terminalUUID = value.getString();
            tracef("activate-terminal triggered for terminal %s", terminalUUID);
            foreach (window; appWindows) {
                if (window.activateTerminal(terminalUUID)) {
                    activateWindow(window);
                    break;
                }
            }
        }, new VariantType("s"));

        registerActionWithSettings(this, ACTION_PREFIX_APP, ACTION_NEW_SESSION, gsShortcuts, delegate(Variant, SimpleAction) { onCreateNewSession(); });

        registerActionWithSettings(this, ACTION_PREFIX_APP, ACTION_NEW_WINDOW, gsShortcuts, delegate(Variant, SimpleAction) { onCreateNewWindow(); });

        registerActionWithSettings(this, ACTION_PREFIX_APP, ACTION_PREFERENCES, gsShortcuts, delegate(Variant, SimpleAction) { onShowPreferences(); });

        if (checkVersion(3, 19, 0).length == 0) {
            registerActionWithSettings(this, ACTION_PREFIX_APP, ACTION_SHORTCUTS, gsShortcuts, delegate(Variant, SimpleAction) {
                import gtk.shortcuts_window: ShortcutsWindow;

                ShortcutsWindow window = getShortcutWindow();
                if (window is null) return;
                window.setDestroyWithParent(true);
                window.setModal(true);
                window.showAll();
            });
        }

        registerAction(this, ACTION_PREFIX_APP, ACTION_ABOUT, null, delegate(Variant, SimpleAction) { onShowAboutDialog(); });

        registerAction(this, ACTION_PREFIX_APP, ACTION_QUIT, null, delegate(Variant, SimpleAction) { quitTilix(); });
    }

    void onCreateNewSession() {
        AppWindow appWindow = cast(AppWindow) getActiveWindow();
        if (appWindow !is null) {
            appWindow.createSession();
        } else {
            onCreateNewWindow();
        }
    }

    void onCreateNewWindow() {
        AppWindow activeAppWindow_ = getActiveAppWindow();
        if (activeAppWindow_ !is null && activeAppWindow_.hasToplevelFocus()) {
            ITerminal terminal = activeAppWindow_.getActiveTerminal();
            if (terminal !is null) {
                cp.workingDir = terminal.currentLocalDirectory();
                ProfileInfo info = prfMgr.getProfile(terminal.defaultProfileUUID());
                cp.profileName = info.name;
            }
        }
        createAppWindow();
        cp.clear();
    }

    void onShowPreferences() {
        presentPreferences();
    }

    /**
     * Shows the about dialog.
     *
	 * This code adapted from grestful (https://github.com/Gert-dev/grestful)
     */
    void onShowAboutDialog() {
        AboutDialog dialog;

        with (dialog = new AboutDialog()) {
            setTransientFor(getActiveWindow());
            setDestroyWithParent(true);
            setModal(true);

            setWrapLicense(true);
            setLogoIconName("");
            setProgramName(APPLICATION_NAME);
            setComments(_(APPLICATION_COMMENTS));
            setVersion(APPLICATION_VERSION);
            setCopyright(APPLICATION_COPYRIGHT);
            setAuthors(APPLICATION_AUTHORS.dup);
            setArtists(APPLICATION_ARTISTS.dup);
            setDocumenters(APPLICATION_DOCUMENTERS.dup);
            // TRANSLATORS: Please add your name to the list of translators if you want to be credited for the translations you have done.
            setTranslatorCredits(_("translator-credits"));
            setLicense(_(APPLICATION_LICENSE));
            setLogoIconName(APPLICATION_ICON_NAME);

            string[] localizedCredits;
            localizedCredits.length = APPLICATION_CREDITS.length;
            foreach (i, credit; APPLICATION_CREDITS) {
                localizedCredits[i] = _(credit);
            }
            addCreditSection(_("Credits"), localizedCredits);

            connectResponse(delegate(int responseId, Dialog sender) {
                if (responseId == gtk.types.ResponseType.Cancel || responseId == gtk.types.ResponseType.DeleteEvent)
                    sender.hideOnDelete(); // Needed to make the window closable (and hide instead of be deleted).
            });
            connectClose(delegate(Dialog dlg) {
                dlg.destroy();
            });
            present();
        }
    }

    void createAppWindow() {
        AppWindow window = new AppWindow(this, useTabs);
        // Window was being realized here to support inserting Window ID
        // into terminal but had lot's of other issues with it so commented
        // it out.
        //window.realize();
        window.initialize();
        window.showAll();
    }

    void quitTilix() {
        ProcessInformation pi = getProcessesInformation();
        if (pi.children.length > 0) {
            if (!promptCanCloseProcesses(gsGeneral, getActiveWindow(), pi)) return;
        }

        if (preferenceDialog !is null) {
            preferenceDialog.close();
        }

        foreach (window; appWindows) {
            window.closeNoPrompt();
        }
    }

    ProcessInformation getProcessesInformation() {
        ProcessInformation result = ProcessInformation(ProcessInfoSource.APPLICATION, _("Tilix"), "", []);
        foreach(window; appWindows) {
            ProcessInformation winInfo = window.getProcessInformation();
            if (winInfo.children.length > 0) {
                result.children ~= winInfo;
            }
        }
        return result;
    }

    void loadBackgroundImage() {
        string filename = gsGeneral.getString(SETTINGS_BACKGROUND_IMAGE_KEY);
        if (isFullBGImage !is null) {
            isFullBGImage.destroy();
            isFullBGImage = null;
        }
        gdkpixbuf.pixbuf.Pixbuf image;
        try {
            if (exists(filename)) {
                int width, height;
                gdkpixbuf.pixbuf.Pixbuf.getFileInfo(filename, width, height);
                if (width > MAX_BG_WIDTH || height > MAX_BG_HEIGHT) {
                    trace("Background image is too large, scaling");
                    image = gdkpixbuf.pixbuf.Pixbuf.newFromFileAtScale(filename, MAX_BG_WIDTH, MAX_BG_HEIGHT, true);
                } else {
                    image = gdkpixbuf.pixbuf.Pixbuf.newFromFile(filename);
                }
                isFullBGImage = renderImage(image, true);
                image.destroy();
            }
        } catch (ErrorWrap ge) {
            errorf("Could not load image '%s'", filename);
        }
    }

    int onCommandLine(ApplicationCommandLine acl, Application app) {
        trace("App processing command line");
        scope (exit) {
            cp.clear();
            acl.setExitStatus(cp.exitCode);
//            acl.destroy();
        }
        cp = CommandParameters(acl);
        if (cp.exit) {
            return cp.exitCode;
        }
        if (cp.exitCode == 0 && cp.action.length > 0) {
            string terminalUUID = cp.terminalUUID;
            if (terminalUUID.length == 0) {
                AppWindow window = getActiveAppWindow();
                if (window !is null) terminalUUID = window.getActiveTerminalUUID();
            }
            //If workingDir is not set, override it with cwd so that it takes priority for
            //executing actions below
            if (cp.workingDir.length == 0 && cp.cwd.length > 0) {
                cp.workingDir = cp.cwd;
            }
            tracef("Executing action %s with working-dir %s", cp.action, cp.workingDir);
            Widget widget = executeAction(terminalUUID, cp.action);
            if (cp.focusWindow && widget !is null) {
                gtk.window.Window window = cast(gtk.window.Window) widget.getToplevel();
                if (window !is null) {
                    trace("Focusing window after action");
                    activateWindow(window);
                }
            }
            return cp.exitCode;
        }
        trace("Activating app");

        if (acl.getIsRemote()) {
            // Check if quake mode or preferences was passed and we have quake window already then
            // just toggle visibility or create quake window. If there isn't a quake window
            // fall through and let activate create one
            if (cp.preferences) {
                presentPreferences();
            } else if (cp.quake) {
                AppWindow qw = getQuakeWindow();
                if (qw !is null) {
                    if (qw.isVisible) {
                        qw.hide();
                    } else {
                        activateWindow(qw);
                        qw.getActiveTerminal().focusTerminal();
                    }
                    return 0;
                }
            } else {
                AppWindow aw = getActiveAppWindow();
                if (aw !is null) {
                    string instanceAction = gsGeneral.getString(SETTINGS_NEW_INSTANCE_MODE_KEY);
                    //If focus-window command line parameter was passed, override setting
                    if (cp.focusWindow) instanceAction = SETTINGS_NEW_INSTANCE_MODE_FOCUS_WINDOW_VALUE;
                    switch (instanceAction) {
                        //New Session
                        case SETTINGS_NEW_INSTANCE_MODE_NEW_SESSION_VALUE:
                            activateWindow(aw);
                            if (cp.session.length > 0) {
                                // This will use global override and load sessions
                                aw.initialize();
                            } else {
                                aw.createSession();
                            }
                            return cp.exitCode;
                        //Split Right, Split Down
                        case SETTINGS_NEW_INSTANCE_MODE_SPLIT_RIGHT_VALUE, SETTINGS_NEW_INSTANCE_MODE_SPLIT_DOWN_VALUE:
                            if (cp.session.length > 0) break;
                            activateWindow(aw);
                            //If workingDir is not set, override it with cwd so that it takes priority for
                            //executing actions below
                            if (cp.workingDir.length == 0) {
                                cp.workingDir = cp.cwd;
                            }
                            if (instanceAction == SETTINGS_NEW_INSTANCE_MODE_SPLIT_RIGHT_VALUE)
                                executeAction(aw.getActiveTerminalUUID, AppWindow.ACTION_PREFIX ~ "-" ~ AppWindow.ACTION_SESSION_ADD_RIGHT);
                            else
                                executeAction(aw.getActiveTerminalUUID, AppWindow.ACTION_PREFIX ~ "-" ~ AppWindow.ACTION_SESSION_ADD_DOWN);

                            return cp.exitCode;
                        //Focus Window
                        case SETTINGS_NEW_INSTANCE_MODE_FOCUS_WINDOW_VALUE:
                            trace("Focus existing window");
                            if (cp.session.length > 0) {
                                // This will use global override and load sessions
                                aw.initialize();
                            }
                            activateWindow(aw);
                            aw.getActiveTerminal().focusTerminal();
                            return cp.exitCode;
                        default:
                            //Fall through to activate
                    }
                }
            }
        }
        activate();
        return cp.exitCode;
    }

    void onAppActivate(Application app) {
        trace("Activate App Signal");
        if (!app.getIsRemote()) {
            if (cp.preferences) presentPreferences();
            else createAppWindow();
        }
        cp.clear();
    }

    void handleThemeChange(ParamSpec, ObjectWrap) {
        string theme = getGtkTheme();
        trace("Theme changed to " ~ theme);
        if (themeCssProvider !is null) {
            StyleContext.removeProviderForScreen(gdk.screen.Screen.getDefault(), themeCssProvider);
            themeCssProvider = null;
        }
        //Check if tilix has a theme specific CSS file to load
        string cssURI = APPLICATION_RESOURCE_ROOT ~ "/css/tilix." ~ theme ~ ".css";
        themeCssProvider = addCssProvider(cssURI, ProviderPriority.APPLICATION);
        if (!themeCssProvider) {
            tracef("No specific CSS found %s", cssURI);
        }
        onThemeChange.emit();
    }

    void onAppStartup(Application app) {
        trace("Startup App Signal");
        (new Settings("org.gnome.desktop.interface")).connectNotify("gtk-theme-name", delegate(ParamSpec ps, ObjectWrap ow) {
            handleThemeChange(null, null);
        }, Yes.After);
        loadResources();
        gsDesktop = new Settings(SETTINGS_DESKTOP_ID);
        gsDesktop.connectChanged(null, delegate(string key, Settings s) {
            if (key == SETTINGS_COLOR_SCHEME_KEY) {
                applyPreference(SETTINGS_THEME_VARIANT_KEY);
            }
        }, Yes.After);
        gsShortcuts = new Settings(SETTINGS_KEY_BINDINGS_ID);
        gsShortcuts.connectChanged(null, delegate(string key, Settings s) {
            string actionName = keyToDetailedActionName(key);
            //trace("Updating shortcut '" ~ actionName ~ "' to '" ~ gsShortcuts.getString(key) ~ "'");
            setShortcut(actionName, gsShortcuts.getString(key));
        }, Yes.After);
        gsGeneral = new Settings(SETTINGS_ID);
        // Set this once globally because it affects more then current window (i.e. shortcuts)
        useTabs = gsGeneral.getBoolean(SETTINGS_USE_TABS_KEY);
        _processMonitor = gsGeneral.getBoolean(SETTINGS_PROCESS_MONITOR);
        gsGeneral.connectChanged(null, delegate(string key, Settings s) {
            applyPreference(key);
        }, Yes.After);

        initProfileManager();
        initBookmarkManager();
        bmMgr.load();
        applyPreferences();
        setupPrimaryMenuActions();
        loadProfileShortcuts();
    }

    void setShortcut(string actionName, string shortcut) {
        if (shortcut == SHORTCUT_DISABLED) {
            char** tmp = (new char*[1]).ptr;
            tmp[0] = cast(char*) '\0';
            import gtk.c.functions : gtk_application_set_accels_for_action;
            import gtk.c.types : GtkApplication;
            gtk_application_set_accels_for_action(cast(GtkApplication*)this._cPtr(No.Dup), toStringz(actionName), tmp);
            trace("Removing accelerator");
        } else {
            string[] accels_ = [shortcut];
            this.setAccelsForAction(actionName, accels_);
        }
    }

    /**
     * Load profile shortcuts
     */
    void loadProfileShortcuts() {
        // Load profile shortcuts
        string[] uuids = prfMgr.getProfileUUIDs();
        foreach(uuid; uuids) {
            Settings gsProfile = prfMgr.getProfileSettings(uuid);
            try {
                string key = gsProfile.getString(SETTINGS_PROFILE_SHORTCUT_KEY);
                if (key != SHORTCUT_DISABLED) {
                    addAccelerator(key, getActionDetailedName(ACTION_PREFIX_TERMINAL,ACTION_PROFILE_SELECT), new Variant(uuid));
                }
            } finally {
                gsProfile.destroy();
            }
        }
    }

    void onAppShutdown(Application app) {
        trace("Quit App Signal");
        if (bmMgr.hasChanged()) {
            bmMgr.save();
        }
        tilix = null;
    }

    void applyPreferences() {
        foreach(key; [SETTINGS_THEME_VARIANT_KEY,SETTINGS_MENU_ACCELERATOR_KEY,SETTINGS_ACCELERATORS_ENABLED,SETTINGS_BACKGROUND_IMAGE_KEY]) {
            applyPreference(key);
        }
    }

    void applyPreference(string key) {
        switch (key) {
            case SETTINGS_THEME_VARIANT_KEY:
                bool darkMode = false;
                bool reset = false;
                string theme = gsGeneral.getString(SETTINGS_THEME_VARIANT_KEY);
                if (theme == SETTINGS_THEME_VARIANT_DARK_VALUE || theme == SETTINGS_THEME_VARIANT_LIGHT_VALUE) {
                    darkMode = (SETTINGS_THEME_VARIANT_DARK_VALUE == theme);
                } else {
                    string colorSchemePreference = gsDesktop.getString(SETTINGS_COLOR_SCHEME_KEY);
                    if (colorSchemePreference !is null) {
                        darkMode = (colorSchemePreference == SETTINGS_COLOR_SCHEME_PREFER_DARK_VALUE);
                    } else {
                        reset = true;
                    }
                }

                if (reset) {
                    /*
                    * Resetting the theme variant to "Default" depends on new
                    * gtk_settings_reset_property API in Gnome 3.20. Once
                    * GtkD is updated to include this it will be added here.
                    */
                    if (checkVersion(3, 19, 0).length == 0) {
                        gtk.settings.Settings.getDefault().resetProperty(GTK_APP_PREFER_DARK_THEME);
                    }
                } else {
                    gtk.settings.Settings.getDefault().setProperty(GTK_APP_PREFER_DARK_THEME, darkMode);
                }
                onThemeChange.emit();
                clearBookmarkIconCache();
                break;
            case SETTINGS_MENU_ACCELERATOR_KEY:
                if (defaultMenuAccel is null) {
                    defaultMenuAccel = new Value("F10");
                    gtk.settings.Settings.getDefault().getProperty(GTK_MENU_BAR_ACCEL, defaultMenuAccel);
                    trace("Default menu accelerator is " ~ defaultMenuAccel.getString());
                }
                if (!gsGeneral.getBoolean(SETTINGS_MENU_ACCELERATOR_KEY)) {
                    gtk.settings.Settings.getDefault().setProperty(GTK_MENU_BAR_ACCEL, new Value(""));
                } else {
                    gtk.settings.Settings.getDefault().setProperty(GTK_MENU_BAR_ACCEL, defaultMenuAccel);
                }
                break;
            case SETTINGS_ACCELERATORS_ENABLED:
                gtk.settings.Settings.getDefault().setProperty(GTK_ENABLE_ACCELS, gsGeneral.getBoolean(SETTINGS_ACCELERATORS_ENABLED));
                break;
            case SETTINGS_BACKGROUND_IMAGE_KEY, SETTINGS_BACKGROUND_IMAGE_MODE_KEY, SETTINGS_BACKGROUND_IMAGE_SCALE_KEY:
                if (key == SETTINGS_BACKGROUND_IMAGE_KEY) {
                    loadBackgroundImage();
                }
                foreach(window; appWindows) {
                    window.updateBackgroundImage();
                }
                break;
            default:
                break;
        }
    }

    Widget executeAction(string terminalUUID, string action) {
        trace("Executing action " ~ action);
        string prefix;
        string actionName;
        getActionNameFromKey(action, prefix, actionName);
        Widget widget = findWidgetForUUID(terminalUUID);
        Widget result = widget;
        while (widget !is null) {
            ActionGroup group = widget.getActionGroup(prefix);
            if (group !is null && group.hasAction(actionName)) {
                tracef("Activating action for prefix=%s and action=%s", prefix, actionName);
                group.activateAction(actionName, null);
                return result;
            }
            widget = widget.getParent();
        }
        //Check if the action belongs to the app
        if (prefix == ACTION_PREFIX_APP) {
            activateAction(actionName, null);
            return result;
        }
        warningf("Could not find action for prefix=%s and action=%s", prefix, actionName);
        return result;
    }

    /**
     * Returns the most active AppWindow, ignores preference
     * windows
     */
    AppWindow getActiveAppWindow() {
        AppWindow activeAppWindow = cast(AppWindow)getActiveWindow();
        if (activeAppWindow !is null) return activeAppWindow;

        gtk.window.Window[] windows = getWindows();
        foreach(window; windows) {
            activeAppWindow = cast(AppWindow) window;
            if (activeAppWindow !is null) return activeAppWindow;
        }
        return null;
    }

    AppWindow getQuakeWindow() {
        gtk.window.Window[] windows = getWindows();
        foreach(window; windows) {
            AppWindow appWindow = cast(AppWindow) window;
            if (appWindow !is null && appWindow.isQuake()) return appWindow;
        }
        return null;
    }

    /**
     * Add main options supported by application
     */
    void addOptions() {
        addMainOption(CMD_WORKING_DIRECTORY, 'w', GOptionFlags.None, GOptionArg.String, _("Set the working directory of the terminal"), _("DIRECTORY"));
        addMainOption(CMD_PROFILE, 'p', GOptionFlags.None, GOptionArg.String, _("Set the starting profile"), _("PROFILE_NAME"));
        addMainOption(CMD_TITLE, 't', GOptionFlags.None, GOptionArg.String, _("Set the title of the new terminal"), _("TITLE"));
        addMainOption(CMD_SESSION, 's', GOptionFlags.None, GOptionArg.StringArray, _("Open the specified session"), _("SESSION_NAME"));
        if (checkVersion(3, 16, 0).length ==0) {
            addMainOption(CMD_ACTION, 'a', GOptionFlags.None, GOptionArg.String, _("Send an action to current Tilix instance"), _("ACTION_NAME"));
        }
        addMainOption(CMD_COMMAND, 'e', GOptionFlags.None, GOptionArg.String, _("Execute the parameter as a command"), _("COMMAND"));
        addMainOption(CMD_MAXIMIZE, '\0', GOptionFlags.None, GOptionArg.None, _("Maximize the terminal window"), null);
        addMainOption(CMD_MINIMIZE, '\0', GOptionFlags.None, GOptionArg.None, _("Minimize the terminal window"), null);
        addMainOption(CMD_WINDOW_STYLE, '\0', GOptionFlags.None, GOptionArg.String, _("Override the preferred window style to use, one of: normal,disable-csd,disable-csd-hide-toolbar,borderless"), _("WINDOW_STYLE"));
        addMainOption(CMD_FULL_SCREEN, '\0', GOptionFlags.None, GOptionArg.None, _("Full-screen the terminal window"), null);
        addMainOption(CMD_FOCUS_WINDOW, '\0', GOptionFlags.None, GOptionArg.None, _("Focus the existing window"), null);
        addMainOption(CMD_NEW_PROCESS, '\0', GOptionFlags.None, GOptionArg.None, _("Start additional instance as new process (Not Recommended)"), null);
        addMainOption(CMD_GEOMETRY, '\0', GOptionFlags.None, GOptionArg.String, _("Set the window size; for example: 80x24, or 80x24+200+200 (COLSxROWS+X+Y)"), _("GEOMETRY"));
        addMainOption(CMD_QUAKE, 'q', GOptionFlags.None, GOptionArg.None, _("Opens a window in quake mode or toggles existing quake mode window visibility"), null);
        addMainOption(CMD_VERSION, 'v', GOptionFlags.None, GOptionArg.None, _("Show the Tilix and dependent component versions"), null);
        addMainOption(CMD_PREFERENCES, '\0', GOptionFlags.None, GOptionArg.None, _("Show the Tilix preferences dialog directly"), null);
        addMainOption(CMD_GROUP, 'g', GOptionFlags.None, GOptionArg.String, _("Group tilix instances into different processes (Experimental, not recommended)"), _("GROUP_NAME"));

        addMainOption(CMD_TERMINAL_UUID, '\0', GOptionFlags.Hidden, GOptionArg.String, _("Hidden argument to pass terminal UUID"), _("TERMINAL_UUID"));
    }

public:

    this(bool newProcess, string group=null) {
        ApplicationFlags flags = ApplicationFlags.HandlesCommandLine;
        if (newProcess) flags |= ApplicationFlags.NonUnique;
        //flags |= ApplicationFlags.CAN_OVERRIDE_APP_ID;
        super(APPLICATION_ID, flags);

        if (group.length > 0) {
            string id = "com.gexperts.Tilix." ~ group;
            if (idIsValid(id)) {
                tracef("Setting app id to %s", id);
                setApplicationId(id);
            } else {
                warningf(_("The application ID %s is not valid"));
            }
        }

        addOptions();

        this.connectActivate(delegate void(Application app) { onAppActivate(app); });
        this.connectStartup(delegate void(Application app) { onAppStartup(app); });
        this.connectShutdown(delegate void(Application app) { onAppShutdown(app); });
        this.connectCommandLine(delegate int(ApplicationCommandLine acl, Application app) { return onCommandLine(acl, app); });
        tilix = this;
    }

    /**
     * Executes a command by invoking the command action.
     * This is used to invoke a command on a remote instance of
     * the GTK Application leveraging the ability for the remote
     * instance to trigger actions on the primary instance.
     *
     * See https://wiki.gnome.org/HowDoI/GtkApplication
     */
    void executeCommand(string command, string terminalID, string cmdLine) {
        Variant[] param = [new Variant(command), new Variant(terminalID), new Variant(cmdLine)];
        activateAction(ACTION_COMMAND, Variant.newTuple(param));
    }

    bool isQuake() {
        AppWindow appWindow = cast(AppWindow) getActiveWindow();
        if (appWindow !is null && appWindow.isQuake()) {
            return true;
        }
        return cp.quake;
    }

    void addAppWindow(AppWindow window) {
        appWindows ~= window;
        //GTK add window
        addWindow(window);
    }

    void removeAppWindow(AppWindow window) {
        gx.util.array.remove(appWindows, window);
        removeWindow(window);
    }

    /**
    * This searches across all Windows to find
    * a widget that matches the UUID specified. At the
    * moment this would be a session or a terminal.
    *
    * This is used for any operations that span windows, at
    * the moment there is just one, dragging a terminal from
    * one Window to the next.
    *
    * TODO - Convert this into a template to eliminate casting
    *        by callers
    */
    Widget findWidgetForUUID(string uuid) {

        foreach (window; appWindows) {
            trace("Finding widget " ~ uuid);
            trace("Checking app window");
            Widget result = window.findWidgetForUUID(uuid);
            if (result !is null) {
                return result;
            }
        }
        return null;
    }

    void presentPreferences() {
        tracef("*** Application ID %s",getApplicationId());

        //Check if preference window already exists
        if (preferenceDialog !is null) {
            AppWindow activeAppWindow_ = getActiveAppWindow();
            if (activeAppWindow_ != preferenceDialog.getParent()) {
                preferenceDialog.setTransientFor(activeAppWindow_);
            }
            preferenceDialog.present();
            return;
        }
        //Otherwise create it and save the ID
        trace("Creating preference window");
        preferenceDialog = new PreferenceDialog(getActiveAppWindow());
        preferenceDialog.connectDestroy(delegate() {
            trace("Remove preference window reference");
            preferenceDialog = null;
        });
        preferenceDialog.showAll();
        preferenceDialog.present();
    }

    void presentProfilePreferences(ProfileInfo profile) {
        presentPreferences();
        preferenceDialog.focusProfile(profile.uuid);
    }

    void presentEncodingPreferences() {
        presentPreferences();
        preferenceDialog.focusEncoding();
    }

    bool testVTEConfig() {
        return !warnedVTEConfigIssue && gsGeneral.getBoolean(SETTINGS_WARN_VTE_CONFIG_ISSUE_KEY);
    }

    override void setAccelsForAction(string detailedActionName, string[] accels) {
        import gx.tilix.terminal.actions;

        if (detailedActionName == getActionDetailedName(gx.tilix.terminal.actions.ACTION_PREFIX, gx.tilix.terminal.actions.ACTION_PASTE)) {
            accels ~= ["<Shift><Ctrl>Insert"];
        } else if (detailedActionName == getActionDetailedName(gx.tilix.terminal.actions.ACTION_PREFIX, gx.tilix.terminal.actions.ACTION_PASTE_PRIMARY)) {
            accels ~= ["<Shift>Insert"];
        }
        super.setAccelsForAction(detailedActionName, accels);
    }

    /**
     * Even though these are parameters passed on the command-line
     * they are used by the terminal when it is created as a global
     * override and referenced via the application object which is global.
     *
     * Originally I was passing command line parameters to the terminal
     * via the hierarchy App > AppWindow > Session > Terminal but this
     * is unwiedly. It's also not feasible when supporting using the
     * command line to create terminals in the current instance since
     * that uses actions. GIO Actions don't have a way to pass arbrirtary
     * parameters, basically it's not feasible to pass these.
     *
     * When a terminal is created, it will check this global overrides and
     * use it where applicaable. The application is responsible for setiing
     * and clearing these overrides around the terminal creation. Since GTK
     * is single threaded this works fine.
     */
    CommandParameters getGlobalOverrides() {
        return cp;
    }

    Surface getBackgroundImage() {
        return isFullBGImage;
    }

    /**
     * Return the Settings object for the proxy. Used so terminals
     * don't need to constantly re-create this on their own.
     */
    Settings getProxySettings() {
        if (gsProxy is null) {
            gsProxy = new Settings(SETTINGS_PROXY_ID);
        }
        return gsProxy;
    }

    /**
     * Shows a dialog when a VTE configuration issue is detected.
     * See Issue #34 and https://github.com/gnunn1/tilix/wiki/VTE-Configuration-Issue
     * for more information.
     */
    void warnVTEConfigIssue() {
        if (testVTEConfig()) {
            warnedVTEConfigIssue = true;
            string msg = _("There appears to be an issue with the configuration of the terminal.\nThis issue is not serious, but correcting it will improve your experience.\nClick the link below for more information:");
            string titleText = "<span weight='bold' size='larger'>" ~ _("Configuration Issue Detected") ~ "</span>";

            auto parent = getActiveWindow();
            auto _cretval = gtk_message_dialog_new(parent ? cast(GtkWindow*)parent._cPtr(No.Dup) : null,
                                                   gtk.types.DialogFlags.Modal,
                                                   gtk.types.MessageType.Warning,
                                                   gtk.types.ButtonsType.Ok,
                                                   null);
            MessageDialog dlg = ObjectWrap._getDObject!(MessageDialog)(_cretval, Yes.Take);

            scope (exit) {
                dlg.destroy();
            }
            with (dlg) {
                setTransientFor(getActiveWindow());
                setMarkup(titleText);
                getMessageArea().setMarginStart(0);
                getMessageArea().setMarginEnd(0);
                (cast(Container)getMessageArea()).add(new Label(msg));
                (cast(Container)getMessageArea()).add(new LinkButton("https://gnunn1.github.io/tilix-web/manual/vteconfig/"));
                CheckButton cb = CheckButton.newWithLabel(_("Do not show this message again"));
                (cast(Container)getMessageArea()).add(cb);
                setImage(Image.newFromIconName("dialog-warning", IconSize.Dialog));
                showAll();
                run();
                if (cb.getActive()) {
                    gsGeneral.setBoolean(SETTINGS_WARN_VTE_CONFIG_ISSUE_KEY, false);
                }
            }
        }
    }

    /**
    * When true asynchronous process monitoring is enabled. This
    * will watch the shell process for new child processes and
    * raise events when detected. Since this uses polling, quick
    * commands (ls, cd, etc) may be missed.
    */
    @property bool processMonitor() {
        return _processMonitor;
    }

// Events
public:
    /**
    * Invoked when the GTK theme or theme-variant has changed. While
    * things could listen to gtk.Settings.connectNotify directly,
    * because this is a long lived object and GtkD doesn't provide a
    * way to remove listeners it will lead to memory leaks so we use
    * this instead
    */
    GenericEvent!() onThemeChange;
}
