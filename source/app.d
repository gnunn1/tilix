/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
import std.stdio;

import std.array;
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

    bool newProcess = false;
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
    try {
        environment.remove("WINDOWID");
    } catch (Exception e) {
        error("Unexpected error occurred", e);
    }

    string uhd = Util.getHomeDir();
    trace("UHD = " ~ uhd);

    // Look for execute command and convert it into a normal -e
    // We do this because this switch means take everything after
    // the switch as a command which GApplication options cannot handle
    // without a callback which D doesn't expose at this time.
    foreach(i, arg; args) {
        if (arg == "-x" || arg == "--execute") {
            string executeCommand = join(args[i+1 .. $], " ");
            trace("Execute Command: " ~ executeCommand);
            args = args[0..i];
            args ~= "-e";
            args ~= executeCommand;
            break;
        }
    }

    //textdomain
    textdomain(TERMINIX_DOMAIN);
    // Init GTK early so localization is available, pass empty
    // args so GTK doesn't attempt to interpret them
    string[] tempargs;
    Main.init(tempargs);

    trace(format("Starting terminix with %d arguments...", args.length));
    foreach(i, arg; args) {
        trace(format("arg[%d] = %s",i, arg));
        // Workaround issue with Unity and older Gnome Shell when DBusActivatable sometimes CWD is set to /, see #285
        if (arg == "--gapplication-service" && pwd == uhd && cwd == "/") {
            info("Detecting DBusActivatable with improper directory, correcting by setting CWD to PWD");
            infof("CWD = %s", cwd);
            infof("PWD = %s", pwd);
            cwd = pwd;
            FileUtils.chdir(cwd);
        } else if (arg == "--new-process") {
            newProcess = true;
        } else if (arg == "-v" || arg == "--version") {
            outputVersions();
            return 0;
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

    //Version checking cribbed from grestful, thanks!
    string gtkError = Version.checkVersion(GTK_VERSION_MAJOR, GTK_VERSION_MINOR, GTK_VERSION_PATCH);
    if (gtkError !is null) {
        MessageDialog dialog = new MessageDialog(null, DialogFlags.MODAL, MessageType.ERROR, ButtonsType.OK,
                format(_("Your GTK version is too old, you need at least GTK %d.%d.%d!"), GTK_VERSION_MAJOR, GTK_VERSION_MINOR, GTK_VERSION_PATCH), null);

        dialog.setDefaultResponse(ResponseType.OK);

        dialog.run();
        return 1;
    }

    trace("Creating app");
    auto terminixApp = new Terminix(newProcess);
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

private:
    void outputVersions() {
        import gx.gtk.vte: getVTEVersion, checkVTEFeature, TerminalFeature;
        import gtk.Version: Version;

        writeln("Versions");
        writeln(format("\tTerminix version: %s", APPLICATION_VERSION));
        writeln(format("\tVTE version: %s", getVTEVersion()));
        writeln(format("\tGTK Version: %d.%d.%d\n", Version.getMajorVersion(), Version.getMinorVersion(), Version.getMicroVersion()));
        writeln("Terminix Special Features");
        writeln(format("\tNotifications enabled=%b", checkVTEFeature(TerminalFeature.EVENT_NOTIFICATION)));
        writeln(format("\tTriggers enabled=%b", checkVTEFeature(TerminalFeature.EVENT_SCREEN_CHANGED)));
        writeln(format("\tBadges enabled=%b", checkVTEFeature(TerminalFeature.DISABLE_BACKGROUND_DRAW)));
    }