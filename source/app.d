/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
import std.stdio;

import std.experimental.logger;
import std.format;
import std.process;

import gtk.Main;
import gtk.Version;
import gtk.MessageDialog;

import gx.i18n.l10n;
import gx.gtk.util;

import gx.terminix.application;
import gx.terminix.cmdparams;
import gx.terminix.constants;

int main(string[] args) {
    trace(format("Starting terminix with %d arguments...", args.length));
    //append TERMINIX_ID to args if present
    try {
        string terminalUUID = environment["TERMINIX_ID"];
        trace("Inserting terminal UUID " ~ terminalUUID);
        args ~= ("--" ~ CMD_TERMINAL_UUID ~ "=" ~ terminalUUID);
    }
    catch (Exception e) {
        trace("No terminix UUID found");
    }
    //textdomain
    textdomain(TERMINIX_DOMAIN);
    //Version checking cribbed from grestful, thanks!
    string gtkError = Version.checkVersion(GTK_VERSION_MAJOR, GTK_VERSION_MINOR, GTK_VERSION_PATCH);
    if (gtkError !is null) {
        Main.init(args);

        MessageDialog dialog = new MessageDialog(null, DialogFlags.MODAL, MessageType.ERROR, ButtonsType.OK,
                format(_("Your GTK version is too old, you need at least GTK %d.%d.%d!"), GTK_VERSION_MAJOR, GTK_VERSION_MINOR, GTK_VERSION_PATCH), null);

        dialog.setDefaultResponse(ResponseType.OK);

        dialog.run();
        return 1;
    }
    
    trace("Creating app");
    auto terminixApp = new Terminix();
    int result;
    try {
        trace("Running application...");
        result = terminixApp.run(args);
        trace("App completed...");
        version (Localize) {
            saveFile(std.conv.to!string(std.path.withExtension(args[0], ".pot")));
        }
    }
    catch (Exception e) {
        error(_("Unexpected exception occurred"));
        error(_("Error: ") ~ e.msg);
    }
    return result;
}
