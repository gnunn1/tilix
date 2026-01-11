/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.prefeditor.prefdialog;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.file;
import std.format;
import std.process;
import std.string;
import std.typecons : No;
import std.variant;

import gdk.event;
import gdk.types;
import gdk.screen;
import gdk.types;

import gio.menu: Menu = Menu;
import gio.settings: Settings = Settings;
import gio.simple_action;
import gio.simple_action_group;
import gio.types;

import glib.variant: Variant = Variant;

import gobject.object;
import gobject.types;
import gobject.global;
import gobject.param_spec;
import gobject.types;
import gobject.value;

import gtk.accel_group;
import gtk.types;
import gtk.application;
import gtk.types;
import gtk.application_window;
import gtk.types;
import gtk.box;
import gtk.types;
import gtk.button;
import gtk.types;
import gtk.cell_renderer_accel;
import gtk.types;
import gtk.cell_renderer_text;
import gtk.types;
import gtk.cell_renderer_toggle;
import gtk.types;
import gtk.check_button;
import gtk.types;
import gtk.combo_box;
import gtk.types;
import gtk.dialog;
import gtk.types;
import gtk.entry;
import gtk.types;
import gtk.file_chooser_button;
import gtk.types;
import gtk.file_filter;
import gtk.types;
import gtk.grid;
import gtk.types;
import gtk.global;

import gx.gtk.eventsignals;
import gtk.header_bar;
import gtk.types;
import gtk.image;
import gtk.types;
import gtk.label;
import gtk.types;
import gtk.list_box;
import gtk.types;
import gtk.list_box_row;
import gtk.types;
import gtk.list_store;
import gtk.types;
import gtk.menu_button;
import gtk.types;
import gtk.message_dialog;
import gtk.types;
import gtk.popover;
import gtk.types;
import gtk.revealer;
import gtk.types;
import gtk.scale;
import gtk.types;
import gtk.scrolled_window;
import gtk.types;
import gtk.search_entry;
import gtk.types;
import gtk.separator;
import gtk.types;
import gtk.settings;
import gtk.types;
import gtk.size_group;
import gtk.types;
import gtk.spin_button;
import gtk.types;
import gtk.stack;
import gtk.types;
import gtk.switch_;
import gtk.types;
import gtk.toggle_button;
import gtk.types;
import gtk.tree_iter;
import gtk.types;
import gtk.tree_model;
import gtk.types;
import gtk.tree_model_filter;
import gtk.types;
import gtk.tree_path;
import gtk.types;
import gtk.tree_store;
import gtk.types;
import gtk.tree_view;
import gtk.types;
import gtk.tree_view_column;
import gtk.types;

import gtk.widget;
import gtk.types;
import gtk.window;
import gtk.types;

import vte.terminal;

import gx.gtk.actions;
import gx.gtk.dialog;
import gx.gtk.resource;
import gx.gtk.settings;
import gx.gtk.keys;
import gx.gtk.types;
import gx.gtk.util;
import gx.gtk.vte;

import gx.i18n.l10n;
import gx.util.array;

import gx.tilix.application;
import gx.tilix.constants;
import gx.tilix.encoding;
import gx.tilix.preferences;

import gx.tilix.prefeditor.bookmarkeditor;
import gx.tilix.prefeditor.common;
import gx.tilix.prefeditor.profileeditor;
import gx.tilix.prefeditor.titleeditor;

/**
 * UI for managing preferences
 */
class PreferenceDialog : ApplicationWindow {

private:
    ToggleButton searchButton;
    Stack pages;
    Settings gsSettings;
    HeaderBar hbMain;
    HeaderBar hbSide;
    ListBox lbSide;
    Button btnDeleteProfile;

    ProfileEditor pe;
    GlobalBookmarkEditor bmEditor;

    bool _wayland;

    int nonProfileRowCount = 0;


    void createUI() {

        setTitle(_("Tilix Preferences"));

        createSplitHeaders();

        //Create Listbox
        lbSide = new ListBox();
        lbSide.setCanFocus(true);
        lbSide.setSelectionMode(SelectionMode.Browse);
        lbSide.setVexpand(true);
        lbSide.connectRowSelected(&onRowSelected);

        //Create Stack and boxes
        pages = new Stack();
        pages.setHexpand(true);
        pages.setVexpand(true);

        GlobalPreferences gp = new GlobalPreferences(gsSettings);
        pages.addTitled(gp, N_("Global"), _("Global"));
        addNonProfileRow(new GenericPreferenceRow(N_("Global"), _("Global")));

        AppearancePreferences ap = new AppearancePreferences(gsSettings);
        pages.addTitled(ap, N_("Appearance"), _("Appearance"));
        addNonProfileRow(new GenericPreferenceRow(N_("Appearance"), _("Appearance")));

        // Quake disabled in Wayland, see #1314
        if (!isWayland(null)) {
            QuakePreferences qp = new QuakePreferences(gsSettings, _wayland);
            pages.addTitled(qp, N_("Quake"), _("Quake"));
            addNonProfileRow(new GenericPreferenceRow(N_("Quake"), _("Quake")));
        }

        bmEditor = new GlobalBookmarkEditor();
        pages.addTitled(bmEditor, N_("Bookmarks"), _("Bookmarks"));
        addNonProfileRow(new GenericPreferenceRow(N_("Bookmarks"), _("Bookmarks")));

        ShortcutPreferences sp = new ShortcutPreferences(gsSettings);
        searchButton.connectToggled(delegate(ToggleButton button) {
            sp.toggleShortcutsFind();
        });
        pages.addTitled(sp, N_("Shortcuts"), _("Shortcuts"));
        addNonProfileRow(new GenericPreferenceRow(N_("Shortcuts"), _("Shortcuts")));

        EncodingPreferences ep = new EncodingPreferences(gsSettings);
        pages.addTitled(ep, N_("Encoding"), _("Encoding"));
        addNonProfileRow(new GenericPreferenceRow(N_("Encoding"), _("Encoding")));

        AdvancedPreferences advp = new AdvancedPreferences(gsSettings);
        pages.addTitled(advp, N_("Advanced"), _("Advanced"));
        addNonProfileRow(new GenericPreferenceRow(N_("Advanced"), _("Advanced")));

        // Profile Editor - Re-used for all profiles
        pe = new ProfileEditor();
        pe.onProfileNameChanged .connect(&profileNameChanged);
        pages.addTitled(pe, N_("Profile"), _("Profile"));
        addNonProfileRow(createProfileTitleRow());
        loadProfiles();

        ScrolledWindow sw = new ScrolledWindow();
        sw.add(lbSide);
        sw.setPolicy(PolicyType.Never, PolicyType.Automatic);
        sw.setShadowType(ShadowType.None);
        sw.setSizeRequest(220, -1);

        Box bButtons = new Box(gtk.types.Orientation.Horizontal, 0);
        bButtons.getStyleContext().addClass("linked");
        setAllMargins(bButtons, 6);
        Button btnAddProfile = new Button();
        btnAddProfile.setImage(Image.newFromIconName("list-add-symbolic", IconSize.Button));
        btnAddProfile.setTooltipText(_("Add profile"));
        btnAddProfile.connectClicked(&onAddProfile);
        bButtons.packStart(btnAddProfile, false, false, 0);

        btnDeleteProfile = new Button();
        btnDeleteProfile.setImage(Image.newFromIconName("list-remove-symbolic", IconSize.Button));
        btnDeleteProfile.setTooltipText(_("Delete profile"));
        btnDeleteProfile.connectClicked(&onDeleteProfile);
        bButtons.packStart(btnDeleteProfile, false, false, 0);

        Box bSide = new Box(gtk.types.Orientation.Vertical, 0);
        bSide.add(sw);
        bSide.add(new Separator(gtk.types.Orientation.Horizontal));
        bSide.add(bButtons);

        Box box = new Box(gtk.types.Orientation.Horizontal, 0);
        box.add(bSide);
        box.add(new Separator(gtk.types.Orientation.Vertical));
        box.add(pages);

        add(box);

        SizeGroup sgSide = new SizeGroup(SizeGroupMode.Horizontal);
        sgSide.addWidget(hbSide);
        sgSide.addWidget(bSide);

        SizeGroup sgMain = new SizeGroup(SizeGroupMode.Horizontal);
        sgMain.addWidget(hbMain);
        sgMain.addWidget(pages);

        //Set initial title
        hbMain.setTitle(_("Global"));
    }

    // Keep track of non-profile rows
    void addNonProfileRow(ListBoxRow row) {
        lbSide.add(row);
        nonProfileRowCount++;
    }

    void onDecorationLayout() {
        Value layoutValue = new Value("");
        gtk.settings.Settings settings = this.getSettings();
        settings.getProperty(GTK_DECORATION_LAYOUT, layoutValue);

        string layout = layoutValue.getString();

        string[] parts = split(layout, ":");
        string part1 = parts[0] ~ ":";
        string part2;

        if (parts.length >= 2)
            part2 = ":" ~ parts[1];

        hbSide.setDecorationLayout(part1);
        hbMain.setDecorationLayout(part2);

        tracef("Decoration layout original: '%s', side: '%s', main: '%s'", layout, part1, part2);
    }

    void createSplitHeaders() {
        hbMain = new HeaderBar();
        hbMain.setHexpand(true);
        hbMain.setTitle("");

        searchButton = new ToggleButton();
        searchButton.setImage(Image.newFromIconName("system-search-symbolic", IconSize.Menu));
        searchButton.setNoShowAll(true);
        hbMain.packEnd(searchButton);

        hbMain.setShowCloseButton(true);

        hbSide = new HeaderBar();
        hbSide.setHexpand(false);
        hbSide.setShowCloseButton(true);
        hbSide.setTitle(_("Preferences"));

        Box bTitle = new Box(gtk.types.Orientation.Horizontal, 0);
        bTitle.add(hbSide);
        Separator sTitle = new Separator(gtk.types.Orientation.Vertical);
        sTitle.getStyleContext().addClass("tilix-title-separator");
        bTitle.add(sTitle);
        bTitle.add(hbMain);

        this.setTitlebar(bTitle);
        this.connectNotify("gtk-decoration-layout", delegate(ParamSpec ps, ObjectWrap ow) {
            onDecorationLayout();
        });
        onDecorationLayout();
    }

    ListBoxRow createProfileTitleRow() {
        ListBoxRow row = new ListBoxRow();
        Box bProfileTitle = new Box(gtk.types.Orientation.Vertical, 2);
        bProfileTitle.add(new Separator(gtk.types.Orientation.Horizontal));
        Label lblProfileTitle = new Label(format("<b>%s</b>",_("Profiles")));
        lblProfileTitle.setUseMarkup(true);
        lblProfileTitle.setHalign(Align.Start);
        lblProfileTitle.setSensitive(false);
        setAllMargins(row, 6);
        bProfileTitle.add(lblProfileTitle);
        row.add(bProfileTitle);
        row.setSelectable(false);
        row.setActivatable(false);
        return row;
    }

    void onRowSelected(ListBoxRow row, ListBox) {
        scope(exit) {updateUI();}
        GenericPreferenceRow gr = cast(GenericPreferenceRow) row;
        if (gr !is null) {
            if (gr.name == N_("Shortcuts")) {
                searchButton.setVisible(true);
            } else {
                searchButton.setVisible(false);
            }
            pages.setVisibleChildName(gr.name);
            hbMain.setTitle(gr.title);
            return;
        }
        ProfilePreferenceRow pr = cast(ProfilePreferenceRow) row;
        if (pr !is null) {
            pe.bind(pr.getProfile());
            pages.setVisibleChildName("Profile");
            hbMain.setTitle(format(_("Profile: %s"), pr.getProfile().name));
        }
    }

    void profileNameChanged(string newName) {
        ProfilePreferenceRow row = cast(ProfilePreferenceRow)lbSide.getSelectedRow();
        if (row !is null) {
            row.updateName(newName);
            hbMain.setTitle(format(_("Profile: %s"), newName));
        }
    }

    void updateUI() {
        ProfilePreferenceRow row = cast(ProfilePreferenceRow)lbSide.getSelectedRow();
        if (row !is null) {
            btnDeleteProfile.setSensitive(getProfileRowCount() >= 2);
        } else {
            btnDeleteProfile.setSensitive(false);
        }
    }

    int getProfileRowCount() {
        return cast(int)(lbSide.getChildren().length - nonProfileRowCount);
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
        updateUI();
    }

    void onDeleteProfile(Button button) {
        ProfilePreferenceRow row = cast(ProfilePreferenceRow)lbSide.getSelectedRow();
        if (row !is null) {
            deleteProfile(row);
        }
    }

    void deleteProfile(ProfilePreferenceRow row) {
        if (getProfileRowCount() < 2) return;
        if (!showConfirmDialog(this, format(_("Are you sure you want to delete '%s'?"), row.name), gsSettings, SETTINGS_PROMPT_ON_DELETE_PROFILE_KEY)) return;

        string uuid = row.uuid;
        int index = getChildIndex(lbSide, row) - 1;
        lbSide.remove(row);
        prfMgr.deleteProfile(uuid);
        if (index < 0) index = 0;
        lbSide.selectRow(lbSide.getRowAtIndex(index));
        updateUI();
        updateDefaultProfileMarker();
    }

    void cloneProfile(ProfilePreferenceRow sourceRow) {
        ProfileInfo target = prfMgr.cloneProfile(sourceRow.getProfile());
        ProfilePreferenceRow row = new ProfilePreferenceRow(this, target);
        row.showAll();
        lbSide.add(row);
        lbSide.selectRow(row);
        updateUI();
    }

    void setDefaultProfile(ProfilePreferenceRow row) {
        prfMgr.setDefaultProfile(row.getProfile().uuid);
        ProfilePreferenceRow[] rows = gx.gtk.util.getChildren!ProfilePreferenceRow(lbSide, false);
        foreach(r; rows) {
            if (r.uuid != row.uuid) {
                r.updateDefault(false);
            }
        }
        row.updateDefault(true);
    }

    void updateDefaultProfileMarker() {
        string uuid = prfMgr.getDefaultProfile();
        ProfilePreferenceRow[] rows = gx.gtk.util.getChildren!ProfilePreferenceRow(lbSide, false);
        foreach(r; rows) {
            if (r.uuid != uuid) {
                r.updateDefault(false);
            } else {
                r.updateDefault(true);
            }
        }
    }

public:

    this(ApplicationWindow window) {
        super(tilix);
        setTitle(_("Preferences"));
        setTypeHint(WindowTypeHint.Dialog);
        //setTransientFor(window);
        setDestroyWithParent(true);
        setShowMenubar(false);
        gsSettings = new Settings(SETTINGS_ID);
        _wayland = isWayland(window);
        createUI();
        updateUI();
        this.connectDestroy(delegate() {
            trace("Preference window is destroyed");
            pe.onProfileNameChanged.disconnect(&profileNameChanged);
            gsSettings.destroy();
            gsSettings = null;
        });
        // For some reason GTK doesn't propagate the destroy
        // signal to the ListBoxRow, have to explicitly remove
        // and destroy it.
        connectDeleteEventBoxed(this, delegate(Event e, Widget w) {
            trace("Deleting list box rows");
            ListBoxRow[] rows = gx.gtk.util.getChildren!ListBoxRow(lbSide, false);
            foreach(row; rows) {
                lbSide.remove(row);
                row.destroy();
            }
            return false;
        });
    }

    debug(Destructors) {
        ~this() {
            import std.stdio: writeln;
            writeln("********** PreferenceDialog destructor");
        }
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

    void focusEncoding() {
        GenericPreferenceRow[] rows = gx.gtk.util.getChildren!GenericPreferenceRow(lbSide, false);
        foreach(row; rows) {
            if (row.name() == N_("Encoding")) {
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
        label.setHalign(Align.Start);
        setAllMargins(label, 6);
        add(label);
    }

    @property override string name() {
        return _name;
    }

    @property string title() {
        return _title;
    }
}

class ProfilePreferenceRow: ListBoxRow {
private:
    ProfileInfo profile;
    PreferenceDialog dialog;

    Label lblName;
    Image imgDefault;

    SimpleActionGroup sag;
    SimpleAction saDefault;

    immutable ACTION_PROFILE_PREFIX = "profile";
    immutable ACTION_PROFILE_DELETE = "delete";
    immutable ACTION_PROFILE_CLONE = "clone";
    immutable ACTION_PROFILE_DEFAULT = "default";

    void createUI() {
        Box box = new Box(gtk.types.Orientation.Horizontal, 0);
        setAllMargins(box, 6);

        lblName = new Label(profile.name);
        lblName.setHalign(Align.Start);
        box.packStart(lblName, true, true, 2);

        MenuButton btnMenu = new MenuButton();
        btnMenu.setRelief(ReliefStyle.None);
        btnMenu.setFocusOnClick(false);
        btnMenu.setPopover(createPopover(btnMenu));

        box.packEnd(btnMenu, false, false, 0);

        imgDefault = Image.newFromIconName("object-select-symbolic", IconSize.Button);
        imgDefault.setNoShowAll(true);
        box.packEnd(imgDefault, false, false, 0);
        if (isDefault) {
            imgDefault.show();
            saDefault.setEnabled(false);
        }

        add(box);
    }

    void createActions() {
        sag = new SimpleActionGroup();
        registerAction(sag, ACTION_PROFILE_PREFIX, ACTION_PROFILE_DELETE, null, delegate(Variant, SimpleAction) {
            dialog.deleteProfile(this);
        });
        registerAction(sag, ACTION_PROFILE_PREFIX, ACTION_PROFILE_CLONE, null, delegate(Variant, SimpleAction) {
            dialog.cloneProfile(this);
        });
        saDefault = registerAction(sag, ACTION_PROFILE_PREFIX, ACTION_PROFILE_DEFAULT, null, delegate(Variant, SimpleAction) {
            dialog.setDefaultProfile(this);
        });
        insertActionGroup(ACTION_PROFILE_PREFIX, sag);
    }

    Popover createPopover(Widget parent) {
        Menu model = new Menu();
        Menu section = new Menu();
        section.append(_("Delete"), getActionDetailedName(ACTION_PROFILE_PREFIX, ACTION_PROFILE_DELETE));
        section.append(_("Clone"), getActionDetailedName(ACTION_PROFILE_PREFIX, ACTION_PROFILE_CLONE));
        model.appendSection(null, section);

        section = new Menu();
        section.append(_("Use for new terminals"), getActionDetailedName(ACTION_PROFILE_PREFIX, ACTION_PROFILE_DEFAULT));
        model.appendSection(null, section);

        return Popover.newFromModel(parent, model);
    }

public:
    this(PreferenceDialog dialog, ProfileInfo profile) {
        this.profile = profile;
        this.dialog = dialog;
        createActions();
        createUI();
        connectDestroy(delegate() {
            trace("ProfileRow destroyed");
            dialog = null;
            sag.destroy();
        });
    }

    void updateName(string newName) {
        profile.name = newName;
        lblName.setText(newName);
    }

    void updateDefault(bool value) {
        if (profile.isDefault != value) {
            profile.isDefault = value;
            if (value) {
                imgDefault.show();
                saDefault.setEnabled(false);
            } else {
                imgDefault.hide();
                saDefault.setEnabled(true);
            }
        }
    }

    ProfileInfo getProfile() {
        return profile;
    }

    @property override string name() {
        return profile.name;
    }

    @property bool isDefault() {
        return profile.isDefault;
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

    Settings gsSettings;

    ListStore ls;

    void createUI() {
        setMarginLeft(18);
        setMarginRight(18);
        setMarginTop(18);
        setMarginBottom(18);

        Label lblEncoding = new Label(_("Encodings showing in menu:"));
        lblEncoding.setHalign(Align.Start);
        add(lblEncoding);

        string[] menuEncodings = gsSettings.getStrv(SETTINGS_ENCODINGS_KEY);
        ls = ListStore.new_([cast(GType)GTypeEnum.Boolean, cast(GType)GTypeEnum.String, cast(GType)GTypeEnum.String]);
        foreach (encoding; encodings) {
            TreeIter iter;
            ls.append(iter);
            ls.setValue(iter, 0, new Value(menuEncodings.canFind(encoding[0])));
            ls.setValue(iter, 1, new Value(encoding[0] ~ " " ~ _(encoding[1])));
            ls.setValue(iter, 2, new Value(encoding[0]));
        }

        TreeView tv = new TreeView();
        tv.setModel(ls);
        tv.setHeadersVisible(false);

        CellRendererToggle toggle = new CellRendererToggle();
        toggle.setActivatable(true);
        toggle.connectToggled(delegate(string path, CellRendererToggle crt) {
            TreeIter iter;
            ls.getIter(iter, TreePath.newFromString(path));
            Value val = new Value();
            ls.getValue(iter, COLUMN_ENCODING, val);
            string encoding = val.getString();
            ls.getValue(iter, COLUMN_IS_ENABLED, val);
            bool enabled = val.getBoolean();
            trace("Menu encoding clicked for " ~ encoding);

            string[] encodingList = gsSettings.getStrv(SETTINGS_ENCODINGS_KEY);
            //Check for the reverse of what toggle is set for since
            //model is not updated until after settings updated
            if (enabled) {
                trace("Encoding is checked, removing");
                gx.util.array.remove(encodingList, encoding);
            } else {
                trace("Encoding is not checked, adding");
                encodingList ~= encoding;
            }
            if (encodingList.length == 0) {
                gsSettings.setStrv(SETTINGS_ENCODINGS_KEY, null);
            } else {
                gsSettings.setStrv(SETTINGS_ENCODINGS_KEY, encodingList);
            }
            ls.setValue(iter, COLUMN_IS_ENABLED, new Value(!enabled));
        });
        TreeViewColumn column = new TreeViewColumn();
        column.setTitle(_("Enabled"));
        column.packStart(toggle, true);
        column.addAttribute(toggle, "active", COLUMN_IS_ENABLED);
        tv.appendColumn(column);

        column = new TreeViewColumn();
        column.setTitle(_("Encoding"));
        CellRendererText crt = new CellRendererText();
        column.packStart(crt, true);
        column.addAttribute(crt, "text", COLUMN_NAME);
        column.setExpand(true);
        tv.appendColumn(column);

        ScrolledWindow sw = new ScrolledWindow();
        sw.add(tv);
        sw.setShadowType(ShadowType.EtchedIn);
        sw.setPolicy(PolicyType.Never, PolicyType.Automatic);
        sw.setHexpand(true);
        sw.setVexpand(true);

        add(sw);
    }

public:

    this(Settings gsSettings) {
        super(gtk.types.Orientation.Vertical, 6);
        this.gsSettings = gsSettings;
        createUI();
        this.connectDestroy(delegate() {
            gsSettings = null;
        });
    }
}

/**
 * Shortcuts preferences page
 */
class ShortcutPreferences : Box {

private:
    Settings gsShortcuts;
    Settings gsSettings;
    SearchEntry se;
    Revealer rFind;
    BindingHelper bh;

    CellRendererAccel craShortcut;
    TreeStore tsShortcuts;
    TreeView tvShortcuts;
    TreeModelFilter filter;
    string[string] labels;
    string[string] prefixes;

    Button btnDefault;

    enum COLUMN_NAME = 0;
    enum COLUMN_SHORTCUT = 1;
    enum COLUMN_ACTION_NAME = 2;
    enum COLUMN_SHORTCUT_TYPE = 3;

    enum SC_TYPE_ACTION = "action";
    enum SC_TYPE_PROFILE = "profile";

    TreeIter getSelectedIter() {
        TreeIter iter;
        TreeModel model;
        if (tvShortcuts.getSelection().getSelected(model, iter)) {
            return iter;
        }
        return null;
    }

    string getValueString(TreeModel model, TreeIter iter, uint column) {
        Value val = new Value();
        model.getValue(iter, cast(int)column, val);
        return val.getString();
    }

    void createUI() {
        setMarginLeft(18);
        setMarginRight(18);
        setMarginTop(18);
        setMarginBottom(18);
        rFind = new Revealer();
        se = new SearchEntry();
        se.connectSearchChanged(delegate(SearchEntry se) {
            filter.refilter();
            tvShortcuts.expandAll();
        });
        rFind.add(se);
        rFind.setRevealChild(false);
        add(rFind);

        //Shortcuts TreeView, note while detailed action name is in the model it's not actually displayed
        tsShortcuts = TreeStore.new_([cast(GType)GTypeEnum.String, cast(GType)GTypeEnum.String, cast(GType)GTypeEnum.String, cast(GType)GTypeEnum.String]);
        loadShortcuts(tsShortcuts);

        filter = cast(TreeModelFilter)tsShortcuts.filterNew(null);
        filter.setVisibleFunc(delegate bool(TreeModel model, TreeIter iter) {
            return filterBookmark(model, iter, this);
        });

        tvShortcuts = new TreeView();
        tvShortcuts.setModel(filter);
        tvShortcuts.setActivateOnSingleClick(false);
        tvShortcuts.connectCursorChanged(delegate(TreeView tv) {
            updateUI();
        });

        bh.bind(SETTINGS_ACCELERATORS_ENABLED, tvShortcuts, "sensitive", SettingsBindFlags.Default);

        TreeViewColumn column = new TreeViewColumn();
        column.setTitle(_("Action"));
        CellRendererText crt = new CellRendererText();
        column.packStart(crt, true);
        column.addAttribute(crt, "text", COLUMN_NAME);
        column.setExpand(true);
        tvShortcuts.appendColumn(column);

        craShortcut = new CellRendererAccel();
        craShortcut.setProperty("editable", new Value(1));
        craShortcut.setProperty("accel-mode", new Value(CellRendererAccelMode.Gtk));
        craShortcut.connectAccelCleared(delegate(string path, CellRendererAccel cra) {
            trace("Clearing shortcut");
            TreeIter iter;
            filter.getIter(iter, TreePath.newFromString(path));
            filter.convertIterToChildIter(iter, iter);
            tsShortcuts.setValue(iter, COLUMN_SHORTCUT, new Value(_(SHORTCUT_DISABLED)));
            //Note accelerator changed by app which is monitoring gsetting changes
            updateShortcutSetting(iter, SHORTCUT_DISABLED);
        });
        craShortcut.connectAccelEdited(delegate(string path, uint accelKey, gdk.types.ModifierType accelMods, uint hwCode, CellRendererAccel cra) {
            string label = gtk.global.acceleratorGetLabel(accelKey, accelMods);
            string name = gtk.global.acceleratorName(accelKey, accelMods);
            trace("Updating shortcut as " ~ label);
            TreeIter iter;
            filter.getIter(iter, TreePath.newFromString(path));
            accelChanged(label, name, iter);
        });
        column = new TreeViewColumn();
        column.setTitle(_("Shortcut Key"));
        column.packStart(craShortcut, true);
        column.addAttribute(craShortcut, "text", COLUMN_SHORTCUT);

        tvShortcuts.appendColumn(column);

        ScrolledWindow scShortcuts = new ScrolledWindow();
        scShortcuts.add(tvShortcuts);
        scShortcuts.setShadowType(ShadowType.EtchedIn);
        scShortcuts.setPolicy(PolicyType.Never, PolicyType.Automatic);
        scShortcuts.setHexpand(true);
        scShortcuts.setVexpand(true);

        add(scShortcuts);

        CheckButton cbAccelerators = CheckButton.newWithLabel(_("Enable shortcuts"));
        bh.bind(SETTINGS_ACCELERATORS_ENABLED, cbAccelerators, "active", SettingsBindFlags.Default);

        btnDefault = new Button();
        btnDefault.setImage(Image.newFromIconName("edit-undo-symbolic", IconSize.Button));
        btnDefault.setTooltipText(_("Restore default shortcut for this action"));
        btnDefault.setSensitive(false);
        btnDefault.connectClicked(delegate(Button b) {
            TreeIter iter = getSelectedIter();
            if (iter is null) return;
            string action = getValueString(filter, iter, COLUMN_ACTION_NAME);
            string defaultValue;
            if (getValueString(filter, iter, COLUMN_SHORTCUT_TYPE) == SC_TYPE_ACTION) {
                defaultValue = gsShortcuts.getDefaultValue(action).getString();
            } else {
                defaultValue = SHORTCUT_DISABLED;
            }
            filter.convertIterToChildIter(iter, iter);
            if (defaultValue == SHORTCUT_DISABLED) {
                tsShortcuts.setValue(iter, COLUMN_SHORTCUT, new Value(_(SHORTCUT_DISABLED)));
                updateShortcutSetting(iter, SHORTCUT_DISABLED);
            } else if (checkAndPromptChangeShortcut(action, defaultValue)) {
                //gsShortcuts.setString(action, defaultValue);
                updateShortcutSetting(iter, defaultValue);
                uint key;
                gdk.types.ModifierType mods;
                gtk.global.acceleratorParse(defaultValue, key, mods);
                string label = gtk.global.acceleratorGetLabel(key, mods);
                tsShortcuts.setValue(iter, COLUMN_SHORTCUT, new Value(label));
            }
        });

        Box box = new Box(gtk.types.Orientation.Horizontal, 0);
        box.packStart(btnDefault, false, false, 0);
        box.packEnd(cbAccelerators, false, false, 0);

        add(box);

        tvShortcuts.expandAll();
    }

    void updateUI() {
        TreeIter selected = getSelectedIter();
        TreeIter parent;
        btnDefault.setSensitive(selected !is null && tsShortcuts.iterParent(parent, selected));
    }

    /**
     * Update the shortcut setting, depending on type updates it profile or keyboard
     * section of settings.
     */
    void updateShortcutSetting(TreeIter iter, string shortcut) {
        if (getValueString(tsShortcuts, iter, COLUMN_SHORTCUT_TYPE) == SC_TYPE_ACTION) {
            gsShortcuts.setString(getValueString(tsShortcuts, iter, COLUMN_ACTION_NAME), shortcut);
        } else {
            string uuid = getValueString(tsShortcuts, iter, COLUMN_ACTION_NAME);
            Settings gsProfile = prfMgr.getProfileSettings(uuid);
            if (gsProfile !is null) {
                gsProfile.setString(SETTINGS_PROFILE_SHORTCUT_KEY, shortcut);
            }
            if (shortcut != SHORTCUT_DISABLED) {
                tilix.addAccelerator(shortcut, getActionDetailedName(ACTION_PREFIX_TERMINAL,ACTION_PROFILE_SELECT), new Variant(uuid));
            } else {
                tilix.removeAccelerator(getActionDetailedName(ACTION_PREFIX_TERMINAL,ACTION_PROFILE_SELECT), new Variant(uuid));
            }
        }
    }

    /**
     * Called when user changes accelerator, will prompt if accelerator duplicates
     */
    void accelChanged(string label, string name, TreeIter iter) {
        string action = getValueString(filter, iter, COLUMN_ACTION_NAME);
        if (checkAndPromptChangeShortcut(action, label)) {
            filter.convertIterToChildIter(iter, iter);
            tsShortcuts.setValue(iter, COLUMN_SHORTCUT, new Value(label));
            tracef("Setting action %s to shortcut %s", action, label);
            //Note accelerator changed by app which is monitoring gsetting changes
            updateShortcutSetting(iter, name);
            //gsShortcuts.setString(action, name);
        }
    }

    void toggleShortcutsFind(){
        if (!rFind.getRevealChild()) {
            rFind.setRevealChild(true);
            se.grabFocus();
        } else {
            rFind.setRevealChild(false);
            se.setText("");
        }
    }

    /**
     * Check if shortcut is already assigned and if so disable it
     */
    bool checkAndPromptChangeShortcut(string actionName, string accelLabel) {
        import gtk.container: Container;
        // Do not check if accel is already used for nautilus shortcuts
        if (actionName.startsWith("nautilus")) return true;

        //Get first level, shortcut categories (i.e. Application, Window, Session or Terminal)
        TreeIterRange categoryRange = TreeIterRange(tsShortcuts);
        foreach(TreeIter categoryIter; categoryRange) {
            //Get second level which is shortcuts
            TreeIterRange shortcutRange = TreeIterRange(tsShortcuts, categoryIter);
            foreach(TreeIter iter; shortcutRange) {
                string currentActionName = getValueString(tsShortcuts, iter, COLUMN_ACTION_NAME);
                if (currentActionName.startsWith("nautilus")) continue;
                if (currentActionName.length > 0 && currentActionName != actionName) {
                    if (getValueString(tsShortcuts, iter, COLUMN_SHORTCUT) == accelLabel) {
                        trace("Checking toplevel");
                        Window parentWindow = cast(Window) this.getToplevel();

                        import gtk.c.functions: gtk_message_dialog_new;
                        import gtk.c.types: GtkWindow;
                        auto _cretval = gtk_message_dialog_new(parentWindow ? cast(GtkWindow*)parentWindow._cPtr(No.Dup) : null,
                                                               gtk.types.DialogFlags.Modal,
                                                               gtk.types.MessageType.Question,
                                                               gtk.types.ButtonsType.OkCancel,
                                                               null);
                        MessageDialog dlg = ObjectWrap._getDObject!(MessageDialog)(_cretval, Yes.Take);

                        scope (exit) {
                            dlg.destroy();
                        }
                        string titleText = "<span weight='bold' size='larger'>" ~ _("Overwrite Existing Shortcut") ~ "</span>";
                        string msg = format(_("The shortcut %s is already assigned to %s.\nDisable the shortcut for the other action and assign here instead?"), accelLabel, getValueString(tsShortcuts, iter, COLUMN_NAME));
                        with (dlg) {
                            if (parentWindow !is null) setTransientFor(parentWindow);
                            setMarkup(titleText);
                            getMessageArea().setMarginLeft(0);
                            getMessageArea().setMarginRight(0);
                            (cast(Container)getMessageArea()).add(new Label(msg));
                            setImage(Image.newFromIconName("dialog-question", IconSize.Dialog));
                            setDefaultResponse(gtk.types.ResponseType.Ok);
                            showAll();
                        }
                        if (dlg.run() != gtk.types.ResponseType.Cancel) {
                            tsShortcuts.setValue(iter, COLUMN_SHORTCUT, new Value(_(SHORTCUT_DISABLED)));
                            updateShortcutSetting(iter, SHORTCUT_DISABLED);
                            //gsShortcuts.setString(currentActionName, SHORTCUT_DISABLED);
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
        import glib.c.functions : g_markup_parse_context_new, g_markup_parse_context_parse, g_markup_parse_context_free;
        import glib.c.types : GMarkupParser, GMarkupParseContext, GMarkupParseFlags, GError;
        import std.string : fromStringz;
        import std.array : empty;

        string ui = getResource(SHORTCUT_UI_RESOURCE);
        if (ui.length == 0) {
            errorf("Could not load '%s' resource",SHORTCUT_UI_RESOURCE);
            return;
        }

        struct ParseHelper {
            string currentId = "";
            bool addNextText = false;
            string[string] labels;
        }

        GMarkupParser parseConfig;
        parseConfig.startElement = cast(typeof(parseConfig.startElement)) function void(GMarkupParseContext* context,
                                             const(char)* elementNameC,
                                             const(char*)* attributeNames,
                                             const(char*)* attributeValues,
                                             void* userData,
                                             GError** err) {
            auto helper = cast(ParseHelper*)userData;
            const elementName = elementNameC.fromStringz;
            if (elementName == "object") {
                string[string] attrs;
                for (uint i = 0; attributeNames[i] != null; i++)
                    attrs[attributeNames[i].fromStringz.to!string] = attributeValues[i].fromStringz.to!string;

                if (attrs.get("class", "") == "GtkShortcutsShortcut")
                    helper.currentId = attrs["id"];

            } else if (elementName == "property" && !helper.currentId.empty) {
                for (uint i = 0; attributeNames[i] != null; i++) {
                    if (attributeNames[i].fromStringz == "name" && attributeValues[i].fromStringz == "title") {
                        helper.addNextText = true;
                        break;
                    }
                }
            }
        };
        parseConfig.text = cast(typeof(parseConfig.text)) function void(GMarkupParseContext* context,
                                         const(char)* text,
                                         size_t textLen,
                                         void* userData,
                                         GError** err) {
            auto helper = cast(ParseHelper*)userData;
            if (!helper.addNextText)
                return;

            helper.labels[helper.currentId] = C_(SHORTCUT_LOCALIZATION_CONTEXT, text.fromStringz.to!string);
            helper.currentId = null;
            helper.addNextText = false;
        };

        try {
            ParseHelper helper;
            auto parser = g_markup_parse_context_new(&parseConfig, GMarkupParseFlags.PrefixErrorPosition, &helper, null);
            g_markup_parse_context_parse(parser, toStringz(ui), cast(ptrdiff_t)ui.length, null);
            g_markup_parse_context_free(parser);
            labels = helper.labels;

            // While you could use sections to get prefixes, not all sections are there
            // and it's not inutituve from a localization perspective. Just add them manually
            prefixes[ACTION_PREFIX_WIN] = C_(SHORTCUT_LOCALIZATION_CONTEXT, "Window");
            prefixes[ACTION_PREFIX_APP] = C_(SHORTCUT_LOCALIZATION_CONTEXT, "Application");
            prefixes[ACTION_PREFIX_TERMINAL] = C_(SHORTCUT_LOCALIZATION_CONTEXT, "Terminal");
            prefixes[ACTION_PREFIX_SESSION] = C_(SHORTCUT_LOCALIZATION_CONTEXT, "Session");
            prefixes[ACTION_PREFIX_NAUTILUS] = C_(SHORTCUT_LOCALIZATION_CONTEXT, "Nautilus");
        } catch (Exception e) {
            error("Failed to parse shortcuts.ui", e);
        }
    }

    /**
     * Returns a list of shortcuts that require a minimum
     * version of GTK to function correctly.
     *
     * This avoids the user trying to customize shortcuts
     * they can't use.
     */
    int[2][string] getGTKVersionedShortcuts() {
        int[2][string] result;

        result["app-shortcuts"] = [3, 19];

        return result;
    }

    /**
     * Returns a list of shortcuts that require a minimum
     * version of VTE to function correctly.
     *
     * This avoids the user trying to customize shortcuts
     * they can't use.
     */
    int[2][string] getVTEVersionedShortcuts() {
        int[2][string] result;
        result["terminal-copy-as-html"] = [VTE_VERSION_COPY_AS_HTML[0], VTE_VERSION_COPY_AS_HTML[1]];
        return result;
    }

    TerminalFeature[string] getVTEFeatureShortcuts() {
        TerminalFeature[string] result;
        result["terminal-next-prompt"] = TerminalFeature.EVENT_SCREEN_CHANGED;
        result["terminal-previous-prompt"] = TerminalFeature.EVENT_SCREEN_CHANGED;
        return result;
    }

    void loadShortcuts(TreeStore ts) {
        loadShortcutsFromSettings(ts);
        loadShortcutsFromProfile(ts);
    }

    void loadShortcutsFromProfile(TreeStore ts) {
        TreeIter currentIter = appendValues(ts, null, ["Profile"]);
        string[] uuids = prfMgr.getProfileUUIDs();
        foreach(uuid; uuids) {
            Settings gsProfile = prfMgr.getProfileSettings(uuid);
            try {
                string name = gsProfile.getString(SETTINGS_PROFILE_VISIBLE_NAME_KEY);
                string key = gsProfile.getString(SETTINGS_PROFILE_SHORTCUT_KEY);
                appendValues(ts, currentIter, [name, acceleratorNameToLabel(key), uuid, SC_TYPE_PROFILE]);
            } finally {
                gsProfile.destroy();
            }
        }
    }

    void loadShortcutsFromSettings(TreeStore ts) {

        int[2][string] gtkVersioned = getGTKVersionedShortcuts();
        int[2][string] vteVersioned = getVTEVersionedShortcuts();
        TerminalFeature[string] vteFeatured = getVTEFeatureShortcuts();

        loadLocalizedShortcutLabels();
        string[] keys = gsShortcuts.listKeys();
        sort(keys);

        TreeIter currentIter;
        string currentPrefix;
        foreach (key; keys) {
            // Check if shortcut supported in current GTK Version
            if (key in gtkVersioned) {
                int[2] gtkVersion = gtkVersioned[key];
                if (gtk.global.checkVersion(gtkVersion[0], gtkVersion[1], 0).length > 0) continue;
            }
            // Check if shortcut supported in current VTE Version
            if (key in vteVersioned) {
                int[2] vteVersion = vteVersioned[key];
                if (!checkVTEVersionNumber(vteVersion[0], vteVersion[1])) continue;
            }
            // Check if shortcut supported by special features (i.e. custom patches) of VTE
            if (key in vteFeatured) {
                if (!checkVTEFeature(vteFeatured[key])) continue;
            }

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

            appendValues(ts, currentIter, [label, acceleratorNameToLabel(gsShortcuts.getString(key)), key, SC_TYPE_ACTION]);
        }
    }

    static bool filterBookmark(TreeModel gtkModel, TreeIter iter, ShortcutPreferences page) {
        string name = page.getValueString(gtkModel, iter, COLUMN_NAME);
        //import std.string: No;
        string text = page.se.getText();
        import std.string : indexOf;
        return (page.tsShortcuts.iterHasChild(iter) || text.length==0 || indexOf(name, text, No.caseSensitive) >= 0);
    }

public:

    this(Settings gsSettings) {
        super(gtk.types.Orientation.Vertical, 6);
        this.gsSettings = gsSettings;
        bh = new BindingHelper(gsSettings);
        gsShortcuts = new Settings(SETTINGS_KEY_BINDINGS_ID);
        createUI();
        this.connectDestroy(delegate() {
            bh.unbind();
            bh = null;
            gsSettings = null;
            gsShortcuts.destroy();
            gsShortcuts = null;
        });
    }

}

/**
 * Appearance preferences page
 */
class AppearancePreferences: Box {
    private:
        BindingHelper bh;
        Settings gsSettings;

        void createUI() {
            setMarginTop(18);
            setMarginBottom(18);
            setMarginLeft(18);
            setMarginRight(18);

            Grid grid = new Grid();
            grid.setColumnSpacing(12);
            grid.setRowSpacing(6);
            int row = 0;

            //Window style
            grid.attach(createLabel(_("Window style")), 0, row, 1, 1);
            Box bWindowStyle = new Box(gtk.types.Orientation.Horizontal, 6);
            ComboBox cbWindowStyle = createNameValueCombo([_("Normal"), _("Disable CSD"), _("Disable CSD, hide toolbar"), _("Borderless")], SETTINGS_WINDOW_STYLE_VALUES);
            bh.bind(SETTINGS_WINDOW_STYLE_KEY, cbWindowStyle, "active-id", SettingsBindFlags.Default);
            bWindowStyle.add(cbWindowStyle);

            Label lblRestart = new Label(_("Window restart required"));
            lblRestart.setHalign(Align.Start);
            lblRestart.setSensitive(false);
            bWindowStyle.add(lblRestart);

            grid.attach(bWindowStyle, 1, row, 1, 1);
            row++;

            //Render terminal titlebars smaller then default
            grid.attach(createLabel(_("Terminal title style")), 0, row, 1, 1);
            ComboBox cbTitleStyle = createNameValueCombo([_("Normal"), _("Small"), _("None")], SETTINGS_TERMINAL_TITLE_STYLE_VALUES);
            bh.bind(SETTINGS_TERMINAL_TITLE_STYLE_KEY, cbTitleStyle, "active-id", SettingsBindFlags.Default);
            grid.attach(cbTitleStyle, 1, row, 1, 1);
            row++;

            grid.attach(createLabel(_("Tab position")), 0, row, 1, 1);
            ComboBox cbTabPosition = createNameValueCombo([_("Left"), _("Right"), _("Top"), _("Bottom")], SETTINGS_TAB_POSITION_VALUES);
            bh.bind(SETTINGS_TAB_POSITION_KEY, cbTabPosition, "active-id", SettingsBindFlags.Default);
            grid.attach(cbTabPosition, 1, row, 1, 1);
            row++;

            //Dark Theme
            grid.attach(createLabel(_("Theme variant")), 0, row, 1, 1);
            ComboBox cbThemeVariant = createNameValueCombo([_("Default"), _("Light"), _("Dark")], SETTINGS_THEME_VARIANT_VALUES);
            bh.bind(SETTINGS_THEME_VARIANT_KEY, cbThemeVariant, "active-id", SettingsBindFlags.Default);
            grid.attach(cbThemeVariant, 1, row, 1, 1);
            row++;

            //Background image
            grid.attach(createLabel(_("Background image")), 0, row, 1, 1);

            FileChooserButton fcbImage = new FileChooserButton(_("Select Image"), FileChooserAction.Open);
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
            fcbImage.connectFileSet(delegate(FileChooserButton fcb) {
               string selectedFilename = fcb.getFilename();
               if (exists(selectedFilename)) {
                   gsSettings.setString(SETTINGS_BACKGROUND_IMAGE_KEY, selectedFilename);
               }
            });

            Button btnReset = new Button();
            btnReset.setImage(Image.newFromIconName("edit-delete-symbolic", IconSize.Button));
            btnReset.setTooltipText(_("Reset background image"));
            btnReset.connectClicked(delegate(Button b) {
                fcbImage.unselectAll();
                gsSettings.reset(SETTINGS_BACKGROUND_IMAGE_KEY);
            });

            ComboBox cbImageMode = createNameValueCombo([_("Scale"), _("Tile"), _("Center"),_("Stretch")], SETTINGS_BACKGROUND_IMAGE_MODE_VALUES);
            bh.bind(SETTINGS_BACKGROUND_IMAGE_MODE_KEY, cbImageMode, "active-id", SettingsBindFlags.Default);

            // Background image settings only enabled if transparency is enabled
            bh.bind(SETTINGS_ENABLE_TRANSPARENCY_KEY, fcbImage, "sensitive", SettingsBindFlags.Default);
            bh.bind(SETTINGS_ENABLE_TRANSPARENCY_KEY, btnReset, "sensitive", SettingsBindFlags.Default);
            bh.bind(SETTINGS_ENABLE_TRANSPARENCY_KEY, cbImageMode, "sensitive", SettingsBindFlags.Default);

            Box bChooser = new Box(gtk.types.Orientation.Horizontal, 2);
            bChooser.add(fcbImage);
            bChooser.add(btnReset);

            Box bImage = new Box(gtk.types.Orientation.Horizontal, 6);
            bImage.add(bChooser);
            bImage.add(cbImageMode);
            grid.attach(bImage, 1, row, 1, 1);
            row++;

            //Session Name
            Label lblSessionName = new Label(_("Default session name"));
            lblSessionName.setHalign(Align.End);
            grid.attach(lblSessionName, 0, row, 1, 1);

            Entry eSessionName = new Entry();
            eSessionName.setHexpand(true);
            bh.bind(SETTINGS_SESSION_NAME_KEY, eSessionName, "text", SettingsBindFlags.Default);
            if (checkVersion(3, 16, 0).length == 0) {
                grid.attach(createTitleEditHelper(eSessionName, TitleEditScope.SESSION), 1, row, 1, 1);
            } else {
                grid.attach(eSessionName, 1, row, 1, 1);
            }
            row++;

            //Application Title
            Label lblAppTitle = new Label(_("Application title"));
            lblAppTitle.setHalign(Align.End);
            grid.attach(lblAppTitle, 0, row, 1, 1);

            Entry eAppTitle = new Entry();
            eAppTitle.setHexpand(true);
            bh.bind(SETTINGS_APP_TITLE_KEY, eAppTitle, "text", SettingsBindFlags.Default);
            if (checkVersion(3, 16, 0).length == 0) {
                grid.attach(createTitleEditHelper(eAppTitle, TitleEditScope.WINDOW), 1, row, 1, 1);
            } else {
                grid.attach(eAppTitle, 1, row, 1, 1);
            }
            row++;

            add(grid);

            //Enable Transparency, only enabled if less then 3.18
            if (getMajorVersion() <= 3 && getMinorVersion() < 18) {
                CheckButton cbTransparent = CheckButton.newWithLabel(_("Enable transparency, requires re-start"));
                bh.bind(SETTINGS_ENABLE_TRANSPARENCY_KEY, cbTransparent, "active", SettingsBindFlags.Default);
                add(cbTransparent);
            }

            if (gtk.global.checkVersion(3, 16, 0).length == 0) {
                CheckButton cbWideHandle = CheckButton.newWithLabel(_("Use a wide handle for splitters"));
                bh.bind(SETTINGS_ENABLE_WIDE_HANDLE_KEY, cbWideHandle, "active", SettingsBindFlags.Default);
                add(cbWideHandle);
            }

            CheckButton cbRightSidebar = CheckButton.newWithLabel(_("Place the sidebar on the right"));
            bh.bind(SETTINGS_SIDEBAR_RIGHT, cbRightSidebar, "active", SettingsBindFlags.Default);
            add(cbRightSidebar);

            CheckButton cbTitleShowWhenSingle = CheckButton.newWithLabel(_("Show the terminal title even if it's the only terminal"));
            bh.bind(SETTINGS_TERMINAL_TITLE_SHOW_WHEN_SINGLE_KEY, cbTitleShowWhenSingle, "active", SettingsBindFlags.Default);
            add(cbTitleShowWhenSingle);

            if (gtk.global.checkVersion(3, GTK_SCROLLEDWINDOW_VERSION, 0).length == 0 && environment.get("GTK_OVERLAY_SCROLLING","1") == "1") {
                CheckButton cbOverlay = CheckButton.newWithLabel(_("Use overlay scrollbars (Application restart required)"));
                bh.bind(SETTINGS_USE_OVERLAY_SCROLLBAR_KEY, cbOverlay, "active", SettingsBindFlags.Default);
                add(cbOverlay);
            }

            CheckButton cbUseTabs = CheckButton.newWithLabel(_("Use tabs instead of sidebar (Application restart required)"));
            bh.bind(SETTINGS_USE_TABS_KEY, cbUseTabs, "active", SettingsBindFlags.Default);
            add(cbUseTabs);
        }

    public:
        this(Settings gsSettings) {
            super(gtk.types.Orientation.Vertical, 6);
            this.gsSettings = gsSettings;
            bh = new BindingHelper(gsSettings);
            createUI();

            connectDestroy(delegate() {
                bh.unbind();
                bh = null;

                gsSettings = null;
            });
        }
}

class QuakePreferences : Box {

private:
    BindingHelper bh;

    void createUI(bool wayland) {
        setMarginTop(18);
        setMarginBottom(18);
        setMarginLeft(18);
        setMarginRight(18);

        Label lblSize = new Label(format("<b>%s</b>", _("Size")));
        lblSize.setUseMarkup(true);
        lblSize.setHalign(Align.Start);
        add(lblSize);

        Grid grid = new Grid();
        grid.setColumnSpacing(12);
        grid.setRowSpacing(6);
        int row = 0;

        // Terminal Height
        grid.attach(createLabel(_("Height percent")), 0, row, 1, 1);
        Scale sHeight = Scale.newWithRange(gtk.types.Orientation.Horizontal, 10, 90, 10);
        sHeight.setValuePos(PositionType.Right);
        sHeight.setHexpand(true);
        sHeight.setHalign(Align.Fill);
        bh.bind(SETTINGS_QUAKE_HEIGHT_PERCENT_KEY, sHeight.getAdjustment(), "value", SettingsBindFlags.Default);
        grid.attach(sHeight, 1, row, 1, 1);
        row++;

        if (!wayland) {
            // Terminal Width
            grid.attach(createLabel(_("Width percent")), 0, row, 1, 1);
            Scale sWidth = Scale.newWithRange(gtk.types.Orientation.Horizontal, 10, 100, 10);
            sWidth.setValuePos(PositionType.Right);
            sWidth.setHexpand(true);
            sWidth.setHalign(Align.Fill);
            bh.bind(SETTINGS_QUAKE_WIDTH_PERCENT_KEY, sWidth.getAdjustment(), "value", SettingsBindFlags.Default);
            grid.attach(sWidth, 1, row, 1, 1);
            row++;

            //Alignment
            grid.attach(createLabel(_("Alignment")), 0, row, 1, 1);
            ComboBox cbAlignment = createNameValueCombo([_("Left"), _("Center"), _("Right")], [SETTINGS_QUAKE_ALIGNMENT_LEFT_VALUE, SETTINGS_QUAKE_ALIGNMENT_CENTER_VALUE, SETTINGS_QUAKE_ALIGNMENT_RIGHT_VALUE]);
            bh.bind(SETTINGS_QUAKE_ALIGNMENT_KEY, cbAlignment, "active-id", SettingsBindFlags.Default);
            grid.attach(cbAlignment, 1, row, 1, 1);
            row++;
        }

        grid.attach(createLabel(_("Tab position")), 0, row, 1, 1);
        ComboBox cbTabPosition = createNameValueCombo([_("Left"), _("Right"), _("Top"), _("Bottom")], SETTINGS_TAB_POSITION_VALUES);
        bh.bind(SETTINGS_QUAKE_TAB_POSITION_KEY, cbTabPosition, "active-id", SettingsBindFlags.Default);
        grid.attach(cbTabPosition, 1, row, 1, 1);
        row++;

        if (!wayland) {
            grid.attach(createLabel(_("Window position")), 0, row, 1, 1);
            ComboBox cbWinPosition = createNameValueCombo([_("Top"), _("Bottom")], SETTINGS_QUAKE_WINDOW_POSITION_VALUES);
            bh.bind(SETTINGS_QUAKE_WINDOW_POSITION_KEY, cbWinPosition, "active-id", SettingsBindFlags.Default);
            grid.attach(cbWinPosition, 1, row, 1, 1);
            row++;
        }

        add(grid);

        Label lblOptions = new Label(format("<b>%s</b>", _("Options")));
        lblOptions.setUseMarkup(true);
        lblOptions.setHalign(Align.Start);
        add(lblOptions);

        Box bContent = new Box(gtk.types.Orientation.Vertical, 6);

        //Show on all workspaces
        CheckButton cbAllWorkspaces = CheckButton.newWithLabel(_("Show terminal on all workspaces"));
        bh.bind(SETTINGS_QUAKE_SHOW_ON_ALL_WORKSPACES_KEY, cbAllWorkspaces, "active", SettingsBindFlags.Default);
        bContent.add(cbAllWorkspaces);

        //Disable animations
        /*
        CheckButton cbDisableAnimations = CheckButton.newWithLabel(_("Set hint for window manager to disable animation"));
        bh.bind(SETTINGS_QUAKE_DISABLE_ANIMATION_KEY, cbDisableAnimations, "active", SettingsBindFlags.Default);
        bContent.add(cbDisableAnimations);
        */

        //Hide window on lose focus, note issue #858
        CheckButton cbHideOnLoseFocus = CheckButton.newWithLabel(_("Hide window when focus is lost"));
        bh.bind(SETTINGS_QUAKE_HIDE_LOSE_FOCUS_KEY, cbHideOnLoseFocus, "active", SettingsBindFlags.Default);
        bContent.add(cbHideOnLoseFocus);

        Label lblDelay = new Label(_("Delay hiding window by (ms)"));
        SpinButton sbDelay = SpinButton.newWithRange(50, 1000, 50);
        bh.bind(SETTINGS_QUAKE_HIDE_LOSE_FOCUS_DELAY_KEY, sbDelay, "value", SettingsBindFlags.Default);
        bh.bind(SETTINGS_QUAKE_HIDE_LOSE_FOCUS_KEY, sbDelay, "sensitive", SettingsBindFlags.Default);
        bh.bind(SETTINGS_QUAKE_HIDE_LOSE_FOCUS_KEY, lblDelay, "sensitive", SettingsBindFlags.Default);

        Box bDelay = new Box(gtk.types.Orientation.Horizontal, 6);
        bDelay.add(lblDelay);
        bDelay.add(sbDelay);
        bDelay.setMarginLeft(48);
        bContent.add(bDelay);

        //Hide headerbar
        CheckButton cbHideHeaderbar = CheckButton.newWithLabel(_("Hide the toolbar of the window"));
        bh.bind(SETTINGS_QUAKE_HIDE_HEADERBAR_KEY, cbHideHeaderbar, "active", SettingsBindFlags.Default);
        bContent.add(cbHideHeaderbar);

        /*
        //Keep window on top
        CheckButton cbKeepOnTop = CheckButton.newWithLabel(_("Always keep window on top"));
        bh.bind(SETTINGS_QUAKE_KEEP_ON_TOP_KEY, cbKeepOnTop, "active", SettingsBindFlags.Default);
        bContent.add(cbKeepOnTop);
        */

        // Wayland doesn't let you put a window on a specific monitor so don't show this
        if (!wayland) {

            //Always on top
            CheckButton cbKeepOnTop = CheckButton.newWithLabel(_("Keep window always on top"));
            bh.bind(SETTINGS_QUAKE_KEEP_ON_TOP_KEY, cbKeepOnTop, "active", SettingsBindFlags.Default);
            bContent.add(cbKeepOnTop);

            //Active Monitor
            CheckButton cbActiveMonitor = CheckButton.newWithLabel(_("Display terminal on active monitor"));
            bh.bind(SETTINGS_QUAKE_ACTIVE_MONITOR_KEY, cbActiveMonitor, "active", SettingsBindFlags.Default);
            bContent.add(cbActiveMonitor);

            //Specific Monitor
            Box bSpecific = new Box(gtk.types.Orientation.Horizontal, 6);
            bSpecific.setMarginLeft(36);
            Label lblSpecific = new Label(_("Display on specific monitor"));
            bh.bind(SETTINGS_QUAKE_ACTIVE_MONITOR_KEY, lblSpecific, "sensitive", SettingsBindFlags.InvertBoolean);
            bSpecific.add(lblSpecific);
            string[] names = [_("Primary Monitor")];
            int[] values = [-1];
            for(int monitor; monitor < Screen.getDefault().getNMonitors(); monitor++) {
                names ~= _("Monitor ") ~ to!string(monitor);
                values ~= monitor;
            }

            ComboBox cbScreen = TComboBox!(int).createComboBox(names, values);
            cbScreen.connectChanged(delegate(ComboBox cb) {
                TreeIter iter;
                if (cb.getActiveIter(iter)) {
                    ListStore ls_ = cast(ListStore)cb.getModel();
                    Value val = new Value();
                    ls_.getValue(iter, 1, val);
                    bh.settings.setInt(SETTINGS_QUAKE_SPECIFIC_MONITOR_KEY, val.getInt());
                } else {
                    bh.settings.setInt(SETTINGS_QUAKE_SPECIFIC_MONITOR_KEY,-1);
                }
            });
            int index = 0;
            foreach(TreeIter iter; TreeIterRange(cbScreen.getModel())) {
                Value val = new Value();
                cbScreen.getModel().getValue(iter, 1, val);
                if (val.getInt() == bh.settings.getInt(SETTINGS_QUAKE_SPECIFIC_MONITOR_KEY)) {
                    cbScreen.setActive(index);
                    break;
                }
                index++;
            }
            //bh.bind(SETTINGS_QUAKE_SPECIFIC_MONITOR_KEY, cbScreen, "active-id", SettingsBindFlags.Default);
            bh.bind(SETTINGS_QUAKE_ACTIVE_MONITOR_KEY, cbScreen, "sensitive", SettingsBindFlags.InvertBoolean);
            bSpecific.add(cbScreen);

            bContent.add(bSpecific);
        }

        add(bContent);
    }

public:

    this(Settings gsSettings, bool wayland) {
        super(gtk.types.Orientation.Vertical, 6);
        bh = new BindingHelper(gsSettings);
        createUI(wayland);
        connectDestroy(delegate() {
            bh.unbind();
            bh = null;
        });
    }
}

/**
 * Global preferences page *
 */
class GlobalPreferences : Box {

private:

    BindingHelper bh;

    void createUI() {
        setMarginTop(18);
        setMarginBottom(18);
        setMarginLeft(18);
        setMarginRight(18);

        Label lblBehavior = new Label(format("<b>%s</b>", _("Behavior")));
        lblBehavior.setUseMarkup(true);
        lblBehavior.setHalign(Align.Start);
        add(lblBehavior);

        //Prompt on new session
        CheckButton cbPrompt = CheckButton.newWithLabel(_("Prompt when creating a new session"));
        bh.bind(SETTINGS_PROMPT_ON_NEW_SESSION_KEY, cbPrompt, "active", SettingsBindFlags.Default);
        add(cbPrompt);

        //Focus follows the mouse
        CheckButton cbFocusMouse = CheckButton.newWithLabel(_("Focus a terminal when the mouse moves over it"));
        bh.bind(SETTINGS_TERMINAL_FOCUS_FOLLOWS_MOUSE_KEY, cbFocusMouse, "active", SettingsBindFlags.Default);
        add(cbFocusMouse);

        //Auto hide the mouse
        CheckButton cbAutoHideMouse = CheckButton.newWithLabel(_("Autohide the mouse pointer when typing"));
        bh.bind(SETTINGS_AUTO_HIDE_MOUSE_KEY, cbAutoHideMouse, "active", SettingsBindFlags.Default);
        add(cbAutoHideMouse);

        //middle click closes the terminal
        CheckButton cbMiddleClickClose = CheckButton.newWithLabel(_("Close terminal by clicking middle mouse button on title"));
        bh.bind(SETTINGS_MIDDLE_CLICK_CLOSE_KEY, cbMiddleClickClose, "active", SettingsBindFlags.Default);
        add(cbMiddleClickClose);

        //zoom in/out terminal with scroll wheel
        CheckButton cbControlScrollZoom = CheckButton.newWithLabel(_("Zoom the terminal using <Control> and scroll wheel"));
        bh.bind(SETTINGS_CONTROL_SCROLL_ZOOM_KEY, cbControlScrollZoom, "active", SettingsBindFlags.Default);
        add(cbControlScrollZoom);

        //require control modifier when clicking title
        CheckButton cbControlClickTitle = CheckButton.newWithLabel(_("Require the <Control> modifier to edit title on click"));
        bh.bind(SETTINGS_CONTROL_CLICK_TITLE_KEY, cbControlClickTitle, "active", SettingsBindFlags.Default);
        add(cbControlClickTitle);

        //Closing of last session closes window
        CheckButton cbCloseWithLastSession = CheckButton.newWithLabel(_("Close window when last session is closed"));
        bh.bind(SETTINGS_CLOSE_WITH_LAST_SESSION_KEY, cbCloseWithLastSession, "active", SettingsBindFlags.Default);
        add(cbCloseWithLastSession);

        // Save window state (maximized, minimized, fullscreen) between invocations
        CheckButton cbWindowSaveState = CheckButton.newWithLabel(_("Save and restore window state"));
        bh.bind(SETTINGS_WINDOW_SAVE_STATE_KEY, cbWindowSaveState, "active", SettingsBindFlags.Default);
        add(cbWindowSaveState);

        //always use regex when searching
        CheckButton cbAlwaysUseRegex = CheckButton.newWithLabel(_("Always search using regular expressions"));
        bh.bind(SETTINGS_ALWAYS_USE_REGEX_IN_SEARCH, cbAlwaysUseRegex, "active", SettingsBindFlags.Default);
        add(cbAlwaysUseRegex);

        //Show Notifications, only show option if notifications are supported
        if (checkVTEFeature(TerminalFeature.EVENT_NOTIFICATION)) {
            CheckButton cbNotify = CheckButton.newWithLabel(_("Send desktop notification on process complete"));
            bh.bind(SETTINGS_NOTIFY_ON_PROCESS_COMPLETE_KEY, cbNotify, "active", SettingsBindFlags.Default);
            add(cbNotify);
        }

        //New Instance Options
        Box bNewInstance = new Box(gtk.types.Orientation.Horizontal, 6);

        Label lblNewInstance = new Label(_("On new instance"));
        lblNewInstance.setHalign(Align.End);
        bNewInstance.add(lblNewInstance);
        ComboBox cbNewInstance = createNameValueCombo([_("New Window"), _("New Session"), _("Split Right"), _("Split Down"), _("Focus Window")], SETTINGS_NEW_INSTANCE_MODE_VALUES);
        bh.bind(SETTINGS_NEW_INSTANCE_MODE_KEY, cbNewInstance, "active-id", SettingsBindFlags.Default);
        bNewInstance.add(cbNewInstance);
        add(bNewInstance);

        // *********** Clipboard Options
        Label lblClipboard = new Label(format("<b>%s</b>", _("Clipboard")));
        lblClipboard.setUseMarkup(true);
        lblClipboard.setHalign(Align.Start);
        add(lblClipboard);

        //Advacned paste is default
        CheckButton cbAdvDefault = CheckButton.newWithLabel(_("Always use advanced paste dialog"));
        bh.bind(SETTINGS_PASTE_ADVANCED_DEFAULT_KEY, cbAdvDefault, "active", SettingsBindFlags.Default);
        add(cbAdvDefault);

        //Unsafe Paste Warning
        CheckButton cbUnsafe = CheckButton.newWithLabel(_("Warn when attempting unsafe paste"));
        bh.bind(SETTINGS_UNSAFE_PASTE_ALERT_KEY, cbUnsafe, "active", SettingsBindFlags.Default);
        add(cbUnsafe);

        //Strip Paste
        CheckButton cbStrip = CheckButton.newWithLabel(_("Strip first character of paste if comment or variable declaration"));
        bh.bind(SETTINGS_STRIP_FIRST_COMMENT_CHAR_ON_PASTE_KEY, cbStrip, "active", SettingsBindFlags.Default);
        add(cbStrip);

        //Strip trailing whitespace on paste
        CheckButton cbStripTrailing = CheckButton.newWithLabel(_("Strip trailing whitespaces and linebreak characters on paste"));
        bh.bind(SETTINGS_STRIP_TRAILING_WHITESPACE, cbStripTrailing, "active", SettingsBindFlags.Default);
        add(cbStripTrailing);

        //Copy on Select
        CheckButton cbCopyOnSelect = CheckButton.newWithLabel(_("Automatically copy text to clipboard when selecting"));
        bh.bind(SETTINGS_COPY_ON_SELECT_KEY, cbCopyOnSelect, "active", SettingsBindFlags.Default);
        add(cbCopyOnSelect);
    }

public:

    this(Settings gsSettings) {
        super(gtk.types.Orientation.Vertical, 6);
        bh = new BindingHelper(gsSettings);
        createUI();
        connectDestroy(delegate() {
            bh.unbind();
            bh = null;
        });
    }
}

/**
 * Global preferences page *
 */
class AdvancedPreferences : Box {
private:
    Settings gsSettings;

    void createUI() {
        setAllMargins(this, 18);
        Grid grid = new Grid();
        grid.setHalign(Align.Fill);
        grid.setColumnSpacing(12);
        grid.setRowSpacing(6);

        uint row = 0;
        createAdvancedUI(grid, row, &getSettings);

        this.add(grid);
    }

    Settings getSettings() {
        return gsSettings;
    }

public:

    this(Settings gsSettings) {
        super(gtk.types.Orientation.Vertical, 6);
        this.gsSettings = gsSettings;
        createUI();
    }

}

// Function to create a right aligned label with appropriate margins
private Label createLabel(string text) {
    Label label = new Label(text);
    label.setHalign(Align.End);
    //label.setMarginLeft(12);
    return label;
}
