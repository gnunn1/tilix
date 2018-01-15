/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.dialog;

import gio.Settings: GSettings = Settings;

import gtk.CheckButton;
import gtk.Entry;
import gtk.MessageDialog;
import gtk.Window;

import gx.i18n.l10n;

/**
 * Displays an error message in a dialog
 */
void showErrorDialog(Window parent, string message, string title = null) {
    showMessageDialog(MessageType.ERROR, parent, message, title);
}

/**
 * Displays a message dialog of the specified type
 */
void showMessageDialog(MessageType mt, Window parent, string message, string title = null) {
    MessageDialog dialog = new MessageDialog(parent, DialogFlags.MODAL + DialogFlags.USE_HEADER_BAR, mt, ButtonsType.OK, message, null);
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
    MessageDialog dialog = new MessageDialog(parent, DialogFlags.MODAL + DialogFlags.USE_HEADER_BAR, MessageType.QUESTION, ButtonsType.OK_CANCEL, message, null);
    scope (exit) {
        dialog.destroy();
    }
    dialog.setTransientFor(parent);
    dialog.setTitle(title);
    Entry entry;
    if (initialValue.length > 0) {
        entry = new Entry(initialValue);
    } else {
        entry = new Entry();
    }
    entry.addOnActivate(delegate(Entry) {
        dialog.response(ResponseType.OK);
    });
    if (validate !is null) {
        entry.addOnChanged(delegate(EditableIF) {
            if (validate(entry.getText)) {
                entry.getStyleContext().removeClass("error");
                dialog.setResponseSensitive(ResponseType.OK, true);
            } else {
                entry.getStyleContext().addClass("error");
                dialog.setResponseSensitive(ResponseType.OK, false);
            }
        });
    }
    dialog.getMessageArea().add(entry);
    entry.showAll();
    dialog.setDefaultResponse(ResponseType.OK);
    if (dialog.run() == ResponseType.OK) {
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

    MessageDialog dialog = new MessageDialog(parent, DialogFlags.MODAL + DialogFlags.USE_HEADER_BAR, MessageType.QUESTION, ButtonsType.OK_CANCEL,
            message, null);
    CheckButton cbPrompt = new CheckButton(_("Do not show this again"));
    cbPrompt.setMarginLeft(12);
    dialog.getContentArea().add(cbPrompt);
    dialog.setDefaultResponse(ResponseType.CANCEL);
    scope (exit) {
        dialog.destroy();
    }
    dialog.showAll();
    bool result = true;
    if (dialog.run() != ResponseType.OK) {
        result = false;
    }
    settings.setBoolean(promptKey, !cbPrompt.getActive());
    return result;
}