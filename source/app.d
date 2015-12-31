/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
import std.stdio;

import std.conv;
import std.experimental.logger;

import gtk.Main;
import gtk.Version;
import gtk.MessageDialog;

import gx.gtk.util;

import gx.terminix.application;
import gx.terminix.cmdparams;
import gx.terminix.constants;

int main(string[] args) {
	
	//Version checking cribbed from grestful, thanks!
	string error = Version.checkVersion(GTK_VERSION_MAJOR, GTK_VERSION_MINOR, GTK_VERSION_PATCH);
    
	if (error !is null)	{
		Main.init(args);
		
		MessageDialog dialog = new MessageDialog(
			null,
			DialogFlags.MODAL,
			MessageType.ERROR,
			ButtonsType.OK,
			"Your GTK version is too old, you need at least GTK " ~
			to!string(GTK_VERSION_MAJOR) ~ '.' ~
			to!string(GTK_VERSION_MINOR) ~ '.' ~
			to!string(GTK_VERSION_PATCH) ~ '!',
			null
			);
		
		dialog.setDefaultResponse(ResponseType.OK);
		
		dialog.run();
		return 1;
	}
    
    CommandParameters cp = CommandParameters(args);
    if (!cp.exit) {
        auto terminixApp = new Terminix(cp);
        //Bypass GTK command line handling since we handle it ourselves
        string[] tempArgs;
        return terminixApp.run(tempArgs);
    } else {
        return cp.exitCode;
    }
}