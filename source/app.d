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

	trace("Starting terminix...");
	//Version checking cribbed from grestful, thanks!
	string gtkError = Version.checkVersion(GTK_VERSION_MAJOR, GTK_VERSION_MINOR, GTK_VERSION_PATCH);
	if (gtkError !is null)	{
		Main.init(args);
		
		MessageDialog dialog = new MessageDialog(
			null,
			DialogFlags.MODAL,
			MessageType.ERROR,
			ButtonsType.OK,
            format(_("Your GTK version is too old, you need at least GTK %d.%d.%d!"), GTK_VERSION_MAJOR, GTK_VERSION_MINOR, GTK_VERSION_PATCH),
			null
			);
		
		dialog.setDefaultResponse(ResponseType.OK);
		
		dialog.run();
		return 1;
	}
    
	trace("Reading command parameters...");
    CommandParameters cp = CommandParameters(args);
    if (!cp.exit) {
        trace("Creating app");
        auto terminixApp = new Terminix(cp);
        //Bypass GTK command line handling since we handle it ourselves
        string[] tempArgs;
        int result;
        try {
            trace("Running application...");
            if (cp.action.length > 0) {
                string id = environment["TERMINIX_ID"];
                if (id.length == 0) {
                    writeln(_("You must execute a command within a running instance of terminix"));
                    return 2;
                } else {
                    trace(format("Sending command=%s, cmdLine=%s", cp.action, cp.cmdLine));
                    terminixApp.register(null);
                    terminixApp.executeCommand(cp.action, id, cp.cmdLine);
                    return 0;    
                }
            } else {
                result = terminixApp.run(tempArgs);
                version(Localize) {
                    saveFile(std.conv.to!string(std.path.withExtension(args[0], ".pot")));
                }
            }
        } catch (Exception e) {
            error(_("Unexpected exception occurred"));
            error(_("Error: ") ~ e.msg);
        }
        return result;
    } else {
        return cp.exitCode;
    }
}