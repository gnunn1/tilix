/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.util;

import std.conv;
import std.experimental.logger;
import std.format;
import std.process;
import std.string;

import gdk.atom;
import gdk.types;
import gdk.global;
import gdk.types;
import gdk.rgba;
import gdk.types;


import gio.file;
import gio.list_model;
import gio.settings: Settings = Settings;

import glib.error;



import gobject.object;
import gobject.types;
import gobject.types;
import gobject.type_instance;
import gobject.types;
import gobject.value;
import gobject.types;

import gtk.bin;
import gtk.types;
import gx.gtk.types;

extern(C) GType gdk_x11_window_get_type();

import gtk.box;
import gtk.types;
import gtk.types;
import gtk.combo_box;
import gtk.types;
import gtk.cell_renderer_text;
import gtk.types;
import gtk.container;
import gtk.types;
import gtk.entry;
import gtk.types;
import gtk.list_store;
import gtk.types;
import gtk.global;
import gtk.types;
import gtk.paned;
import gtk.types;
import gtk.settings;
import gtk.types;
import gtk.style_context;
import gtk.types;
import gtk.tree_iter;
import gtk.types;
import gtk.tree_model;
import gtk.types;
import gtk.tree_path;
import gtk.types;
import gtk.tree_store;
import gtk.types;
import gtk.tree_view;
import gtk.types;
import gtk.tree_view_column;
import gtk.types;
import gtk.widget;
import gtk.types;
import gtk.window;
import gtk.types;

import gx.gtk.x11;

/**
 * Parse filename and return File object
 */
public File parseName(string parseName) {
    return File.newForCommandlineArg(parseName);
}



/**
 * Directly process events for up to a specified period
 */
static if (__VERSION__ >=2075) {
    void processEvents(uint millis) {
        import std.datetime.stopwatch: StopWatch, AutoStart;
        StopWatch sw = StopWatch(AutoStart.yes);
        scope (exit) {
            sw.stop();
        }
        while (gtk.global.eventsPending() && sw.peek.total!"msecs" < millis) {
            gtk.global.mainIteration();
        }
    }
} else {
    void processEvents(uint millis) {
        import std.datetime: StopWatch, AutoStart;
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
    if (window.isActive()) return;

    if (isWayland(window)) {
        trace("Present Window for Wayland");
        window.presentWithTime(CURRENT_TIME);
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
    if (window is null || window.getWindow() is null) {
        return (environment.get("XDG_SESSION_TYPE","x11") == "wayland" && environment.get("GDK_BACKEND")!="x11");
    }

    import gobject.c.types : GTypeInstance;
    import gobject.c.functions: g_type_check_instance_is_a;

    GType x11Type = gdk_x11_window_get_type();
    GTypeInstance* instance = cast(GTypeInstance*)(window.getWindow()._cPtr());

    return g_type_check_instance_is_a(instance, x11Type) == 0;
}

/**
 * Return the name of the GTK Theme
 */
string getGtkTheme() {
    Settings settings = new Settings("org.gnome.desktop.interface");
    // `GSettings` keys are not GObject properties; the theme name is stored in
    // the `gtk-theme` key of `org.gnome.desktop.interface`.
    try {
        return settings.getString("gtk-theme");
    } catch (ErrorWrap) {
        return "";
    } catch (Exception) {
        return "";
    }
}

/**
 * Convenience method for creating a box and adding children
 */
Box createBox(gtk.types.Orientation orientation, int spacing,  Widget[] children) {
    Box result = new Box(orientation, spacing);
    foreach(child; children) {
        result.add(child);
    }
    return result;
}

/**
 * Finds the index position of a child in a container.
 */
int getChildIndex(Container container, Widget child) {
    Widget[] children = container.getChildren();
    foreach(i, c; children) {
        if (c._cPtr() == child._cPtr()) return cast(int) i;
    }
    return -1;
}

/**
 * Walks up the parent chain until it finds the parent of the
 * requested type.
 */
T findParent(T) (Widget widget) {
    while ((widget !is null)) {
        widget = widget.getParent();
        T result = cast(T) widget;
        if (result !is null) return result;
    }
    return null;
}

/**
 * Template for finding all children of a specific type
 */
T[] getChildren(T) (Widget widget, bool recursive) {
    T[] result;
    Widget[] children;

    if (widget is null) return result;

    Bin bin = cast(Bin) widget;
    if (bin !is null) {
        children = [bin.getChild()];
    } else {
        Container container = cast(Container) widget;
        if (container !is null) {
            children = container.getChildren();
        }
    }

    foreach(child; children) {
        T match = cast(T) child;
        if (match !is null) result ~= match;
        if (recursive) {
            result ~= getChildren!(T)(child, recursive);
        }
    }
    return result;
}

/**
 * Gets the background color from style context. Works around
 * spurious VTE State messages on GTK 3.19 or later. See the
 * blog entry here: https://blogs.gnome.org/mclasen/2015/11/20/a-gtk-update/
 */
void getStyleBackgroundColor(StyleContext context, StateFlags flags, RGBA color) {
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
void getStyleColor(StyleContext context, StateFlags flags, RGBA color) {
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
    widget.setMarginStart(left);
    widget.setMarginTop(top);
    widget.setMarginEnd(right);
    widget.setMarginBottom(bottom);
}

/**
 * Defined here since not defined in GtkD
 */
enum MouseButton : uint {
    PRIMARY = 1,
    MIDDLE = 2,
    SECONDARY = 3
}

/**
 * Not declared in GtkD
 */
enum long CURRENT_TIME = 0;

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
    return w1._cPtr() == w2._cPtr();
}

/**
 * Appends multiple values to a row in a list store
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
 * Creates a combobox that holds a set of name/value pairs
 * where the name is displayed.
 */
ComboBox createNameValueCombo(const string[string] keyValues) {

    ListStore ls = ListStore.new_([cast(GType)GTypeEnum.String, cast(GType)GTypeEnum.String]);

    foreach (key, value; keyValues) {
        appendValues(ls, [value, key]);
    }

    ComboBox cb = new ComboBox();
    cb.setModel(ls);
    cb.setFocusOnClick(false);
    cb.setIdColumn(1);
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

    ListStore ls = ListStore.new_([cast(GType)GTypeEnum.String, cast(GType)GTypeEnum.String]);

    for (int i = 0; i < names.length; i++) {
        appendValues(ls, [names[i], values[i]]);
    }

    ComboBox cb = new ComboBox();
    cb.setModel(ls);
    cb.setFocusOnClick(false);
    cb.setIdColumn(1);
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

        GTypeEnum valueType = GTypeEnum.String;
        if (is(typeof(values) == int[])) valueType = GTypeEnum.Int;
        else if (is(typeof(values) == uint[])) valueType = GTypeEnum.Int;
        else if (is(typeof(values) == long[])) valueType = GTypeEnum.Int64;
        else if (is(typeof(values) == ulong[])) valueType = GTypeEnum.Int64;
        else if (is(typeof(values) == double[])) valueType = GTypeEnum.Double;

        trace(valueType);

        ListStore ls = ListStore.new_([cast(GType)GTypeEnum.String, cast(GType)valueType]);

        for (int row; row < values.length; row++) {
            TreeIter iter;
            ls.append(iter);
            ls.setValue(iter, 0, new Value(names[row]));
            ls.setValue(iter, 1, new Value(values[row]));
        }

        ComboBox cb = new ComboBox();
        cb.setModel(ls);
        cb.setFocusOnClick(false);
        cb.setIdColumn(1);
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
    model.iterNthChild(iter, null, row);
    if (iter !is null) {
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
        if (_empty) trace("TreeIter has no children");
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
        //bool hasNext = model.getIterFirst(iter);
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
