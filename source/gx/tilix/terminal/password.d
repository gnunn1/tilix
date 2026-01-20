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

import gdk.event : Event;
import gdk.event_key : EventKey;
// GID does not provide gdk.keysyms, define required constants locally
private enum GdkKeysyms { GDK_Return = 0xff0d, GDK_Escape = 0xff1b }

import gobject.object : ObjectWrap;
import gobject.c.types : GObject;
import gobject.value : Value;

import gio.async_result : AsyncResult;
import gio.cancellable : Cancellable;
import gio.c.types : GAsyncResult;
import gio.settings: GSettings=Settings;
import gio.types : SettingsBindFlags;

import glib.error : ErrorWrap;

import gtk.box : Box;
import gtk.button : Button;
import gtk.cell_renderer_text : CellRendererText;
import gtk.check_button : CheckButton;
import gtk.dialog : Dialog;
import gtk.editable : Editable;
import gtk.entry : Entry;
import gtk.grid : Grid;
import gtk.label : Label;
import gtk.list_store : ListStore;
import gtk.tree_iter : TreeIter;
import gtk.tree_path : TreePath;
import gtk.tree_view : TreeView;
import gtk.tree_view_column : TreeViewColumn;
import gtk.scrolled_window : ScrolledWindow;
import gtk.search_entry : SearchEntry;
import gtk.widget : Widget;
import gtk.window : Window;
import gtk.types : Align, DialogFlags, Orientation, PolicyType, ResponseType, ShadowType;

import secret.collection : Collection;
import secret.item : Item;
import secret.schema : Schema;
import secret.global : passwordStoreSync, passwordClearSync, passwordLookupSync;
import secret.service : Service;
import secret.value : SecretValue = Value;
import secret.types : SchemaFlags, ServiceFlags, CollectionFlags;
import secret.c.types : SecretSchema, SecretSchemaAttribute, SecretSchemaAttributeType, SecretSchemaFlags;
import secret.c.functions : secret_schema_newv;

import glib.c.types : GHashTable;
import glib.c.functions : g_hash_table_new, g_hash_table_insert;

import std.typecons : Flag, Yes;

import gx.gtk.util : GTypes, selectRow, getValueString, getSelectedIter;
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

    GSettings gsSettings;

    Schema schema;
    // These are populated asynchronously
    Service service;
    Collection collection;

    // Keep a list of pending async operations so we can cancel them
    // if the user closes the app
    Cancellable[string] pending;

    // Null terminated strings we need to keep a reference for C async methods




    // List of items
    string[][] rows;

    void createUI() {
        with (getContentArea()) {
            setMarginLeft(18);
            setMarginRight(18);
            setMarginTop(18);
            setMarginBottom(18);
        }

        Box b = new Box(Orientation.Vertical, 6);

        se = new SearchEntry();
        se.connectSearchChanged(delegate() {
            filterEntries();
        });
        se.connectKeyPressEvent(delegate(EventKey event) {
            uint keyval = event.keyval;
            if (keyval == GdkKeysyms.GDK_Escape) {
                response(ResponseType.Cancel);
                return true;
            }
            if (keyval == GdkKeysyms.GDK_Return) {
                response(ResponseType.Apply);
                return true;
            }
            return false;
        });
        b.add(se);

        Box bList = new Box(Orientation.Horizontal, 6);

        ls = ListStore.new_([GTypes.STRING, GTypes.STRING]);

        tv = new TreeView();
        tv.setModel(ls);
        tv.setHeadersVisible(false);
        auto crt1 = new CellRendererText();
        TreeViewColumn column = new TreeViewColumn();
        column.setTitle(_("Name"));
        column.packStart(crt1, true);
        column.addAttribute(crt1, "text", COLUMN_NAME);
        column.setMinWidth(300);
        tv.appendColumn(column);
        auto crt2 = new CellRendererText();
        TreeViewColumn column2 = new TreeViewColumn();
        column2.setTitle(_("ID"));
        column2.packStart(crt2, true);
        column2.addAttribute(crt2, "text", COLUMN_ID);
        column2.setVisible(false);
        tv.appendColumn(column2);

        tv.connectCursorChanged(delegate() {
            updateUI();
        });
        tv.connectRowActivated(delegate(TreePath p, TreeViewColumn c) {
            response(ResponseType.Apply);
        });

        ScrolledWindow sw = new ScrolledWindow();
        sw.add(tv);
        sw.setShadowType(ShadowType.EtchedIn);
        sw.setPolicy(PolicyType.Never, PolicyType.Automatic);
        sw.setHexpand(true);
        sw.setVexpand(true);
        sw.setSizeRequest(-1, 200);

        bList.add(sw);

        Box bButtons = new Box(Orientation.Vertical, 6);
        Button btnNew = Button.newWithLabel(_("New"));
        btnNew.connectClicked(delegate() {
            PasswordDialog pd = new PasswordDialog(cast(Window) this);
            scope (exit) {pd.destroy();}
            pd.showAll();
            if (pd.run() == ResponseType.Ok) {
                tracef("Storing password, label=%s",pd.label);
                string uuid = randomUUID().toString();

                string[string] attributes;
                attributes[ATTRIBUTE_ID] = uuid;
                attributes[ATTRIBUTE_DESCRIPTION] = "Tilix Password";

                try {
                    passwordStoreSync(schema, attributes, DEFAULT_COLLECTION, pd.label, pd.password, null);
                    reload();
                } catch (Exception e) {
                    trace("Error storing password: " ~ e.msg);
                }
            }
        });
        bButtons.add(btnNew);

        Button btnEdit = Button.newWithLabel(_("Edit"));
        btnEdit.connectClicked(delegate() {
            TreeIter selected = getSelectedIter(tv);
            if (selected) {
                string id = getValueString(ls, selected, COLUMN_ID);
                PasswordDialog pd = new PasswordDialog(cast(Window) this, getValueString(ls, selected, COLUMN_NAME), "");
                scope(exit) {pd.destroy();}
                pd.showAll();
                if (pd.run() == ResponseType.Ok) {
                    Item[] items = collection.getItems();

                    foreach (item; items) {
                        if (item.getSchemaName() == SCHEMA_NAME) {
                            string itemID = item.getAttributes().get(ATTRIBUTE_ID, "");
                            trace("ItemID " ~ itemID);
                            if (id == itemID) {
                                trace("Modifying item...");
                                item.setLabelSync(pd.label, null);
                                item.setSecretSync(new SecretValue(pd.password, pd.password.length, "text/plain"), null);
                                reload();
                                break;
                            }
                        }
                    }
                }
            }
        });
        bButtons.add(btnEdit);

        Button btnDelete = Button.newWithLabel(_("Delete"));
        btnDelete.connectClicked(delegate() {
            TreeIter selected = getSelectedIter(tv);
            if (selected) {
                string id = getValueString(ls, selected, COLUMN_ID);
                string[string] ht;

                ht[ATTRIBUTE_ID] = id;
                passwordClearSync(schema, ht, null);
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
        TreeIter selected = getSelectedIter(tv);
        if (selected) selectedID = getValueString(ls, selected, COLUMN_ID);
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
        if (items is null || items.length == 0) return;

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
        service.disconnect();
        service = null;
        collection = null;
        createService();
    }

    string[string] createHashTable() {

        string[string] ht; return ht;
    }

    void createSchema() {
        // Create the schema using C API since GID doesn't expose Schema constructors
        // We need to create a GHashTable with attribute names -> types
        import core.stdc.string : strlen;
        import std.string : toStringz;
        
        GHashTable* ht = g_hash_table_new(null, null);
        // Values in the hash table are the attribute types (cast to void*)
        g_hash_table_insert(ht, cast(void*) toStringz(ATTRIBUTE_ID), cast(void*) SecretSchemaAttributeType.String);
        g_hash_table_insert(ht, cast(void*) toStringz(ATTRIBUTE_DESCRIPTION), cast(void*) SecretSchemaAttributeType.String);
        
        SecretSchema* cSchema = secret_schema_newv(toStringz(SCHEMA_NAME), SecretSchemaFlags.None, ht);
        schema = new Schema(cast(void*) cSchema, Yes.Take);
    }

    void createService() {
        Cancellable c = new Cancellable();
        pending[PENDING_SERVICE] = c;
        // GID async methods use D delegates, no user data needed
        Service.get(ServiceFlags.OpenSession, c, &onSecretServiceReady);
    }

    void createCollection() {
        Cancellable c = new Cancellable();
        pending[PENDING_COLLECTION] = c;
        // GID async methods use D delegates, no user data needed
        Collection.forAlias(service, DEFAULT_COLLECTION, CollectionFlags.LoadItems, c, &onCollectionReady);
    }

    void updateUI() {
        setResponseSensitive(ResponseType.Apply, getSelectedIter(tv) !is null);
    }

    // GID-style async callback for Service.get
    void onSecretServiceReady(ObjectWrap sourceObject, AsyncResult res) {
        trace("secretServiceCallback called");
        try {
            Service ss = Service.getFinish(res);
            if (ss !is null) {
                pending.remove(PENDING_SERVICE);
                service = ss;
                createCollection();
                trace("Retrieved secret service");
            }
        } catch (ErrorWrap ge) {
            trace("Error occurred: " ~ ge.msg);
            return;
        }
    }

    // GID-style async callback for Collection.forAlias
    void onCollectionReady(ObjectWrap sourceObject, AsyncResult res) {
        trace("collectionCallback called");
        try {
            Collection c = Collection.forAliasFinish(res);
            if (c !is null) {
                pending.remove(PENDING_COLLECTION);
                collection = c;
                loadEntries();
                trace("Retrieved default collection");
            }
        } catch (ErrorWrap ge) {
            trace("Error occurred: " ~ ge.msg);
            return;
        }
    }

public:

    this(Window parent) {
        super();
        setTitle(_("Insert Password"));
        setTransientFor(parent);
        setModal(true);
        addButton(_("Apply"), ResponseType.Apply);
        addButton(_("Cancel"), ResponseType.Cancel);
        gsSettings = new GSettings(SETTINGS_ID);
        setDefaultResponse(ResponseType.Apply);
        connectDestroy(delegate() {
            foreach(c; pending) {
                c.cancel();
            }
        });
        EMPTY_ATTRIBUTES = null;



        trace("Retrieving secret service");
        createSchema();
        createUI();
        createService();
    }

    @property string password() {
        TreeIter selected = getSelectedIter(tv);
        if (selected) {
            string id = getValueString(ls, selected, COLUMN_ID);
            trace("Getting password for " ~ id);
            string[string] ht;

            ht[ATTRIBUTE_ID] = id;
            string pwd = passwordLookupSync(schema, ht, null);
            if (gsSettings.getBoolean(SETTINGS_PASSWORD_INCLUDE_RETURN_KEY)) {
                pwd ~= '\n';
            }
            return pwd;
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
        setResponseSensitive(ResponseType.Ok, eLabel.getText().length > 0 && ePassword.getText().length > 0 && ePassword.getText() == eConfirmPassword.getText());
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
        addButton(_("OK"), ResponseType.Ok);
        addButton(_("Cancel"), ResponseType.Cancel);
        setDefaultResponse(ResponseType.Ok);
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
