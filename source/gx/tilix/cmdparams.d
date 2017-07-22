module gx.tilix.cmdparams;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.file;
import std.path;
import std.process;
import std.regex;
import std.stdio;
import std.string;

import gio.ApplicationCommandLine;

import glib.VariantDict;
import glib.Variant : GVariant = Variant;
import glib.VariantType : GVariantType = VariantType;

import gx.i18n.l10n;
import gx.util.path;

enum CMD_WORKING_DIRECTORY = "working-directory";
enum CMD_SESSION = "session";
enum CMD_PROFILE = "profile";
enum CMD_COMMAND = "command";
// Not that execute is a special command and not handled by GApplication options.
// See app.d for more info.
enum CMD_EXECUTE = "execute";
enum CMD_ACTION = "action";
enum CMD_TERMINAL_UUID = "terminalUUID";
enum CMD_MAXIMIZE = "maximize";
enum CMD_MINIMIZE = "minimize";
enum CMD_FULL_SCREEN = "full-screen";
enum CMD_FOCUS_WINDOW = "focus-window";
enum CMD_GEOMETRY = "geometry";
enum CMD_NEW_PROCESS = "new-process";
enum CMD_TITLE = "title";
enum CMD_QUAKE = "quake";
enum CMD_VERSION = "version";
enum CMD_PREFERENCES = "preferences";
enum CMD_WINDOW_STYLE = "window-style";


/**
 * Indicates how much of geometry was passed
 *  PARTIAL - Width and Height only
 *  FULL - Width, Height, x and y
 */
enum GeometryFlag {NONE, PARTIAL, FULL}

struct Geometry {
    int x, y;
    uint width, height;
    bool xNegative;
    bool yNegative;
    GeometryFlag flag;
}

/**
 * Manages the command line options
 */
struct CommandParameters {

private:
    string _workingDir;
    string _profileName;
    string[] _session;
    string _action;
    string _command;
    string _cmdLine;
    string _terminalUUID;
    string _cwd;
    string _pwd;
    string _title;
    string _windowStyle;
    Geometry _geometry;

    bool _maximize;
    bool _minimize;
    bool _fullscreen;
    bool _focusWindow;
    bool _newProcess;
    bool _quake;
    bool _version;
    bool _preferences;

    bool _exit = false;
    int _exitCode = 0;

    enum GEOMETRY_PATTERN_FULL = "(?P<width>\\d+)x(?P<height>\\d+)(?P<x>[-+]\\d+)(?P<y>[-+]\\d+)";
    enum GEOMETRY_PATTERN_DIMENSIONS = "(?P<width>\\d+)x(?P<height>\\d+)";

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
            size_t l;
            return value.getString(l);
        }
    }

    string validatePath(string path) {
        if (path.length > 0) {
            path = resolvePath(path);
            try {
                if (!isDir(path)) {
                    writeln(format(_("Ignoring as '%s' is not a directory"), path));
                    path.length = 0;
                }
            } catch (Exception e) {
                writeln(format(_("Ignoring as '%s' is not a directory"), path));
                path.length = 0;
            }
        }
        return path;
    }

    void parseGeometry(string value) {
        trace("Parsing geometry string " ~ value);
        auto r = regex(GEOMETRY_PATTERN_FULL);
        auto m = matchFirst(value, r);
        if (m) {
            _geometry.width = to!uint(m["width"]);
            _geometry.height = to!uint(m["height"]);
            _geometry.x = to!int(m["x"]);
            _geometry.xNegative = m["x"].startsWith("-");
            _geometry.y = to!int(m["y"]);
            _geometry.yNegative = m["y"].startsWith("-");
            _geometry.flag = GeometryFlag.FULL;
            return;
        } else {
            r = regex(GEOMETRY_PATTERN_DIMENSIONS);
            m = matchFirst(value, r);
            if (m) {
                _geometry.width = to!int(m["width"]);
                _geometry.height = to!int(m["height"]);
                _geometry.flag = GeometryFlag.PARTIAL;
                return;
            } else {
                errorf(_("Geometry string '%s' is invalid and could not be parsed"), value);
            }
        }
        _geometry.flag = GeometryFlag.NONE;
    }

public:

    this(ApplicationCommandLine acl) {
        _cmdLine = acl.getCwd();

        //Declare a string variant type
        GVariantType vts = new GVariantType("s");
        VariantDict vd = acl.getOptionsDict();

        _workingDir = validatePath(getValue(vd, CMD_WORKING_DIRECTORY, vts));
        _pwd = acl.getenv("PWD");
        _cwd = acl.getCwd();

        if (_cwd.length > 0) _cwd = validatePath(_cwd);

        _session = getValues(vd, CMD_SESSION);
        if (_session.length > 0) {
            foreach(i, filename; _session) {
                _session[i] = resolvePath(filename);
            }
        }
        _profileName = getValue(vd, CMD_PROFILE, vts);
        _title = getValue(vd, CMD_TITLE, vts);
        _command = getValue(vd, CMD_COMMAND, vts);
        _action = getValue(vd, CMD_ACTION, vts);
        _windowStyle = getValue(vd, CMD_WINDOW_STYLE, vts);
        if (_session.length > 0 && (_profileName.length > 0 || _workingDir.length > 0 || _command.length > 0)) {
            writeln(_("You cannot load a session and set a profile/working directory/execute command option, please choose one or the other"));
            _exitCode = 1;
            _exit = true;
        }
        _terminalUUID = getValue(vd, CMD_TERMINAL_UUID, vts);
        if (_action.length > 0) {
            if (!acl.getIsRemote()) {
                writeln(_("You can only use the action parameter within Tilix"));
                _exitCode = 2;
                _exit = true;
                _action.length = 0;
            }
        }

        _maximize = vd.contains(CMD_MAXIMIZE);
        _minimize = vd.contains(CMD_MINIMIZE);
        _fullscreen = vd.contains(CMD_FULL_SCREEN);
        _focusWindow = vd.contains(CMD_FOCUS_WINDOW);
        _newProcess = vd.contains(CMD_NEW_PROCESS);
        _quake = vd.contains(CMD_QUAKE);
        _version = vd.contains(CMD_VERSION);
        _preferences = vd.contains(CMD_PREFERENCES);
        _exit = _version;

        string geometryParam = getValue(vd, CMD_GEOMETRY, vts);
        if (geometryParam.length > 0)
            parseGeometry(geometryParam);

        if (_quake && (_maximize || _minimize || _geometry.flag != GeometryFlag.NONE)) {
                writeln(_("You cannot use the quake mode with maximize, minimize or geometry parameters"));
                _exitCode = 3;
                _exit = true;
        }

        trace("Command line parameters:");
        trace("\tworking-directory=" ~ _workingDir);
        trace("\tsession=" ~ _session);
        trace("\tprofile=" ~ _profileName);
        trace("\ttitle=" ~ _title);
        trace("\taction=" ~ _action);
        trace("\tcommand=" ~ _command);
        trace("\tcwd=" ~ _cwd);
        trace("\tpwd=" ~ _pwd);
        if (_quake) {
            trace("\tquake");
        }
    }

    void clear() {
        _workingDir.length = 0;
        _profileName.length = 0;
        _session.length = 0;
        _action.length = 0;
        _command.length = 0;
        _exitCode = 0;
        _cmdLine.length = 0;
        _terminalUUID.length = 0;
        _cwd.length = 0;
        _pwd.length = 0;
        _windowStyle.length = 0;
        _maximize = false;
        _minimize = false;
        _fullscreen = false;
        _focusWindow = false;
        _newProcess = false;
        _quake = false;
        _geometry = Geometry(0, 0, 0, 0, false, false, GeometryFlag.NONE);
        _exit = false;
        _title.length = 0;
        _version = false;
        _preferences = false;
    }

    @property string workingDir() {
        return _workingDir;
    }

    @property void workingDir(string value) {
        _workingDir = value;
    }

    @property string cwd() {
        return _cwd;
    }

    @property string pwd() {
        return _pwd;
    }

    @property string profileName() {
        return _profileName;
    }

    @property void profileName(string name) {
        _profileName = name;
    } 

    @property string[] session() {
        return _session;
    }

    @property string action() {
        return _action;
    }

    @property string command() {
        return _command;
    }

    @property string cmdLine() {
        return _cmdLine;
    }

    @property string terminalUUID() {
        return _terminalUUID;
    }

    @property string windowStyle() {
        return _windowStyle;
    }

    @property bool maximize() {
        return _maximize;
    }

    @property bool minimize() {
        return _minimize;
    }

    @property bool fullscreen() {
        return _fullscreen;
    }

    @property bool focusWindow() {
        return _focusWindow;
    }

    @property bool exit() {
        return _exit;
    }

    @property int exitCode() {
        return _exitCode;
    }

    @property Geometry geometry() {
        return _geometry;
    }

    @property bool newProcess() {
        return _newProcess;
    }

    @property string title() {
        return _title;
    }

    @property bool quake() {
        return _quake;
    }

    @property bool outputVersion() {
        return _version;
    }

    @property bool preferences() {
        return _preferences;
    }

    @property bool windowStateOverride() {
        return _maximize || _minimize || _fullscreen;
    }
}
