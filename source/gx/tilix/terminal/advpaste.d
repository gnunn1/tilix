/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.advpaste;

import std.experimental.logger;
import std.format;
import std.string;

import gdk.event;
import gdk.event_key;
import gdk.types;
import gx.gtk.keys;
import gx.gtk.types;
import gdk.types;

import gio.settings: Settings = Settings;

import gtk.box;
import gtk.types;
import gtk.check_button;
import gtk.types;
import gtk.dialog;
import gtk.types;
import gtk.label;
import gtk.types;
import gtk.spin_button;
import gtk.types;
import gtk.text_buffer;
import gtk.types;
import gtk.text_tag_table;
import gtk.types;
import gtk.text_view;
import gtk.types;
import gtk.scrolled_window;
import gtk.types;
import gtk.widget;
import gtk.types;
import gtk.window;
import gtk.types;
import gtk.text_iter;

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

    Settings gsSettings;

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

        Box b = new Box(gtk.types.Orientation.Vertical, 6);
        if (unsafe) {
            string[3] msg = getUnsafePasteMessage();
            Label lblUnsafe = new Label("<span weight='bold' size='large'>" ~ msg[0] ~ "</span>\n" ~ msg[1] ~ "\n" ~ msg[2]);
            lblUnsafe.setUseMarkup(true);
            lblUnsafe.setLineWrap(true);
            b.add(lblUnsafe);
            getWidgetForResponse(gtk.types.ResponseType.Apply).getStyleContext().addClass("destructive-action");
        }

        buffer = new TextBuffer(new TextTagTable());
        buffer.setText(text, cast(int)text.length);
        TextView view = new TextView();
        view.setBuffer(buffer);
        view.connectKeyPressEvent(delegate(EventKey event, Widget w) {
            uint keyval = event.keyval;
            if (keyval == Keys.Return && (event.state & gdk.types.ModifierType.ControlMask)) {
                response(gtk.types.ResponseType.Apply);
                return true;
            }
            return false;
        });
        ScrolledWindow sw = new ScrolledWindow();
        sw.add(view);
        sw.setShadowType(ShadowType.EtchedIn);
        sw.setPolicy(PolicyType.Automatic, PolicyType.Automatic);
        sw.setHexpand(true);
        sw.setVexpand(true);
        sw.setSizeRequest(400, 140);

        b.add(sw);

        Label lblTransform = new Label(format("<b>%s</b>", _("Transform")));
        lblTransform.setUseMarkup(true);
        lblTransform.setHalign(Align.Start);
        lblTransform.setMarginTop(6);
        b.add(lblTransform);

        //Tabs to Spaces
        Box bTabs = new Box(gtk.types.Orientation.Horizontal, 6);
        cbTabsToSpaces = CheckButton.newWithLabel(_("Convert spaces to tabs"));
        gsSettings.bind(SETTINGS_ADVANCED_PASTE_REPLACE_TABS_KEY, cbTabsToSpaces, "active", SettingsBindFlags.Default);
        bTabs.add(cbTabsToSpaces);

        sbTabWidth = SpinButton.newWithRange(0, 32, 1);
        gsSettings.bind(SETTINGS_ADVANCED_PASTE_SPACE_COUNT_KEY, sbTabWidth.getAdjustment(), "value", SettingsBindFlags.Default);
        gsSettings.bind(SETTINGS_ADVANCED_PASTE_REPLACE_TABS_KEY, sbTabWidth, "sensitive", SettingsBindFlags.Default);
        bTabs.add(sbTabWidth);

        b.add(bTabs);

        cbConvertCRLF = CheckButton.newWithLabel(_("Convert CRLF and CR to LF"));
        gsSettings.bind(SETTINGS_ADVANCED_PASTE_REPLACE_CRLF_KEY, cbConvertCRLF, "active", SettingsBindFlags.Default);
        b.add(cbConvertCRLF);

        getContentArea().add(b);
    }

    string transform() {
        TextIter start, end;
        buffer.getBounds(start, end);
        string text = buffer.getText(start, end, true);
        if (gsSettings.getBoolean(SETTINGS_ADVANCED_PASTE_REPLACE_TABS_KEY)) {
            text = text.detab(gsSettings.getInt(SETTINGS_ADVANCED_PASTE_SPACE_COUNT_KEY));
        }
        if (gsSettings.getBoolean(SETTINGS_ADVANCED_PASTE_REPLACE_CRLF_KEY)) {
            text = text.replace("\r\n", "\n");
            text = text.replace("\r", "\n");

        }
        return text;
    }

public:
    this(Window parent, string text, bool unsafe) {
        super();
        setTitle(_("Advanced Paste"));
        setTransientFor(parent);
        setModal(true);
        addButton(_("Paste"), gtk.types.ResponseType.Apply);
        addButton(_("Cancel"), gtk.types.ResponseType.Cancel);
        setDefaultResponse(gtk.types.ResponseType.Apply);
        gsSettings = new Settings(SETTINGS_ID);
        createUI(text, unsafe);
    }

    @property string text() {
        TextIter start, end;
        buffer.getBounds(start, end);
        return buffer.getText(start, end, true);
    }
}
