/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.util;

import gid.gid : No, Yes;

import std.conv;
import std.experimental.logger;
import std.format;
import std.process;
import std.string;

// GID imports - gdk
import gdk.atom;
import gdk.rgba : RGBA;

// GID imports - gio
import gio.file : File;
import gio.list_model : ListModel;
import gio.settings : Settings;
import gio.c.functions : g_file_parse_name, g_settings_get_strv;
import gio.c.types : GFile, GSettings;

// GID imports - glib
import glib.error : ErrorWrap;

// GID imports - gobject
import gobject.object : ObjectWrap;
import gobject.value : Value;
import gobject.c.functions : g_type_check_instance_is_a;
import gobject.c.types : GType, GTypeInstance;

// GID imports - gtk
import gtk.bin : Bin;
import gtk.box : Box;
import gtk.combo_box : ComboBox;
import gtk.cell_renderer_text : CellRendererText;
import gtk.container : Container;
import gtk.entry : Entry;
import gtk.list_store : ListStore;
import gtk.global : eventsPending, mainIterationDo;
import gtk.paned : Paned;
import gtk.settings : GtkSettings = Settings;
import gtk.style_context : StyleContext;
import gtk.tree_iter : TreeIter;
import gtk.tree_model : TreeModel;
import gtk.tree_path : TreePath;
import gtk.tree_store : TreeStore;
import gtk.tree_view : TreeView;
import gtk.tree_view_column : TreeViewColumn;
import gtk.widget : Widget;
import gtk.window : Window;
import gtk.types : Orientation, StateFlags;

import gx.gtk.x11;

/**
 * Parse filename and return File object
 */
public File parseName(string parseName) {
    auto p = g_file_parse_name(parseName.ptr);

    if (p is null) {
        return null;
    }

    return ObjectWrap._getDObject!File(p, Yes.Take);
}

/**
 * Workaround for GID 0.9.7 bug in Settings.getStrv where the loop
 * counting array length has an erroneous 'break' statement, causing
 * it to return at most 1 element instead of all elements.
 *
 * This function correctly retrieves all string array elements.
 */
string[] getSettingsStrv(Settings settings, string key) {
    import std.string : fromStringz;

    char** cretval = g_settings_get_strv(cast(GSettings*)settings._cPtr(No.Dup), key.ptr);
    string[] result;

    if (cretval !is null) {
        // Correctly count all elements (no erroneous break)
        size_t length = 0;
        while (cretval[length] !is null) {
            length++;
        }

        result = new string[length];
        foreach (i; 0 .. length) {
            result[i] = cast(string) fromStringz(cretval[i]);
        }
    }

    return result;
}

/**
 * Directly process events for up to a specified period
 */
static if (__VERSION__ >= 2075) {
    void processEvents(uint millis) {
        import std.datetime.stopwatch : StopWatch, AutoStart;

        StopWatch sw = StopWatch(AutoStart.yes);
        scope (exit) {
            sw.stop();
        }
        while (eventsPending() && sw.peek.total!"msecs" < millis) {
            mainIterationDo(false);
        }
    }
} else {
    void processEvents(uint millis) {
        import std.datetime : StopWatch, AutoStart;

        StopWatch sw = StopWatch(AutoStart.yes);
        scope (exit) {
            sw.stop();
        }
        while (eventsPending() && sw.peek().msecs < millis) {
            mainIterationDo(false);
        }
    }
}

/**
 * Activates a window using the X11 APIs when available
 */
void activateWindow(Window window) {
    if (window.isActive())
        return;

    if (isWayland(window)) {
        trace("Present Window for Wayland");
        window.presentWithTime(GDK_CURRENT_TIME);
    } else {
        trace("Present Window for X11");
        window.present();
        activateX11Window(window);
    }
}

/**
 * Returns true if running under Wayland, right now
 * it just uses a simple environment variable check to detect it.
 */
bool isWayland(Window window) {
    import gdk.window : GdkWindow = Window;

    if (window is null) {
        return (environment.get("XDG_SESSION_TYPE", "x11") == "wayland" && environment.get("GDK_BACKEND") != "x11");
    }

    GdkWindow gdkWin = window.getWindow();
    if (gdkWin is null) {
        return (environment.get("XDG_SESSION_TYPE", "x11") == "wayland" && environment.get("GDK_BACKEND") != "x11");
    }

    GType x11Type = getX11WindowType();
    GTypeInstance* instance = cast(GTypeInstance*)(gdkWin._cPtr);

    return g_type_check_instance_is_a(instance, x11Type) == 0;
}

/**
 * Return the name of the GTK Theme
 */
string getGtkTheme() {
    auto settings = GtkSettings.getDefault();
    return settings.gtkThemeName;
}

/**
 * Convenience method for creating a box and adding children
 */
Box createBox(Orientation orientation, int spacing, Widget[] children) {
    Box result = new Box(orientation, spacing);
    foreach (child; children) {
        result.add(child);
    }
    return result;
}

/**
 * Finds the index position of a child in a container.
 */
int getChildIndex(Container container, Widget child) {
    auto children = container.getChildren();
    foreach (i, c; children) {
        if (c._cPtr == child._cPtr)
            return cast(int) i;
    }
    return -1;
}

/**
 * Walks up the parent chain until it finds the parent of the
 * requested type.
 */
T findParent(T)(Widget widget) {
    while ((widget !is null)) {
        widget = widget.getParent();
        T result = cast(T) widget;
        if (result !is null)
            return result;
    }
    return null;
}

/**
 * Template for finding all children of a specific type
 */
T[] findChildren(T)(Widget widget, bool recursive) {
    T[] result;
    Widget[] children;

    if (widget is null)
        return result;

    Bin bin = cast(Bin) widget;
    if (bin !is null) {
        auto child = bin.getChild();
        if (child !is null)
            children = [child];
    } else {
        Container container = cast(Container) widget;
        if (container !is null) {
            children = container.getChildren();
        }
    }

    foreach (child; children) {
        T match = cast(T) child;
        if (match !is null)
            result ~= match;
        if (recursive) {
            result ~= findChildren!(T)(child, recursive);
        }
    }
    return result;
}

/**
 * Gets the background color from style context. Works around
 * spurious VTE State messages on GTK 3.19 or later. See the
 * blog entry here: https://blogs.gnome.org/mclasen/2015/11/20/a-gtk-update/
 */
void getStyleBackgroundColor(StyleContext context, StateFlags flags, out RGBA color) {
    with (context) {
        save();
        setState(flags);
        getBackgroundColor(getState(), color);
        restore();
    }
}

/**
 * Gets the color from style context. Works around
 * spurious VTE State messages on GTK 3.19 or later. See the
 * blog entry here: https://blogs.gnome.org/mclasen/2015/11/20/a-gtk-update/
 */
void getStyleColor(StyleContext context, StateFlags flags, out RGBA color) {
    with (context) {
        save();
        setState(flags);
        getColor(getState(), color);
        restore();
    }
}

/**
 * Sets all margins of a widget to the same value
 */
void setAllMargins(Widget widget, int margin) {
    setMargins(widget, margin, margin, margin, margin);
}

/**
 * Sets margins of a widget to the passed values
 */
void setMargins(Widget widget, int left, int top, int right, int bottom) {
    widget.marginStart = left;
    widget.marginTop = top;
    widget.marginEnd = right;
    widget.marginBottom = bottom;
}

/**
 * Defined here since not defined in GID
 */
enum MouseButton : uint {
    Primary = 1,
    Middle = 2,
    Secondary = 3
}

/**
 * Not declared in GID
 */
enum long GDK_CURRENT_TIME = 0;

/**
 * Compares two RGBA and returns if they are equal, supports null references
 */
bool equal(RGBA r1, RGBA r2) {
    if (r1 is null && r2 is null)
        return true;
    if ((r1 is null && r2 !is null) || (r1 !is null && r2 is null))
        return false;
    return r1.equal(r2);
}

bool equal(Widget w1, Widget w2) {
    if (w1 is null && w2 is null)
        return true;
    if ((w1 is null && w2 !is null) || (w1 !is null && w2 is null))
        return false;
    return w1._cPtr == w2._cPtr;
}

/**
 * Appends multiple values to a row in a tree store
 */
TreeIter appendValues(TreeStore ts, TreeIter parentIter, string[] values) {
    TreeIter iter;
    ts.append(iter, parentIter);
    for (int i = 0; i < values.length; i++) {
        ts.setValue(iter, i, new Value(values[i]));
    }
    return iter;
}
/**
 * Appends multiple values to a row in a list store
 */
TreeIter appendValues(ListStore ls, string[] values) {
    TreeIter iter;
    ls.append(iter);
    for (int i = 0; i < values.length; i++) {
        ls.setValue(iter, i, new Value(values[i]));
    }
    return iter;
}

/**
 * GType constants for common types
 */
enum GTypes : GType {
    STRING = 64,    // G_TYPE_STRING
    BOOLEAN = 20,   // G_TYPE_BOOLEAN
    INT = 24,       // G_TYPE_INT
    INT64 = 40,     // G_TYPE_INT64
    DOUBLE = 60     // G_TYPE_DOUBLE
}

/**
 * Creates a combobox that holds a set of name/value pairs
 * where the name is displayed.
 */
ComboBox createNameValueCombo(const string[string] keyValues) {
    ListStore ls = ListStore.new_([GTypes.STRING, GTypes.STRING]);

    foreach (key, value; keyValues) {
        appendValues(ls, [value, key]);
    }

    ComboBox cb = ComboBox.newWithModel(ls);
    cb.focusOnClick = false;
    cb.idColumn = 1;
    CellRendererText cell = new CellRendererText();
    cell.setAlignment(0, 0);
    cb.packStart(cell, false);
    cb.addAttribute(cell, "text", 0);

    return cb;
}

/**
 * Creates a combobox that holds a set of name/value pairs
 * where the name is displayed.
 */
ComboBox createNameValueCombo(const string[] names, const string[] values) {
    assert(names.length == values.length);

    ListStore ls = ListStore.new_([GTypes.STRING, GTypes.STRING]);

    for (int i = 0; i < names.length; i++) {
        appendValues(ls, [names[i], values[i]]);
    }

    ComboBox cb = ComboBox.newWithModel(ls);
    cb.focusOnClick = false;
    cb.idColumn = 1;
    CellRendererText cell = new CellRendererText();
    cell.setAlignment(0, 0);
    cb.packStart(cell, false);
    cb.addAttribute(cell, "text", 0);

    return cb;
}

template TComboBox(T) {

    ComboBox createComboBox(const string[] names, T[] values) {
        assert(names.length == values.length);
        trace(typeof(values).stringof);

        GType valueType = GTypes.STRING;
        if (is(typeof(values) == int[]))
            valueType = GTypes.INT;
        else if (is(typeof(values) == uint[]))
            valueType = GTypes.INT;
        else if (is(typeof(values) == long[]))
            valueType = GTypes.INT64;
        else if (is(typeof(values) == ulong[]))
            valueType = GTypes.INT64;
        else if (is(typeof(values) == double[]))
            valueType = GTypes.DOUBLE;

        trace(valueType);

        ListStore ls = ListStore.new_([GTypes.STRING, valueType]);

        for (int row; row < values.length; row++) {
            TreeIter iter;
            ls.append(iter);
            ls.setValue(iter, 0, new Value(names[row]));
            ls.setValue(iter, 1, new Value(values[row]));
        }

        ComboBox cb = ComboBox.newWithModel(ls);
        cb.focusOnClick = false;
        cb.idColumn = 1;
        CellRendererText cell = new CellRendererText();
        cell.setAlignment(0, 0);
        cb.packStart(cell, false);
        cb.addAttribute(cell, "text", 0);
        return cb;
    }
}

/**
 * Selects the specified row in a Treeview
 */
void selectRow(TreeView tv, int row, TreeViewColumn column = null) {
    TreeModel model = tv.getModel();
    TreeIter iter;
    if (model.iterNthChild(iter, null, row)) {
        tv.setCursor(model.getPath(iter), column, false);
    } else {
        tracef("No TreeIter found for row %d", row);
    }
}

/**
 * An implementation of a range that allows using foreach with a TreeModel and TreeIter
 */
struct TreeIterRange {

private:
    TreeModel model;
    TreeIter iter;
    bool _empty;

public:
    this(TreeModel model) {
        this.model = model;
        _empty = !model.getIterFirst(iter);
    }

    this(TreeModel model, TreeIter parent) {
        this.model = model;
        _empty = !model.iterChildren(iter, parent);
        if (_empty)
            trace("TreeIter has no children");
    }

    @property bool empty() {
        return _empty;
    }

    @property auto front() {
        return iter;
    }

    void popFront() {
        _empty = !model.iterNext(iter);
    }

    /**
     * Based on the example here https://www.sociomantic.com/blog/2010/06/opapply-recipe/#.Vm8mW7grKEI
     */
    int opApply(int delegate(ref TreeIter iter) dg) {
        int result = 0;
        bool hasNext = !_empty;
        while (hasNext) {
            result = dg(iter);
            if (result) {
                break;
            }
            hasNext = model.iterNext(iter);
        }
        return result;
    }
}

/**
 * Helper function to get a string value from a TreeModel at the given column
 */
string getValueString(TreeModel model, TreeIter iter, int column) {
    Value val;
    model.getValue(iter, column, val);
    if (val is null) return "";
    return val.getString();
}

/**
 * Helper function to get a string value from a TreeStore at the given column
 */
string getValueString(TreeStore store, TreeIter iter, int column) {
    return getValueString(cast(TreeModel) store, iter, column);
}

/**
 * Helper function to get a string value from a ListStore at the given column
 */
string getValueString(ListStore store, TreeIter iter, int column) {
    return getValueString(cast(TreeModel) store, iter, column);
}

/**
 * Helper function to get an int value from a TreeModel at the given column
 */
int getValueInt(TreeModel model, TreeIter iter, int column) {
    Value val;
    model.getValue(iter, column, val);
    if (val is null) return 0;
    return val.getInt();
}

/**
 * Helper function to get an int value from a TreeStore at the given column
 */
int getValueInt(TreeStore store, TreeIter iter, int column) {
    return getValueInt(cast(TreeModel) store, iter, column);
}

/**
 * Helper function to get an int value from a ListStore at the given column
 */
int getValueInt(ListStore store, TreeIter iter, int column) {
    return getValueInt(cast(TreeModel) store, iter, column);
}

/**
 * Helper function to get the selected TreeIter from a TreeView
 * Returns null if nothing is selected
 */
TreeIter getSelectedIter(TreeView tv) {
    import gtk.tree_selection : TreeSelection;
    TreeSelection selection = tv.getSelection();
    if (selection is null) return null;
    TreeModel model;
    TreeIter iter;
    if (selection.getSelected(model, iter)) {
        return iter;
    }
    return null;
}

/**
 * Helper function to check if a TreeIter has a parent
 */
bool hasParent(TreeModel model, TreeIter iter) {
    TreeIter parent;
    return model.iterParent(parent, iter);
}

/**
 * Helper function to get parent iter
 */
TreeIter getParentIter(TreeModel model, TreeIter iter) {
    TreeIter parent;
    if (model.iterParent(parent, iter)) {
        return parent;
    }
    return null;
}