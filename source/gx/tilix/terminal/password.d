/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

 module gx.tilix.terminal.password;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.process;
import std.string;
import std.uuid;

import gdk.event;
import gdk.event_key;
import gdk.types;
import gx.gtk.keys;
import gx.gtk.types;

import gobject.object;
import gobject.types;
import gobject.value;
import gobject.global;

import gio.cancellable;
import gio.settings: Settings=Settings;
import gio.async_result;

import glib.error;
import glib.types;
import glib.global;

import gtk.box;
import gtk.types;
import gtk.button;
import gtk.types;
import gtk.cell_renderer_text;
import gtk.types;
import gtk.check_button;
import gtk.types;
import gtk.dialog;
import gtk.types;
import gtk.editable;
import gtk.types;
import gtk.entry;
import gtk.types;
import gtk.grid;
import gtk.types;
import gtk.label;
import gtk.types;
import gtk.list_store;
import gtk.types;
import gtk.tree_model;
import gtk.tree_iter;
import gtk.types;
import gtk.tree_path;
import gtk.types;
import gtk.tree_view;
import gtk.types;
import gtk.tree_view_column;
import gtk.types;
import gtk.scrolled_window;
import gtk.types;
import gtk.search_entry;
import gtk.types;
import gtk.widget;
import gtk.types;
import gtk.window;
import gtk.types;

import secret.global;
import secret.collection;
import secret.item;
import secret.schema : Schema;
import secret.service;
import secret.value : SecretValue = Value;
import secret.types;
import secret.c.types;

import gx.gtk.util;
import gx.i18n.l10n;

import gx.tilix.preferences;

class PasswordManagerDialog: Dialog {

private:

    enum COLUMN_NAME = 0;
    enum COLUMN_ID = 1;

    enum SCHEMA_NAME = "com.gexperts.tilix.Password";

    enum ATTRIBUTE_ID = "id";
    enum ATTRIBUTE_DESCRIPTION = "description";

    enum PENDING_COLLECTION = "collection";
    enum PENDING_SERVICE = "service";

    enum DEFAULT_COLLECTION = "default";

    string[string] EMPTY_ATTRIBUTES;

    SearchEntry se;
    TreeView tv;
    ListStore ls;
    Button btnEdit;
    Button btnDelete;

    Settings gsSettings;

    Schema schema;
    // These are populated asynchronously
    Service service;
    Collection collection;

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

    // Keep a list of pending async operations so we can cancel them
    // if the user closes the app
    Cancellable[string] pending;

    // Null terminated strings we need to keep a reference for C async methods
    immutable(char*) attrDescription;
    immutable(char*) attrID;
    immutable(char*) descriptionValue;

    // List of items
    string[][] rows;

    void createUI() {
        with (getContentArea()) {
            setMarginLeft(18);
            setMarginRight(18);
            setMarginTop(18);
            setMarginBottom(18);
        }

        Box b = new Box(gtk.types.Orientation.Vertical, 6);

        se = new SearchEntry();
        se.connectSearchChanged(delegate(SearchEntry se) {
            filterEntries();
        });
        se.connectKeyPressEvent(delegate(EventKey event, Widget w) {
            uint keyval = event.keyval;
            if (keyval == Keys.Escape) {
                response(gtk.types.ResponseType.Cancel);
                return true;
            }
            if (keyval == Keys.Return) {
                response(gtk.types.ResponseType.Apply);
                return true;
            }
            return false;
        });
        b.add(se);

        Box bList = new Box(gtk.types.Orientation.Horizontal, 6);

        ls = ListStore.new_([cast(GType)GTypeEnum.String, cast(GType)GTypeEnum.String]);

        tv = new TreeView();
        tv.setModel(ls);
        tv.setHeadersVisible(false);
        TreeViewColumn column = new TreeViewColumn();
        column.setTitle(_("Name"));
        CellRendererText crt = new CellRendererText();
        column.packStart(crt, true);
        column.addAttribute(crt, "text", COLUMN_NAME);
        column.setMinWidth(300);
        tv.appendColumn(column);

        column = new TreeViewColumn();
        column.setTitle(_("ID"));
        crt = new CellRendererText();
        column.packStart(crt, true);
        column.addAttribute(crt, "text", COLUMN_ID);
        column.setVisible(false);
        tv.appendColumn(column);

        tv.connectCursorChanged(delegate(TreeView tv) {
            updateUI();
        });
        tv.connectRowActivated(delegate(TreePath p, TreeViewColumn c, TreeView t) {
            response(gtk.types.ResponseType.Apply);
        });

        ScrolledWindow sw = new ScrolledWindow();
        sw.add(tv);
        sw.setShadowType(ShadowType.EtchedIn);
        sw.setPolicy(PolicyType.Never, PolicyType.Automatic);
        sw.setHexpand(true);
        sw.setVexpand(true);
        sw.setSizeRequest(-1, 200);

        bList.add(sw);

        Box bButtons = new Box(gtk.types.Orientation.Vertical, 6);
        Button btnNew = Button.newWithLabel(_("New"));
        btnNew.connectClicked(delegate(Button b) {
            PasswordDialog pd = new PasswordDialog(this);
            scope (exit) {pd.destroy();}
            pd.showAll();
            if (pd.run() == gtk.types.ResponseType.Ok) {
                tracef("Storing password, label=%s",pd.label);
                Cancellable c = new Cancellable();
                //We could potentially have many password operations on the go, use random key
                string uuid = randomUUID().toString();
                pending[uuid] = c;
                string[string] attributes;
                attributes[ATTRIBUTE_ID] = uuid;
                attributes[ATTRIBUTE_DESCRIPTION] = "Tilix Password";
                passwordStoreSync(schema, attributes, DEFAULT_COLLECTION, pd.label, pd.password, c);
                reload();
            }
        });
        bButtons.add(btnNew);

        btnEdit = Button.newWithLabel(_("Edit"));
        btnEdit.connectClicked(delegate(Button b) {
            TreeIter selected = getSelectedIter();
            if (selected !is null) {
                string id = getValueString(ls, selected, COLUMN_ID);
                PasswordDialog pd = new PasswordDialog(this, getValueString(ls, selected, COLUMN_NAME), "");
                scope(exit) {pd.destroy();}
                pd.showAll();
                if (pd.run() == gtk.types.ResponseType.Ok) {
                    Item[] items = collection.getItems();
                    foreach (item; items) {
                        if (item.getSchemaName() == SCHEMA_NAME) {
                            string[string] attributes = item.getAttributes();
                            if (attributes.get(ATTRIBUTE_ID, "") == id) {
                                trace("Modifying item...");
                                item.setLabelSync(pd.label, null);
                                item.setAttributesSync(schema, attributes, null);
                                item.setSecretSync(new SecretValue(pd.password, cast(ptrdiff_t)pd.password.length, "text/plain"), null);
                                reload();
                                break;
                            }
                        }
                    }
                }
            }
        });
        bButtons.add(btnEdit);

        btnDelete = Button.newWithLabel(_("Delete"));
        btnDelete.connectClicked(delegate(Button b) {
            TreeIter selected = getSelectedIter();
            if (selected !is null) {
                string id = getValueString(ls, selected, COLUMN_ID);
                string[string] attributes;
                attributes[ATTRIBUTE_ID] = id;
                passwordClearSync(schema, attributes, null);
                foreach(index, row; rows) {
                    if (row[1] == id) {
                        std.algorithm.remove(rows, index);
                    }
                }
                ls.remove(selected);
            }
        });
        bButtons.add(btnDelete);

        bList.add(bButtons);

        b.add(bList);
        CheckButton cbIncludeEnter = CheckButton.newWithLabel(_("Include return character with password"));
        gsSettings.bind(SETTINGS_PASSWORD_INCLUDE_RETURN_KEY, cbIncludeEnter, "active", SettingsBindFlags.Default);

        b.add(cbIncludeEnter);
        getContentArea().add(b);
    }

    void filterEntries() {
        string selectedID;
        TreeIter selected = getSelectedIter();
        if (selected !is null) selectedID = getValueString(ls, selected, COLUMN_ID);
        selected = null;
        ls.clear();
        foreach(row; rows) {
            if (se.getText().length ==0 || row[0].indexOf(se.getText()) >=0) {
                TreeIter iter;
                ls.append(iter);
                ls.setValue(iter, COLUMN_NAME, new Value(row[0]));
                ls.setValue(iter, COLUMN_ID, new Value(row[1]));
                if (row[1] == selectedID) selected = iter;
            }
        }
        if (selected !is null) tv.getSelection().selectIter(selected);
        else selectRow(tv, 0);
    }

    void loadEntries() {
        Item[] items = collection.getItems();
        rows.length = 0;
        foreach (item; items) {
            if (item.getSchemaName() == SCHEMA_NAME) {
                string id = item.getAttributes().get(ATTRIBUTE_ID, "");
                rows ~= [item.getLabel(), id];
            }
        }
        rows.sort();

        filterEntries();
        updateUI();
    }

    // Reload entries from collections
    void reload() {
        // Have to disconnect otherwise you just get back cached entries
        service = null;
        collection = null;
        createService();
    }

    void createSchema() {
        import secret.c.functions : secret_schema_new;
        import secret.c.types : SecretSchemaFlags, SecretSchemaAttributeType;
        import gobject.object : ObjectWrap;
        import std.typecons : Yes;

        auto _cretval = secret_schema_new(toStringz(SCHEMA_NAME), SecretSchemaFlags.None,
            toStringz(ATTRIBUTE_ID), SecretSchemaAttributeType.String,
            toStringz(ATTRIBUTE_DESCRIPTION), SecretSchemaAttributeType.String,
            null);
        schema = ObjectWrap._getDObject!(Schema)(_cretval, Yes.Take);
    }

    void createService() {
        Cancellable c = new Cancellable();
        pending[PENDING_SERVICE] = c;
        Service.get(SecretServiceFlags.OpenSession, c, (ObjectWrap sourceObject, AsyncResult res) {
            trace("secretServiceCallback called");
            try {
                Service ss = Service.getFinish(res);
                if (ss !is null) {
                    pending.remove(PENDING_SERVICE);
                    this.service = ss;
                    createCollection();
                    trace("Retrieved secret service");
                }
            } catch (ErrorWrap ge) {
                trace("Error occurred: " ~ ge.msg);
            }
        });
    }

    void createCollection() {
        Cancellable c = new Cancellable();
        pending[PENDING_COLLECTION] = c;
        Collection.forAlias(service, DEFAULT_COLLECTION, SecretCollectionFlags.LoadItems, c, (ObjectWrap sourceObject, AsyncResult res) {
            trace("collectionCallback called");
            try {
                Collection c_ = Collection.forAliasFinish(res);
                if (c_ !is null) {
                    this.pending.remove(PENDING_COLLECTION);
                    this.collection = c_;
                    this.loadEntries();
                    trace("Retrieved default collection");
                }
            } catch (ErrorWrap ge) {
                trace("Error occurred: " ~ ge.msg);
            }
        });
    }

    void updateUI() {
        setResponseSensitive(gtk.types.ResponseType.Apply, getSelectedIter() !is null);
    }

public:

    this(Window parent) {
        super();
        setTitle(_("Insert Password"));
        setTransientFor(parent);
        setModal(true);
        addButton(_("Apply"), gtk.types.ResponseType.Apply);
        addButton(_("Cancel"), gtk.types.ResponseType.Cancel);
        gsSettings = new Settings(SETTINGS_ID);
        setDefaultResponse(gtk.types.ResponseType.Apply);
        connectDestroy(delegate() {
            foreach(c; pending) {
                c.cancel();
            }
        });
        EMPTY_ATTRIBUTES = null;
        attrID = toStringz(ATTRIBUTE_ID);
        attrDescription = toStringz(ATTRIBUTE_DESCRIPTION);
        descriptionValue = toStringz("Tilix Password");
        trace("Retrieving secret service");
        createSchema();
        createUI();
        createService();
    }

    @property string password() {
        TreeIter selected = getSelectedIter();
        if (selected !is null) {
            string id = getValueString(ls, selected, COLUMN_ID);
            trace("Getting password for " ~ id);
            string[string] attributes;
            attributes[ATTRIBUTE_ID] = id;
            string password = passwordLookupSync(schema, attributes, null);
            if (gsSettings.getBoolean(SETTINGS_PASSWORD_INCLUDE_RETURN_KEY)) {
                password ~= '\n';
            }
            return password;
        } else {
            return null;
        }
    }

}

private:
class PasswordDialog: Dialog {

private:

    Label lblMatch;
    Label lblName;
    Label lblPassword;
    Label lblRepeatPwd;

    Entry eLabel;
    Entry ePassword;
    Entry eConfirmPassword;

    void createUI(string _label, string _password) {

        Grid grid = new Grid();
        grid.setColumnSpacing(12);
        grid.setRowSpacing(6);

        int row = 0;
        // Name (i.e. Label in libsecret parlance)
        lblName = new Label(_("Name"));
        lblName.setHalign(Align.End);
        grid.attach(lblName, 0, row, 1, 1);
        eLabel = new Entry();
        eLabel.setWidthChars(40);
        eLabel.setText(_label);
        grid.attach(eLabel, 1, row, 1, 1);
        row++;

        //Password
        lblPassword = new Label(_("Password"));
        lblPassword.setHalign(Align.End);
        grid.attach(lblPassword, 0, row, 1, 1);
        ePassword = new Entry();
        ePassword.setVisibility(false);
        ePassword.setText(_password);
        grid.attach(ePassword, 1, row, 1, 1);
        row++;

        //Confirm Password
        lblRepeatPwd = new Label(_("Confirm Password"));
        lblRepeatPwd.setHalign(Align.End);
        grid.attach(lblRepeatPwd, 0, row, 1, 1);
        eConfirmPassword = new Entry();
        eConfirmPassword.setVisibility(false);
        eConfirmPassword.setText(_password);
        grid.attach(eConfirmPassword, 1, row, 1, 1);
        row++;

        lblMatch = new Label("Password does not match confirmation");
        lblMatch.setSensitive(false);
        lblMatch.setNoShowAll(true);
        lblMatch.setHalign(Align.Center);
        grid.attach(lblMatch, 1, row, 1, 1);

        with (getContentArea()) {
            setMarginLeft(18);
            setMarginRight(18);
            setMarginTop(18);
            setMarginBottom(18);
            add(grid);
        }
        updateUI();
        eLabel.connectChanged(&entryChanged);
        ePassword.connectChanged(&entryChanged);
        eConfirmPassword.connectChanged(&entryChanged);
    }

    void entryChanged(Editable) {
        updateUI();
    }

    void updateUI() {
        setResponseSensitive(gtk.types.ResponseType.Ok, eLabel.getText().length > 0 && ePassword.getText().length > 0 && ePassword.getText() == eConfirmPassword.getText());
        if (ePassword.getText() != eConfirmPassword.getText()) {
            lblMatch.show();
        } else {
            lblMatch.hide();
        }
    }

    this(Window parent, string title) {
        super();
        setTitle(title);
        setTransientFor(parent);
        setModal(true);
        addButton(_("Ok"), gtk.types.ResponseType.Ok);
        addButton(_("Cancel"), gtk.types.ResponseType.Cancel);
        setDefaultResponse(gtk.types.ResponseType.Ok);
    }

public:
    this(Window parent) {
        this(parent, _("Add Password"));
        createUI("","");
    }

    this(Window parent, string _label, string _password) {
        this(parent, _("Edit Password"));
        createUI(_label, _password);
    }

    @property string label() {
        return eLabel.getText();
    }

    @property string password() {
        return ePassword.getText();
    }

}
