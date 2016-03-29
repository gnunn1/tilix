/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.application;

import std.experimental.logger;
import std.format;
import std.path;
import std.process;
import std.variant;

import gio.ActionGroupIF;
import gio.ActionMapIF;
import gio.Application : GApplication = Application;
import gio.ApplicationCommandLine;
import gio.Menu;
import gio.MenuModel;
import gio.Settings : GSettings = Settings;
import gio.SimpleAction;

import glib.ListG;
import glib.Variant : GVariant = Variant;
import glib.VariantDict : GVariantDict = VariantDict;
import glib.VariantType : GVariantType = VariantType;

import gobject.Value;

import gtk.AboutDialog;
import gtk.Application;
import gtk.CheckButton;
import gtk.Dialog;
import gtk.Image;
import gtk.Label;
import gtk.LinkButton;
import gtk.Main;
import gtk.MessageDialog;
import gtk.Settings;
import gtk.Version;
import gtk.Widget;
import gtk.Window;

import gx.gtk.actions;
import gx.gtk.util;
import gx.i18n.l10n;
import gx.terminix.appwindow;
import gx.terminix.cmdparams;
import gx.terminix.common;
import gx.terminix.constants;
import gx.terminix.preferences;
import gx.terminix.prefwindow;
import gx.terminix.profilewindow;
import gx.terminix.shortcuts;

Terminix terminix;

/**
 * The GTK Application used by Terminix.
 */
class Terminix : Application {

private:

    enum ACTION_PREFIX = "app";

    enum ACTION_NEW_WINDOW = "new-window";
    enum ACTION_NEW_SESSION = "new-session";
    enum ACTION_ACTIVATE_SESSION = "activate-session";
    enum ACTION_PREFERENCES = "preferences";
    enum ACTION_ABOUT = "about";
    enum ACTION_QUIT = "quit";
    enum ACTION_COMMAND = "command";
    enum ACTION_SHORTCUTS = "shortcuts";

    GSettings gsShortcuts;
    GSettings gsGeneral;
    Value defaultMenuAccel;

    CommandParameters cp;

    AppWindow[] appWindows;
    ProfileWindow[] profileWindows;
    PreferenceWindow preferenceWindow;

    bool warnedVTEConfigIssue = false;

    /**
     * Load and register binary resource file and add css files as providers
     */
    void loadResources() {
        //Load resources
        if (findResource(APPLICATION_RESOURCES, true)) {
            foreach (cssFile; APPLICATION_CSS_RESOURCES) {
                string cssURI = buildPath(APPLICATION_RESOURCE_ROOT, cssFile);
                trace(format("Could not load CSS %s", cssURI));
                if (!addCssProvider(cssURI, ProviderPriority.APPLICATION)) {
                    error(format("Could not load CSS %s", cssURI));
                }
            }
        }
    }

    /**
     * Installs the application menu. This is the menu that drops down in gnome-shell when you click the application
     * name next to Activities.
     * 
	 * This code adapted from grestful (https://github.com/Gert-dev/grestful)
     */
    void installAppMenu() {
        Menu appMenu = new Menu();

        registerAction(this, ACTION_PREFIX, ACTION_ACTIVATE_SESSION, null, delegate(GVariant value, SimpleAction) {
            ulong l;
            string sessionUUID = value.getString(l);
            trace("activate-session triggered for session " ~ sessionUUID);
            foreach (window; appWindows) {
                if (window.activateSession(sessionUUID)) {
                    window.present();
                    break;
                }
            }
        }, new GVariantType("s"));

        registerActionWithSettings(this, ACTION_PREFIX, ACTION_NEW_SESSION, gsShortcuts, delegate(GVariant, SimpleAction) { onCreateNewSession(); });

        registerActionWithSettings(this, ACTION_PREFIX, ACTION_NEW_WINDOW, gsShortcuts, delegate(GVariant, SimpleAction) { onCreateNewWindow(); });

        registerActionWithSettings(this, ACTION_PREFIX, ACTION_PREFERENCES, gsShortcuts, delegate(GVariant, SimpleAction) { onShowPreferences(); });

        if (Version.checkVersion(3, 19, 0).length == 0) {
            registerActionWithSettings(this, ACTION_PREFIX, ACTION_SHORTCUTS, gsShortcuts, delegate(GVariant, SimpleAction) { 
                import gtk.ShortcutsWindow: ShortcutsWindow;
                
                ShortcutsWindow window = getShortcutWindow();
                if (window is null) return;
                window.setDestroyWithParent(true);
                window.setModal(true);
                window.showAll();                     
            });
        }
        
        registerAction(this, ACTION_PREFIX, ACTION_ABOUT, null, delegate(GVariant, SimpleAction) { onShowAboutDialog(); });

        registerAction(this, ACTION_PREFIX, ACTION_QUIT, null, delegate(GVariant, SimpleAction) { quitTerminix(); });

        Menu newSection = new Menu();
        newSection.append(_("New Session"), getActionDetailedName(ACTION_PREFIX, ACTION_NEW_SESSION));
        newSection.append(_("New Window"), getActionDetailedName(ACTION_PREFIX, ACTION_NEW_WINDOW));
        appMenu.appendSection(null, newSection);

        Menu prefSection = new Menu();
        prefSection.append(_("Preferences"), getActionDetailedName(ACTION_PREFIX, ACTION_PREFERENCES));
        if (Version.checkVersion(3, 19, 0).length == 0) {
            prefSection.append(_("Shortcuts"), getActionDetailedName(ACTION_PREFIX, ACTION_SHORTCUTS));
        }        
        appMenu.appendSection(null, prefSection);

        Menu otherSection = new Menu();
        otherSection.append(_("About"), getActionDetailedName(ACTION_PREFIX, ACTION_ABOUT));
        otherSection.append(_("Quit"), getActionDetailedName(ACTION_PREFIX, ACTION_QUIT));
        appMenu.appendSection(null, otherSection);

        this.setAppMenu(appMenu);
    }

    void onCreateNewSession() {
        AppWindow appWindow = cast(AppWindow) getActiveWindow();
        if (appWindow !is null)
            appWindow.createSession();
    }

    void onCreateNewWindow() {
        createAppWindow();
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
            setLogoIconName(null);
            setName(APPLICATION_NAME);
            setComments(_(APPLICATION_COMMENTS));
            setVersion(APPLICATION_VERSION);
            setCopyright(APPLICATION_COPYRIGHT);
            setAuthors(APPLICATION_AUTHORS.dup);
            setArtists(APPLICATION_ARTISTS.dup);
            setDocumenters(APPLICATION_DOCUMENTERS.dup);
            setTranslatorCredits(APPLICATION_TRANSLATORS);
            setLicense(_(APPLICATION_LICENSE));
            setLogoIconName(APPLICATION_ICON_NAME);

            string[] localizedCredits;
            localizedCredits.length = APPLICATION_CREDITS.length;
            foreach (i, credit; APPLICATION_CREDITS) {
                localizedCredits[i] = _(credit);
            }
            addCreditSection(_("Credits"), localizedCredits);

            addOnResponse(delegate(int responseId, Dialog sender) {
                if (responseId == ResponseType.CANCEL || responseId == ResponseType.DELETE_EVENT)
                    sender.hideOnDelete(); // Needed to make the window closable (and hide instead of be deleted).
            });

            present();
        }
    }

    void createAppWindow() {
        AppWindow window = new AppWindow(this);
        window.initialize();
        window.showAll();
    }

    void quitTerminix() {
        foreach (window; appWindows) {
            window.close();
        }
        foreach (window; profileWindows) {
            window.close();
        }
        if (preferenceWindow !is null)
            preferenceWindow.close();
    }

    int onCommandLine(ApplicationCommandLine acl, GApplication) {
        trace("App processing command line");
        scope (exit) {
            cp.clear();
            acl.setExitStatus(cp.exitCode);
            acl.destroy();
        }
        cp = CommandParameters(acl);
        if (cp.exitCode == 0) {
            if (cp.action.length > 0) {
                trace("Executing action  " ~ cp.action);
                string terminalUUID = cp.terminalUUID;
                if (terminalUUID.length == 0) {
                    AppWindow window = getActiveAppWindow();
                    if (window !is null) terminalUUID = window.getActiveTerminalUUID();   
                } 
                executeAction(terminalUUID, cp.action);
                return cp.exitCode;
            }
        } else {
            trace(format("Exit code is %d", cp.exitCode));
        }
        trace("Activating app");
        
        if (acl.getIsRemote()) {
            AppWindow aw = getActiveAppWindow();
            if (aw !is null) {    
                switch (gsGeneral.getString(SETTINGS_NEW_INSTANCE_MODE_KEY)) {
                    //New Session
                    case SETTINGS_NEW_INSTANCE_MODE_VALUES[1]:
                        aw.present();
                        aw.createSession();
                        return cp.exitCode;
                    //Split Horizontal
                    case SETTINGS_NEW_INSTANCE_MODE_VALUES[2]:
                        aw.present();
                        executeAction(aw.getActiveTerminalUUID, "terminal-split-horizontal");
                        return cp.exitCode;
                    //Split Verical
                    case SETTINGS_NEW_INSTANCE_MODE_VALUES[3]:
                        aw.present();
                        executeAction(aw.getActiveTerminalUUID, "terminal-split-vertical");
                        return cp.exitCode;
                    default:
                        //Fall through to activate
                }
            }        
        }
        activate();
        return cp.exitCode;
    }

    void onAppActivate(GApplication app) {
        trace("Activate App Signal");
        if (!app.getIsRemote())
            createAppWindow();
        cp.clear();
    }

    void onAppStartup(GioApplication) {
        trace("Startup App Signal");
        loadResources();
        gsShortcuts = new GSettings(SETTINGS_PROFILE_KEY_BINDINGS_ID);
        trace("Monitoring shortcuts");
        gsShortcuts.addOnChanged(delegate(string key, Settings) {
            string actionName = keyToDetailedActionName(key);
            trace("Updating shortcut '" ~ actionName ~ "' to '" ~ gsShortcuts.getString(key) ~ "'");
            string shortcut = gsShortcuts.getString(key); 
            if (shortcut == SHORTCUT_DISABLED) {
                char** tmp = (new char*[1]).ptr;
                tmp[0] = cast(char*) '\0';                
                gtkc.gtk.gtk_application_set_accels_for_action(gtkApplication, glib.Str.Str.toStringz(actionName), tmp);
                trace("Removing accelerator");
            } else {
                setAccelsForAction(actionName, [shortcut]);
            }
        });
        gsGeneral = new GSettings(SETTINGS_ID);
        gsGeneral.addOnChanged(delegate(string, Settings) { applyPreferences(); });

        initProfileManager();
        applyPreferences();
        installAppMenu();
    }
    
    void onAppShutdown(GioApplication) {
        trace("Quit App Signal");
        terminix = null;
    }

    void applyPreferences() {
        string theme = gsGeneral.getString(SETTINGS_THEME_VARIANT_KEY);
        if (theme == SETTINGS_THEME_VARIANT_DARK_VALUE || theme == SETTINGS_THEME_VARIANT_LIGHT_VALUE) {
            Settings.getDefault().setProperty(GTK_APP_PREFER_DARK_THEME, (SETTINGS_THEME_VARIANT_DARK_VALUE == theme));
        } else {
            /*
             * Resetting the theme variant to "Default" depends on new 
             * gtk_settings_reset_property API in Gnome 3.20. Once
             * GtkD is updated to include this it will be added here.
             */ 
            if (Version.checkVersion(3, 19, 0).length == 0) {
                Settings.getDefault.resetProperty(GTK_APP_PREFER_DARK_THEME);
            }
        }
        if (defaultMenuAccel is null) {
            defaultMenuAccel = new Value("F10");
            Settings.getDefault().getProperty(GTK_MENU_BAR_ACCEL, defaultMenuAccel);
            trace("Default menu accelerator is " ~ defaultMenuAccel.getString());
        }
        if (!gsGeneral.getBoolean(SETTINGS_MENU_ACCELERATOR_KEY)) {
            Settings.getDefault().setProperty(GTK_MENU_BAR_ACCEL, new Value(""));
        } else {
            Settings.getDefault().setProperty(GTK_MENU_BAR_ACCEL, defaultMenuAccel);
        }
    }

    void executeAction(string terminalUUID, string action) {
        trace("Executing action " ~ action);
        string prefix;
        string actionName;
        getActionNameFromKey(action, prefix, actionName);
        Widget widget = findWidgetForUUID(terminalUUID);
        while (widget !is null) {
            ActionGroupIF group = widget.getActionGroup(prefix);
            if (group !is null && group.hasAction(actionName)) {
                trace(format("Activating action for prefix=%s and action=%s", prefix, actionName));
                group.activateAction(actionName, null);
                return;
            }
            widget = widget.getParent();
        }
        //Check if the action belongs to the app
        if (prefix == ACTION_PREFIX) {
            activateAction(actionName, null);
            return;
        }
        trace(format("Could not find action for prefix=%s and action=%s", prefix, actionName));
    }
    
    /**
     * Returns the most active AppWindow, ignores preference
     * an profile windows
     */
    AppWindow getActiveAppWindow() {
        AppWindow appWindow = cast(AppWindow)getActiveWindow();
        if (appWindow !is null) return appWindow;
        
        ListG list = getWindows();
        Window[] windows = list.toArray!(Window)();
        foreach(window; windows) {
            appWindow = cast(AppWindow) window;
            if (appWindow !is null) return appWindow;
        }
        return null;
    }

public:

    this() {
        super(APPLICATION_ID, ApplicationFlags.HANDLES_COMMAND_LINE);
        addMainOption(CMD_WORKING_DIRECTORY, 'w', GOptionFlags.NONE, GOptionArg.STRING, _("Set the working directory of the terminal"), _("DIRECTORY"));
        addMainOption(CMD_PROFILE, 'p', GOptionFlags.NONE, GOptionArg.STRING, _("Set the starting profile"), _("PROFILE_NAME"));
        addMainOption(CMD_SESSION, 's', GOptionFlags.NONE, GOptionArg.STRING_ARRAY, _("Open the specified session"), _("SESSION_NAME"));
        addMainOption(CMD_ACTION, 'a', GOptionFlags.NONE, GOptionArg.STRING, _("Send an action to current Terminix instance"), _("ACTION_NAME"));
        addMainOption(CMD_EXECUTE, 'x', GOptionFlags.NONE, GOptionArg.STRING, _("Execute the passed command"), _("EXECUTE"));
        addMainOption(CMD_TERMINAL_UUID, 't', GOptionFlags.HIDDEN, GOptionArg.STRING, _("Hidden argument to pass terminal UUID"), _("TERMINAL_UUID"));

        this.addOnActivate(&onAppActivate);
        this.addOnStartup(&onAppStartup);
        this.addOnShutdown(&onAppShutdown);
        this.addOnCommandLine(&onCommandLine);
        terminix = this;
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
        GVariant[] param = [new GVariant(command), new GVariant(terminalID), new GVariant(cmdLine)];
        activateAction(ACTION_COMMAND, new GVariant(param));
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

    void addProfileWindow(ProfileWindow window) {
        profileWindows ~= window;
        //GTK add window
        addWindow(window);
    }

    void removeProfileWindow(ProfileWindow window) {
        gx.util.array.remove(profileWindows, window);
        //GTK remove window
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
        //Check if preference window already exists
        if (preferenceWindow !is null) {
            preferenceWindow.present();
            return;
        }
        //Otherwise create it and save the ID
        preferenceWindow = new PreferenceWindow(this);
        addWindow(preferenceWindow);
        preferenceWindow.addOnDelete(delegate(Event, Widget) {
            preferenceWindow = null; 
            removeWindow(preferenceWindow); 
            return false; 
        });
        preferenceWindow.showAll();
    }

    void closeProfilePreferences(ProfileInfo profile) {
        foreach (window; profileWindows) {
            if (window.uuid == profile.uuid) {
                window.destroy();
                return;
            }
        }
    }

    void presentProfilePreferences(ProfileInfo profile) {
        foreach (window; profileWindows) {
            if (window.uuid == profile.uuid) {
                window.present();
                return;
            }
        }
        ProfileWindow window = new ProfileWindow(this, profile);
        window.showAll();
    }

    bool testVTEConfig() {
        return !warnedVTEConfigIssue && gsGeneral.getBoolean(SETTINGS_WARN_VTE_CONFIG_ISSUE_KEY);
    }

    /**
     * Even those these are parameters passed on the command-line
     * they are used by the terminal when it is created as a global
     * override.
     *
     * Originally I was passing command line parameters to the terminal
     * via the heirarchy App > AppWindow > Session > Terminal but this
     * is unwiedly. It's also not feasible when supporting using the
     * command line to create terminals in the current instance since
     * that uses actions and it's not feasible to pass these via the
     * action mechanism.
     *
     * When a terminal is created, it will check this global overrides and
     * use it where applicaable. The application is responsible for setiing
     * and clearing these overrides around the terminal creation. Since GTK
     * is single threaded this works fine.
     */
    CommandParameters getGlobalOverrides() {
        return cp;
    }

    /**
     * Shows a dialog when a VTE configuration issue is detected.
     * See Issue #34 and https://github.com/gnunn1/terminix/wiki/VTE-Configuration-Issue
     * for more information.
     */
    void warnVTEConfigIssue() {
        if (testVTEConfig()) {
            warnedVTEConfigIssue = true;
            string msg = _("There appears to be an issue with the configuration of the terminal.\nThis issue is not serious, but correcting it will improve your experience.\nClick the link below for more information:");
            string title = "<span weight='bold' size='larger'>" ~ _("Configuration Issue Detected") ~ "</span>";
            MessageDialog dlg = new MessageDialog(getActiveWindow(), DialogFlags.MODAL, MessageType.WARNING, ButtonsType.OK, null, null);
            scope (exit) {
                dlg.destroy();
            }
            with (dlg) {
                setTransientFor(getActiveWindow());
                setMarkup(title);
                getMessageArea().setMarginLeft(0);
                getMessageArea().setMarginRight(0);
                getMessageArea().add(new Label(msg));
                getMessageArea().add(new LinkButton("https://github.com/gnunn1/terminix/wiki/VTE-Configuration-Issue"));
                CheckButton cb = new CheckButton(_("Do not show this message again"));
                getMessageArea().add(cb);
                setImage(new Image("dialog-warning", IconSize.DIALOG));
                showAll();
                run();
                if (cb.getActive()) {
                    gsGeneral.setBoolean(SETTINGS_WARN_VTE_CONFIG_ISSUE_KEY, false);
                }
            }
        }
    }
}
