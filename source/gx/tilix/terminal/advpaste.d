/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.advpaste;

import std.experimental.logger;
import std.format;
import std.string;

import gdk.event : Event;
import gdk.event_key : EventKey;
// GID does not provide gdk.keysyms, define required constants locally
private enum GdkKeysyms { GDK_Return = 0xff0d, GDK_Escape = 0xff1b }

import gio.settings: GSettings = Settings;
import gio.types : SettingsBindFlags;

import gtk.box : Box;
import gtk.check_button : CheckButton;
import gtk.dialog : Dialog;
import gtk.label : Label;
import gtk.spin_button : SpinButton;
import gtk.text_buffer : TextBuffer;
import gtk.text_iter : TextIter;
import gtk.text_tag_table : TextTagTable;
import gtk.text_view : TextView;
import gtk.scrolled_window : ScrolledWindow;
import gtk.widget : Widget;
import gtk.window : Window;
import gtk.types : Align, DialogFlags, Orientation, PolicyType, ResponseType, ShadowType;
import gdk.types : ModifierType;

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

        Box b = new Box(Orientation.Vertical, 6);
        if (unsafe) {
            string[3] msg = getUnsafePasteMessage();
            Label lblUnsafe = new Label("<span weight='bold' size='large'>" ~ msg[0] ~ "</span>\n" ~ msg[1] ~ "\n" ~ msg[2]);
            lblUnsafe.setUseMarkup(true);
            lblUnsafe.setLineWrap(true);
            b.add(lblUnsafe);
            getWidgetForResponse(ResponseType.Apply).getStyleContext().addClass("destructive-action");
        }

        buffer = new TextBuffer(new TextTagTable());
        buffer.setText(text, cast(int)text.length);
        TextView view = TextView.newWithBuffer(buffer);
        view.connectKeyPressEvent(delegate(EventKey event) {
            uint keyval = event.keyval;
            if (keyval == GdkKeysyms.GDK_Return && (event.state & ModifierType.ControlMask)) {
                response(ResponseType.Apply);
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
        Box bTabs = new Box(Orientation.Horizontal, 6);
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
        TextIter startIter, endIter;
        buffer.getBounds(startIter, endIter);
        string text = buffer.getText(startIter, endIter, false);
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
        addButton(_("Paste"), ResponseType.Apply);
        addButton(_("Cancel"), ResponseType.Cancel);
        setDefaultResponse(ResponseType.Apply);
        gsSettings = new GSettings(SETTINGS_ID);
        createUI(text, unsafe);
    }

    @property string text() {
        return transform();
    }
}
