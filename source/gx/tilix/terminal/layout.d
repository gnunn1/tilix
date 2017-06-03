/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.layout;

import std.format;

import gtk.Dialog;
import gtk.Entry;
import gtk.Grid;
import gtk.Label;
import gtk.Version;
import gtk.Window;

import gx.i18n.l10n;
import gx.gtk.vte;

import gx.tilix.prefeditor.titleeditor;

/**
 * Dialog that enables the user to set the layout options for a terminal
 */
class LayoutDialog: Dialog {

private:
    Entry eBadge;
    Entry eTitle;
    Entry eCommand;

public:
    this(Window window) {
        super(_("Layout Options"), window, DialogFlags.MODAL + DialogFlags.USE_HEADER_BAR, [_("OK"), _("Cancel")], [ResponseType.OK, ResponseType.CANCEL]);
        setDefaultResponse(ResponseType.OK);
        setTransientFor(window);
        setDefaultSize(400, -1);

        Grid grid = new Grid();
        grid.setMarginTop(18);
        grid.setMarginBottom(18);
        grid.setMarginLeft(18);
        grid.setMarginRight(18);
        grid.setColumnSpacing(12);
        grid.setRowSpacing(6);

        int row = 0;

        Label lblActive = new Label(format("<b>%s</b>", _("Active")));
        lblActive.setUseMarkup(true);
        lblActive.setHalign(Align.START);
        grid.attach(lblActive, 0, row, 2, 1);
        row++;

        Label lblTitle = new Label(_("Title"));
        lblTitle.setHalign(Align.END);
        grid.attach(lblTitle, 0, row, 1, 1);
        eTitle = new Entry();
        eTitle.setWidthChars(20);
        eTitle.setHexpand(true);
        if (Version.checkVersion(3,16, 0).length == 0) {
            grid.attach(createTitleEditHelper(eTitle, TitleEditScope.TERMINAL), 1, row, 1, 1);
        } else {
            grid.attach(eTitle, 1, row, 1, 1);
        }
        row++;

        if (checkVTEFeature(TerminalFeature.DISABLE_BACKGROUND_DRAW)) {
            Label lblBadge = new Label(_("Badge"));
            lblBadge.setHalign(Align.END);
            grid.attach(lblBadge, 0, row, 1, 1);
            eBadge = new Entry();
            eBadge.setHexpand(true);
            eBadge.setWidthChars(20);
            if (Version.checkVersion(3,16, 0).length == 0) {
                grid.attach(createTitleEditHelper(eBadge, TitleEditScope.TERMINAL), 1, row, 1, 1);
            } else {
                grid.attach(eBadge, 1, row, 1, 1);
            }
            row++;
        }

        Label lblLoad = new Label(format("<b>%s</b>", _("Session Load")));
        lblLoad.setUseMarkup(true);
        lblLoad.setHalign(Align.START);
        lblLoad.setMarginTop(6);
        grid.attach(lblLoad, 0, row, 2, 1);
        row++;

        Label lblCommand = new Label(_("Command"));
        lblCommand.setHalign(Align.END);

        grid.attach(lblCommand, 0, row, 1, 1);
        eCommand = new Entry();
        eCommand.setWidthChars(20);
        grid.attach(eCommand, 1, row, 1, 1);
        row++;

        Label lblInfo = new Label(_("Active options are always in effect and apply immediately.\nSession Load options only apply when loading a session file."));
        lblInfo.setSensitive(false);
        lblInfo.setMarginTop(6);
        lblInfo.setLineWrap(true);
        grid.attach(lblInfo, 0, row, 2, 1);
        row++;

        getContentArea().add(grid);
    }

    @property string title() {
        return eTitle.getText();
    }

    @property void title(string value) {
        if (value.length > 0) {
            eTitle.setText(value);
        }
    }

    @property string badge() {
        if (!checkVTEFeature(TerminalFeature.DISABLE_BACKGROUND_DRAW)) return "";
        return eBadge.getText();
    }

    @property void badge(string value) {
        if (checkVTEFeature(TerminalFeature.DISABLE_BACKGROUND_DRAW) && value.length > 0) {
            eBadge.setText(value);
        }
    }

    @property string command() {
        return eCommand.getText();
    }

    @property void command(string value) {
        if (value.length > 0) {
            eCommand.setText(value);
        }
    }
}