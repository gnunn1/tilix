/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.prefeditor.common;

import std.format;

import gio.Settings: GSettings = Settings;

import gtk.Box;
import gtk.Button;
import gtk.Label;
import gtk.Window;

import gx.gtk.vte;
import gx.i18n.l10n;

import gx.tilix.preferences;
import gx.tilix.prefeditor.advdialog;


/**
 * Creates the advanced UI (custom links, triggers) that is shared between
 * the preference and profile editor.
 *
 * Note need to use a delegate to get settings because in profile advdialog
 * the same UI is re-used but the profile settings object is switched. If we
 * don't use a delegate the references to the event handlers become pinned to
 * one object instance.
 */
void createAdvancedUI(Box box, GSettings delegate() scb, bool showTriggerLineSettings = false) {
    // Custom Links Section
    Label lblCustomLinks = new Label(format("<b>%s</b>", _("Custom Links")));
    lblCustomLinks.setUseMarkup(true);
    lblCustomLinks.setHalign(Align.START);
    box.add(lblCustomLinks);

    string customLinksDescription = _("A list of user defined links that can be clicked on in the terminal based on regular expression definitions.");
    box.packStart(createDescriptionLabel(customLinksDescription), false, false, 0);

    Button btnEditLink = new Button(_("Edit"));
    btnEditLink.setHexpand(false);
    btnEditLink.setHalign(Align.START);
    btnEditLink.addOnClicked(delegate(Button) {
        GSettings gs = scb();
        string[] links = gs.getStrv(SETTINGS_ALL_CUSTOM_HYPERLINK_KEY);
        EditCustomLinksDialog dlg = new EditCustomLinksDialog(cast(Window) box.getToplevel(), links);
        scope (exit) {
            dlg.destroy();
        }
        dlg.showAll();
        if (dlg.run() == ResponseType.APPLY) {
            gs.setStrv(SETTINGS_ALL_CUSTOM_HYPERLINK_KEY, dlg.getLinks());
        }
    });
    box.packStart(btnEditLink, false, false, 0);

    if (checkVTEFeature(TerminalFeature.EVENT_SCREEN_CHANGED)) {
        // Triggers Section
        Label lblTriggers = new Label(format("<b>%s</b>", _("Triggers")));
        lblTriggers.setUseMarkup(true);
        lblTriggers.setHalign(Align.START);
        lblTriggers.setMarginTop(12);
        box.packStart(lblTriggers, false, false, 0);

        string triggersDescription = _("Triggers are regular expressions that are used to check against output text in the terminal. When a match is detected the configured action is executed.");
        box.packStart(createDescriptionLabel(triggersDescription), false, false, 0);

        Button btnEditTriggers = new Button(_("Edit"));
        btnEditTriggers.setHexpand(false);
        btnEditTriggers.setHalign(Align.START);
        btnEditTriggers.addOnClicked(delegate(Button) {
            GSettings gs = scb();
            EditTriggersDialog dlg = new EditTriggersDialog(cast(Window) box.getToplevel(), gs, showTriggerLineSettings);
            scope (exit) {
                dlg.destroy();
            }
            dlg.showAll();
            if (dlg.run() == ResponseType.APPLY) {
                gs.setStrv(SETTINGS_ALL_TRIGGERS_KEY, dlg.getTriggers());
            }
        });
        box.packStart(btnEditTriggers, false, false, 0);
    }
}

/**
 * Create a description label that handles long lines
 */
Label createDescriptionLabel(string desc) {
    Label lblDescription = new Label(desc);
    lblDescription.setUseMarkup(true);
    lblDescription.setSensitive(false);
    lblDescription.setLineWrap(true);
    lblDescription.setHalign(Align.START);
    lblDescription.setMaxWidthChars(70);
    return lblDescription;
}