/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

 module gx.terminix.terminal.password;

import std.conv;
import std.experimental.logger;
import std.format;
import std.string;

import gobject.ObjectG;

import gio.Cancellable;
import gio.SimpleAsyncResult;

import glib.HashTable;
import glib.ListG;

import gtk.Box;
import gtk.Button;
import gtk.CellRendererText;
import gtk.Dialog;
import gtk.SearchEntry;
import gtk.ListStore;
import gtk.TreeViewColumn;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeView;
import gtk.ScrolledWindow;
import gtk.SearchEntry;
import gtk.Window;

import secret.Collection;
import secret.Item;
import secret.Schema;
import secret.Service;

import gx.i18n.l10n;

class PasswordDialog: Dialog {

private:

    enum COLUMN_NAME = 0;
    enum COLUMN_DESCRIPTION = 1;

    enum SCHEMA_NAME = "com.gexperts.Terminix.Password";

    enum ATTRIBUTE_DESCRIPTION = "Description";

    enum PENDING_COLLECTION = "collection";
    enum PENDING_SERVICE = "service";

    SearchEntry se;
    TreeView tv;
    ListStore ls;

    Schema schema;
    // These are populated asynchronously
    Service service;
    Collection collection;

    string _password;

    Cancellable[string] pending;

    HashTable attributes; 

    void createUI() {
        with (getContentArea()) {
            setMarginLeft(18);
            setMarginRight(18);
            setMarginTop(18);
            setMarginBottom(18);
        }

        Box b = new Box(Orientation.VERTICAL, 6);

        SearchEntry se = new SearchEntry();
        b.add(se);

        Box bList = new Box(Orientation.HORIZONTAL, 6);

        ls = new ListStore([GType.STRING, GType.STRING]);
        tv = new TreeView(ls);
        TreeViewColumn column = new TreeViewColumn(_("Name"), new CellRendererText(), "text", COLUMN_NAME);
        tv.appendColumn(column);
        column = new TreeViewColumn(_("Description"), new CellRendererText(), "text", COLUMN_DESCRIPTION);
        tv.appendColumn(column);

        ScrolledWindow sw = new ScrolledWindow(tv);
        sw.setShadowType(ShadowType.ETCHED_IN);
        sw.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sw.setHexpand(true);
        
        bList.add(sw);

        Box bButtons = new Box(Orientation.VERTICAL, 6);
        Button btnNew = new Button(_("New"));
        bButtons.add(btnNew);

        Button btnDelete = new Button(_("Delete"));
        bButtons.add(btnDelete);

        bList.add(bButtons);

        b.add(bList);
        getContentArea().add(b);
    }

    void loadEntries() {
        ListG list = collection.getItems();
        Item[] items = list.toArray!Item;
        ls.clear();
        foreach(item; items) {
            trace(item.getLabel());
            if (item.getSchemaName() == SCHEMA_NAME) {
                TreeIter iter = ls.createIter();
                ls.setValue(iter, COLUMN_NAME, item.getLabel());
                immutable(char)* key = toStringz(ATTRIBUTE_DESCRIPTION);
                char* value = cast(char*)item.getAttributes().lookup(cast(void*)key);
                ls.setValue(iter, COLUMN_DESCRIPTION, to!string(value));
            }
        }
    }

    void createSchema() {
        SecretSchemaAttribute[32] attributes;
        attributes[0] = SecretSchemaAttribute(toStringz(ATTRIBUTE_DESCRIPTION), SecretSchemaAttributeType.STRING);
        attributes[1] = SecretSchemaAttribute(null, SecretSchemaAttributeType.STRING);

        SecretSchema ss = SecretSchema(toStringz(SCHEMA_NAME), 
                          SecretSchemaFlags.NONE,
                          attributes);
        schema = new Schema(&ss, true);
    }

    void createCollection() {
        Cancellable c = new Cancellable();
        pending[PENDING_COLLECTION] = c;
        Collection.forAlias(service, "default", SecretCollectionFlags.NONE, c, &collectionCallback, this.getDialogStruct());
    }

    extern(C) static void collectionCallback(GObject* sourceObject, GAsyncResult* res, void* userData) {
        trace("collectionCallback called");
        Collection c = Collection.forAliasFinish(new SimpleAsyncResult(cast(GSimpleAsyncResult*)res, false));
        if (c !is null) {
            PasswordDialog pd = cast(PasswordDialog) ObjectG.getDObject!(Dialog)(cast(GtkDialog*) userData, false);
            if (pd !is null) {
                pd.pending.remove(PENDING_COLLECTION);
                pd.collection = c;
                pd.loadEntries();
                trace("Retrieved default collection");
            }
        }
    }

    extern(C) static void secretServiceCallback(GObject* sourceObject, GAsyncResult* res, void* userData) {
        trace("secretServiceCallback called");
        Service ss = Service.getFinish(new SimpleAsyncResult(cast(GSimpleAsyncResult*)res, false));
        if (ss !is null) {
            PasswordDialog pd = cast(PasswordDialog) ObjectG.getDObject!(Dialog)(cast(GtkDialog*) userData, false);
            if (pd !is null) {
                pd.pending.remove(PENDING_SERVICE);
                pd.service = ss;
                pd.createCollection();
                trace("Retrieved secret service");
            }
        }
    }

public:

    this(Window parent) {
        super(_("Insert Password"), parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("Apply"), _("Cancel")], [GtkResponseType.APPLY, GtkResponseType.CANCEL]);
        setDefaultResponse(GtkResponseType.APPLY);
        addOnDestroy(delegate(Widget) {
            foreach(c; pending) {
                c.cancel();
            }
        });
        import gtkc.glib;
        attributes = new HashTable(g_str_hash, g_str_equal);
        trace("Retrieving secret service");
        Cancellable c = new Cancellable();
        pending[PENDING_SERVICE] = c;
        Service.get(SecretServiceFlags.OPEN_SESSION | SecretServiceFlags.LOAD_COLLECTIONS, c, &secretServiceCallback, this.getDialogStruct());
        createSchema();
        createUI();        
    }

    @property string password() {
        return _password;
    }
}