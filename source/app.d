/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
import std.stdio;

import std.experimental.logger;
import std.file;
import std.format;
import std.process;

import glib.FileUtils;
import glib.Util;

import gtk.Main;
import gtk.Version;
import gtk.MessageDialog;

import gx.i18n.l10n;
import gx.gtk.util;

import gx.terminix.application;
import gx.terminix.cmdparams;
import gx.terminix.constants;

int main(string[] args) {
    static if (USE_FILE_LOGGING) {
        sharedLog = new FileLogger("/tmp/terminix.log");
    }
    
    string cwd = Util.getCurrentDir();
    string pwd;
    string de;
    trace("CWD = " ~ cwd);
    try {
        pwd = environment["PWD"];
        de = environment["XDG_CURRENT_DESKTOP"];
        trace("PWD = " ~ pwd);
    } catch (Exception e) {
        trace("No PWD environment variable found");
    }
    
    string uhd = Util.getHomeDir();
    trace("UHD = " ~ uhd);
    
    trace(format("Starting terminix with %d arguments...", args.length));
    foreach(i, arg; args) {
        trace(format("arg[%d] = %s",i, arg));
        // Workaround issue with Unity and older Gnome Shell when DBusActivatable sometimes CWD is set to /, see #285
        if (arg == "--gapplication-service" && pwd == uhd && cwd == "/") {
            info("Detecting DBusActivatable with improper directory, correcting by setting CWD to PWD");
            info(format("CWD = %s", cwd));                
            info(format("PWD = %s", pwd));                
            cwd = pwd;
            FileUtils.chdir(cwd);
        }
    }
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
    // Init GTK early so localization is available, pass empty
    // args so GTK doesn't attempt to interpret them
    string[] tempargs;
    Main.init(tempargs);
    //Version checking cribbed from grestful, thanks!
    string gtkError = Version.checkVersion(GTK_VERSION_MAJOR, GTK_VERSION_MINOR, GTK_VERSION_PATCH);
    if (gtkError !is null) {
        //Main.init(args);

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
    }
    catch (Exception e) {
        error(_("Unexpected exception occurred"));
        error(_("Error: ") ~ e.msg);
    }
    return result;
}
