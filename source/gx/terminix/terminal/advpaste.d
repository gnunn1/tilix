/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.terminal.advpaste;

import std.experimental.logger;

import gtk.Box;
import gtk.Dialog;
import gtk.TextBuffer;
import gtk.TextTagTable;
import gtk.TextView;
import gtk.ScrolledWindow;
import gtk.Window;

import gx.i18n.l10n;

class AdvancedPasteDialog: Dialog {

private:

    TextBuffer buffer;

    void createUI(string text) {
        with (getContentArea()) {
            setMarginLeft(18);
            setMarginRight(18);
            setMarginTop(18);
            setMarginBottom(18);
        }

        buffer = new TextBuffer(new TextTagTable());
        buffer.setText(text);
        TextView view = new TextView(buffer);
        ScrolledWindow sw = new ScrolledWindow(view);
        sw.setShadowType(ShadowType.ETCHED_IN);
        sw.setPolicy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        sw.setHexpand(true);
        sw.setVexpand(true);
        sw.setSizeRequest(400, 300);

        Box b = new Box(Orientation.VERTICAL, 6);
        b.add(sw);
        getContentArea().add(b);        
    }

public:
    this(Window parent, string text) {
        super(_("Advanced Paste"), parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("Paste"), _("Cancel")], [GtkResponseType.APPLY, GtkResponseType.CANCEL]);
        setDefaultResponse(GtkResponseType.APPLY);
        createUI(text);        
    }

    @property string text() {
        return buffer.getText();
    }
}
