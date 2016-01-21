module gx.terminix.cmdparams;

import std.experimental.logger;
import std.getopt;
import std.stdio;
import std.string;

import gx.i18n.l10n;

/**
 * Manages the terminix command line options
 */
struct CommandParameters {

private:
    string _workingDir;
    string _profileName;
    string _session;
    string _action;
    string _execute;
    string _cmdLine;

    bool _exit = false;
    int _exitCode = 0;

public:    
    
    this(string[] args) {
        _cmdLine.length = 0;
        //Start from 1 to skip executable
        foreach(i, arg; args[1..$]) {
            if (i > 0) _cmdLine ~=" ";
            if (arg.indexOf(" ") > 0) arg ="\"" ~ arg ~ "\""; 
            _cmdLine ~= arg;
        }
        try { 
            auto results = getopt(args, 
                                "working-directory|w", _("Set the working directory of the terminal"), &_workingDir, 
                                "profile|p", _("Set the starting profile"), &_profileName, 
                                "session|s", _("Open the specified session"), &_session,
                                "action|a",_("Send an action to current Terminix instance"), &_action,
                                "execute|x",_("Execute the passed command"), &_execute);
            if (results.helpWanted) {
                defaultGetoptPrinter("Terminix Usage:\n\tterminix [OPTIONS]\n\nAvailable options are:\n", results.options);
                writeln("Note that the session option is not compatible with profile and working-directory options");
                _exitCode = 0;
                _exit = true;
            }

            if (_session.length > 0 && (_profileName.length > 0 || _workingDir.length > 0)) {
                writeln(_("You cannot load a session and set a profile/working directory, please choose one or the other"));
                _exitCode = 1;
                _exit = true;
            }
            trace("Command Line Options:\n\tworkingDirectory: " ~ _workingDir);
            trace("Command Line Options:\n\tprofileName: " ~ _profileName);
        } catch (GetOptException e) {
            writeln("Unexpected error occurred when parsing command line parameters, error was:");
            writeln("\t" ~ e.msg);
            writeln();
            writeln("Exiting terminix");
            _exitCode = 1;
            _exit = true;
        }                              
    }
    
    void clear() {
        _workingDir.length = 0;
        _profileName.length = 0;
        _session.length = 0;
        _action.length = 0;
        _execute.length = 0;
        _exitCode = 0;
        _cmdLine.length = 0;
        _exit = false;
    }
    
    @property string workingDir() {return _workingDir;}

    @property string profileName() {return _profileName;}
    
    @property string session() {return _session;}
    
    @property string action() {return _action;}
    
    @property string execute() {return _execute;}
    
    @property string cmdLine() {return _cmdLine;}
    
    @property bool exit() {return _exit;}
    
    @property int exitCode() {return _exitCode;}     
}
