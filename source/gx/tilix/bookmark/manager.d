/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.bookmark.manager;

import std.algorithm;
import std.array;
import std.conv;
import std.experimental.logger;
import std.file;
import std.json;
import std.path;
import std.uuid;

import gdk.Pixbuf;
import gdk.RGBA;
import gdk.Screen;

import glib.Util;

import gtk.IconInfo;
import gtk.IconTheme;
import gtk.StyleContext;
import gtk.Widget;

import gx.i18n.l10n;

import gx.tilix.constants;

enum BookmarkType {
    FOLDER,
    PATH,
    REMOTE,
    COMMAND}

class BookmarkException: Exception {

    this(string message) {
        super(message);
    }
}

interface Bookmark {

    JSONValue serialize(FolderBookmark parent);
    void deserialize(JSONValue value);

    @property BookmarkType type();

    /**
     * Parent of the bookmark, will be null in case
     * of root.
     */
    @property FolderBookmark parent();

    @property void parent(FolderBookmark parent);

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

    FolderBookmark _parent;
public:

    this() {
        _uuid = randomUUID().toString();
    }

    this(string name) {
        this();
        this._name = name;
    }

    @property FolderBookmark parent() {
        return _parent;
    }

    @property void parent(FolderBookmark value) {
        if (_parent != value) {
            _parent = value;
            bmMgr.changed;
        }
    }

    @property string name() {
        return _name;
    }

    @property void name(string value) {
        if (_name != value) {
            _name = value;
            bmMgr.changed();
        }
    }

    @property string uuid() {
        return _uuid;
    }

    JSONValue serialize(FolderBookmark parent) {
        JSONValue value = [NODE_BOOKMARK_TYPE : to!string(type())];
        value[NODE_NAME] = name;
        _parent = parent;
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
        bm.parent = this;
        bmMgr.changed();
    }

    void remove(Bookmark bm) {
        import gx.util.array: remove;
        list.remove(bm);
        bm.parent = null;
        bmMgr.changed();
    }

    void insertBefore(Bookmark target, Bookmark bm) {
        ptrdiff_t index = list.countUntil(target);
        if (index < 0) {
            throw new BookmarkException("Target was not located in the folder");
        }
        list.insertInPlace(index, bm);
        bm.parent = this;
        bmMgr.changed();
    }

    void insertAfter(Bookmark target, Bookmark bm) {
        ptrdiff_t index = list.countUntil(target);
        if (index < 0) {
            throw new BookmarkException("Target was not located in the folder");
        }
        if (index < list.length - 1) {
            list.insertInPlace(index + 1, bm);
        } else {
            list ~= bm;
        }
        bm.parent = this;
        bmMgr.changed();
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

    override JSONValue serialize(FolderBookmark parent) {
        // LDC 1.0.0 breaks on super call to abstract class, see #769
        JSONValue value = [NODE_BOOKMARK_TYPE : to!string(type())];
        value[NODE_NAME] = name;
        _parent = parent;

        //JSONValue value = super.serialize(parent);

        JSONValue[] jsonList = [];
        foreach(item; list) {
            jsonList ~= item.serialize(this);
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

    @property void path(string value) {
        if (_path != value) {
            _path = value;
            bmMgr.changed();
        }
    }

    override JSONValue serialize(FolderBookmark parent) {
        // LDC 1.0.0 breaks on super call to abstract class, see #769
        JSONValue value = [NODE_BOOKMARK_TYPE : to!string(type())];
        value[NODE_NAME] = name;
        _parent = parent;

        //JSONValue value = super.serialize(parent);
        value[NODE_PATH] = _path;
        return value;
    }

    override void deserialize(JSONValue value) {
        super.deserialize(value);
        _path = value[NODE_PATH].str();
    }

    @property string terminalCommand() {
        return "cd " ~ _path.replace(" ", "\\ ");
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
        if (_host != value) {
            _host = value;
            bmMgr.changed();
        }
    }

    @property uint port() {
        return _port;
    }

    @property void port(uint value) {
        if (_port != value) {
            _port = value;
            bmMgr.changed();
        }
    }

    @property string user() {
        return _user;
    }

    @property void user(string value) {
        if (_user != value) {
            _user = value;
            bmMgr.changed();
        }
    }

    @property string params() {
        return _params;
    }

    @property void params(string value) {
        if (_params != value) {
            _params = value;
            bmMgr.changed();
        }
    }

    @property ProtocolType protocolType() {
        return _protocolType;
    }

    @property void protocolType(ProtocolType value) {
        if (_protocolType != value) {
            _protocolType = value;
            bmMgr.changed();
        }
    }

    @property string command() {
        return _command;
    }

    @property void command(string value) {
        if (_command != value) {
            _command = value;
            bmMgr.changed();
        }
    }

    override JSONValue serialize(FolderBookmark parent) {
        // LDC 1.0.0 breaks on super call to abstract class, see #769
        JSONValue value = [NODE_BOOKMARK_TYPE : to!string(type())];
        value[NODE_NAME] = name;
        _parent = parent;

        //JSONValue value = super.serialize(parent);
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
                if (user.length > 0) result ~= " " ~ user ~ "@" ~ host;
                else result ~= " " ~ host;
                if (port > 0) result ~= " -p " ~ to!string(port);
                if (command.length > 0) result ~= " \"" ~ command ~ "\"";
                break;
            case ProtocolType.TELNET:
                result = "telnet";
                if (params.length > 0) result ~= " " ~ params;
                result ~= " " ~ host;
                if (port > 0) result ~= " " ~ to!string(port);
                break;
            case ProtocolType.FTP: .. case ProtocolType.SFTP:
                result = "ftp";
                if (_protocolType == ProtocolType.SFTP) {
                    result = "s" ~ result;
                }
                if (params.length > 0) result ~= " " ~ params;
                if (user.length > 0) result ~= " " ~ user ~ "@" ~ host;
                else result ~= " " ~ host;
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
        if (_command != value) {
            _command = value;
            bmMgr.changed();
        }
    }

    override JSONValue serialize(FolderBookmark parent) {
        // LDC 1.0.0 breaks on super call to abstract class, see #769
        JSONValue value = [NODE_BOOKMARK_TYPE : to!string(type())];
        value[NODE_NAME] = name;
        _parent = parent;

        //JSONValue value = super.serialize(parent);
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
 * Manages all the bookmarks for tilix, this is
 * intended to run as a singleton.
 */
class BookmarkManager {
private:
    enum BOOKMARK_FILE = "bookmarks.json";

    FolderBookmark _root;
    Bookmark[string] bookmarks;

    bool _changed = false;

    /**
     * Remove all references to folder and it's children
     * from bookmarks associative array. Could also be used
     * for other cleanup but not needed at this time.
     */
    void clear(FolderBookmark fb) {
        if (fb is null) return;
        foreach(bm; fb) {
            if (bm.uuid in bookmarks) bookmarks.remove(bm.uuid);
            FolderBookmark child = cast(FolderBookmark) bm;
            if (child !is null) clear(child);
        }
    }

public:
    this() {
        _root = new FolderBookmark(_("Root"));
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

    void remove(Bookmark bm) {
        if (bm is null || bm.parent is null) {
            error("Unexpected error, bookmark %s is nuill or bookmark has no parent", bm.name);
            return;
        }
        tracef("Removing %s from folder %s", bm.name, bm.parent.name);
        bm.parent.remove(bm);
        bookmarks.remove(bm.uuid);
        clear(cast(FolderBookmark) bm);
    }

    void moveBefore(Bookmark target, Bookmark source) {
        source.parent.remove(source);
        target.parent.insertBefore(target, source);
    }

    void moveAfter(Bookmark target, Bookmark source) {
        source.parent.remove(source);
        target.parent.insertAfter(target, source);
    }

    void moveInto(FolderBookmark target, Bookmark source) {
        source.parent.remove(source);
        target.add(source);
    }

    string localize(BookmarkType type) {
        return _(localizedBookmarks[cast(uint)type]);
    }

    Bookmark get(string uuid) {
        if (uuid in bookmarks) {
            return bookmarks[uuid];
        } else {
            return null;
        }
    }

    void save() {
        string path = buildPath(Util.getUserConfigDir(), APPLICATION_CONFIG_FOLDER);
        if (!exists(path)) {
            mkdirRecurse(path);
        }
        string filename = buildPath(path, BOOKMARK_FILE);
        string json = root.serialize(null).toPrettyString();
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
                //TODO: Copy bad file
            }
        }
        _changed = false;
    }

    void changed() {
        _changed = true;
    }

    @property FolderBookmark root() {
        return _root;
    }

    @property bool hasChanged() {
        return _changed;
    }
}


void initBookmarkManager() {
    bmMgr = new BookmarkManager();
}

Pixbuf[] getBookmarkIcons(Widget widget) {
    if (bmIcons.length > 0) return bmIcons;
    string[] names = ["folder-symbolic","mark-location-symbolic","folder-remote-symbolic", "application-x-executable-symbolic"];
    Pixbuf[] icons;
    IconTheme iconTheme = IconTheme.getForScreen(Screen.getDefault());
    if (iconTheme is null) {
        error("IconTheme could not be loaded");
        return [null, null, null, null];
    }

    RGBA fg;
    if (!widget.getStyleContext().lookupColor("theme_fg_color", fg)) {
        error("theme_fg_color could not be loaded");
        return [null, null, null, null];
    }
    foreach(name; names) {
        IconInfo iconInfo = iconTheme.lookupIcon(name, 16, IconLookupFlags.GENERIC_FALLBACK);
        bool wasSymbolic;
        icons ~= iconInfo.loadSymbolic(fg, null, null, null, wasSymbolic);
    }
    bmIcons = icons;
    return icons;
}

/**
 * Clears the bookmark icon cache.
 */
void clearBookmarkIconCache() {
    bmIcons.length = 0;
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
    Pixbuf[] bmIcons;

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