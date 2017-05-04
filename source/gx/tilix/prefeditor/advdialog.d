/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.prefeditor.advdialog;

import std.conv;
import std.csv;
import std.experimental.logger;
import std.format;
import std.typecons;

import gio.Settings: GSettings = Settings;

import glib.GException;
import glib.Regex: GRegex = Regex;

import gtk.Box;
import gtk.Button;
import gtk.CellRendererCombo;
import gtk.CellRendererText;
import gtk.CellRendererToggle;
import gtk.CheckButton;
import gtk.Dialog;
import gtk.Label;
import gtk.ListStore;
import gtk.ScrolledWindow;
import gtk.SpinButton;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Window;

import gx.i18n.l10n;
import gx.gtk.util;
import gx.util.string;

import gx.tilix.preferences;

/**
 * Dialog for editing custom hyperlinks
 */
class EditCustomLinksDialog: Dialog {

private:
    enum COLUMN_REGEX = 0;
    enum COLUMN_CMD = 1;
    enum COLUMN_CASE = 2;

    TreeView tv;
    ListStore ls;
    Button btnDelete;

    Label lblErrors;

    void createUI(string[] links) {

        setAllMargins(getContentArea(), 18);
        Box box = new Box(Orientation.HORIZONTAL, 6);

        ls = new ListStore([GType.STRING, GType.STRING, GType.BOOLEAN]);
        foreach(link; links) {
            foreach(value; csvReader!(Tuple!(string, string, string))(link)) {
                TreeIter iter = ls.createIter();
                ls.setValue(iter, COLUMN_REGEX, value[0]);
                ls.setValue(iter, COLUMN_CMD, value[1]);
                try {
                    ls.setValue(iter, COLUMN_CASE, to!bool(value[2]));
                } catch (Exception e) {
                    ls.setValue(iter, COLUMN_CASE, false);
                }
            }
        }

        tv = new TreeView(ls);
        tv.setActivateOnSingleClick(false);
        tv.addOnCursorChanged(delegate(TreeView) {
            updateUI();
        });
        tv.setHeadersVisible(true);

        //Regex column
        CellRendererText crtRegex = new CellRendererText();
        crtRegex.setProperty("editable", 1);
        crtRegex.addOnEdited(delegate(string path, string newText, CellRendererText) {
            TreeIter iter = new TreeIter();
            ls.getIter(iter, new TreePath(path));
            ls.setValue(iter, COLUMN_REGEX, newText);
            updateUI();
        });
        TreeViewColumn column = new TreeViewColumn(_("Regex"), crtRegex, "text", COLUMN_REGEX);
        column.setMinWidth(200);
        tv.appendColumn(column);

        //Command column
        CellRendererText crtCommand = new CellRendererText();
        crtCommand.setProperty("editable", 1);
        crtCommand.addOnEdited(delegate(string path, string newText, CellRendererText) {
            TreeIter iter = new TreeIter();
            ls.getIter(iter, new TreePath(path));
            ls.setValue(iter, COLUMN_CMD, newText);
        });
        column = new TreeViewColumn(_("Command"), crtCommand, "text", COLUMN_CMD);
        column.setMinWidth(200);
        tv.appendColumn(column);

        //Case Insensitive Column
        CellRendererToggle crtCase = new CellRendererToggle();
        crtCase.setActivatable(true);
        crtCase.addOnToggled(delegate(string path, CellRendererToggle crt) {
            TreeIter iter = new TreeIter();
            ls.getIter(iter, new TreePath(path));
            ls.setValue(iter, COLUMN_CASE, !crt.getActive());
        });
        column = new TreeViewColumn(_("Case Insensitive"), crtCase, "active", COLUMN_CASE);
        tv.appendColumn(column);

        ScrolledWindow sc = new ScrolledWindow(tv);
        sc.setShadowType(ShadowType.ETCHED_IN);
        sc.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sc.setHexpand(true);
        sc.setVexpand(true);
        sc.setSizeRequest(-1, 250);

        box.add(sc);

        Box buttons = new Box(Orientation.VERTICAL, 6);
        Button btnAdd = new Button(_("Add"));
        btnAdd.addOnClicked(delegate(Button) {
            ls.createIter();
            selectRow(tv, ls.iterNChildren(null) - 1, null);
        });
        buttons.add(btnAdd);
        btnDelete = new Button(_("Delete"));
        btnDelete.addOnClicked(delegate(Button) {
            TreeIter selected = tv.getSelectedIter();
            if (selected) {
                ls.remove(selected);
            }
        });
        buttons.add(btnDelete);

        box.add(buttons);

        getContentArea().add(box);

        lblErrors = createErrorLabel();
        getContentArea().add(lblErrors);

        updateUI();
    }

    void updateUI() {
        btnDelete.setSensitive(tv.getSelectedIter() !is null);
        setResponseSensitive(GtkResponseType.APPLY, validateRegex(ls, COLUMN_REGEX, lblErrors));
    }

public:
    this(Window parent, string[] links) {
        super(_("Edit Custom Links"), parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("Apply"), _("Cancel")], [GtkResponseType.APPLY, GtkResponseType.CANCEL]);
        setDefaultResponse(GtkResponseType.APPLY);
        createUI(links);
    }

    string[] getLinks() {
        string[] results;
        foreach (TreeIter iter; TreeIterRange(ls)) {
            string regex = ls.getValueString(iter, COLUMN_REGEX);
            if (regex.length == 0) continue;
            results ~= escapeCSV(regex) ~ ',' ~
                       escapeCSV(ls.getValueString(iter, COLUMN_CMD)) ~ ',' ~
                       to!string(ls.getValue(iter, COLUMN_CASE).getBoolean());
        }
        return results;
    }
}

/**
 * Dialog for editing triggers
 */
class EditTriggersDialog: Dialog {

private:
    enum COLUMN_REGEX = 0;
    enum COLUMN_ACTION = 1;
    enum COLUMN_PARAMETERS = 2;

    TreeView tv;
    ListStore ls;
    ListStore lsActions;
    Button btnDelete;

    Label lblErrors;

    string[string] localizedActions;

    void createUI(GSettings gs, bool showLineSettings) {

        string[] triggers = gs.getStrv(SETTINGS_ALL_TRIGGERS_KEY);

        setAllMargins(getContentArea(), 18);
        Box box = new Box(Orientation.HORIZONTAL, 6);

        ls = new ListStore([GType.STRING, GType.STRING, GType.STRING]);
        foreach(trigger; triggers) {
            foreach(value; csvReader!(Tuple!(string, string, string))(trigger)) {
                TreeIter iter = ls.createIter();
                ls.setValue(iter, COLUMN_REGEX, value[0]);
                ls.setValue(iter, COLUMN_ACTION, _(value[1]));
                ls.setValue(iter, COLUMN_PARAMETERS, value[2]);
            }
        }

        tv = new TreeView(ls);
        tv.setActivateOnSingleClick(false);
        tv.addOnCursorChanged(delegate(TreeView) {
            updateUI();
        });
        tv.setHeadersVisible(true);
        //Regex column
        CellRendererText crtRegex = new CellRendererText();
        crtRegex.setProperty("editable", 1);
        crtRegex.addOnEdited(delegate(string path, string newText, CellRendererText) {
            TreeIter iter = new TreeIter();
            ls.getIter(iter, new TreePath(path));
            ls.setValue(iter, COLUMN_REGEX, newText);
            updateUI();
        });
        TreeViewColumn column = new TreeViewColumn(_("Regex"), crtRegex, "text", COLUMN_REGEX);
        column.setMinWidth(200);
        tv.appendColumn(column);

        //Action Column
        CellRendererCombo crtAction = new CellRendererCombo();
        ListStore lsActions = new ListStore([GType.STRING]);
        foreach(value; SETTINGS_PROFILE_TRIGGER_ACTION_VALUES) {
            TreeIter iter = lsActions.createIter();
            lsActions.setValue(iter, 0, _(value));
            localizedActions[_(value)] = value;
        }
        import gtkc.gobject: g_object_set;
        import glib.Str: Str;
        g_object_set(crtAction.getCellRendererComboStruct, Str.toStringz("model"), lsActions.getListStoreStruct(), null);
        crtAction.setProperty("editable", 1);
        crtAction.setProperty("has-entry", 0);
        crtAction.setProperty("text-column", 0);
        crtAction.addOnChanged(delegate(string path, TreeIter actionIter, CellRendererCombo) {
            TreeIter iter = new TreeIter();
            ls.getIter(iter, new TreePath(path));
            string action = lsActions.getValueString(actionIter, 0);
            if (iter !is null) {
                ls.setValue(iter, COLUMN_ACTION, action);
            }
        });
        column = new TreeViewColumn(_("Action"), crtAction, "text", COLUMN_ACTION);
        column.setMinWidth(150);
        tv.appendColumn(column);

        //Parameter column
        CellRendererText crtParameter = new CellRendererText();
        crtParameter.setProperty("editable", 1);
        crtParameter.addOnEdited(delegate(string path, string newText, CellRendererText) {
            TreeIter iter = new TreeIter();
            ls.getIter(iter, new TreePath(path));
            ls.setValue(iter, COLUMN_PARAMETERS, newText);
        });
        column = new TreeViewColumn(_("Parameter"), crtParameter, "text", COLUMN_PARAMETERS);
        column.setMinWidth(200);
        tv.appendColumn(column);

        ScrolledWindow sc = new ScrolledWindow(tv);
        sc.setShadowType(ShadowType.ETCHED_IN);
        sc.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sc.setHexpand(true);
        sc.setVexpand(true);
        sc.setSizeRequest(-1, 250);

        box.add(sc);

        Box buttons = new Box(Orientation.VERTICAL, 6);
        Button btnAdd = new Button(_("Add"));
        btnAdd.addOnClicked(delegate(Button) {
            ls.createIter();
            selectRow(tv, ls.iterNChildren(null) - 1, null);
        });
        buttons.add(btnAdd);
        btnDelete = new Button(_("Delete"));
        btnDelete.addOnClicked(delegate(Button) {
            TreeIter selected = tv.getSelectedIter();
            if (selected) {
                ls.remove(selected);
            }
        });
        buttons.add(btnDelete);

        box.add(buttons);
        getContentArea().add(box);

        if (showLineSettings) {
            // Maximum number of lines to check for triggers when content change is
            // received from VTE with a block of text
            Box bLines = new Box(Orientation.HORIZONTAL, 6);
            bLines.setMarginTop(6);

            CheckButton cbTriggerLimit = new CheckButton(_("Limit number of lines for trigger processing to:"));
            gs.bind(SETTINGS_TRIGGERS_UNLIMITED_LINES_KEY, cbTriggerLimit, "active", GSettingsBindFlags.DEFAULT | GSettingsBindFlags.INVERT_BOOLEAN);

            SpinButton sbLines = new SpinButton(256.0, double.max, 256.0);
            gs.bind(SETTINGS_TRIGGERS_LINES_KEY, sbLines, "value", GSettingsBindFlags.DEFAULT);
            gs.bind(SETTINGS_TRIGGERS_UNLIMITED_LINES_KEY, sbLines, "sensitive",
                    GSettingsBindFlags.GET | GSettingsBindFlags.NO_SENSITIVITY | GSettingsBindFlags.INVERT_BOOLEAN);

            bLines.add(cbTriggerLimit);
            bLines.add(sbLines);

            getContentArea().add(bLines);
        }
        lblErrors = createErrorLabel();
        getContentArea().add(lblErrors);
        updateUI();
    }

    void updateUI() {
        btnDelete.setSensitive(tv.getSelectedIter() !is null);
        setResponseSensitive(GtkResponseType.APPLY, validateRegex(ls, COLUMN_REGEX, lblErrors));
    }

public:
    this(Window parent, GSettings gs, bool showLineSettings = false) {
        super(_("Edit Triggers"), parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("Apply"), _("Cancel")], [GtkResponseType.APPLY, GtkResponseType.CANCEL]);
        setDefaultResponse(GtkResponseType.APPLY);
        createUI(gs, showLineSettings);
    }

    string[] getTriggers() {
        string[] results;
        foreach (TreeIter iter; TreeIterRange(ls)) {
            string regex = ls.getValueString(iter, COLUMN_REGEX);
            if (regex.length == 0) continue;
            results ~= escapeCSV(regex) ~ ',' ~
                       escapeCSV(localizedActions[ls.getValueString(iter, COLUMN_ACTION)]) ~ ',' ~
                       escapeCSV(ls.getValueString(iter, COLUMN_PARAMETERS));
        }
        return results;
    }
}

private:

Label createErrorLabel() {
    Label lblErrors = new Label("");
    lblErrors.setHalign(Align.START);
    lblErrors.setMarginTop(12);
    lblErrors.getStyleContext().addClass("tilix-error");
    lblErrors.setNoShowAll(true);

    return lblErrors;
}

bool validateRegex(ListStore ls, int regexColumn, Label lblErrors) {
    bool valid = true;
    string errors;
    int index = 0;
    foreach (TreeIter iter; TreeIterRange(ls)) {
        index++;
        try {
            string regex = ls.getValueString(iter, regexColumn);
            if (regex.length > 0) {
                GRegex check = new GRegex(regex, GRegexCompileFlags.OPTIMIZE, cast(GRegexMatchFlags) 0);
            }
        } catch (GException ge) {
            if (errors.length > 0) errors ~= "\n";
            errors ~= format(_("Row %d: "), index) ~ ge.msg;
            valid = false;
        }
    }
    if (errors.length == 0) {
        lblErrors.hide();
    } else {
        lblErrors.setText(errors);
        lblErrors.show();
    }
    return valid;
}