/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.application;

import std.experimental.logger;
import std.format;
import std.path;
import std.variant;

import gio.ActionMapIF;
import gio.Menu;
import gio.MenuModel;
import gio.Settings : GSettings = Settings;
import gio.SimpleAction;

import glib.Variant : GVariant = Variant;
import glib.VariantType : GVariantType = VariantType;

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
import gtk.Widget;
import gtk.Window;

import gx.gtk.actions;
import gx.gtk.util;
import gx.i18n.l10n;
import gx.terminix.appwindow;
import gx.terminix.cmdparams;
import gx.terminix.constants;
import gx.terminix.preferences;
import gx.terminix.prefwindow;
import gx.terminix.profilewindow;

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

    GSettings gsShortcuts;
    GSettings gsGeneral;

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
                if (!addCssProvider(cssURI, ProviderPriority.FALLBACK)) {
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

        registerAction(this, ACTION_PREFIX, ACTION_ACTIVATE_SESSION, null, delegate(GVariant value, SimpleAction sa) {
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

        registerAction(this, ACTION_PREFIX, ACTION_NEW_SESSION, null, delegate(GVariant, SimpleAction) { onCreateNewSession(); });

        registerAction(this, ACTION_PREFIX, ACTION_NEW_WINDOW, null, delegate(GVariant, SimpleAction) { onCreateNewWindow(); });

        registerAction(this, ACTION_PREFIX, ACTION_PREFERENCES, null, delegate(GVariant, SimpleAction) { onShowPreferences(); });

        registerAction(this, ACTION_PREFIX, ACTION_ABOUT, null, delegate(GVariant, SimpleAction) { onShowAboutDialog(); });

        registerAction(this, ACTION_PREFIX, ACTION_QUIT, null, delegate(GVariant, SimpleAction) {
            quitTerminix();
        });

        Menu newSection = new Menu();
        newSection.append(_("New Session"), getActionDetailedName(ACTION_PREFIX, ACTION_NEW_SESSION));
        newSection.append(_("New Window"), getActionDetailedName(ACTION_PREFIX, ACTION_NEW_WINDOW));
        appMenu.appendSection(null, newSection);

        Menu prefSection = new Menu();
        prefSection.append(_("Preferences"), getActionDetailedName(ACTION_PREFIX, ACTION_PREFERENCES));
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
            setDestroyWithParent(true);
            //setTransientFor(this.window);
            setModal(true);

            setWrapLicense(true);
            setLogoIconName(null);
            setName(APPLICATION_NAME);
            setComments(APPLICATION_COMMENTS);
            setVersion(APPLICATION_VERSION);
            setCopyright(APPLICATION_COPYRIGHT);
            setAuthors(APPLICATION_AUTHORS.dup);
            setArtists(APPLICATION_ARTISTS.dup);
            setDocumenters(APPLICATION_DOCUMENTERS.dup);
            setTranslatorCredits(APPLICATION_TRANSLATORS);
            setLicense(APPLICATION_LICENSE);
            addCreditSection(_("Credits"), APPLICATION_CREDITS);

            addOnResponse(delegate(int responseId, Dialog sender) {
                if (responseId == ResponseType.CANCEL || responseId == ResponseType.DELETE_EVENT)
                    sender.hideOnDelete(); // Needed to make the window closable (and hide instead of be deleted).
            });

            present();
        }
    }
    
    void createAppWindow(bool onActivate = false) {
        AppWindow window = new AppWindow(this);
        if (onActivate)
            window.initialize(cp);
        else
            window.initialize();
        window.showAll();
    }

    void quitTerminix() {
        foreach(window; appWindows) {
            window.close();
        }
        foreach(window; profileWindows) {
            window.close();
        }
        if (preferenceWindow !is null) preferenceWindow.close();
    }

    void onAppActivate(GioApplication app) {
        trace("Activate App Signal");
        createAppWindow(true);
    }

    void onAppStartup(GioApplication app) {
        trace("Startup App Signal");
        loadResources();
        gsShortcuts = new GSettings(SETTINGS_PROFILE_KEY_BINDINGS_ID);
        gsShortcuts.addOnChanged(delegate(string key, Settings) {
            trace("Updating shortcut '" ~ keyToDetailedActionName(key) ~ "' to '" ~ gsShortcuts.getString(key) ~ "'");
            setAccelsForAction(keyToDetailedActionName(key), [gsShortcuts.getString(key)]);
            string[] values = getAccelsForAction(keyToDetailedActionName(key));
            foreach (value; values) {
                trace("Accel " ~ value ~ " for action " ~ keyToDetailedActionName(key));
            }
        });
        gsGeneral = new GSettings(SETTINGS_ID);
        gsGeneral.addOnChanged(delegate(string key, Settings) { applyPreferences(); });

        initProfileManager();
        applyPreferences();
        installAppMenu();
    }

    void onAppShutdown(GioApplication app) {
        trace("Quit App Signal");
        terminix = null;
    }

    void applyPreferences() {
        Settings.getDefault().setProperty(GTK_APP_PREFER_DARK_THEME, (SETTINGS_THEME_VARIANT_DARK_VALUE == gsGeneral.getString(SETTINGS_THEME_VARIANT_KEY)));
    }

public:

    this(CommandParameters cp) {
        super(APPLICATION_ID, ApplicationFlags.FLAGS_NONE);
        this.cp = cp;
        this.addOnActivate(&onAppActivate);
        this.addOnStartup(&onAppStartup);
        this.addOnShutdown(&onAppShutdown);
        terminix = this;
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

        foreach(window; appWindows) {
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
        foreach(window; profileWindows) {
            if (window.uuid == profile.uuid) {
                window.destroy();
                return;
            }
        }
    }
    
    void presentProfilePreferences(ProfileInfo profile) {
        foreach(window; profileWindows) {
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
     * Shows a dialog when a VTE configuration issue is detected.
     * See Issue #34 and https://github.com/gnunn1/terminix/wiki/VTE-Configuration-Issue
     * for more information.
     */
    void warnVTEConfigIssue() {
        if (testVTEConfig()) {
            warnedVTEConfigIssue = true;
            string msg = _("There appears to be an issue with the configuration of the terminal.\n" ~
                         "This issue is not serious, but correcting it will improve your experience\n" ~
                         "Click the link below for more information:");
            string title = "<span weight='bold' size='larger'>" ~ _("Configuration Issue Detected") ~ "</span>";
            MessageDialog dlg = new MessageDialog(getActiveWindow(), DialogFlags.MODAL, MessageType.WARNING, ButtonsType.OK, null, null);
            scope(exit) {dlg.destroy();}
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