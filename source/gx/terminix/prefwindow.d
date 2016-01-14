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
import gtk.Widget;

import vte.Terminal;

import gx.gtk.actions;
import gx.gtk.util;

import gx.i18n.l10n;

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
        foreach(encoding; encodings) {
            TreeIter iter = ls.createIter();
            ls.setValue(iter, 0, menuEncodings.canFind(encoding[0]));
            ls.setValue(iter, 1, encoding[0] ~ " " ~ encoding[1]);
            ls.setValue(iter, 2, encoding[0]);
        }
        
        TreeView tv = new TreeView(ls);
        tv.setHeadersVisible(false);
        
        CellRendererToggle toggle = new CellRendererToggle();
        toggle.setActivatable(true);
        toggle.addOnToggled(delegate(string path, CellRendererToggle crt) {
            TreeIter iter = new TreeIter();
            ls.getIter(iter, new TreePath(path));
            string[] menuEncodings = gsSettings.getStrv(SETTINGS_ENCODINGS_KEY);
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
        //tvShortcuts.addOnCursorChanged(delegate(TreeView) { updateUI(); });

        TreeViewColumn column = new TreeViewColumn(_("Action"), new CellRendererText(), "text", COLUMN_NAME);
        column.setExpand(true);
        tvShortcuts.appendColumn(column);

        CellRendererAccel craShortcut = new CellRendererAccel();
        craShortcut.setProperty("editable", 1);
        craShortcut.addOnAccelCleared(delegate(string path, CellRendererAccel cra) {
            TreeIter iter = new TreeIter();
            tsShortcuts.getIter(iter, new TreePath(path));
            tsShortcuts.setValue(iter, COLUMN_SHORTCUT, SHORTCUT_DISABLED);
            //Note accelerator changed by app which is monitoring gsetting changes
            gsShortcuts.setString(tsShortcuts.getValueString(iter, COLUMN_ACTION_NAME), SHORTCUT_DISABLED);
        });
        craShortcut.addOnAccelEdited(delegate(string path, uint accelKey, GdkModifierType accelMods, uint hardwareKeycode, CellRendererAccel cra) {
            TreeIter iter = new TreeIter();
            tsShortcuts.getIter(iter, new TreePath(path));
            string label = AccelGroup.acceleratorName(accelKey, accelMods);
            tsShortcuts.setValue(iter, COLUMN_SHORTCUT, label);
            //Note accelerator changed by app which is monitoring gsetting changes
            gsShortcuts.setString(tsShortcuts.getValueString(iter, COLUMN_ACTION_NAME), label);
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
            appendValues(ts, currentIter, [_(id), gsShortcuts.getString(key), key]);
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
        btnNew.addOnClicked(delegate(Button button) {
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
        btnEdit.addOnClicked(delegate(Button button) { editProfile(); });
        bButtons.add(btnEdit);
        btnDelete = new Button(_("Delete"));
        btnDelete.addOnClicked(delegate(Button button) {
            ProfileInfo profile = getSelectedProfile();
            if (profile.uuid !is null) {
                prfMgr.deleteProfile(profile.uuid);
                lsProfiles.remove(tvProfiles.getSelectedIter());
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
            ProfileWindow window = new ProfileWindow(app, profile);
            app.addWindow(window);
            window.addOnDelete(&onProfileWindowDeleted);
            window.showAll();
            //TODO: Track profile editing windows to focus instead of creating new
            //prefId = window.getId();
        }
    }

    //Update Profile Name here in case it changed
    bool onProfileWindowDeleted(Event event, Widget widget) {
        ProfileWindow window = cast(ProfileWindow) widget;
        if (window) {
            ProfileInfo profile = prfMgr.getProfile(window.uuid);
            foreach (TreeIter iter; TreeIterRange(lsProfiles)) {
                if (lsProfiles.getValue(iter, COLUMN_UUID).getString() == window.uuid) {
                    lsProfiles.setValue(iter, COLUMN_NAME, profile.name);
                }
            }
        }
        return false;
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
        btnDelete.setSensitive(selected !is null && lsProfiles.iterNChildren(null) > 0);
        btnEdit.setSensitive(selected !is null);
    }

    void addProfile(ProfileInfo profile) {
        TreeIter iter = lsProfiles.createIter();
        lsProfiles.setValue(iter, 0, profile.isDefault);
        lsProfiles.setValue(iter, 1, profile.name);
        lsProfiles.setValue(iter, 2, profile.uuid);
    }

    void loadProfiles() {
        ProfileInfo[] profiles = prfMgr.getProfiles();
        lsProfiles.clear();
        foreach (ProfileInfo profile; profiles) {
            addProfile(profile);
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
class GlobalPreferences : Grid {

private:

    ComboBox cbThemeVariant;

    void createUI(Settings gsSettings) {
        //Set basic grid settings
        setColumnSpacing(12);
        setRowSpacing(6);
        setMarginTop(18);
        setMarginBottom(18);
        setMarginLeft(18);
        setMarginRight(18);

        int row = 0;
        Label lblBehavior = new Label("");
        lblBehavior.setUseMarkup(true);
        lblBehavior.setHalign(Align.START);
        lblBehavior.setMarkup(format("<b>%s</b>", _("Behavior")));
        attach(lblBehavior, 0, row, 2, 1);
        row++;

        //Prompt on new session
        CheckButton cbPrompt = new CheckButton(_("Prompt when creating a new session"));
        gsSettings.bind(SETTINGS_PROMPT_ON_NEW_SESSION_KEY, cbPrompt, "active", GSettingsBindFlags.DEFAULT);
        attach(cbPrompt, 0, row, 2, 1);
        row++;
        
        //Show Notifications, only show option if notifications are supported
        if (Signals.lookup("notification-received", Terminal.getType())  != 0) {
            CheckButton cbNotify = new CheckButton(_("Send desktop notification on process complete"));
            gsSettings.bind(SETTINGS_NOTIFY_ON_PROCESS_COMPLETE_KEY, cbNotify, "active", GSettingsBindFlags.DEFAULT);
            attach(cbNotify, 0, row, 2, 1);
            row++;
        }

        Label lblAppearance = new Label("");
        lblAppearance.setUseMarkup(true);
        lblAppearance.setHalign(Align.START);
        lblAppearance.setMarkup(format("<b>%s</b>", _("Appearance")));
        attach(lblAppearance, 0, row, 2, 1);
        row++;

        //Dark Theme
        attach(createLabel(_("Theme Variant")), 0, row, 1, 1);

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

        attach(cbThemeVariant, 1, row, 1, 1);
        row++;
    }

public:

    this(Settings gsSettings) {
        super();
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
