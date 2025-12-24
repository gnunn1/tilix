/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.dialog;

import std.string : toStringz;
import std.typecons : No, Yes;
import gio.settings: Settings = Settings;

import gtk.check_button;
import gtk.types;
import gtk.entry;
import gtk.types;
import gtk.message_dialog;
import gtk.types;
import gtk.window;
import gtk.types;
import gtk.types;
import gtk.global;
import gtk.types;
import gtk.editable;
import gtk.types;
import gtk.container;
import gtk.types;
import gtk.c.types;

import gx.i18n.l10n;

/**
 * Displays an error message in a dialog
 */
void showErrorDialog(gtk.window.Window parent, string message, string title = null) {
    showMessageDialog(gtk.types.MessageType.Error, parent, message, title);
}

/**
 * Displays a message dialog of the specified type
 */
void showMessageDialog(gtk.types.MessageType mt, gtk.window.Window parent, string message, string title = null) {
    import gtk.c.functions : gtk_message_dialog_new;
    import gobject.object : ObjectWrap;
    import std.typecons : Yes;
    auto dialogPtr = gtk_message_dialog_new(parent ? cast(GtkWindow*)parent._cPtr(No.Dup) : null,
            gtk.types.DialogFlags.Modal | gtk.types.DialogFlags.UseHeaderBar, mt, gtk.types.ButtonsType.Ok, toStringz(message));
    MessageDialog dialog = ObjectWrap._getDObject!(MessageDialog)(dialogPtr, Yes.Take);
    scope (exit) {
        dialog.destroy();
    }
    dialog.setTransientFor(parent);
    if (title.length > 0)
        dialog.setTitle(title);
    dialog.run();
}

alias OnValidate = bool delegate(string value);

/**
 * Show an input dialog with a single entry for input
 */
bool showInputDialog(gtk.window.Window parent, string value, string initialValue = "", string title = "", string message = "", OnValidate validate = null) {
    import gtk.c.functions : gtk_message_dialog_new;
    import gobject.object : ObjectWrap;
    import std.typecons : Yes;
    auto dialogPtr = gtk_message_dialog_new(parent ? cast(GtkWindow*)parent._cPtr(No.Dup) : null,
            gtk.types.DialogFlags.Modal | gtk.types.DialogFlags.UseHeaderBar, gtk.types.MessageType.Question, gtk.types.ButtonsType.OkCancel, toStringz(message));
    MessageDialog dialog = ObjectWrap._getDObject!(MessageDialog)(dialogPtr, Yes.Take);
    scope (exit) {
        dialog.destroy();
    }
    dialog.setTransientFor(parent);
    dialog.setTitle(title);
    Entry entry = new Entry();
    if (initialValue.length > 0) {
        entry.setText(initialValue);
    }
    entry.connectActivate(delegate(Entry e) {
        dialog.response(gtk.types.ResponseType.Ok);
    });
    if (validate !is null) {
        entry.connectChanged(delegate(Editable e) {
            if (validate(entry.getText())) {
                entry.getStyleContext().removeClass("error");
                dialog.setResponseSensitive(gtk.types.ResponseType.Ok, true);
            } else {
                entry.getStyleContext().addClass("error");
                dialog.setResponseSensitive(gtk.types.ResponseType.Ok, false);
            }
        });
    }
    (cast(Container)dialog.getMessageArea()).add(entry);
    entry.showAll();
    dialog.setDefaultResponse(gtk.types.ResponseType.Ok);
    if (dialog.run() == gtk.types.ResponseType.Ok) {
        value = entry.getText();
        return true;
    } else {
        return false;
    }
}

/**
 * Shows a confirmation dialog with the optional ability to include an ignore checkbox
 * tied to gio.Settings so the user no longer has to see the dialog.
 */
bool showConfirmDialog(gtk.window.Window parent, string message, Settings settings = null, string promptKey = "") {
    if (settings !is null && !settings.getBoolean(promptKey)) return true;

    import gtk.c.functions : gtk_message_dialog_new;
    import gobject.object : ObjectWrap;
    import std.typecons : Yes;
    auto dialogPtr = gtk_message_dialog_new(parent ? cast(GtkWindow*)parent._cPtr(No.Dup) : null,
            gtk.types.DialogFlags.Modal | gtk.types.DialogFlags.UseHeaderBar, gtk.types.MessageType.Question, gtk.types.ButtonsType.OkCancel, toStringz(message));
    MessageDialog dialog = ObjectWrap._getDObject!(MessageDialog)(dialogPtr, Yes.Take);

    CheckButton cbPrompt = new CheckButton();
    cbPrompt.setLabel(_("Do not show this again"));
    cbPrompt.setMarginStart(12);
    (cast(Container)dialog.getContentArea()).add(cbPrompt);
    dialog.setDefaultResponse(gtk.types.ResponseType.Cancel);
    scope (exit) {
        dialog.destroy();
    }
    dialog.showAll();
    bool result = true;
    if (dialog.run() != gtk.types.ResponseType.Ok) {
        result = false;
    }
    settings.setBoolean(promptKey, !cbPrompt.getActive());
    return result;
}