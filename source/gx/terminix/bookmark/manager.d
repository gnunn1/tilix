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
    SSH,
    FTP,
    COMMAND}

interface Bookmark {

    JSONValue serialize();
    void deserialize(JSONValue value);

    @property BookmarkType type();

    @property string name();
    @property void name(string value);

    @property string uuid();
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
}


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
            case BookmarkType.SSH:
                break;
            case BookmarkType.FTP:
                break;
            case BookmarkType.COMMAND:
                break;
        }
        return null;
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

    string[5] localizedBookmarks = [N_("Folder"), N_("Path"), N_("SSH"), N_("FTP"), N_("Command")];

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