/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.prefwindow;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.file;
import std.format;
import std.string;
import std.variant;

import gdk.Event;

import gio.Menu: GMenu = Menu;
import gio.Settings: GSettings = Settings;
import gio.SimpleAction;
import gio.SimpleActionGroup;

import glib.Variant: GVariant = Variant;

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
import gtk.Entry;
import gtk.FileChooserButton;
import gtk.FileFilter;
import gtk.Grid;
import gtk.HeaderBar;
import gtk.Image;
import gtk.Label;
import gtk.ListBox;
import gtk.ListBoxRow;
import gtk.ListStore;
import gtk.MenuButton;
import gtk.MessageDialog;
import gtk.Popover;
import gtk.Scale;
import gtk.ScrolledWindow;
import gtk.Separator;
import gtk.Settings;
import gtk.SizeGroup;
import gtk.SpinButton;
import gtk.Stack;
import gtk.Switch;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeStore;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Version;
import gtk.Widget;
import gtk.Window;

import vte.Terminal;

import gx.gtk.actions;
import gx.gtk.resource;
import gx.gtk.util;
import gx.gtk.vte;

import gx.i18n.l10n;
import gx.util.array;

import gx.terminix.application;
import gx.terminix.constants;
import gx.terminix.encoding;
import gx.terminix.preferences;
import gx.terminix.profilewindow;

/**
 * UI for managing Terminix preferences
 */
class PreferenceWindow : ApplicationWindow {

private:
    Stack pages;
    GSettings gsSettings;
    HeaderBar hbMain;
    HeaderBar hbSide;
    ListBox lbSide;

    ProfileEditor pe;

    // Track how many non-profile rows there are to prevent the last profile from being deleted
    immutable int NON_PROFILE_ROW_COUNT = 6;    

    void createUI(Application app) {

        createSplitHeaders();

        //Create Listbox
        lbSide = new ListBox();
        lbSide.setCanFocus(true);
        lbSide.setSelectionMode(SelectionMode.BROWSE);
        lbSide.setVexpand(true);
        lbSide.addOnRowSelected(&onRowSelected);

        //Create Stack and boxes
        pages = new Stack();
        pages.setHexpand(true);
        pages.setVexpand(true);

        GlobalPreferences gp = new GlobalPreferences(gsSettings);
        pages.addTitled(gp, N_("Global"), _("Global"));
        lbSide.add(new GenericPreferenceRow(N_("Global"), _("Global")));

        AppearancePreferences ap = new AppearancePreferences(gsSettings);
        pages.addTitled(ap, N_("Appearance"), _("Appearance"));
        lbSide.add(new GenericPreferenceRow(N_("Appearance"), _("Appearance")));

        QuakePreferences qp = new QuakePreferences(gsSettings);
        pages.addTitled(qp, N_("Quake"), _("Quake"));
        lbSide.add(new GenericPreferenceRow(N_("Quake"), _("Quake")));

        ShortcutPreferences sp = new ShortcutPreferences(gsSettings);
        pages.addTitled(sp, N_("Shortcuts"), _("Shortcuts"));
        lbSide.add(new GenericPreferenceRow(N_("Shortcuts"), _("Shortcuts")));

        EncodingPreferences ep = new EncodingPreferences(gsSettings);
        pages.addTitled(ep, N_("Encoding"), _("Encoding"));
        lbSide.add(new GenericPreferenceRow(N_("Encoding"), _("Encoding")));

        // Profile Editor - Re-used for all profiles
        pe = new ProfileEditor();
        pe.addOnProfileNameChanged(&profileNameChanged);
        pages.addTitled(pe, N_("Profile"), _("Profile"));
        lbSide.add(createProfileTitleRow());
        loadProfiles();

        ScrolledWindow sw = new ScrolledWindow(lbSide);
        sw.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sw.setShadowType(ShadowType.NONE);
        sw.setSizeRequest(180, -1);

        Box bSide = new Box(Orientation.VERTICAL,0); 
        bSide.add(sw);

        Button btnAddProfile = new Button(_("Add Profile"));
        btnAddProfile.addOnClicked(&onAddProfile);
        setAllMargins(btnAddProfile, 6);
        bSide.add(btnAddProfile);

        Box box = new Box(Orientation.HORIZONTAL, 0);
        box.add(bSide);
        box.add(new Separator(Orientation.VERTICAL));
        box.add(pages);

        add(box);

        SizeGroup sg = new SizeGroup(SizeGroupMode.HORIZONTAL);
        sg.addWidget(hbSide);
        sg.addWidget(bSide);

        //Set initial title
        hbMain.setTitle(_("Global"));
    }

    void createSplitHeaders() {
        hbMain = new HeaderBar();
        hbMain.setHexpand(true);
        hbMain.setTitle("");
        hbMain.setShowCloseButton(true);

        hbSide = new HeaderBar();
        hbSide.setTitle(_("Preferences"));

        Value layout = new Value("");
        Settings.getDefault().getProperty(GTK_DECORATION_LAYOUT, layout);

        string[] parts = split(layout.getString(), ":");
        string part1 = parts[0] ~ ":";
        string part2;

        if (parts.length >= 2)
            part2 = ":" ~ parts[1];

        hbSide.setDecorationLayout(part1);
        hbMain.setDecorationLayout(part2);

        Box bTitle = new Box(Orientation.HORIZONTAL, 0);
        bTitle.add(hbSide);
        bTitle.add(new Separator(Orientation.VERTICAL));
        bTitle.add(hbMain); 

        this.setTitlebar(bTitle);
    }

    ListBoxRow createProfileTitleRow() {
        ListBoxRow row = new ListBoxRow();
        Box bProfileTitle = new Box(Orientation.VERTICAL, 2);
        bProfileTitle.add(new Separator(Orientation.HORIZONTAL));
        Label lblProfileTitle = new Label("<b>Profiles</b>");
        lblProfileTitle.setUseMarkup(true);
        lblProfileTitle.setHalign(Align.START);
        lblProfileTitle.setSensitive(false);
        setAllMargins(row, 6);
        bProfileTitle.add(lblProfileTitle);
        row.add(bProfileTitle);
        row.setSelectable(false);
        row.setActivatable(false);     
        return row;        
    }

    void onRowSelected(ListBoxRow row, ListBox) {
        GenericPreferenceRow gr = cast(GenericPreferenceRow) row;
        if (gr !is null) {
            pages.setVisibleChildName(gr.name);
            hbMain.setTitle(gr.title);
            return;
        }
        ProfilePreferenceRow pr = cast(ProfilePreferenceRow) row;
        if (pr !is null) {
            trace(pr.getProfile().uuid);
            pe.bind(pr.getProfile());
            pages.setVisibleChildName("Profile");
            hbMain.setTitle(format("Profile: %s", pr.getProfile().name));
        }
    }

    void profileNameChanged(string newName) {
        ProfilePreferenceRow row = cast(ProfilePreferenceRow)lbSide.getSelectedRow();
        if (row !is null) {
            row.updateName(newName);
            hbMain.setTitle(format("Profile: %s", newName));
        }
    }

// Stuff that deals with profiles
private:

    void loadProfiles() {
        ProfileInfo[] infos = prfMgr.getProfiles();
        foreach (ProfileInfo info; infos) {
            ProfilePreferenceRow row = new ProfilePreferenceRow(this, info);
            lbSide.add(row); 
        }
    }

    void onAddProfile(Button button) {
        ProfileInfo profile = prfMgr.createProfile(SETTINGS_PROFILE_NEW_NAME_VALUE);
        ProfilePreferenceRow row = new ProfilePreferenceRow(this, profile);
        row.showAll();
        lbSide.add(row);
        lbSide.selectRow(row);
    }

    void deleteProfile(ProfilePreferenceRow row) {
        if (lbSide.getChildren().length  <= NON_PROFILE_ROW_COUNT + 1) return;
        string uuid = row.uuid;
        int index = getChildIndex(lbSide, row) - 1;
        lbSide.remove(row);
        prfMgr.deleteProfile(uuid);
        if (index < 0) index = 0; 
        lbSide.selectRow(lbSide.getRowAtIndex(index));
    }

    void cloneProfile(ProfilePreferenceRow sourceRow) {
        ProfileInfo target = prfMgr.cloneProfile(sourceRow.getProfile());
        ProfilePreferenceRow row = new ProfilePreferenceRow(this, target);
        row.showAll();
        lbSide.add(row);
        lbSide.selectRow(row);
    }

    void setDefaultProfile(ProfilePreferenceRow row) {
        prfMgr.setDefaultProfile(row.getProfile().uuid);
        ProfilePreferenceRow[] rows = gx.gtk.util.getChildren!ProfilePreferenceRow(lbSide, false);
        foreach(r; rows) {
            r.getProfile().isDefault = false;
        }
        row.getProfile.isDefault = true;
    }

public:

    this(Application app) {
        super(app);
        gsSettings = new GSettings(SETTINGS_ID);
        app.addWindow(this);
        createUI(app);
    }

    void focusProfile(string uuid) {
        ProfilePreferenceRow[] rows = gx.gtk.util.getChildren!ProfilePreferenceRow(lbSide, false);
        foreach(row; rows) {
            if (row.getProfile().uuid == uuid) {
                lbSide.selectRow(row);
                return;
            }
        }
    }
}

class GenericPreferenceRow: ListBoxRow {
private:
    string _name;
    string _title;

public:
    this(string name, string title) {
        super();
        _name = name;
        _title = title;

        Label label = new Label(_(name));
        label.setHalign(Align.START);
        setAllMargins(label, 6);
        add(label);
    }

    @property string name() {
        return _name;
    }

    @property string title() {
        return _title;
    }
}

class ProfilePreferenceRow: ListBoxRow {
private:
    ProfileInfo profile;
    PreferenceWindow window;

    Label lblName;

    immutable ACTION_PROFILE_PREFIX = "profile";
    immutable ACTION_PROFILE_DELETE = "delete";
    immutable ACTION_PROFILE_CLONE = "clone";
    immutable ACTION_PROFILE_DEFAULT = "default";

    void createUI() {
        Box box = new Box(Orientation.HORIZONTAL, 6);
        setAllMargins(box, 6);

        lblName = new Label(profile.name);
        lblName.setHalign(Align.START);
        box.packStart(lblName, true, true, 6);

        MenuButton btnMenu = new MenuButton();
        btnMenu.setRelief(ReliefStyle.NONE);
        btnMenu.setFocusOnClick(false);
        btnMenu.setPopover(createPopover(btnMenu));
        
        box.packEnd(btnMenu, false, false, 0);

        add(box);
    }

    void createActions() {
        SimpleActionGroup sag = new SimpleActionGroup();
        registerAction(sag, ACTION_PROFILE_PREFIX, ACTION_PROFILE_DELETE, null, delegate(GVariant, SimpleAction) {
            window.deleteProfile(this);
        });
        registerAction(sag, ACTION_PROFILE_PREFIX, ACTION_PROFILE_CLONE, null, delegate(GVariant, SimpleAction) {
            window.cloneProfile(this);
        });
        registerAction(sag, ACTION_PROFILE_PREFIX, ACTION_PROFILE_DEFAULT, null, delegate(GVariant, SimpleAction) {
            window.setDefaultProfile(this);
        });
        insertActionGroup(ACTION_PROFILE_PREFIX, sag);
    }

    Popover createPopover(Widget parent) {
        GMenu model = new GMenu();
        GMenu section = new GMenu();
        section.append(_("Delete"), getActionDetailedName(ACTION_PROFILE_PREFIX, ACTION_PROFILE_DELETE));
        section.append(_("Clone"), getActionDetailedName(ACTION_PROFILE_PREFIX, ACTION_PROFILE_CLONE));
        model.appendSection(null, section);

        section = new GMenu();
        section.append(_("Use for new terminals"), getActionDetailedName(ACTION_PROFILE_PREFIX, ACTION_PROFILE_DEFAULT));
        model.appendSection(null, section);

        Popover popover = new Popover(parent);
        popover.bindModel(model, null);
        return popover;
    }

public:
    this(PreferenceWindow window, ProfileInfo profile) {
        this.profile = profile;
        this.window = window;
        createActions();
        createUI();
    }

    ProfileInfo getProfile() {
        return profile;
    }

    void updateName(string newName) {
        profile.name = newName;
        lblName.setText(newName);
    }

    @property string uuid() {
        return profile.uuid;
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

    GSettings gsSettings;

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

    this(GSettings gsSettings) {
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
    GSettings gsShortcuts;
    GSettings gsSettings;

    TreeStore tsShortcuts;
    string[string] labels;
    string[string] prefixes;

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
            string action = tsShortcuts.getValueString(iter, COLUMN_ACTION_NAME);
            if (checkAndPromptChangeShortcut(action, name, label)) {
                tsShortcuts.setValue(iter, COLUMN_SHORTCUT, label);
                tracef("Setting action %s to shortcut %s", action, label);
                //Note accelerator changed by app which is monitoring gsetting changes
                gsShortcuts.setString(action, name);
            }
        });
        column = new TreeViewColumn(_("Shortcut Key"), craShortcut, "text", COLUMN_SHORTCUT);

        tvShortcuts.appendColumn(column);

        ScrolledWindow scShortcuts = new ScrolledWindow(tvShortcuts);
        scShortcuts.setShadowType(ShadowType.ETCHED_IN);
        scShortcuts.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        scShortcuts.setHexpand(true);
        scShortcuts.setVexpand(true);

        add(scShortcuts);

        CheckButton cbAccelerators = new CheckButton(_("Enable shortcuts"));
        gsSettings.bind(SETTINGS_ACCELERATORS_ENABLED, cbAccelerators, "active", GSettingsBindFlags.DEFAULT);
        add(cbAccelerators);

        tvShortcuts.expandAll();
    }

    /**
     * Check if shortcut is already assigned and if so disable it
     */
    bool checkAndPromptChangeShortcut(string actionName, string accelName, string accelLabel) {
        //Get first level, shortcut categories (i.e. Application, Window, Session or Terminal)
        TreeIterRange categoryRange = TreeIterRange(tsShortcuts);
        foreach(TreeIter categoryIter; categoryRange) {
            //Get second level which is shortcuts
            TreeIterRange shortcutRange = TreeIterRange(tsShortcuts, categoryIter);
            foreach(TreeIter iter; shortcutRange) {
                string currentActionName = tsShortcuts.getValueString(iter, COLUMN_ACTION_NAME);
                if (currentActionName.length > 0 && currentActionName != actionName) {
                    if (tsShortcuts.getValueString(iter, COLUMN_SHORTCUT) == accelLabel) {
                        MessageDialog dlg = new MessageDialog(cast(Window) this.getToplevel(), DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.OK_CANCEL, null, null);
                        scope (exit) {
                            dlg.destroy();
                        }
                        string title = "<span weight='bold' size='larger'>" ~ _("Overwrite Existing Shortcut") ~ "</span>";
                        string msg = format(_("The shortcut %s is already assigned to %s.\nDisable the shortcut for the other action and assign here instead?"), accelLabel, tsShortcuts.getValueString(iter, COLUMN_NAME));
                        with (dlg) {
                            setTransientFor(cast(Window) this.getToplevel());
                            setMarkup(title);
                            getMessageArea().setMarginLeft(0);
                            getMessageArea().setMarginRight(0);
                            getMessageArea().add(new Label(msg));
                            setImage(new Image("dialog-question", IconSize.DIALOG));
                            dlg.setDefaultResponse(ResponseType.OK);
                            showAll();
                        }
                        if (dlg.run() != ResponseType.CANCEL) {
                            tsShortcuts.setValue(iter, COLUMN_SHORTCUT, _(SHORTCUT_DISABLED));
                            gsShortcuts.setString(currentActionName, SHORTCUT_DISABLED);
                            return true;
                        } else {
                            return false;
                        }
                    }
                }
            }
        }

        return true;
    }

    /**
     * Parses the shortcuts.ui XML to extract the localized text, weight
     * parse instead of loading it in Builder to maintain compatibility with
     * pre GTK 3.20
     */
    void loadLocalizedShortcutLabels() {
        //Clear associative arrays since clear method isn't compatible with LDC
        labels = null;
        prefixes = null;

        string ui = getResource(SHORTCUT_UI_RESOURCE);
        if (ui.length == 0) {
            errorf("Could not load '%s' resource",SHORTCUT_UI_RESOURCE);
            return;
        }

        import std.xml: DocumentParser, ElementParser, Element, XMLException;

        try {
            DocumentParser parser = new DocumentParser(ui);
            parser.onStartTag["object"] = (ElementParser xml) {
                if (xml.tag.attr["class"] == "GtkShortcutsShortcut") {
                    string id = xml.tag.attr["id"];
                    xml.onEndTag["property"] = (in Element e) {
                        if (e.tag.attr["name"] == "title") {
                            labels[id] = C_(SHORTCUT_LOCALIZATION_CONTEXT, e.text);
                        }
                    };
                    xml.parse();
                }
            };
            parser.parse();
            // While you could use sections to get prefixes, not all sections are there
            // and it's not inutituve from a localization perspective. Just add them manually
            prefixes["win"] = C_(SHORTCUT_LOCALIZATION_CONTEXT, "Window");
            prefixes["app"] = C_(SHORTCUT_LOCALIZATION_CONTEXT, "Application");
            prefixes["terminal"] = C_(SHORTCUT_LOCALIZATION_CONTEXT, "Terminal");
            prefixes["session"] = C_(SHORTCUT_LOCALIZATION_CONTEXT, "Session");
        } catch (XMLException e) {
            error("Failed to parse shortcuts.ui", e);
        }
    }

    void loadShortcuts(TreeStore ts) {

        loadLocalizedShortcutLabels();

        string[] keys = gsShortcuts.listKeys();
        sort(keys);

        TreeIter currentIter;
        string currentPrefix;
        foreach (key; keys) {
            string prefix, id;
            getActionNameFromKey(key, prefix, id);
            if (prefix != currentPrefix) {
                currentPrefix = prefix;
                string localizedPrefix = _(prefix);
                if (prefix in prefixes) localizedPrefix = prefixes[prefix];
                currentIter = appendValues(ts, null, [localizedPrefix]);
            }
            string label = _(id);
            if (key in labels) {
                label = labels[key];
            }

            appendValues(ts, currentIter, [label, acceleratorNameToLabel(gsShortcuts.getString(key)), key]);
        }
    }

public:

    this(GSettings gsSettings) {
        super(Orientation.VERTICAL, 6);
        this.gsSettings = gsSettings;
        gsShortcuts = new GSettings(SETTINGS_PROFILE_KEY_BINDINGS_ID);
        createUI();
    }

}

/**
 * Appearance preferences page
 */
class AppearancePreferences: Box {
    private:
        void createUI(GSettings gsSettings) {
            setMarginTop(18);
            setMarginBottom(18);
            setMarginLeft(18);
            setMarginRight(18);

            //Enable Transparency, only enabled if less then 3.18
            if (Version.getMajorVersion() <= 3 && Version.getMinorVersion() < 18) {
                CheckButton cbTransparent = new CheckButton(_("Enable transparency, requires re-start"));
                gsSettings.bind(SETTINGS_ENABLE_TRANSPARENCY_KEY, cbTransparent, "active", GSettingsBindFlags.DEFAULT);
                add(cbTransparent);
            }

            Grid grid = new Grid();
            grid.setColumnSpacing(12);
            grid.setRowSpacing(6);
            int row = 0;

            //Render terminal titlebars smaller then default
            grid.attach(createLabel(_("Terminal title style")), 0, row, 1, 1);
            ComboBox cbTitleStyle = createNameValueCombo([_("Normal"), _("Small"), _("None")], SETTINGS_TERMINAL_TITLE_STYLE_VALUES);
            gsSettings.bind(SETTINGS_TERMINAL_TITLE_STYLE_KEY, cbTitleStyle, "active-id", GSettingsBindFlags.DEFAULT);
            grid.attach(cbTitleStyle, 1, row, 1, 1);
            row++;

            //Dark Theme
            grid.attach(createLabel(_("Theme variant")), 0, row, 1, 1);
            ComboBox cbThemeVariant = createNameValueCombo([_("Default"), _("Light"), _("Dark")], SETTINGS_THEME_VARIANT_VALUES);
            gsSettings.bind(SETTINGS_THEME_VARIANT_KEY, cbThemeVariant, "active-id", GSettingsBindFlags.DEFAULT);
            grid.attach(cbThemeVariant, 1, row, 1, 1);
            row++;

            //Background Image
            grid.attach(createLabel(_("Background image")), 0, row, 1, 1);

            FileChooserButton fcbImage = new FileChooserButton(_("Select Image"), FileChooserAction.OPEN);
            fcbImage.setHexpand(true);
            FileFilter ff = new FileFilter();
            ff.setName(_("All Image Files"));
            ff.addMimeType("image/jpeg");
            ff.addMimeType("image/png");
            ff.addMimeType("image/bmp");
            fcbImage.addFilter(ff);
            ff = new FileFilter();
            ff.addPattern("*");
            ff.setName(_("All Files"));
            fcbImage.addFilter(ff);
            string filename = gsSettings.getString(SETTINGS_BACKGROUND_IMAGE_KEY);
            if (exists(filename)) {
                fcbImage.setFilename(filename);
            }
            fcbImage.addOnFileSet(delegate(FileChooserButton fcb) {
               string selectedFilename = fcb.getFilename();
               if (exists(selectedFilename)) {
                   gsSettings.setString(SETTINGS_BACKGROUND_IMAGE_KEY, selectedFilename);
               }
            });

            Button btnReset = new Button("edit-delete-symbolic", IconSize.BUTTON);
            btnReset.setTooltipText(_("Reset background image"));
            btnReset.addOnClicked(delegate(Button) {
                fcbImage.unselectAll();
                gsSettings.reset(SETTINGS_BACKGROUND_IMAGE_KEY);
            });

            ComboBox cbImageMode = createNameValueCombo([_("Scale"), _("Tile"), _("Center"),_("Stretch")], SETTINGS_BACKGROUND_IMAGE_MODE_VALUES);
            gsSettings.bind(SETTINGS_BACKGROUND_IMAGE_MODE_KEY, cbImageMode, "active-id", GSettingsBindFlags.DEFAULT);

            // Background image settings only enabled if transparency is enabled
            gsSettings.bind(SETTINGS_ENABLE_TRANSPARENCY_KEY, fcbImage, "sensitive", GSettingsBindFlags.DEFAULT);
            gsSettings.bind(SETTINGS_ENABLE_TRANSPARENCY_KEY, btnReset, "sensitive", GSettingsBindFlags.DEFAULT);
            gsSettings.bind(SETTINGS_ENABLE_TRANSPARENCY_KEY, cbImageMode, "sensitive", GSettingsBindFlags.DEFAULT);

            Box bChooser = new Box(Orientation.HORIZONTAL, 2);
            bChooser.add(fcbImage);
            bChooser.add(btnReset);

            Box bImage = new Box(Orientation.HORIZONTAL, 6);
            bImage.add(bChooser);
            bImage.add(cbImageMode);
            grid.attach(bImage, 1, row, 1, 1);
            row++;

            //Session Name
            Label lblSessionName = new Label(_("Default session name"));
            lblSessionName.setHalign(Align.END);
            grid.attach(lblSessionName, 0, row, 1, 1);

            Entry eSessionName = new Entry();
            eSessionName.setHexpand(true);
            gsSettings.bind(SETTINGS_SESSION_NAME_KEY, eSessionName, "text", GSettingsBindFlags.DEFAULT);
            grid.attach(eSessionName, 1, row, 1, 1);
            row++;

            //Application Title
            Label lblAppTitle = new Label(_("Application title"));
            lblAppTitle.setHalign(Align.END);
            grid.attach(lblAppTitle, 0, row, 1, 1);

            Entry eAppTitle = new Entry();
            eAppTitle.setHexpand(true);
            gsSettings.bind(SETTINGS_APP_TITLE_KEY, eAppTitle, "text", GSettingsBindFlags.DEFAULT);
            grid.attach(eAppTitle, 1, row, 1, 1);
            row++;

            add(grid);

            if (Version.checkVersion(3, 16, 0).length == 0) {
                CheckButton cbWideHandle = new CheckButton(_("Use a wide handle for splitters"));
                gsSettings.bind(SETTINGS_ENABLE_WIDE_HANDLE_KEY, cbWideHandle, "active", GSettingsBindFlags.DEFAULT);
                add(cbWideHandle);
            }

            CheckButton cbRightSidebar = new CheckButton(_("Place the sidebar on the right"));
            gsSettings.bind(SETTINGS_SIDEBAR_RIGHT, cbRightSidebar, "active", GSettingsBindFlags.DEFAULT);
            add(cbRightSidebar);

            CheckButton cbTitleShowWhenSingle = new CheckButton(_("Show the terminal title even if its the only terminal"));
            gsSettings.bind(SETTINGS_TERMINAL_TITLE_SHOW_WHEN_SINGLE_KEY, cbTitleShowWhenSingle, "active", GSettingsBindFlags.DEFAULT);
            add(cbTitleShowWhenSingle);
        }

    public:
        this(GSettings gsSettings) {
            super(Orientation.VERTICAL, 6);
            createUI(gsSettings);
        }
}

class QuakePreferences : Box {

private:
    void createUI(GSettings gsSettings) {
        setMarginTop(18);
        setMarginBottom(18);
        setMarginLeft(18);
        setMarginRight(18);

        Label lblSize = new Label(format("<b>%s</b>", _("Size")));
        lblSize.setUseMarkup(true);
        lblSize.setHalign(Align.START);
        add(lblSize);

        Grid grid = new Grid();
        grid.setColumnSpacing(12);
        grid.setRowSpacing(6);
        int row = 0;

        // Terminal Height
        grid.attach(createLabel(_("Height percent")), 0, row, 1, 1);
        Scale sHeight = new Scale(Orientation.HORIZONTAL, 10, 100, 10);
        sHeight.setDrawValue(false);
        sHeight.setHexpand(true);
        sHeight.setHalign(Align.FILL);
        gsSettings.bind(SETTINGS_QUAKE_HEIGHT_PERCENT_KEY, sHeight.getAdjustment(), "value", GSettingsBindFlags.DEFAULT);
        grid.attach(sHeight, 1, row, 1, 1);
        row++;

        if (!isWayland(cast(Window) this.getToplevel())) {
            // Terminal Width
            grid.attach(createLabel(_("Width percent")), 0, row, 1, 1);
            Scale sWidth = new Scale(Orientation.HORIZONTAL, 10, 100, 10);
            sWidth.setDrawValue(false);
            sWidth.setHexpand(true);
            sWidth.setHalign(Align.FILL);
            gsSettings.bind(SETTINGS_QUAKE_WIDTH_PERCENT_KEY, sWidth.getAdjustment(), "value", GSettingsBindFlags.DEFAULT);
            grid.attach(sWidth, 1, row, 1, 1);
            row++;

            //Alignment
            grid.attach(createLabel(_("Alignment")), 0, row, 1, 1);
            ComboBox cbAlignment = createNameValueCombo([_("Left"), _("Center"), _("Right")], [SETTINGS_QUAKE_ALIGNMENT_LEFT_VALUE, SETTINGS_QUAKE_ALIGNMENT_CENTER_VALUE, SETTINGS_QUAKE_ALIGNMENT_RIGHT_VALUE], gsSettings, SETTINGS_QUAKE_ALIGNMENT_KEY);
            cbAlignment.addOnDestroy(delegate(Widget) {
                gsSettings.unbind(cbAlignment, "active-id");
            });
            grid.attach(cbAlignment, 1, row, 1, 1);
            row++;
        }

        add(grid);

        Label lblOptions = new Label(format("<b>%s</b>", _("Options")));
        lblOptions.setUseMarkup(true);
        lblOptions.setHalign(Align.START);
        add(lblOptions);

        Box bContent = new Box(Orientation.VERTICAL, 6);

        //Show on all workspaces
        CheckButton cbAllWorkspaces = new CheckButton(_("Show terminal on all workspaces"));
        gsSettings.bind(SETTINGS_QUAKE_SHOW_ON_ALL_WORKSPACES_KEY, cbAllWorkspaces, "active", GSettingsBindFlags.DEFAULT);
        bContent.add(cbAllWorkspaces);

        //Disable animations
        CheckButton cbDisableAnimations = new CheckButton(_("Set hint for window manager to disable animation"));
        gsSettings.bind(SETTINGS_QUAKE_DISABLE_ANIMATION_KEY, cbDisableAnimations, "active", GSettingsBindFlags.DEFAULT);
        bContent.add(cbDisableAnimations);

        //Hide window on lose focus
        CheckButton cbHideOnLoseFocus = new CheckButton(_("Hide window when focus is lost"));
        gsSettings.bind(SETTINGS_QUAKE_HIDE_LOSE_FOCUS_KEY, cbHideOnLoseFocus, "active", GSettingsBindFlags.DEFAULT);
        bContent.add(cbHideOnLoseFocus);

        /*
        //Keep window on top
        CheckButton cbKeepOnTop = new CheckButton(_("Always keep window on top"));
        gsSettings.bind(SETTINGS_QUAKE_KEEP_ON_TOP_KEY, cbKeepOnTop, "active", GSettingsBindFlags.DEFAULT);
        bContent.add(cbKeepOnTop);
        */

        // Wayland doesn't let you put a window on a specific monitor so don't show this
        if (!isWayland(cast(Window) this.getToplevel())) {

            //Active Monitor
            CheckButton cbActiveMonitor = new CheckButton(_("Display terminal on active monitor"));
            gsSettings.bind(SETTINGS_QUAKE_ACTIVE_MONITOR_KEY, cbActiveMonitor, "active", GSettingsBindFlags.DEFAULT);
            bContent.add(cbActiveMonitor);

            //Specific Monitor
            Box bSpecific = new Box(Orientation.HORIZONTAL, 6);
            bSpecific.setMarginLeft(36);
            Label lblSpecific = new Label(_("Display on specific monitor"));
            gsSettings.bind(SETTINGS_QUAKE_ACTIVE_MONITOR_KEY, lblSpecific, "sensitive", GSettingsBindFlags.INVERT_BOOLEAN);
            bSpecific.add(lblSpecific);
            SpinButton sbScreen = new SpinButton(0, getScreen().getNMonitors() - 1, 1);
            gsSettings.bind(SETTINGS_QUAKE_SPECIFIC_MONITOR_KEY, sbScreen, "value", GSettingsBindFlags.DEFAULT);
            gsSettings.bind(SETTINGS_QUAKE_ACTIVE_MONITOR_KEY, sbScreen, "sensitive", GSettingsBindFlags.INVERT_BOOLEAN);
            bSpecific.add(sbScreen);

            bContent.add(bSpecific);
        }

        add(bContent);
    }

public:

    this(GSettings gsSettings) {
        super(Orientation.VERTICAL, 6);
        createUI(gsSettings);
    }
}

/**
 * Global preferences page *
 */
class GlobalPreferences : Box {

private:

    void createUI(GSettings gsSettings) {
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

        //middle click closes the terminal
        CheckButton cbMiddleClickClose = new CheckButton(_("Close terminal by clicking middle mouse button on title"));
        gsSettings.bind(SETTINGS_MIDDLE_CLICK_CLOSE_KEY, cbMiddleClickClose, "active", GSettingsBindFlags.DEFAULT);
        add(cbMiddleClickClose);

        //Closing of last session closes window
        CheckButton cbCloseWithLastSession = new CheckButton(_("Close window when last session is closed"));
        gsSettings.bind(SETTINGS_CLOSE_WITH_LAST_SESSION_KEY, cbCloseWithLastSession, "active", GSettingsBindFlags.DEFAULT);
        add(cbCloseWithLastSession);

        //Show Notifications, only show option if notifications are supported
        if (checkVTEFeature(TerminalFeature.EVENT_NOTIFICATION)) {
            CheckButton cbNotify = new CheckButton(_("Send desktop notification on process complete"));
            gsSettings.bind(SETTINGS_NOTIFY_ON_PROCESS_COMPLETE_KEY, cbNotify, "active", GSettingsBindFlags.DEFAULT);
            add(cbNotify);
        }

        //New Instance Options
        Box bNewInstance = new Box(Orientation.HORIZONTAL, 6);

        Label lblNewInstance = new Label(_("On new instance"));
        lblNewInstance.setHalign(Align.END);
        bNewInstance.add(lblNewInstance);
        ComboBox cbNewInstance = createNameValueCombo([_("New Window"), _("New Session"), _("Split Right"), _("Split Down"), _("Focus Window")], SETTINGS_NEW_INSTANCE_MODE_VALUES);
        gsSettings.bind(SETTINGS_NEW_INSTANCE_MODE_KEY, cbNewInstance, "active-id", GSettingsBindFlags.DEFAULT);
        bNewInstance.add(cbNewInstance);
        add(bNewInstance);

        // *********** Clipboard Options
        Label lblClipboard = new Label(format("<b>%s</b>", _("Clipboard")));
        lblClipboard.setUseMarkup(true);
        lblClipboard.setHalign(Align.START);
        add(lblClipboard);

        //Advacned paste is default
        CheckButton cbAdvDefault = new CheckButton(_("Always use advanced paste dialog"));
        gsSettings.bind(SETTINGS_PASTE_ADVANCED_DEFAULT_KEY, cbAdvDefault, "active", GSettingsBindFlags.DEFAULT);
        add(cbAdvDefault);

        //Unsafe Paste Warning
        CheckButton cbUnsafe = new CheckButton(_("Warn when attempting unsafe paste"));
        gsSettings.bind(SETTINGS_UNSAFE_PASTE_ALERT_KEY, cbUnsafe, "active", GSettingsBindFlags.DEFAULT);
        add(cbUnsafe);

        //Strip Paste
        CheckButton cbStrip = new CheckButton(_("Strip first character of paste if comment or variable declaration"));
        gsSettings.bind(SETTINGS_STRIP_FIRST_COMMENT_CHAR_ON_PASTE_KEY, cbStrip, "active", GSettingsBindFlags.DEFAULT);
        add(cbStrip);

        //Copy on Select
        CheckButton cbCopyOnSelect = new CheckButton(_("Automatically copy text to clipboard when selecting"));
        gsSettings.bind(SETTINGS_COPY_ON_SELECT_KEY, cbCopyOnSelect, "active", GSettingsBindFlags.DEFAULT);
        add(cbCopyOnSelect);
    }

public:

    this(GSettings gsSettings) {
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