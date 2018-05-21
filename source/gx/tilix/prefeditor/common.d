/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.prefeditor.common;

import std.format;
import std.experimental.logger;

import gio.Settings: GSettings = Settings;

import gtk.Box;
import gtk.Button;
import gtk.Grid;
import gtk.Label;
import gtk.Window;
import gtk.Version;

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
void createAdvancedUI(Grid grid, ref uint row, GSettings delegate() scb, bool showTriggerLineSettings = false) {
    // Custom Links Section
    Label lblCustomLinks = new Label(format("<b>%s</b>", _("Custom Links")));
    lblCustomLinks.setUseMarkup(true);
    lblCustomLinks.setHalign(Align.START);
    grid.attach(lblCustomLinks, 0, row, 3, 1);
    row++;

    string customLinksDescription = _("A list of user defined links that can be clicked on in the terminal based on regular expression definitions.");
    grid.attach(createDescriptionLabel(customLinksDescription), 0, row, 2, 1);

    Button btnEditLink = new Button(_("Edit"));
    btnEditLink.setHalign(Align.FILL);
    btnEditLink.setValign(Align.CENTER);    

    btnEditLink.addOnClicked(delegate(Button) {
        GSettings gs = scb();
        string[] links = gs.getStrv(SETTINGS_ALL_CUSTOM_HYPERLINK_KEY);
        EditCustomLinksDialog dlg = new EditCustomLinksDialog(cast(Window) grid.getToplevel(), links);
        scope (exit) {
            dlg.destroy();
        }
        dlg.showAll();
        if (dlg.run() == ResponseType.APPLY) {
            gs.setStrv(SETTINGS_ALL_CUSTOM_HYPERLINK_KEY, dlg.getLinks());
        }
    });
    grid.attach(btnEditLink, 2, row, 1, 1);
    row++;

    if (checkVTEFeature(TerminalFeature.EVENT_SCREEN_CHANGED)) {
        // Triggers Section
        Label lblTriggers = new Label(format("<b>%s</b>", _("Triggers")));
        lblTriggers.setUseMarkup(true);
        lblTriggers.setHalign(Align.START);
        lblTriggers.setMarginTop(12);
        grid.attach(lblTriggers, 0, row, 3, 1);
        row++;

        string triggersDescription = _("Triggers are regular expressions that are used to check against output text in the terminal. When a match is detected the configured action is executed.");
        grid.attach(createDescriptionLabel(triggersDescription), 0, row, 2, 1);

        Button btnEditTriggers = new Button(_("Edit"));
        btnEditTriggers.setHalign(Align.FILL);
        btnEditTriggers.setValign(Align.CENTER);    

        btnEditTriggers.addOnClicked(delegate(Button) {
            GSettings gs = scb();
            EditTriggersDialog dlg = new EditTriggersDialog(cast(Window) grid.getToplevel(), gs, showTriggerLineSettings);
            scope (exit) {
                dlg.destroy();
            }
            dlg.showAll();
            if (dlg.run() == ResponseType.APPLY) {
                gs.setStrv(SETTINGS_ALL_TRIGGERS_KEY, dlg.getTriggers());
            }
        });
        grid.attach(btnEditTriggers, 2, row, 1, 1);
        row++;
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
    if (Version.checkVersion(3, 16, 0).length == 0) {
        lblDescription.setXalign(0.0);
    }
    lblDescription.setMaxWidthChars(70);
    return lblDescription;
}