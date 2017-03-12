/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.advpaste;

import std.experimental.logger;
import std.format;
import std.string;

import gdk.Event;
import gdk.Keysyms;

import gio.Settings: GSettings = Settings;

import gtk.Box;
import gtk.CheckButton;
import gtk.Dialog;
import gtk.Label;
import gtk.SpinButton;
import gtk.TextBuffer;
import gtk.TextTagTable;
import gtk.TextView;
import gtk.ScrolledWindow;
import gtk.Widget;
import gtk.Window;

import gx.i18n.l10n;

import gx.tilix.preferences;

string[3] getUnsafePasteMessage() {
    string[3] result = [_("This command is asking for Administrative access to your computer"),
                        _("Copying commands from the internet can be dangerous. "),
                        _("Be sure you understand what each part of this command does.")];

    return result;
}

/**
 * A dialog that is shown to support advance paste. It allows the user
 * to review and edit the content as well as performing various transformations
 * before pasting.
 */
class AdvancedPasteDialog: Dialog {

private:

    GSettings gsSettings;

    TextBuffer buffer;
    CheckButton cbTabsToSpaces;
    SpinButton sbTabWidth;

    CheckButton cbConvertCRLF;

    void createUI(string text, bool unsafe) {
        with (getContentArea()) {
            setMarginLeft(18);
            setMarginRight(18);
            setMarginTop(18);
            setMarginBottom(18);
        }

        Box b = new Box(Orientation.VERTICAL, 6);
        if (unsafe) {
            string[3] msg = getUnsafePasteMessage();
            Label lblUnsafe = new Label("<span weight='bold' size='large'>" ~ msg[0] ~ "</span>\n" ~ msg[1] ~ "\n" ~ msg[2]);
            lblUnsafe.setUseMarkup(true);
            lblUnsafe.setLineWrap(true);
            b.add(lblUnsafe);
            getWidgetForResponse(ResponseType.APPLY).getStyleContext().addClass("destructive-action");
        }

        buffer = new TextBuffer(new TextTagTable());
        buffer.setText(text);
        TextView view = new TextView(buffer);
        view.addOnKeyPress(delegate(Event event, Widget w) {
            uint keyval;
            event.getKeyval(keyval);
            if (keyval == GdkKeysyms.GDK_Return && (event.key.state & GdkModifierType.CONTROL_MASK)) {
                response(GtkResponseType.APPLY);
                return true;
            }
            return false;
        });
        ScrolledWindow sw = new ScrolledWindow(view);
        sw.setShadowType(ShadowType.ETCHED_IN);
        sw.setPolicy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        sw.setHexpand(true);
        sw.setVexpand(true);
        sw.setSizeRequest(400, 140);

        b.add(sw);

        Label lblTransform = new Label(format("<b>%s</b>", _("Transform")));
        lblTransform.setUseMarkup(true);
        lblTransform.setHalign(Align.START);
        lblTransform.setMarginTop(6);
        b.add(lblTransform);

        //Tabs to Spaces
        Box bTabs = new Box(Orientation.HORIZONTAL, 6);
        cbTabsToSpaces = new CheckButton(_("Convert spaces to tabs"));
        gsSettings.bind(SETTINGS_ADVANCED_PASTE_REPLACE_TABS_KEY, cbTabsToSpaces, "active", GSettingsBindFlags.DEFAULT);
        bTabs.add(cbTabsToSpaces);

        sbTabWidth = new SpinButton(0, 32, 1);
        gsSettings.bind(SETTINGS_ADVANCED_PASTE_SPACE_COUNT_KEY, sbTabWidth.getAdjustment(), "value", GSettingsBindFlags.DEFAULT);
        gsSettings.bind(SETTINGS_ADVANCED_PASTE_REPLACE_TABS_KEY, sbTabWidth, "sensitive", GSettingsBindFlags.DEFAULT);
        bTabs.add(sbTabWidth);

        b.add(bTabs);

        cbConvertCRLF = new CheckButton(_("Convert CRLF and CR to LF"));
        gsSettings.bind(SETTINGS_ADVANCED_PASTE_REPLACE_CRLF_KEY, cbConvertCRLF, "active", GSettingsBindFlags.DEFAULT);
        b.add(cbConvertCRLF);

        getContentArea().add(b);
    }

    string transform() {
        string text = buffer.getText();
        if (gsSettings.getBoolean(SETTINGS_ADVANCED_PASTE_REPLACE_TABS_KEY)) {
            text = text.detab(gsSettings.getInt(SETTINGS_ADVANCED_PASTE_SPACE_COUNT_KEY));
        }
        if (gsSettings.getBoolean(SETTINGS_ADVANCED_PASTE_REPLACE_CRLF_KEY)) {
            text = text.replace("/r/n", "/n");
            text = text.replace("/r", "/n");

        }
        return text;
    }

public:
    this(Window parent, string text, bool unsafe) {
        super(_("Advanced Paste"), parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("Paste"), _("Cancel")], [GtkResponseType.APPLY, GtkResponseType.CANCEL]);
        setTransientFor(parent);
        setDefaultResponse(GtkResponseType.APPLY);
        gsSettings = new GSettings(SETTINGS_ID);
        createUI(text, unsafe);
    }

    @property string text() {
        return transform();
    }
}
