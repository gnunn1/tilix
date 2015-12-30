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

import gobject.Value;

import gtk.AccelGroup;
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Box;
import gtk.Button;
import gtk.CellRendererAccel;
import gtk.CellRendererText;
import gtk.CellRendererToggle;
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

import gx.gtk.actions;
import gx.gtk.util;

import gx.i18n.l10n;

import gx.terminix.preferences;
import gx.terminix.profilewindow;
import gx.util.array;

class PreferenceWindow : ApplicationWindow {

private:
	Notebook nb;

	void createUI() {
		HeaderBar hb = new HeaderBar();
		hb.setShowCloseButton(true);
		hb.setTitle(_("Preferences"));
		this.setTitlebar(hb);

		nb = new Notebook();
		nb.setHexpand(true);
		nb.setVexpand(true);

		GlobalPreferences gp = new GlobalPreferences();
		nb.appendPage(gp, _("Global"));

		ShortcutPreferences sp = new ShortcutPreferences();
		nb.appendPage(sp, _("Shortcuts"));

		ProfilePreferences pp = new ProfilePreferences(getApplication());
		nb.appendPage(pp, _("Profiles"));

		add(nb);
	}

public:
	this(Application app) {
		super(app);
		createUI();
	}
}

/**
 * Shortcuts preferences page
 */
 
class ShortcutPreferences: Box {

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
        craShortcut.setProperty( "editable", 1 );
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
        foreach(key; keys) {
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
			foreach (TreeIter iter;
			TreeIterRange(lsProfiles)) {
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

	void createUI() {
		//Set basic grid settings
		setColumnSpacing(12);
		setRowSpacing(6);
		setMarginTop(18);
		setMarginBottom(18);
		setMarginLeft(18);
		setMarginRight(18);

		Settings settings = new Settings(SETTINGS_ID);

		int row = 0;
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

		settings.bind(SETTINGS_THEME_VARIANT_KEY, cbThemeVariant, "active-id", GSettingsBindFlags.DEFAULT);

		attach(cbThemeVariant, 1, row, 1, 1);
		row++;
	}

public:

	this() {
		super();
		createUI();
	}
}

// Function to create a right aligned label with appropriate margins
private Label createLabel(string text) {
	Label label = new Label(text);
	label.setHalign(GtkAlign.END);
	//label.setMarginLeft(12);
	return label;
}
