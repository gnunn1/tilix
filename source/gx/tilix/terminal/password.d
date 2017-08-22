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

import gdk.Event;
import gdk.Keysyms;

import gobject.ObjectG;

import gio.Cancellable;
import gio.Settings: GSettings=Settings;
import gio.SimpleAsyncResult;

import glib.GException;
import glib.HashTable;
import glib.ListG;

import gtk.Box;
import gtk.Button;
import gtk.CellRendererText;
import gtk.CheckButton;
import gtk.Dialog;
import gtk.EditableIF;
import gtk.Entry;
import gtk.Grid;
import gtk.Label;
import gtk.ListStore;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.ScrolledWindow;
import gtk.SearchEntry;
import gtk.Widget;
import gtk.Window;

import secret.Collection;
import secret.Item;
import secret.Schema;
import secret.Secret;
import secret.Service;
import secret.Value;

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

    HashTable EMPTY_ATTRIBUTES;

    SearchEntry se;
    TreeView tv;
    ListStore ls;

    GSettings gsSettings;

    Schema schema;
    // These are populated asynchronously
    Service service;
    Collection collection;

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

        Box b = new Box(Orientation.VERTICAL, 6);

        se = new SearchEntry();
        se.addOnSearchChanged(delegate(SearchEntry) {
            filterEntries();
        });
        se.addOnKeyPress(delegate(Event event, Widget w) {
            uint keyval;
            if (event.getKeyval(keyval)) {
                if (keyval == GdkKeysyms.GDK_Escape) {
                    response = ResponseType.CANCEL;
                    return true;
                }
                if (keyval == GdkKeysyms.GDK_Return) {
                    response = ResponseType.APPLY;
                    return true;
                }
            }
            return false;
        });
        b.add(se);

        Box bList = new Box(Orientation.HORIZONTAL, 6);

        ls = new ListStore([GType.STRING, GType.STRING]);

        tv = new TreeView(ls);
        tv.setHeadersVisible(false);
        TreeViewColumn column = new TreeViewColumn(_("Name"), new CellRendererText(), "text", COLUMN_NAME);
        column.setMinWidth(300);
        tv.appendColumn(column);
        column = new TreeViewColumn(_("ID"), new CellRendererText(), "text", COLUMN_NAME);
        column.setVisible(false);
        tv.appendColumn(column);

        tv.addOnCursorChanged(delegate(TreeView) {
            updateUI();
        });
        tv.addOnRowActivated(delegate(TreePath, TreeViewColumn, TreeView) {
            response(ResponseType.APPLY);
        });

        ScrolledWindow sw = new ScrolledWindow(tv);
        sw.setShadowType(ShadowType.ETCHED_IN);
        sw.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sw.setHexpand(true);
        sw.setVexpand(true);
        sw.setSizeRequest(-1, 200);

        bList.add(sw);

        Box bButtons = new Box(Orientation.VERTICAL, 6);
        Button btnNew = new Button(_("New"));
        btnNew.addOnClicked(delegate(Button) {
            PasswordDialog pd = new PasswordDialog(this);
            scope (exit) {pd.destroy();}
            pd.showAll();
            if (pd.run() == ResponseType.OK) {
                SecretSchema* ss = schema.getSchemaStruct();
                trace("Schema name is " ~ to!string(ss.name));
                tracef("Storing password, label=%s",pd.label);
                Cancellable c = new Cancellable();
                //We could potentially have many password operations on the go, use random key
                string uuid = randomUUID().toString();
                pending[uuid] = c;
                import gtkc.glib;
                HashTable attributes = new HashTable(g_str_hash, g_str_equal);
                immutable(char*) uuidz = toStringz(uuid);
                attributes.insert(cast(void*)attrID, cast(void*)uuidz);
                attributes.insert(cast(void*)attrDescription, cast(void*)descriptionValue);
                Secret.passwordStorev(schema, attributes, DEFAULT_COLLECTION, pd.label, pd.password, c, &passwordStoreCallback, this.getDialogStruct());
            }
        });
        bButtons.add(btnNew);

        Button btnEdit = new Button(_("Edit"));
        btnEdit.addOnClicked(delegate(Button) {
            TreeIter selected = tv.getSelectedIter();
            if (selected) {
                string id = ls.getValueString(selected, COLUMN_ID);
                PasswordDialog pd = new PasswordDialog(this, ls.getValueString(selected, COLUMN_NAME), "");
                scope(exit) {pd.destroy();}
                pd.showAll();
                if (pd.run() == ResponseType.OK) {
                    ListG list = collection.getItems();
                    Item[] items = list.toArray!Item;
                    foreach (item; items) {
                        if (item.getSchemaName() == SCHEMA_NAME) {
                            string itemID = to!string(cast(char*)item.getAttributes().lookup(cast(void*)attrID));
                            trace("ItemID " ~ itemID);
                            if (id == itemID) {
                                trace("Modifying item...");
                                item.setLabelSync(pd.label, null);
                                item.setSecretSync(new Value(pd.password, pd.password.length, "text/plain"), null);
                                reload();
                                break;
                            }
                        }
                    }
                }
            }
        });
        bButtons.add(btnEdit);

        Button btnDelete = new Button(_("Delete"));
        btnDelete.addOnClicked(delegate(Button) {
            TreeIter selected = tv.getSelectedIter();
            if (selected) {
                string id = ls.getValueString(selected, COLUMN_ID);
                HashTable ht = createHashTable();
                immutable(char*) idz = toStringz(id);
                ht.insert(cast(void*)attrID, cast(void*)idz);
                Secret.passwordClearvSync(schema, ht, null);
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
        CheckButton cbIncludeEnter = new CheckButton(_("Include return character with password"));
        gsSettings.bind(SETTINGS_PASSWORD_INCLUDE_RETURN_KEY, cbIncludeEnter, "active", GSettingsBindFlags.DEFAULT);

        b.add(cbIncludeEnter);
        getContentArea().add(b);
    }

    void filterEntries() {
        string selectedID;
        TreeIter selected = tv.getSelectedIter();
        if (selected) selectedID = ls.getValueString(selected, COLUMN_ID);
        selected = null;
        ls.clear();
        foreach(row; rows) {
            if (se.getText().length ==0 || row[0].indexOf(se.getText()) >=0) {
                TreeIter iter = ls.createIter();
                ls.setValue(iter, COLUMN_NAME, row[0]);
                ls.setValue(iter, COLUMN_ID, row[1]);
                if (row[1] == selectedID) selected = iter;
            }
        }
        if (selected !is null) tv.getSelection().selectIter(selected);
        else selectRow(tv, 0);
    }

    void loadEntries() {
        ListG list = collection.getItems();
        if (list is null) return;
        Item[] items = list.toArray!Item;
        rows.length = 0;
        foreach (item; items) {
            if (item.getSchemaName() == SCHEMA_NAME) {
                string id = to!string(cast(char*)item.getAttributes().lookup(cast(void*)attrID));
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
        service.disconnect();
        service = null;
        collection = null;
        createService();
    }

    HashTable createHashTable() {
        import gtkc.glib;
        return new HashTable(g_str_hash, g_str_equal);
    }

    void createSchema() {
        HashTable ht = createHashTable();
        ht.insert(cast(void*)attrID, cast(void*)0);
        ht.insert(cast(void*)attrDescription, cast(void*)0);
        schema = new Schema(SCHEMA_NAME, SecretSchemaFlags.NONE, ht);
    }

    void createService() {
        Cancellable c = new Cancellable();
        pending[PENDING_SERVICE] = c;
        Service.get(SecretServiceFlags.OPEN_SESSION, c, &secretServiceCallback, this.getDialogStruct());
    }

    void createCollection() {
        Cancellable c = new Cancellable();
        pending[PENDING_COLLECTION] = c;
        Collection.forAlias(service, DEFAULT_COLLECTION, SecretCollectionFlags.LOAD_ITEMS, c, &collectionCallback, this.getDialogStruct());
    }

    void updateUI() {
        setResponseSensitive(ResponseType.APPLY, tv.getSelectedIter() !is null);
    }

    extern(C) static void passwordStoreCallback(GObject* sourceObject, GAsyncResult* res, void* userData) {
        trace("passwordCallback called");
        try {
            Secret.passwordStoreFinish(new SimpleAsyncResult(cast(GSimpleAsyncResult*)res, false));
            PasswordManagerDialog pd = cast(PasswordManagerDialog) ObjectG.getDObject!(Dialog)(cast(GtkDialog*) userData, false);
            if (pd !is null) {
                trace("Re-loading entries");
                pd.reload();
            }
        } catch (GException ge) {
            trace("Error occurred: " ~ ge.msg);
            return;
        }
    }

    extern(C) static void collectionCallback(GObject* sourceObject, GAsyncResult* res, void* userData) {
        trace("collectionCallback called");
        try {
            Collection c = Collection.forAliasFinish(new SimpleAsyncResult(cast(GSimpleAsyncResult*)res, false));
            if (c !is null) {
                PasswordManagerDialog pd = cast(PasswordManagerDialog) ObjectG.getDObject!(Dialog)(cast(GtkDialog*) userData, false);
                if (pd !is null) {
                    pd.pending.remove(PENDING_COLLECTION);
                    pd.collection = c;
                    pd.loadEntries();
                    trace("Retrieved default collection");
                }
            }
        } catch (GException ge) {
            trace("Error occurred: " ~ ge.msg);
            return;
        }
    }

    extern(C) static void secretServiceCallback(GObject* sourceObject, GAsyncResult* res, void* userData) {
        trace("secretServiceCallback called");
        try {
            Service ss = Service.getFinish(new SimpleAsyncResult(cast(GSimpleAsyncResult*)res, false));
            if (ss !is null) {
                PasswordManagerDialog pd = cast(PasswordManagerDialog) ObjectG.getDObject!(Dialog)(cast(GtkDialog*) userData, false);
                if (pd !is null) {
                    pd.pending.remove(PENDING_SERVICE);
                    pd.service = ss;
                    pd.createCollection();
                    trace("Retrieved secret service");
                }
            }

        } catch (GException ge) {
            trace("Error occurred: " ~ ge.msg);
            return;
        }
    }

public:

    this(Window parent) {
        super(_("Insert Password"), parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("Apply"), _("Cancel")], [GtkResponseType.APPLY, GtkResponseType.CANCEL]);
        gsSettings = new GSettings(SETTINGS_ID);
        setDefaultResponse(GtkResponseType.APPLY);
        addOnDestroy(delegate(Widget) {
            foreach(c; pending) {
                c.cancel();
            }
        });
        EMPTY_ATTRIBUTES = createHashTable();
        attrID = toStringz(ATTRIBUTE_ID);
        attrDescription = toStringz(ATTRIBUTE_DESCRIPTION);
        descriptionValue = toStringz("Tilix Password");
        trace("Retrieving secret service");
        createSchema();
        createUI();
        createService();
    }

    @property string password() {
        TreeIter selected = tv.getSelectedIter();
        if (selected) {
            string id = ls.getValueString(selected, COLUMN_ID);
            trace("Getting password for " ~ id);
            HashTable ht = createHashTable();
            immutable(char*) idz = toStringz(id);
            ht.insert(cast(void*)attrID, cast(void*)idz);
            string password = Secret.passwordLookupvSync(schema, ht, null);
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
        lblName.setHalign(Align.END);
        grid.attach(lblName, 0, row, 1, 1);
        eLabel = new Entry();
        eLabel.setWidthChars(40);
        eLabel.setText(_label);
        grid.attach(eLabel, 1, row, 1, 1);
        row++;

        //Password
        lblPassword = new Label(_("Password"));
        lblPassword.setHalign(Align.END);
        grid.attach(lblPassword, 0, row, 1, 1);
        ePassword = new Entry();
        ePassword.setVisibility(false);
        ePassword.setText(_password);
        grid.attach(ePassword, 1, row, 1, 1);
        row++;

        //Confirm Password
        lblRepeatPwd = new Label(_("Confirm Password"));
        lblRepeatPwd.setHalign(Align.END);
        grid.attach(lblRepeatPwd, 0, row, 1, 1);
        eConfirmPassword = new Entry();
        eConfirmPassword.setVisibility(false);
        eConfirmPassword.setText(_password);
        grid.attach(eConfirmPassword, 1, row, 1, 1);
        row++;

        lblMatch = new Label("Password does not match confirmation");
        lblMatch.setSensitive(false);
        lblMatch.setNoShowAll(true);
        lblMatch.setHalign(Align.CENTER);
        grid.attach(lblMatch, 1, row, 1, 1);

        with (getContentArea()) {
            setMarginLeft(18);
            setMarginRight(18);
            setMarginTop(18);
            setMarginBottom(18);
            add(grid);
        }
        updateUI();
        eLabel.addOnChanged(&entryChanged);
        ePassword.addOnChanged(&entryChanged);
        eConfirmPassword.addOnChanged(&entryChanged);
    }

    void entryChanged(EditableIF) {
        updateUI();
    }

    void updateUI() {
        setResponseSensitive(GtkResponseType.OK, eLabel.getText().length > 0 && ePassword.getText().length > 0 && ePassword.getText() == eConfirmPassword.getText());
        if (ePassword.getText() != eConfirmPassword.getText()) {
            lblMatch.show();
        } else {
            lblMatch.hide();
        }
    }

    this(Window parent, string title) {
        super(title, parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("OK"), _("Cancel")], [GtkResponseType.OK, GtkResponseType.CANCEL]);
        setDefaultResponse(GtkResponseType.OK);
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
