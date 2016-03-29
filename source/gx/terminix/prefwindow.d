/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.prefwindow;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.format;
import std.variant;

import gdk.Event;

import gio.Settings;

import gobject.Signals;
import gobject.Value;

import gtk.AccelGroup;
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Box;
import gtk.Button;
import gtk.CellRendererAccel;
import gtk.CellRendererText;
import gtk.CellRendererToggle;
import gtk.CheckButton;
import gtk.ComboBox;
import gtk.Grid;
import gtk.HeaderBar;
import gtk.Label;
import gtk.ListStore;
import gtk.Notebook;
import gtk.ScrolledWindow;
import gtk.Switch;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeStore;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Version;
import gtk.Widget;

import vte.Terminal;

import gx.gtk.actions;
import gx.gtk.util;

import gx.i18n.l10n;

import gx.terminix.application;
import gx.terminix.encoding;
import gx.terminix.preferences;
import gx.terminix.profilewindow;
import gx.util.array;

/**
 * UI for managing Terminix preferences
 */
class PreferenceWindow : ApplicationWindow {

private:
    Notebook nb;
    Settings gsSettings;

    void createUI(Application app) {
        HeaderBar hb = new HeaderBar();
        hb.setShowCloseButton(true);
        hb.setTitle(_("Preferences"));
        this.setTitlebar(hb);
        nb = new Notebook();
        nb.setHexpand(true);
        nb.setVexpand(true);

        GlobalPreferences gp = new GlobalPreferences(gsSettings);
        nb.appendPage(gp, _("Global"));

        ShortcutPreferences sp = new ShortcutPreferences();
        nb.appendPage(sp, _("Shortcuts"));

        ProfilePreferences pp = new ProfilePreferences(app);
        nb.appendPage(pp, _("Profiles"));

        EncodingPreferences ep = new EncodingPreferences(gsSettings);
        nb.appendPage(ep, _("Encoding"));

        add(nb);
    }

public:

    this(Application app) {
        super(app);
        gsSettings = new Settings(SETTINGS_ID);
        app.addWindow(this);
        createUI(app);
    }
}

/**
 * Encodings preferences
 */
class EncodingPreferences : Box {

private:
    enum COLUMN_IS_ENABLED = 0;
    enum COLUMN_NAME = 1;
    enum COLUMN_ENCODING = 2;

    Settings gsSettings;

    ListStore ls;

    void createUI() {
        setMarginLeft(18);
        setMarginRight(18);
        setMarginTop(18);
        setMarginBottom(18);

        Label lblEncoding = new Label(_("Encodings showing in menu:"));
        lblEncoding.setHalign(Align.START);
        add(lblEncoding);

        string[] menuEncodings = gsSettings.getStrv(SETTINGS_ENCODINGS_KEY);
        ls = new ListStore([GType.BOOLEAN, GType.STRING, GType.STRING]);
        foreach (encoding; encodings) {
            TreeIter iter = ls.createIter();
            ls.setValue(iter, 0, menuEncodings.canFind(encoding[0]));
            ls.setValue(iter, 1, encoding[0] ~ " " ~ _(encoding[1]));
            ls.setValue(iter, 2, encoding[0]);
        }

        TreeView tv = new TreeView(ls);
        tv.setHeadersVisible(false);

        CellRendererToggle toggle = new CellRendererToggle();
        toggle.setActivatable(true);
        toggle.addOnToggled(delegate(string path, CellRendererToggle) {
            TreeIter iter = new TreeIter();
            ls.getIter(iter, new TreePath(path));
            string encoding = ls.getValue(iter, COLUMN_ENCODING).getString();
            bool enabled = ls.getValue(iter, COLUMN_IS_ENABLED).getBoolean();
            trace("Menu encoding clicked for " ~ encoding);
            //Check for the reverse of what toggle is set for since 
            //model is not updated until after settings updated
            if (enabled) {
                trace("Encoding is checked, removing");
                gx.util.array.remove(menuEncodings, encoding);
            } else {
                trace("Encoding is not checked, adding");
                menuEncodings ~= encoding;
            }
            gsSettings.setStrv(SETTINGS_ENCODINGS_KEY, menuEncodings);
            ls.setValue(iter, COLUMN_IS_ENABLED, !enabled);
        });
        TreeViewColumn column = new TreeViewColumn(_("Enabled"), toggle, "active", COLUMN_IS_ENABLED);
        tv.appendColumn(column);
        column = new TreeViewColumn(_("Encoding"), new CellRendererText(), "text", COLUMN_NAME);
        column.setExpand(true);
        tv.appendColumn(column);

        ScrolledWindow sw = new ScrolledWindow(tv);
        sw.setShadowType(ShadowType.ETCHED_IN);
        sw.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sw.setHexpand(true);
        sw.setVexpand(true);

        add(sw);
    }

public:

    this(Settings gsSettings) {
        super(Orientation.VERTICAL, 6);
        this.gsSettings = gsSettings;
        createUI();
    }
}

/**
 * Shortcuts preferences page
 */
class ShortcutPreferences : Box {

private:
    Settings gsShortcuts;

    TreeStore tsShortcuts;

    enum COLUMN_NAME = 0;
    enum COLUMN_SHORTCUT = 1;
    enum COLUMN_ACTION_NAME = 2;

    void createUI() {
        setMarginLeft(18);
        setMarginRight(18);
        setMarginTop(18);
        setMarginBottom(18);

        //Shortcuts TreeView, note while detailed action name is in the model it's not actually displayed
        tsShortcuts = new TreeStore([GType.STRING, GType.STRING, GType.STRING]);
        loadShortcuts(tsShortcuts);

        TreeView tvShortcuts = new TreeView(tsShortcuts);
        tvShortcuts.setActivateOnSingleClick(false);

        TreeViewColumn column = new TreeViewColumn(_("Action"), new CellRendererText(), "text", COLUMN_NAME);
        column.setExpand(true);
        tvShortcuts.appendColumn(column);

        CellRendererAccel craShortcut = new CellRendererAccel();
        craShortcut.setProperty("editable", 1);
        craShortcut.setProperty("accel-mode", GtkCellRendererAccelMode.GTK);
        craShortcut.addOnAccelCleared(delegate(string path, CellRendererAccel) {
            trace("Clearing shortcut");
            TreeIter iter = new TreeIter();
            tsShortcuts.getIter(iter, new TreePath(path));
            tsShortcuts.setValue(iter, COLUMN_SHORTCUT, _(SHORTCUT_DISABLED));
            //Note accelerator changed by app which is monitoring gsetting changes
            gsShortcuts.setString(tsShortcuts.getValueString(iter, COLUMN_ACTION_NAME), SHORTCUT_DISABLED);
        });
        craShortcut.addOnAccelEdited(delegate(string path, uint accelKey, GdkModifierType accelMods, uint, CellRendererAccel) {
            string label = AccelGroup.acceleratorGetLabel(accelKey, accelMods);
            string name = AccelGroup.acceleratorName(accelKey, accelMods);
            trace("Updating shortcut as " ~ label);
            TreeIter iter = new TreeIter();
            tsShortcuts.getIter(iter, new TreePath(path));
            tsShortcuts.setValue(iter, COLUMN_SHORTCUT, label);
            //Note accelerator changed by app which is monitoring gsetting changes
            string action = tsShortcuts.getValueString(iter, COLUMN_ACTION_NAME);
            trace(format("Setting action %s to shortcut %s", action, label));
            gsShortcuts.setString(action, name);
        });
        column = new TreeViewColumn(_("Shortcut Key"), craShortcut, "text", COLUMN_SHORTCUT);

        tvShortcuts.appendColumn(column);

        ScrolledWindow scShortcuts = new ScrolledWindow(tvShortcuts);
        scShortcuts.setShadowType(ShadowType.ETCHED_IN);
        scShortcuts.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        scShortcuts.setHexpand(true);
        scShortcuts.setVexpand(true);
        add(scShortcuts);

        tvShortcuts.expandAll();
    }

    void loadShortcuts(TreeStore ts) {
        string[] keys = gsShortcuts.listKeys();
        sort(keys);

        TreeIter currentIter;
        string currentPrefix;
        foreach (key; keys) {
            string prefix, id;
            getActionNameFromKey(key, prefix, id);
            if (prefix != currentPrefix) {
                currentPrefix = prefix;
                currentIter = appendValues(ts, null, [_(prefix)]);
            }
            appendValues(ts, currentIter, [_(id), acceleratorNameToLabel(gsShortcuts.getString(key)), key]);
        }
    }

public:

    this() {
        super(Orientation.VERTICAL, 6);
        gsShortcuts = new Settings(SETTINGS_PROFILE_KEY_BINDINGS_ID);
        createUI();
    }

}

/**
 * Profile preferences page
 */
class ProfilePreferences : Box {

private:

    enum COLUMN_IS_DEFAULT = 0;
    enum COLUMN_NAME = 1;
    enum COLUMN_UUID = 2;

    Application app;
    Button btnNew;
    Button btnDelete;
    Button btnEdit;
    //Button btnClone;
    TreeView tvProfiles;
    ListStore lsProfiles;

    Settings[string] profiles;

    void createUI() {
        setMarginLeft(18);
        setMarginRight(18);
        setMarginTop(18);
        setMarginBottom(18);

        //Profiles TreeView, note while UUID is in the model it's not actually displayed
        lsProfiles = new ListStore([GType.BOOLEAN, GType.STRING, GType.STRING]);
        loadProfiles();

        tvProfiles = new TreeView(lsProfiles);
        tvProfiles.setActivateOnSingleClick(false);
        tvProfiles.addOnCursorChanged(delegate(TreeView) { updateUI(); });

        CellRendererToggle toggle = new CellRendererToggle();
        toggle.setRadio(true);
        toggle.setActivatable(true);
        toggle.addOnToggled(delegate(string treePath, CellRendererToggle) {
            //Update UI and set Default profile
            foreach (TreeIter iter; TreeIterRange(lsProfiles)) {
                TreePath path = lsProfiles.getPath(iter);
                bool isDefault = (path.toString() == treePath);
                if (isDefault)
                    prfMgr.setDefaultProfile(lsProfiles.getValue(iter, COLUMN_UUID).getString());
                lsProfiles.setValue(iter, 0, isDefault);
            }
        });
        TreeViewColumn column = new TreeViewColumn(_("Default"), toggle, "active", COLUMN_IS_DEFAULT);
        tvProfiles.appendColumn(column);
        column = new TreeViewColumn(_("Profile"), new CellRendererText(), "text", COLUMN_NAME);
        column.setExpand(true);
        tvProfiles.appendColumn(column);

        ScrolledWindow scProfiles = new ScrolledWindow(tvProfiles);
        scProfiles.setShadowType(ShadowType.ETCHED_IN);
        scProfiles.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        scProfiles.setHexpand(true);
        add(scProfiles);

        //Row of buttons on right
        Box bButtons = new Box(Orientation.VERTICAL, 4);
        bButtons.setVexpand(true);

        btnNew = new Button(_("New"));
        btnNew.addOnClicked(delegate(Button) {
            ProfileInfo profile = prfMgr.createProfile(SETTINGS_PROFILE_NEW_NAME_VALUE);
            //profiles ~= profile;
            addProfile(profile);
            selectRow(tvProfiles, lsProfiles.iterNChildren(null) - 1, null);
            editProfile();
        });
        bButtons.add(btnNew);
        /*
		btnClone = new Button(_("Clone"));
		bButtons.add(btnClone);
		*/
        btnEdit = new Button(_("Edit"));
        btnEdit.addOnClicked(delegate(Button) { editProfile(); });
        bButtons.add(btnEdit);
        btnDelete = new Button(_("Delete"));
        btnDelete.addOnClicked(delegate(Button) {
            ProfileInfo profile = getSelectedProfile();
            if (profile.uuid !is null) {
                //If profile window for this profile is open, close it first 
                terminix.closeProfilePreferences(profile);
                lsProfiles.remove(tvProfiles.getSelectedIter());
                profiles.remove(profile.uuid);
                prfMgr.deleteProfile(profile.uuid);
            }
        });
        bButtons.add(btnDelete);

        add(bButtons);

        selectRow(tvProfiles, 0);
        updateUI();
    }

    void editProfile() {
        ProfileInfo profile = getSelectedProfile();
        if (profile.uuid !is null) {
            terminix.presentProfilePreferences(profile);
        }
    }

    ProfileInfo getSelectedProfile() {
        TreeIter selected = tvProfiles.getSelectedIter();
        if (selected) {
            return ProfileInfo(lsProfiles.getValue(selected, COLUMN_IS_DEFAULT).getBoolean(), lsProfiles.getValue(selected, COLUMN_UUID).getString(),
                    lsProfiles.getValue(selected, COLUMN_NAME).getString());
        } else {
            return ProfileInfo(false, null, null);
        }
    }

    void updateUI() {
        TreeIter selected = tvProfiles.getSelectedIter();
        btnDelete.setSensitive(selected !is null && lsProfiles.iterNChildren(null) > 1);
        btnEdit.setSensitive(selected !is null);
    }

    void addProfile(ProfileInfo profile) {
        TreeIter iter = lsProfiles.createIter();
        lsProfiles.setValue(iter, 0, profile.isDefault);
        lsProfiles.setValue(iter, 1, profile.name);
        lsProfiles.setValue(iter, 2, profile.uuid);
        Settings ps = prfMgr.getProfileSettings(profile.uuid);
        ps.addOnChanged(delegate(string key, Settings settings) {
            if (key == SETTINGS_PROFILE_VISIBLE_NAME_KEY) {
                foreach (uuid, ps; profiles) {
                    if (ps == settings) {
                        updateProfileName(uuid, ps.getString(SETTINGS_PROFILE_VISIBLE_NAME_KEY));
                        break;
                    }
                }
            }
        });
        profiles[profile.uuid] = ps;
    }

    //Update Profile Name here in case it changed
    void updateProfileName(string uuid, string name) {
        foreach (TreeIter iter; TreeIterRange(lsProfiles)) {
            if (lsProfiles.getValue(iter, COLUMN_UUID).getString() == uuid) {
                lsProfiles.setValue(iter, COLUMN_NAME, name);
            }
        }
    }

    void loadProfiles() {
        ProfileInfo[] infos = prfMgr.getProfiles();
        lsProfiles.clear();
        foreach (ProfileInfo info; infos) {
            addProfile(info);
        }
    }

public:

    this(Application app) {
        super(Orientation.HORIZONTAL, 12);
        this.app = app;
        createUI();
    }
}

/**
 * Global preferences page *
 */
class GlobalPreferences : Box {

private:

    ComboBox cbThemeVariant;

    void createUI(Settings gsSettings) {
        //Set basic grid settings
        setMarginTop(18);
        setMarginBottom(18);
        setMarginLeft(18);
        setMarginRight(18);

        Label lblBehavior = new Label(format("<b>%s</b>", _("Behavior")));
        lblBehavior.setUseMarkup(true);
        lblBehavior.setHalign(Align.START);
        add(lblBehavior);

        //Prompt on new session
        CheckButton cbPrompt = new CheckButton(_("Prompt when creating a new session"));
        gsSettings.bind(SETTINGS_PROMPT_ON_NEW_SESSION_KEY, cbPrompt, "active", GSettingsBindFlags.DEFAULT);
        add(cbPrompt);
        
        //Focus follows the mouse
        CheckButton cbFocusMouse = new CheckButton(_("Focus a terminal when the mouse moves over it"));
        gsSettings.bind(SETTINGS_TERMINAL_FOCUS_FOLLOWS_MOUSE_KEY, cbFocusMouse, "active", GSettingsBindFlags.DEFAULT);
        add(cbFocusMouse);

        //Auto hide the mouse
        CheckButton cbAutoHideMouse = new CheckButton(_("Autohide the mouse pointer when typing"));
        gsSettings.bind(SETTINGS_AUTO_HIDE_MOUSE_KEY, cbAutoHideMouse, "active", GSettingsBindFlags.DEFAULT);
        add(cbAutoHideMouse);

        //Show Notifications, only show option if notifications are supported
        if (Signals.lookup("notification-received", Terminal.getType()) != 0) {
            CheckButton cbNotify = new CheckButton(_("Send desktop notification on process complete"));
            gsSettings.bind(SETTINGS_NOTIFY_ON_PROCESS_COMPLETE_KEY, cbNotify, "active", GSettingsBindFlags.DEFAULT);
            add(cbNotify);
        }

        //New Instance Options
        Box bNewInstance = new Box(Orientation.HORIZONTAL, 6);
        
        Label lblNewInstance = new Label(_("On new instance"));
        lblNewInstance.setHalign(Align.END);
        bNewInstance.add(lblNewInstance);
        ComboBox cbNewInstance = createNameValueCombo([_("New Window"), _("New Session"), _("Split Horizontal"), _("Split Vertical")], SETTINGS_NEW_INSTANCE_MODE_VALUES);
        gsSettings.bind(SETTINGS_NEW_INSTANCE_MODE_KEY, cbNewInstance, "active-id", GSettingsBindFlags.DEFAULT);
        bNewInstance.add(cbNewInstance);
        add(bNewInstance);

        // *********** Paste Options
        Label lblPaste = new Label(format("<b>%s</b>", _("Paste")));
        lblPaste.setUseMarkup(true);
        lblPaste.setHalign(Align.START);
        add(lblPaste);

        //Unsafe Paste Warning
        CheckButton cbUnsafe = new CheckButton(_("Warn when attempting unsafe paste"));
        gsSettings.bind(SETTINGS_UNSAFE_PASTE_ALERT_KEY, cbUnsafe, "active", GSettingsBindFlags.DEFAULT);
        add(cbUnsafe);

        //Strip Paste
        CheckButton cbStrip = new CheckButton(_("Strip first character of paste if comment or variable declaration"));
        gsSettings.bind(SETTINGS_STRIP_FIRST_COMMENT_CHAR_ON_PASTE_KEY, cbStrip, "active", GSettingsBindFlags.DEFAULT);
        add(cbStrip);
        
        // *********** Appearance Options
        Label lblAppearance = new Label(format("<b>%s</b>", _("Appearance")));
        lblAppearance.setUseMarkup(true);
        lblAppearance.setHalign(Align.START);
        add(lblAppearance);

        //Enable Transparency, only enabled if less then 3.18
        if (Version.getMajorVersion() <= 3 && Version.getMinorVersion() < 18) {
            CheckButton cbTransparent = new CheckButton(_("Enable transparency, requires re-start"));
            gsSettings.bind(SETTINGS_ENABLE_TRANSPARENCY_KEY, cbTransparent, "active", GSettingsBindFlags.DEFAULT);
            add(cbTransparent);
        }

        //Render terminal titlebars smaller then default
        CheckButton cbSmallTitlebar = new CheckButton(_("Use small size for terminal titlebars"));
        gsSettings.bind(SETTINGS_ENABLE_SMALL_TITLE_KEY, cbSmallTitlebar, "active", GSettingsBindFlags.DEFAULT);
        add(cbSmallTitlebar);
        
        if (Version.checkVersion(3, 16, 0).length == 0) {
            CheckButton cbWideHandle = new CheckButton(_("Use a wide handle for splitters"));
            gsSettings.bind(SETTINGS_ENABLE_WIDE_HANDLE_KEY, cbWideHandle, "active", GSettingsBindFlags.DEFAULT);
            add(cbWideHandle);
        }
        
        //Dark Theme
        Box b = new Box(Orientation.HORIZONTAL, 6);
        b.add(createLabel(_("Theme Variant")));

        ListStore lsThemeVariant = new ListStore([GType.STRING, GType.STRING]);

        appendValues(lsThemeVariant, [_("Default"), SETTINGS_THEME_VARIANT_SYSTEM_VALUE]);
        appendValues(lsThemeVariant, [_("Light"), SETTINGS_THEME_VARIANT_LIGHT_VALUE]);
        appendValues(lsThemeVariant, [_("Dark"), SETTINGS_THEME_VARIANT_DARK_VALUE]);

        cbThemeVariant = new ComboBox(lsThemeVariant, false);
        cbThemeVariant.setFocusOnClick(false);
        cbThemeVariant.setIdColumn(1);
        CellRendererText cell = new CellRendererText();
        cell.setAlignment(0, 0);
        cbThemeVariant.packStart(cell, false);
        cbThemeVariant.addAttribute(cell, "text", 0);

        gsSettings.bind(SETTINGS_THEME_VARIANT_KEY, cbThemeVariant, "active-id", GSettingsBindFlags.DEFAULT);

        b.add(cbThemeVariant);
        add(b);
    }

public:

    this(Settings gsSettings) {
        super(Orientation.VERTICAL, 6);
        createUI(gsSettings);
    }
}

// Function to create a right aligned label with appropriate margins
private Label createLabel(string text) {
    Label label = new Label(text);
    label.setHalign(GtkAlign.END);
    //label.setMarginLeft(12);
    return label;
}
