/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.dialog;

import gtk.Entry;
import gtk.MessageDialog;
import gtk.Window;

/**
 * Displays an error message in a dialog
 */
void showErrorDialog(Window parent, string message, string title = null) {
    MessageDialog dialog = new MessageDialog(parent, DialogFlags.MODAL + DialogFlags.USE_HEADER_BAR, MessageType.ERROR, ButtonsType.OK, message, null);
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