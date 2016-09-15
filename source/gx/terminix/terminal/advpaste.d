/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.terminal.advpaste;

import std.experimental.logger;
import std.format;
import std.string;

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
import gtk.Window;

import gx.i18n.l10n;

import gx.terminix.preferences;

string[3] getUnsafePasteMessage() {
    string[3] result = [_("This command is asking for Administrative access to your computer"),
                        _("Copying commands from the internet can be dangerous. "),
                        _("Be sure you understand what each part of this command does.")];

    return result;
}

const string CONTROL_CODES = [0:8,11,14:32];
/**
 * A dialog that is shown to support advance paste. It allows the user
 * to review and edit the content as well as performing various transformations
 * before pasting.
 */
class AdvancedPasteDialog: Dialog {

private:

    GSettings gsSettings;

    TextBuffer buffer;

    CheckButton cbRemoveCC;

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
        buffer.addOnChanged(delegate(TextBuffer) {
            updateUI();
        });
        TextView view = new TextView(buffer);
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
        CheckButton cbTabsToSpaces = new CheckButton(_("Convert spaces to tabs"));
        gsSettings.bind(SETTINGS_ADVANCED_PASTE_REPLACE_TABS_KEY, cbTabsToSpaces, "active", GSettingsBindFlags.DEFAULT);
        bTabs.add(cbTabsToSpaces);

        SpinButton sbTabWidth = new SpinButton(0, 32, 1);
        gsSettings.bind(SETTINGS_ADVANCED_PASTE_SPACE_COUNT_KEY, sbTabWidth.getAdjustment(), "value", GSettingsBindFlags.DEFAULT);
        gsSettings.bind(SETTINGS_ADVANCED_PASTE_REPLACE_TABS_KEY, sbTabWidth, "sensitive", GSettingsBindFlags.DEFAULT);
        bTabs.add(sbTabWidth);

        b.add(bTabs);

        CheckButton cbConvertCRLF = new CheckButton(_("Convert CRLF and CR to LF"));
        gsSettings.bind(SETTINGS_ADVANCED_PASTE_REPLACE_CRLF_KEY, cbConvertCRLF, "active", GSettingsBindFlags.DEFAULT);
        b.add(cbConvertCRLF);

        cbRemoveCC = new CheckButton(_("Remove unsafe control codes"));
        gsSettings.bind(SETTINGS_ADVANCED_PASTE_REMOVE_CONTROL_CODES_KEY, cbRemoveCC, "active", GSettingsBindFlags.DEFAULT);
        b.add(cbRemoveCC);

        getContentArea().add(b);
        updateUI();
    }

    void updateUI() {
        cbRemoveCC.setSensitive(hasControlCodes(buffer.getText()));
    }

    bool hasControlCodes(string text) {
        foreach(code; CONTROL_CODES) {
            if (text.indexOf(code) >= 0) return true;
        }
        return false;
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
        if (hasControlCodes(text) && gsSettings.getBoolean(SETTINGS_ADVANCED_PASTE_REMOVE_CONTROL_CODES_KEY)) {
            text = text.removechars(CONTROL_CODES);
        }
        return text;
    }

public:
    this(Window parent, string text, bool unsafe) {
        super(_("Advanced Paste"), parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("Paste"), _("Cancel")], [GtkResponseType.APPLY, GtkResponseType.CANCEL]);
        setDefaultResponse(GtkResponseType.APPLY);
        gsSettings = new GSettings(SETTINGS_ID);
        createUI(text, unsafe);        
    }

    @property string text() {
        return transform();
    }
}
