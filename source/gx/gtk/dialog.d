/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.dialog;

// GID imports - gio
import gio.settings : GSettings = Settings;

// GID imports - gobject
import gobject.object : ObjectWrap;

// GID imports - gtk
import gtk.box : Box;
import gtk.check_button : CheckButton;
import gtk.c.functions : gtk_message_dialog_new;
import gtk.types : DialogFlags, MessageType, ButtonsType;
import gtk.c.types : GtkWidget, GtkWindow;
import gtk.editable : Editable;
import gtk.entry : Entry;
import gtk.message_dialog : MessageDialog;
import gtk.types : DialogFlags, MessageType, ButtonsType, ResponseType;
import gtk.widget : Widget;
import gtk.window : Window;

import gid.gid : No;

import gx.i18n.l10n;

/**
 * Displays an error message in a dialog
 */
void showErrorDialog(Window parent, string message, string title = null) {
    showMessageDialog(MessageType.Error, parent, message, title);
}

/**
 * Displays a message dialog of the specified type
 */
void showMessageDialog(MessageType mt, Window parent, string message, string title = null) {
    DialogFlags flags = DialogFlags.Modal | DialogFlags.UseHeaderBar;
    GtkWidget* widget = gtk_message_dialog_new(
        parent ? cast(GtkWindow*) parent._cPtr(No.Dup) : null,
        flags,
        cast(MessageType) mt,
        ButtonsType.Ok,
        message.ptr,
        null
    );
    MessageDialog dialog = ObjectWrap._getDObject!MessageDialog(cast(void*) widget, No.Take);
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
bool showInputDialog(Window parent, out string value, string initialValue = "", string title = "", string message = "", OnValidate validate = null) {
    DialogFlags flags = DialogFlags.Modal | DialogFlags.UseHeaderBar;
    GtkWidget* widget = gtk_message_dialog_new(
        parent ? cast(GtkWindow*) parent._cPtr(No.Dup) : null,
        flags,
        MessageType.Question,
        ButtonsType.OkCancel,
        message.ptr,
        null
    );
    MessageDialog dialog = ObjectWrap._getDObject!MessageDialog(cast(void*) widget, No.Take);
    scope (exit) {
        dialog.destroy();
    }
    dialog.setTransientFor(parent);
    dialog.setTitle(title);
    Entry entry = new Entry();
    if (initialValue.length > 0) {
        entry.setText(initialValue);
    }
    entry.connectActivate(delegate() {
        dialog.response(ResponseType.Ok);
    });
    if (validate !is null) {
        entry.connectChanged(delegate() {
            if (validate(entry.getText())) {
                entry.getStyleContext().removeClass("error");
                dialog.setResponseSensitive(ResponseType.Ok, true);
            } else {
                entry.getStyleContext().addClass("error");
                dialog.setResponseSensitive(ResponseType.Ok, false);
            }
        });
    }
    Widget messageArea = dialog.getMessageArea();
    Box messageBox = cast(Box) messageArea;
    if (messageBox !is null) {
        messageBox.add(entry);
    }
    entry.showAll();
    dialog.setDefaultResponse(ResponseType.Ok);
    if (dialog.run() == ResponseType.Ok) {
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
bool showConfirmDialog(Window parent, string message, GSettings settings = null, string promptKey = "") {
    if (settings !is null && !settings.getBoolean(promptKey)) return true;

    DialogFlags flags = DialogFlags.Modal | DialogFlags.UseHeaderBar;
    GtkWidget* widget = gtk_message_dialog_new(
        parent ? cast(GtkWindow*) parent._cPtr(No.Dup) : null,
        flags,
        MessageType.Question,
        ButtonsType.OkCancel,
        message.ptr,
        null
    );
    MessageDialog dialog = ObjectWrap._getDObject!MessageDialog(cast(void*) widget, No.Take);
    CheckButton cbPrompt = CheckButton.newWithLabel(_("Do not show this again"));
    cbPrompt.marginStart = 12;
    dialog.getContentArea().add(cbPrompt);
    dialog.setDefaultResponse(ResponseType.Cancel);
    scope (exit) {
        dialog.destroy();
    }
    dialog.showAll();
    bool result = true;
    if (dialog.run() != ResponseType.Ok) {
        result = false;
    }
    settings.setBoolean(promptKey, !cbPrompt.getActive());
    return result;
}