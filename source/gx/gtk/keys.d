module gx.gtk.keys;

import gdk.types;

public alias Keysyms = Keys;

/**
 * Helper to provide GtkD-like Keys access to GDK keysyms
 */
struct Keys {
    enum PageUp = KEY_Page_Up;
    enum PageDown = KEY_Page_Down;

    static foreach (name; __traits(allMembers, gdk.types)) {
        static if (name.length > 4 && name[0..4] == "KEY_") {
            static if (name[4] >= '0' && name[4] <= '9' ||
                       name[4..$] == "cent" ||
                       name[4..$] == "function" ||
                       name[4..$] == "union" ||
                       name[4..$] == "break" ||
                       name[4..$] == "continue" ||
                       name[4..$] == "return" ||
                       name[4..$] == "if" ||
                       name[4..$] == "else" ||
                       name[4..$] == "default" ||
                       name[4..$] == "case" ||
                       name[4..$] == "switch" ||
                       name[4..$] == "in" ||
                       name[4..$] == "is" ||
                       name[4..$] == "new" ||
                       name[4..$] == "delete") {
                mixin("enum _" ~ name[4..$] ~ " = gdk.types." ~ name ~ ";");
            } else {
                mixin("enum " ~ name[4..$] ~ " = gdk.types." ~ name ~ ";");
            }
        }
    }
}
