module gx.terminix.cmdparams;

import std.experimental.logger;
import std.file;
import std.path;
import std.process;
import std.stdio;
import std.string;

import gio.ApplicationCommandLine;

import glib.VariantDict;
import glib.Variant : GVariant = Variant;
import glib.VariantType : GVariantType = VariantType;

import gx.i18n.l10n;

enum CMD_WORKING_DIRECTORY = "working-directory";
enum CMD_SESSION = "session";
enum CMD_PROFILE = "profile";
enum CMD_EXECUTE = "execute";
enum CMD_ACTION = "action";
enum CMD_TERMINAL_UUID = "terminalUUID";

/**
 * Manages the terminix command line options
 */
struct CommandParameters {

private:
    string _workingDir;
    string _profileName;
    string[] _session;
    string _action;
    string _execute;
    string _cmdLine;
    string _terminalUUID;

    bool _exit = false;
    int _exitCode = 0;

    string[] getValues(VariantDict vd, string key) {
        GVariant value = vd.lookupValue(key, new GVariantType("as"));
        if (value is null)
            return [];
        else {
            return value.getStrv();
        }
    }

    string getValue(VariantDict vd, string key, GVariantType vt) {
        GVariant value = vd.lookupValue(key, vt);
        if (value is null)
            return "";
        else {
            ulong l;
            return value.getString(l);
        }
    }

public:

    this(ApplicationCommandLine acl) {
        _cmdLine = acl.getCwd();

        //Declare a string variant type
        GVariantType vts = new GVariantType("s");
        VariantDict vd = acl.getOptionsDict();
        _workingDir = getValue(vd, CMD_WORKING_DIRECTORY, vts);
        if (_workingDir.length > 0) {
            _workingDir = expandTilde(_workingDir);
            if (!isDir(_workingDir)) {
                writeln(format(_("Ignoring parameter working-directory as '%s' is not a directory"), _workingDir));
                _workingDir.length = 0;
            }
        }
        _session = getValues(vd, CMD_SESSION);
        if (_session.length > 0) {
            for (ulong i = _session.length - 1; i--; i >= 0) {
                _session[i] = expandTilde(_session[i]);
                if (!isFile(_session[i])) {
                    writeln(format(_("Ignoring parameter session as '%s' does not exist"), _session));
                    std.algorithm.remove(_session, i);
                }
            }
        }
        _profileName = getValue(vd, CMD_PROFILE, vts);
        _execute = getValue(vd, CMD_EXECUTE, vts);
        _action = getValue(vd, CMD_ACTION, vts);
        if (_session.length > 0 && (_profileName.length > 0 || _workingDir.length > 0 || _execute.length > 0)) {
            writeln(_("You cannot load a session and set a profile/working directory/execute command option, please choose one or the other"));
            _exitCode = 1;
            _exit = true;
        }
        _terminalUUID = getValue(vd, CMD_TERMINAL_UUID, vts);
        if (_action.length > 0) {
            if (!acl.getIsRemote()) {
                writeln("You can only use the the action parameter within Terminix");
                _exitCode = 2;
                _exit = true;
                _action.length = 0;
            }
        }
        trace("Command line parameters:");
        trace("\tworking-directory=" ~ _workingDir);
        trace("\tsession=" ~ _session);
        trace("\tprofile=" ~ _profileName);
        trace("\taction=" ~ _action);
        trace("\texecute=" ~ _execute);
    }

    void clear() {
        _workingDir.length = 0;
        _profileName.length = 0;
        _session.length = 0;
        _action.length = 0;
        _execute.length = 0;
        _exitCode = 0;
        _cmdLine.length = 0;
        _terminalUUID.length = 0;
        _exit = false;
    }

    @property string workingDir() {
        return _workingDir;
    }

    @property string profileName() {
        return _profileName;
    }

    @property string[] session() {
        return _session;
    }

    @property string action() {
        return _action;
    }

    @property string execute() {
        return _execute;
    }

    @property string cmdLine() {
        return _cmdLine;
    }

    @property string terminalUUID() {
        return _terminalUUID;
    }

    @property bool exit() {
        return _exit;
    }

    @property int exitCode() {
        return _exitCode;
    }
}
