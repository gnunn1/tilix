/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.prefeditor.advdialog;

import std.conv;
import std.csv;
import std.experimental.logger;
import std.format;
import std.string;
import std.typecons;

import gio.settings: Settings = Settings;
import gio.types;

import glib.error;
import glib.regex: Regex = Regex;
import glib.types;

import gobject.types;
import gobject.value;

import gtk.box;
import gtk.types;
import gtk.button;
import gtk.types;
import gtk.cell_renderer_combo;
import gtk.types;
import gtk.cell_renderer_text;
import gtk.types;
import gtk.cell_renderer_toggle;
import gtk.types;
import gtk.check_button;
import gtk.types;
import gtk.dialog;
import gtk.types;
import gtk.header_bar;
import gtk.types;
import gtk.image;
import gtk.label;
import gtk.types;
import gtk.list_store;
import gtk.tree_model;
import gtk.types;
import gtk.scrolled_window;
import gtk.types;
import gtk.spin_button;
import gtk.types;
import gtk.tree_iter;
import gtk.types;
import gtk.tree_path;
import gtk.types;
import gtk.tree_view;
import gtk.types;
import gtk.tree_view_column;
import gtk.types;
import gtk.window;
import gtk.types;

import pango.types;

import gx.gtk.keys;
import gx.gtk.types;
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
    Button btnMoveUp;
    Button btnMoveDown;

    Label lblErrors;

    TreeIter getSelectedIter() {
        TreeIter iter;
        TreeModel model;
        if (tv.getSelection().getSelected(model, iter)) {
            return iter;
        }
        return null;
    }

    string getValueString(TreeModel model, TreeIter iter, uint column) {
        Value val = new Value();
        model.getValue(iter, cast(int)column, val);
        return val.getString();
    }

    void createUI(string[] links) {

        setAllMargins(getContentArea(), 18);
        Box box = new Box(gtk.types.Orientation.Vertical, 6);

        ls = ListStore.new_([cast(GType)GTypeEnum.String, cast(GType)GTypeEnum.String, cast(GType)GTypeEnum.Boolean]);
        foreach(link; links) {
            foreach(value; csvReader!(Tuple!(string, string, string))(link)) {
                TreeIter iter;
                ls.append(iter);
                ls.setValue(iter, COLUMN_REGEX, new Value(value[0]));
                ls.setValue(iter, COLUMN_CMD, new Value(value[1]));
                try {
                    ls.setValue(iter, COLUMN_CASE, new Value(to!bool(value[2])));
                } catch (Exception e) {
                    ls.setValue(iter, COLUMN_CASE, new Value(false));
                }
            }
        }

        tv = new TreeView();
        tv.setModel(ls);
        tv.setActivateOnSingleClick(false);
        tv.connectCursorChanged(delegate(TreeView tv) {
            updateUI();
        });
        tv.setHeadersVisible(true);

        //Regex column
        CellRendererText crtRegex = new CellRendererText();
        crtRegex.setProperty("editable", new Value(1));
        crtRegex.connectEdited(delegate(string path, string newText, CellRendererText crt) {
            TreeIter iter;
            ls.getIter(iter, TreePath.newFromString(path));
            ls.setValue(iter, COLUMN_REGEX, new Value(newText));
            updateUI();
        });
        TreeViewColumn column = new TreeViewColumn();
        column.setTitle(_("Regex"));
        column.packStart(crtRegex, true);
        column.addAttribute(crtRegex, "text", COLUMN_REGEX);
        column.setMinWidth(200);
        tv.appendColumn(column);

        //Command column
        CellRendererText crtCommand = new CellRendererText();
        crtCommand.setProperty("editable", new Value(1));
        crtCommand.connectEdited(delegate(string path, string newText, CellRendererText crt) {
            TreeIter iter;
            ls.getIter(iter, TreePath.newFromString(path));
            ls.setValue(iter, COLUMN_CMD, new Value(newText));
        });
        column = new TreeViewColumn();
        column.setTitle(_("Command"));
        column.packStart(crtCommand, true);
        column.addAttribute(crtCommand, "text", COLUMN_CMD);
        column.setMinWidth(200);
        tv.appendColumn(column);

        //Case Insensitive Column
        CellRendererToggle crtCase = new CellRendererToggle();
        crtCase.setActivatable(true);
        crtCase.connectToggled(delegate(string path, CellRendererToggle crt) {
            TreeIter iter;
            ls.getIter(iter, TreePath.newFromString(path));
            ls.setValue(iter, COLUMN_CASE, new Value(!crt.getActive()));
        });
        column = new TreeViewColumn();
        column.setTitle(_("Case Insensitive"));
        column.packStart(crtCase, true);
        column.addAttribute(crtCase, "active", COLUMN_CASE);
        tv.appendColumn(column);

        ScrolledWindow sc = new ScrolledWindow();
        sc.add(tv);
        sc.setShadowType(ShadowType.EtchedIn);
        sc.setPolicy(PolicyType.Never, PolicyType.Automatic);
        sc.setHexpand(true);
        sc.setVexpand(true);
        sc.setSizeRequest(-1, 250);

        box.add(sc);

        Box buttons = new Box(gtk.types.Orientation.Horizontal, 0);
        buttons.getStyleContext().addClass("linked");

        Button btnAdd = new Button();
        btnAdd.setImage(Image.newFromIconName("list-add-symbolic", IconSize.Button));
        btnAdd.setTooltipText(_("Add"));
        btnAdd.connectClicked(delegate(Button b) {
            TreeIter iter;
            ls.append(iter);
            selectRow(tv, ls.iterNChildren(null) - 1, null);
        });
        buttons.add(btnAdd);
        btnDelete = new Button();
        btnDelete.setImage(Image.newFromIconName("list-remove-symbolic", IconSize.Button));
        btnDelete.setTooltipText(_("Delete"));
        btnDelete.connectClicked(delegate(Button b) {
            TreeIter selected = getSelectedIter();
            if (selected !is null) {
                ls.remove(selected);
            }
        });
        buttons.add(btnDelete);

        btnMoveUp = new Button();
        btnMoveUp.setImage(Image.newFromIconName("pan-up-symbolic", IconSize.Button));
        btnMoveUp.setTooltipText(_("Move up"));
        btnMoveUp.connectClicked(delegate(Button b) {
            TreeIter selected = getSelectedIter();
            if (selected !is null) {
                TreeIter previous = new TreeIter(cast(void*)selected._cPtr, No.Take);
                if (ls.iterPrevious(previous)) ls.swap(selected, previous);
            }
        });
        buttons.add(btnMoveUp);

        btnMoveDown = new Button();
        btnMoveDown.setImage(Image.newFromIconName("pan-down-symbolic", IconSize.Button));
        btnMoveDown.setTooltipText(_("Move down"));
        btnMoveDown.connectClicked(delegate(Button b) {
            TreeIter selected = getSelectedIter();
            if (selected !is null) {
                TreeIter next = new TreeIter(cast(void*)selected._cPtr, No.Take);
                if (ls.iterNext(next)) ls.swap(selected, next);
            }
        });
        buttons.add(btnMoveDown);

        box.add(buttons);

        getContentArea().add(box);

        lblErrors = createErrorLabel();
        getContentArea().add(lblErrors);

        updateUI();
    }

    void updateUI() {
        TreeIter selected = getSelectedIter();
        btnDelete.setSensitive(selected !is null);
        btnMoveUp.setSensitive(selected !is null && ls.getPath(selected).getIndices()[0] > 0);
        btnMoveDown.setSensitive(selected !is null && ls.getPath(selected).getIndices()[0] < ls.iterNChildren(null) - 1);
        setResponseSensitive(gtk.types.ResponseType.Apply, validateRegex(ls, COLUMN_REGEX, lblErrors));
    }

public:
    this(Window parent, string[] links) {
        super();
        setTitle(_("Edit Custom Links"));
        setTransientFor(parent);
        setModal(true);
        addButton(_("Apply"), gtk.types.ResponseType.Apply);
        addButton(_("Cancel"), gtk.types.ResponseType.Cancel);
        setDefaultResponse(gtk.types.ResponseType.Apply);
        createUI(links);
    }

    string[] getLinks() {
        string[] results;
        foreach (TreeIter iter; TreeIterRange(ls)) {
            string regex = getValueString(ls, iter, COLUMN_REGEX);
            if (regex.length == 0) continue;
            Value val = new Value();
            ls.getValue(iter, COLUMN_CASE, val);
            results ~= escapeCSV(regex) ~ ',' ~
                       escapeCSV(getValueString(ls, iter, COLUMN_CMD)) ~ ',' ~
                       to!string(val.getBoolean());
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

    TreeIter getSelectedIter() {
        TreeIter iter;
        TreeModel model;
        if (tv.getSelection().getSelected(model, iter)) {
            return iter;
        }
        return null;
    }

    string getValueString(TreeModel model, TreeIter iter, uint column) {
        Value val = new Value();
        model.getValue(iter, cast(int)column, val);
        return val.getString();
    }

    void createUI(Settings gs, bool showLineSettings) {

        string[] triggers = gs.getStrv(SETTINGS_ALL_TRIGGERS_KEY);

        setAllMargins(getContentArea(), 18);
        Box box = new Box(gtk.types.Orientation.Horizontal, 6);

        ls = ListStore.new_([cast(GType)GTypeEnum.String, cast(GType)GTypeEnum.String, cast(GType)GTypeEnum.String]);
        foreach(trigger; triggers) {
            foreach(value; csvReader!(Tuple!(string, string, string))(trigger)) {
                TreeIter iter;
                ls.append(iter);
                ls.setValue(iter, COLUMN_REGEX, new Value(value[0]));
                ls.setValue(iter, COLUMN_ACTION, new Value(_(value[1])));
                ls.setValue(iter, COLUMN_PARAMETERS, new Value(value[2]));
            }
        }

        tv = new TreeView();
        tv.setModel(ls);
        tv.setActivateOnSingleClick(false);
        tv.connectCursorChanged(delegate(TreeView tv) {
            updateUI();
        });
        tv.setHeadersVisible(true);
        //Regex column
        CellRendererText crtRegex = new CellRendererText();
        crtRegex.setProperty("editable", new Value(1));
        crtRegex.connectEdited(delegate(string path, string newText, CellRendererText crt) {
            TreeIter iter;
            ls.getIter(iter, TreePath.newFromString(path));
            ls.setValue(iter, COLUMN_REGEX, new Value(newText));
            updateUI();
        });
        TreeViewColumn column = new TreeViewColumn();
        column.setTitle(_("Regex"));
        column.packStart(crtRegex, true);
        column.addAttribute(crtRegex, "text", COLUMN_REGEX);
        column.setMinWidth(200);
        tv.appendColumn(column);

        //Action Column
        CellRendererCombo crtAction = new CellRendererCombo();
        ListStore lsActions = ListStore.new_([cast(GType)GTypeEnum.String]);
        foreach(value; SETTINGS_PROFILE_TRIGGER_ACTION_VALUES) {
            TreeIter iter;
            lsActions.append(iter);
            lsActions.setValue(iter, 0, new Value(_(value)));
            localizedActions[_(value)] = value;
        }
        import gobject.c.types: GObject;
        import gobject.c.functions: g_object_set;
        g_object_set(cast(GObject*)crtAction._cPtr(), toStringz("model"), lsActions._cPtr(), null);
        crtAction.setProperty("editable", new Value(1));
        crtAction.setProperty("has-entry", new Value(0));
        crtAction.setProperty("text-column", new Value(0));
        crtAction.connectChanged(delegate(string path, TreeIter actionIter, CellRendererCombo crt) {
            TreeIter iter;
            ls.getIter(iter, TreePath.newFromString(path));
            string action = getValueString(lsActions, actionIter, 0);
            if (iter !is null) {
                ls.setValue(iter, COLUMN_ACTION, new Value(action));
            }
        });
        column = new TreeViewColumn();
        column.setTitle(_("Action"));
        column.packStart(crtAction, true);
        column.addAttribute(crtAction, "text", COLUMN_ACTION);
        column.setMinWidth(150);
        tv.appendColumn(column);

        //Parameter column
        CellRendererText crtParameter = new CellRendererText();
        crtParameter.setProperty("editable", new Value(1));
        crtParameter.connectEdited(delegate(string path, string newText, CellRendererText crt) {
            TreeIter iter;
            ls.getIter(iter, TreePath.newFromString(path));
            ls.setValue(iter, COLUMN_PARAMETERS, new Value(newText));
        });
        column = new TreeViewColumn();
        column.setTitle(_("Parameter"));
        column.packStart(crtParameter, true);
        column.addAttribute(crtParameter, "text", COLUMN_PARAMETERS);
        column.setMinWidth(200);
        tv.appendColumn(column);

        ScrolledWindow sc = new ScrolledWindow();
        sc.add(tv);
        sc.setShadowType(ShadowType.EtchedIn);
        sc.setPolicy(PolicyType.Never, PolicyType.Automatic);
        sc.setHexpand(true);
        sc.setVexpand(true);
        sc.setSizeRequest(-1, 250);

        box.add(sc);

        Box buttons = new Box(gtk.types.Orientation.Vertical, 6);
        Button btnAdd = Button.newWithLabel(_("Add"));
        btnAdd.connectClicked(delegate(Button b) {
            TreeIter iter;
            ls.append(iter);
            selectRow(tv, ls.iterNChildren(null) - 1, null);
        });
        buttons.add(btnAdd);
        btnDelete = Button.newWithLabel(_("Delete"));
        btnDelete.connectClicked(delegate(Button b) {
            TreeIter selected = getSelectedIter();
            if (selected !is null) {
                ls.remove(selected);
            }
        });
        buttons.add(btnDelete);

        box.add(buttons);
        (cast(Box)getContentArea()).add(box);

        if (showLineSettings) {
            // Maximum number of lines to check for triggers when content change is
            // received from VTE with a block of text
            Box bLines = new Box(gtk.types.Orientation.Horizontal, 6);
            bLines.setMarginTop(6);

            CheckButton cbTriggerLimit = CheckButton.newWithLabel(_("Limit number of lines for trigger processing to:"));
            gs.bind(SETTINGS_TRIGGERS_UNLIMITED_LINES_KEY, cbTriggerLimit, "active", SettingsBindFlags.Default | SettingsBindFlags.InvertBoolean);

            SpinButton sbLines = SpinButton.newWithRange(256.0, double.max, 256.0);
            gs.bind(SETTINGS_TRIGGERS_LINES_KEY, sbLines, "value", SettingsBindFlags.Default);
            gs.bind(SETTINGS_TRIGGERS_UNLIMITED_LINES_KEY, sbLines, "sensitive",
                    SettingsBindFlags.Get | SettingsBindFlags.NoSensitivity | SettingsBindFlags.InvertBoolean);

            bLines.add(cbTriggerLimit);
            bLines.add(sbLines);

            (cast(Box)getContentArea()).add(bLines);
        }
        lblErrors = createErrorLabel();
        (cast(Box)getContentArea()).add(lblErrors);
        updateUI();
    }

    void updateUI() {
        btnDelete.setSensitive(getSelectedIter() !is null);
        setResponseSensitive(gtk.types.ResponseType.Apply, validateRegex(ls, COLUMN_REGEX, lblErrors));
    }

public:
    this(Window parent, Settings gs, bool showLineSettings = false) {
        super();
        setTitle(_("Edit Triggers"));
        setTransientFor(parent);
        setModal(true);
        addButton(_("Apply"), gtk.types.ResponseType.Apply);
        addButton(_("Cancel"), gtk.types.ResponseType.Cancel);
        setDefaultResponse(gtk.types.ResponseType.Apply);
        createUI(gs, showLineSettings);
    }

    string[] getTriggers() {
        string[] results;
        foreach (TreeIter iter; TreeIterRange(ls)) {
            string regex = getValueString(ls, iter, COLUMN_REGEX);
            if (regex.length == 0) continue;
            results ~= escapeCSV(regex) ~ ',' ~
                       escapeCSV(localizedActions[getValueString(ls, iter, COLUMN_ACTION)]) ~ ',' ~
                       escapeCSV(getValueString(ls, iter, COLUMN_PARAMETERS));
        }
        return results;
    }
}

private:

Label createErrorLabel() {
    Label lblErrors = new Label("");
    lblErrors.setHalign(Align.Start);
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
            Value val = new Value();
            ls.getValue(iter, regexColumn, val);
            string regex = val.getString();
            if (regex.length > 0) {
                Regex check = new Regex(regex, RegexCompileFlags.Optimize, cast(RegexMatchFlags) 0);
            }
        } catch (ErrorWrap ge) {
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