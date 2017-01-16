/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.bookmark.manager;

import std.algorithm;
import std.experimental.logger;
import std.json;
import std.uuid;

enum BookmarkType {
    FOLDER = "folder",
    PATH = "path",
    SSH = "ssh",
    FTP = "ftp",
    COMMAND = "command"}

interface BaseBookmark {

    JSONValue serialize();
    void deserialize(JSONValue value);

    @property BookmarkType type();

    @property string name();
    @property void name(string value);

    @property string uuid();
}

abstract class AbstractBookmark: BaseBookmark {
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
        JSONValue value = [NODE_BOOKMARK_TYPE : type()];
        value[NODE_NAME] = name;
        return value;
    }

    void deserialize(JSONValue value) {
        _name = value[NODE_NAME].toString();
    }
}

/**
 * Folder that holds a list of Bookmarks
 */
class FolderBookmark: AbstractBookmark {

private:

    enum NODE_LIST = "list";

    BaseBookmark[] list;

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

    int opApply ( int delegate ( ref BaseBookmark x ) dg ) {
        int result = 0;
        foreach (ref x; list) {
            result = dg(x);
            if (result) break;
        }
        return result;
    }

    void add(BaseBookmark bb) {
        list ~= bb;
    }

    void remove(BaseBookmark bb) {
        long index = list.countUntil(bb);
        if (index >= 0) {
            list[index] = null;
            list = std.algorithm.remove(list, index);
        }
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
            BaseBookmark bb = bmMgr.createBookmark(item[NODE_BOOKMARK_TYPE].toString());
            bb.deserialize(item);
            add(bb);
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
        return path;
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
        _path = value[NODE_PATH].toString();
    }
}


class BookmarkManager {
private:
    FolderBookmark _root;


public:
    this() {
        _root = new FolderBookmark("root");
    }

    BaseBookmark createBookmark(string type) {
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

    @property FolderBookmark root() {
        return _root;
    }
}


void initBookmarkManager() {
    bmMgr = new BookmarkManager();
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

unittest {
    initBookmarkManager();
    FolderBookmark root = bmMgr.root;

    PathBookmark pb = new PathBookmark("Home", "/home/gnunn");
    root.add(pb);

    pb = new PathBookmark("Development", "/home/gnunn/Development");
    root.add(pb);

    string json = root.serialize().toPrettyString();

    import std.stdio;
    writeln(json);

    FolderBookmark test = new FolderBookmark();
    test.deserialize(json);
}