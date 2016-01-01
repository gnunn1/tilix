module gx.terminix.cmdparams;

import std.experimental.logger;
import std.getopt;
import std.stdio;

import gx.i18n.l10n;

/**
 * Manages the terminix command line options
 */
struct CommandParameters {

    string workingDir;
    string profileName;
    string session;
    
    bool exit = false;
    int exitCode = 0;

    this(string[] args) {
        auto results = getopt(args,
            "working-directory|w", _("Set the working directory of the terminal"), &workingDir,
            "profile|p", _("Set the starting profile"), &profileName,
            "session|s", _("Open the specified session"), &session
        );
        
        if (results.helpWanted) {
            defaultGetoptPrinter("Terminix Usage:\n\tterminix [OPTIONS]\n\nAvailable options are:\n", results.options);
            writeln("Note that the session option is not compatible with profile and working-directory options");
            exit = true;
        }
        
        if (session.length > 0 && (profileName.length > 0 || workingDir.length > 0)) {
            writeln(_("You cannot load a session and set a profile/working directory, please choose one or the other"));
            exitCode =1;
            exit = true;
        }
        trace("Command Line Options:\n\tworkingDirectory: " ~ workingDir);                
    }
}