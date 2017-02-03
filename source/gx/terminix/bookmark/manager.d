/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.bookmark.manager;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.file;
import std.json;
import std.path;
import std.uuid;

import gdk.Pixbuf;

import glib.Util;

import gtk.IconInfo;
import gtk.IconTheme;

import gx.i18n.l10n;

import gx.terminix.constants;

enum BookmarkType {
    FOLDER,
    PATH,
    REMOTE,
    COMMAND}

interface Bookmark {

    JSONValue serialize();
    void deserialize(JSONValue value);

    @property BookmarkType type();

    /**
     * Bookmark name
     */
    @property string name();

    @property void name(string value);

    /**
     * Unique identifier for the bookmark
     */
    @property string uuid();

    /**
     * The command to insert into the terminal
     * for this bookmark.
     */
    @property string terminalCommand();
}

abstract class AbstractBookmark: Bookmark {
private:
    string _name;
    string _uuid;

public:

    this() {
        _uuid = randomUUID().toString();
    }

    this(string name) {
        this();
        this._name = name;
    }

    @property string name() {
        return _name;
    }
    @property void name(string value) {
        _name = value;
    }

    @property string uuid() {
        return _uuid;
    }

    JSONValue serialize() {
        JSONValue value = [NODE_BOOKMARK_TYPE : to!string(type())];
        value[NODE_NAME] = name;
        return value;
    }

    void deserialize(JSONValue value) {
        _name = value[NODE_NAME].str();
    }
}

/**
 * Folder that holds a list of Bookmarks
 */
class FolderBookmark: AbstractBookmark {

private:

    enum NODE_LIST = "list";

    Bookmark[] list;

package:

    void add(Bookmark bm) {
        list ~= bm;
    }

    void remove(Bookmark bm) {
        size_t index = list.countUntil(bm);
        if (index >= 0) {
            list[index] = null;
            list = std.algorithm.remove(list, index);
        }
    }

public:

    this() {
        super();
    }

    this(string name) {
        super(name);
    }

    @property BookmarkType type() {
        return BookmarkType.FOLDER;
    }

    int opApply ( int delegate ( ref Bookmark x ) dg ) {
        int result = 0;
        foreach (ref x; list) {
            result = dg(x);
            if (result) break;
        }
        return result;
    }

    override JSONValue serialize() {
        JSONValue value = super.serialize();
        JSONValue[] jsonList = [];
        foreach(item; list) {
            jsonList ~= item.serialize();
        }
        value[NODE_LIST] = jsonList;
        return value;
    }

    override void deserialize(JSONValue value) {
        super.deserialize(value);
        JSONValue[] jsonList = value[NODE_LIST].array();
        foreach(item; jsonList) {
            try {
                BookmarkType type = to!BookmarkType(item[NODE_BOOKMARK_TYPE].str());
                Bookmark bm = bmMgr.createBookmark(type);
                bm.deserialize(item);
                bmMgr.add(this, bm);
            } catch (Exception e) {
                error(_("Error deserializing bookmark"));
                error(e);
            }
        }
    }

    @property string terminalCommand() {
        return "";
    }
}

class PathBookmark: AbstractBookmark {
private:
    string _path;

    enum NODE_PATH = "path";

public:

    this() {
        super();
    }

    this(string name, string path) {
        super(name);
        _path = path;
    }

    @property BookmarkType type() {
        return BookmarkType.PATH;
    }

    @property string path() {
        return _path;
    }

    @property void path(string path) {
        _path = path;
    }

    override JSONValue serialize() {
        JSONValue value = super.serialize();
        value[NODE_PATH] = _path;
        return value;
    }

    override void deserialize(JSONValue value) {
        super.deserialize(value);
        _path = value[NODE_PATH].str();
    }

    @property string terminalCommand() {
        return "cd " ~ _path;
    }
}

/**
 * The type of protocol a remote bookmark uses
 */
enum ProtocolType {SSH, TELNET, FTP, SFTP}

/**
 * represents a bookmark to a remote system
 */
class RemoteBookmark: AbstractBookmark {
private:
    ProtocolType _protocolType;
    string _host;
    uint _port;
    string _user;
    string _params;
    string _path;
    string _command;

    enum NODE_HOST = "host";
    enum NODE_PORT = "port";
    enum NODE_USER = "user";
    enum NODE_PARAMS = "params";
    enum NODE_PROTOCOL_TYPE = "protocolType";
    enum NODE_COMMAND = "command";

public:

    this() {
        super();
    }

    @property BookmarkType type() {
        return BookmarkType.REMOTE;
    }

    @property string host() {
        return _host;
    }

    @property void host(string value) {
        _host = value;
    }

    @property uint port() {
        return _port;
    }

    @property void port(uint value) {
        _port = value;
    }

    @property string user() {
        return _user;
    }

    @property void user(string value) {
        _user = value;
    }

    @property string params() {
        return _params;
    }

    @property void params(string value) {
        _params = value;
    }

    @property ProtocolType protocolType() {
        return _protocolType;
    }

    @property void protocolType(ProtocolType value) {
        _protocolType = value;
    }

    @property string command() {
        return _command;
    }

    @property void command(string value) {
        _command = value;
    }

    override JSONValue serialize() {
        JSONValue value = super.serialize();
        value[NODE_HOST] = _host;
        value[NODE_PORT] = _port;
        value[NODE_USER] = _user;
        value[NODE_PARAMS] = _params;
        value[NODE_PROTOCOL_TYPE] = to!string(protocolType);
        value[NODE_COMMAND] = _command;
        return value;
    }

    override void deserialize(JSONValue value) {
        super.deserialize(value);
        _host = value[NODE_HOST].str;
        _port = to!uint(value[NODE_PORT].integer);
        _user = value[NODE_USER].str;
        _params = value[NODE_PARAMS].str;
        _protocolType = to!ProtocolType(value[NODE_PROTOCOL_TYPE].str);
        _command = value[NODE_COMMAND].str;
    }

    @property string terminalCommand() {
        string result;
        switch(_protocolType) {
            case ProtocolType.SSH:
                result = "ssh";
                if (params.length > 0) result ~= " " ~ params;
                if (user.length > 0) result ~= user ~ "@";
                result ~= host;
                if (port > 0) result ~= " -p " ~ to!string(port);
                if (command.length > 0) result ~= " " ~ command;
                break;
            case ProtocolType.TELNET:
                result = "telnet";
                if (params.length > 0) result ~= " " ~ params;
                result ~= host;
                if (port > 0) result ~= " " ~ to!string(port);
                break;
            case ProtocolType.FTP: .. case ProtocolType.SFTP:
                result = "ftp";
                if (_protocolType == ProtocolType.SFTP) {
                    result = "s" ~ result;
                }
                if (params.length > 0) result ~= " " ~ params;
                if (user.length > 0) result ~= user ~ "@";
                result ~= host;
                if (port > 0) result ~= " " ~ to!string(port);
                break;
            default:
        }
        return result;
    }
}

/**
 * Bookmark that represents an arbritary executable command.
 */
class CommandBookmark: AbstractBookmark {
private:
    string _command;

    enum NODE_COMMAND = "command";

public:
    this() {
        super();
    }

    @property BookmarkType type() {
        return BookmarkType.COMMAND;
    }

    @property string command() {
        return _command;
    }

    @property void command(string value) {
        _command = value;
    }

    override JSONValue serialize() {
        JSONValue value = super.serialize();
        value[NODE_COMMAND] = _command;
        return value;
    }

    override void deserialize(JSONValue value) {
        super.deserialize(value);
        _command = value[NODE_COMMAND].str;
    }

    @property string terminalCommand() {
        return _command;
    }

}

/**
 * Manages all the bookmarks for terminix, this is
 * intended to run as a singleton.
 */
class BookmarkManager {
private:
    enum BOOKMARK_FILE = "bookmarks.json";

    FolderBookmark _root;
    Bookmark[string] bookmarks;

public:
    this() {
        _root = new FolderBookmark("root");
    }

    Bookmark createBookmark(BookmarkType type) {
        tracef("Creating bookmark %s", type);
        final switch (type) {
            case BookmarkType.FOLDER:
                return new FolderBookmark();
            case BookmarkType.PATH:
                return new PathBookmark();
            case BookmarkType.REMOTE:
                return new RemoteBookmark();
            case BookmarkType.COMMAND:
                return new CommandBookmark();
        }
    }

    void add(FolderBookmark fb, Bookmark bm) {
        fb.add(bm);
        bookmarks[bm.uuid] = bm;
    }

    void remove(FolderBookmark fb, Bookmark bm) {
        fb.remove(bm);
        bookmarks.remove(bm.uuid);
    }

    string localize(BookmarkType type) {
        return _(localizedBookmarks[cast(uint)type]);
    }

    Bookmark get(string uuid) {
        return bookmarks[uuid];
    }

    void save() {
        string filename = buildPath(Util.getUserConfigDir(), APPLICATION_CONFIG_FOLDER, BOOKMARK_FILE);
        string json = root.serialize().toPrettyString();
        write(filename, json);
    }

    void load() {
        string filename = buildPath(Util.getUserConfigDir(), APPLICATION_CONFIG_FOLDER, BOOKMARK_FILE);
        if (exists(filename)) {
            try {
                string json = readText(filename);
                JSONValue value = parseJSON(json);
                _root.deserialize(value);
            } catch (Exception e) {
                error(_("Could not load bookmarks due to unexpected error"));
                error(e);
            }
        }
    }

    @property FolderBookmark root() {
        return _root;
    }
}


void initBookmarkManager() {
    bmMgr = new BookmarkManager();
}

Pixbuf[] getBookmarkIcons() {
    string[] names = ["folder-symbolic","folder-open-symbolic","folder-remote-symbolic", "folder-remote-symbolic", "application-x-executable-symbolic"];
    Pixbuf[] icons;
    IconTheme iconTheme = new IconTheme();
    foreach(name; names) {
        IconInfo iconInfo = iconTheme.lookupIcon(name, 16, cast(IconLookupFlags) 0);
        icons ~= iconInfo.loadIcon();
    }
    return icons;
}

/**
 * Instance variable for the BookmarkManager. It is the responsibility of the
 * application to initialize this. Debated about using a Java like singleton pattern
 * but let's keep it simple for now.
 *
 * Also note that this variable is meant to be accessed only from the GTK main thread
 * and hence is not declared as shared.
 */
BookmarkManager bmMgr;


private:
    enum NODE_NAME = "name";
    enum NODE_BOOKMARK_TYPE = "type";

    string[5] localizedBookmarks = [N_("Folder"), N_("Path"), N_("Remote"), N_("Command")];

unittest {
    initBookmarkManager();
    FolderBookmark root = bmMgr.root;

    PathBookmark pb = new PathBookmark("Home", "/home/gnunn");
    root.add(pb);

    pb = new PathBookmark("Development", "/home/gnunn/Development");
    root.add(pb);

    JSONValue json = root.serialize();

    import std.stdio;
    writeln(json.toPrettyString());

    FolderBookmark test = new FolderBookmark();
    test.deserialize(json);
}