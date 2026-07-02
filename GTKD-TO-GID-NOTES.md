# GtkD to GID Migration Notes

This document captures all patterns, problems, and solutions discovered during the migration of Tilix from GtkD to GID bindings.

---

## Table of Contents

1. [Import Path Changes](#1-import-path-changes)
2. [Signal Connections](#2-signal-connections)
3. [Enum Naming Conventions](#3-enum-naming-conventions)
4. [Constructor Patterns](#4-constructor-patterns)
5. [Property Access](#5-property-access)
6. [C API Fallback Patterns](#6-c-api-fallback-patterns)
7. [Type System Differences](#7-type-system-differences)
8. [Common Problems and Solutions](#8-common-problems-and-solutions)
9. [Memory Management](#9-memory-management)
10. [Platform-Specific Considerations](#10-platform-specific-considerations)

---

## 1. Import Path Changes

GID uses snake_case for module names instead of GtkD's PascalCase.

### General Pattern

| GtkD | GID |
|------|-----|
| `gtk.Window` | `gtk.window` |
| `gtk.ApplicationWindow` | `gtk.application_window` |
| `gtk.MessageDialog` | `gtk.message_dialog` |
| `gtk.CssProvider` | `gtk.css_provider` |
| `gtk.StyleContext` | `gtk.style_context` |
| `gdk.RGBA` | `gdk.rgba` |
| `gdk.Screen` | `gdk.screen` |
| `gio.Settings` | `gio.settings` |
| `gio.SimpleAction` | `gio.simple_action` |
| `glib.Variant` | `glib.variant` |
| `glib.VariantType` | `glib.variant_type` |
| `gobject.ObjectG` | `gobject.object` |
| `gobject.ParamSpec` | `gobject.param_spec` |
| `vte.Terminal` | `vte.terminal` |
| `cairo.Context` | `cairo.context` |
| `cairo.ImageSurface` | `cairo.surface` (see note below) |
| `pango.PgFontDescription` | `pango.font_description` |
| `gdkpixbuf.Pixbuf` | `gdkpixbuf.pixbuf` |

### Special Import Cases

#### Cairo ImageSurface
GID does not have a separate `ImageSurface` class. Use `cairo.surface.Surface` with `imageSurfaceCreate()` from `cairo.global`:

```d
// GtkD
import cairo.ImageSurface;
ImageSurface surface = new ImageSurface(Format.ARGB32, width, height);

// GID
import cairo.surface : Surface;
import cairo.global : imageSurfaceCreate;
Surface surface = imageSurfaceCreate(Format.Argb32, width, height);
```

#### GIO Application vs GTK Application
When using both, use aliases to avoid conflicts:

```d
// GID
import gio.application : GioApplication = Application;
import gtk.application : Application;
```

#### GIO Settings vs GTK Settings
```d
// GID
import gio.settings : GSettings = Settings;
import gtk.settings : GtkSettings = Settings;
```

#### Global Functions
Many utility functions moved to `global` modules:

```d
// GtkD
import glib.Util;
import glib.FileUtils;
import gtk.Main;
import gtk.Version;

// GID
import glib.global : getCurrentDir, getHomeDir, setPrgname, chdir;
import gtk.global : checkVersion, getMajorVersion, getMinorVersion, getMicroVersion;
```

#### Internationalization
```d
// GtkD
import glib.Internationalization;
Internationalization.dgettext(domain, text);

// GID
import glib.global : dgettext, dpgettext2;
dgettext(domain, text);
```

---

## 2. Signal Connections

### Basic Pattern

GtkD uses `addOn*` methods, GID uses `connect*` methods:

| GtkD | GID |
|------|-----|
| `widget.addOnClicked(&handler)` | `widget.connectClicked(&handler)` |
| `widget.addOnDestroy(&handler)` | `widget.connectDestroy(&handler)` |
| `widget.addOnActivate(&handler)` | `widget.connectActivate(&handler)` |
| `widget.addOnStartup(&handler)` | `widget.connectStartup(&handler)` |
| `widget.addOnShutdown(&handler)` | `widget.connectShutdown(&handler)` |
| `widget.addOnCommandLine(&handler)` | `widget.connectCommandLine(&handler)` |
| `widget.addOnResponse(&handler)` | `widget.connectResponse(&handler)` |
| `widget.addOnClose(&handler)` | `widget.connectClose(&handler)` |

### Signal Connection Return Value

GID `connect*` methods return `ulong` (the signal handler ID) which can be used to disconnect later.

### Settings Changed Signal

```d
// GtkD
gsettings.addOnChanged(delegate(string key, Settings) { ... });

// GID - note the detail parameter (can be null for all keys)
gsettings.connectChanged(null, delegate(string key, GSettings) { ... });
```

### Notify Signal (Property Changes)

```d
// GtkD
settings.addOnNotify(&handler, "property-name", ConnectFlags.AFTER);

// GID
settings.connectNotify("property-name", &handler, No.After);
```

### ConnectFlags

```d
// GtkD
ConnectFlags.AFTER

// GID
import gid.gid : No, Yes;
No.After  // or Yes.After
```

---

## 3. Enum Naming Conventions

GID uses PascalCase for enum values instead of SCREAMING_CASE:

| GtkD | GID |
|------|-----|
| `ResponseType.OK` | `ResponseType.Ok` |
| `ResponseType.CANCEL` | `ResponseType.Cancel` |
| `ResponseType.DELETE_EVENT` | `ResponseType.DeleteEvent` |
| `DialogFlags.MODAL` | `DialogFlags.Modal` |
| `MessageType.ERROR` | `MessageType.Error` |
| `MessageType.WARNING` | `MessageType.Warning` |
| `ButtonsType.OK` | `ButtonsType.Ok` |
| `ButtonsType.OK_CANCEL` | `ButtonsType.OkCancel` |
| `IconSize.DIALOG` | `IconSize.Dialog` |
| `ApplicationFlags.HANDLES_COMMAND_LINE` | `ApplicationFlags.HandlesCommandLine` |
| `ApplicationFlags.NON_UNIQUE` | `ApplicationFlags.NonUnique` |
| `GOptionFlags.NONE` | `GOptionFlags.None` |
| `GOptionFlags.HIDDEN` | `GOptionFlags.Hidden` |
| `GOptionArg.STRING` | `GOptionArg.String` |
| `GOptionArg.STRING_ARRAY` | `GOptionArg.StringArray` |
| `GOptionArg.NONE` | `GOptionArg.None` |
| `Format.ARGB32` | `Format.Argb32` |
| `Operator.SOURCE` | `Operator.Source` |

---

## 4. Constructor Patterns

### Factory Methods Instead of Constructors

GID often uses factory methods instead of constructors:

```d
// GtkD
new Button("label")
new CheckButton("label")
new Image(iconName, size)
new SpinButton(min, max, step)
new Label("text")

// GID
Button.newWithLabel("label")
CheckButton.newWithLabel("label")
Image.newFromIconName(iconName, size)
SpinButton.newWithRange(min, max, step)
new Label("text")  // simple constructors still work
```

### Pixbuf Loading

```d
// GtkD
new Pixbuf(filename)
new Pixbuf(filename, width, height, preserveAspect)

// GID
Pixbuf.newFromFile(filename)
Pixbuf.newFromFileAtScale(filename, width, height, preserveAspect)
```

### AboutDialog

```d
// GtkD
with (dialog = new AboutDialog()) { ... }

// GID - need to separate construction from with block
dialog = new AboutDialog();
with (dialog) { ... }
```

---

## 5. Property Access

### GTK Settings Properties

GID provides D-style property accessors:

```d
// GtkD
Settings.getDefault().setProperty(GTK_APP_PREFER_DARK_THEME, darkMode);
Settings.getDefault().getProperty(GTK_MENU_BAR_ACCEL, value);

// GID
GtkSettings.getDefault().gtkApplicationPreferDarkTheme = darkMode;
string accel = GtkSettings.getDefault().gtkMenuBarAccel;
GtkSettings.getDefault().gtkMenuBarAccel = "";
GtkSettings.getDefault().gtkEnableAccels = true;
```

### Reset Property

```d
// GtkD
Settings.getDefault.resetProperty(propertyName);

// GID
GtkSettings.getDefault.resetProperty(propertyName);
```

---

## 6. C API Fallback Patterns

Some widgets don't have high-level D constructors in GID and require using the C API directly.

### MessageDialog

```d
// GtkD
MessageDialog dialog = new MessageDialog(parent, DialogFlags.MODAL,
    MessageType.ERROR, ButtonsType.OK, message, null);

// GID
import gtk.c.functions : gtk_message_dialog_new;
import gtk.c.types : GtkDialogFlags, GtkMessageType, GtkButtonsType, GtkWidget, GtkWindow;
import gobject.object : ObjectG;
import gid.gid : No;

GtkDialogFlags flags = GtkDialogFlags.Modal;
GtkWidget* widget = gtk_message_dialog_new(
    parent ? cast(GtkWindow*) parent.cPtr(No.Dup) : null,
    flags,
    GtkMessageType.Error,
    GtkButtonsType.Ok,
    message.ptr,
    null
);
MessageDialog dialog = ObjectG.getDObject!MessageDialog(cast(void*) widget, No.Take);
```

### Accessing C Pointers

```d
// GtkD
widget.getWidgetStruct()
window.getWindowStruct()

// GID
widget.cPtr(No.Dup)
// For specific types, cast as needed:
cast(GtkWindow*) window.cPtr(No.Dup)
```

### gtk_application_set_accels_for_action

```d
// GtkD
gtk_application_set_accels_for_action(gtkApplication, Str.toStringz(actionName), tmp);

// GID
import gid.gid : Str = ZeroTermString;
gtk_application_set_accels_for_action(cast(GtkApplication*)cPtr(No.Dup), Str(actionName), tmp);
```

---

## 7. Type System Differences

### Variant.getString

```d
// GtkD
size_t length;
string value = variant.getString(length);

// GID - simplified, no length parameter needed
string value = variant.getString();
```

### ListG to Array

```d
// GtkD
ListG list = getWindows();
Window[] windows = list.toArray!(Window)();

// GID - returns D array directly
Window[] windows = getWindows();
```

### Application ID Validation

```d
// GtkD
if (idIsValid(id)) { ... }

// GID - static method on Application class
if (GioApplication.idIsValid(id)) { ... }
```

### Version Checking

```d
// GtkD
if (Version.checkVersion(3, 19, 0).length == 0) { ... }

// GID - returns null if version is sufficient
if (checkVersion(3, 19, 0) is null) { ... }
```

---

## 8. Common Problems and Solutions

### Problem: "unable to read module" Error

**Cause**: GtkD-style PascalCase import path used instead of GID snake_case.

**Solution**: Convert import paths to snake_case:
```d
// Wrong
import gtk.ApplicationWindow;
import gio.SimpleAction;

// Correct
import gtk.application_window;
import gio.simple_action;
```

### Problem: Unused Import Causes Build Failure

**Cause**: An import references a non-existent module (leftover from incomplete migration).

**Solution**: Remove unused imports. For example:
```d
// This was unused and the module doesn't exist in GID
import gobject.type : Type;  // Remove this line
```

### Problem: Enum Value Not Found

**Cause**: Using SCREAMING_CASE instead of PascalCase.

**Solution**: Convert enum values:
```d
// Wrong
ResponseType.OK
DialogFlags.MODAL

// Correct
ResponseType.Ok
DialogFlags.Modal
```

### Problem: setMarginLeft/setMarginRight Deprecated

**Solution**: Use setMarginStart/setMarginEnd:
```d
// Deprecated
widget.setMarginLeft(0);
widget.setMarginRight(0);

// Correct
widget.setMarginStart(0);
widget.setMarginEnd(0);
```

### Problem: Dynamic Symbol Loading (dlopen/dlsym)

For runtime symbol loading (e.g., X11-specific functions), use POSIX APIs:

```d
import core.sys.posix.dlfcn : dlopen, dlsym, RTLD_NOW;

void* lib = dlopen("libgdk-3.so.0", RTLD_NOW);
if (lib !is null) {
    auto func = cast(FuncType) dlsym(lib, "function_name");
}
```

---

## 9. Memory Management

### Ownership Flags

GID uses `Flag!"Take"` for ownership:

```d
import gid.gid : No, Yes;

// Don't take ownership (caller still owns the object)
ObjectG.getDObject!Widget(ptr, No.Take);

// Take ownership (GID will free when D object is collected)
ObjectG.getDObject!Widget(ptr, Yes.Take);
```

### Scope Exit for Cleanup

```d
MessageDialog dialog = ...;
scope (exit) {
    dialog.destroy();
}
// use dialog...
```

---

## 10. Platform-Specific Considerations

### X11 Functions

X11-specific GDK functions are not directly available in GID and must be loaded at runtime:

```d
// Load X11-specific functions dynamically
import core.sys.posix.dlfcn : dlopen, dlsym, RTLD_NOW;

private void* gdkX11Lib;
private extern(C) ulong function(void*) gdk_x11_window_get_xid;

static this() {
    gdkX11Lib = dlopen("libgdk-3.so.0", RTLD_NOW);
    if (gdkX11Lib !is null) {
        gdk_x11_window_get_xid = cast(typeof(gdk_x11_window_get_xid))
            dlsym(gdkX11Lib, "gdk_x11_window_get_xid");
    }
}
```

### Idle and Timeout Functions

```d
// GtkD
import gdk.Threads : threadsAddIdle, threadsAddTimeout;

// GID
import gdk.global : threadsAddIdle, threadsAddTimeout;
import glib.types : SourceFunc, PRIORITY_DEFAULT_IDLE;

// GID supports D delegates directly
SourceFunc wrappedDelegate = delegate bool() { ... };
threadsAddIdle(PRIORITY_DEFAULT_IDLE, wrappedDelegate);
```

---

## Appendix: Import Mapping Quick Reference

### GtkD Low-Level Modules → GID

| GtkD | GID |
|------|-----|
| `gtkc.gtk` | Remove (use specific modules) |
| `gtkc.glib` | `glib.c.functions` |
| `gtkc.glibtypes` | `glib.c.types` |
| `gtkc.gobject` | `gobject.c.functions` |
| `gtkc.giotypes` | `gio.c.types` |
| `gtkc.Loader` | `core.sys.posix.dlfcn` |
| `gtkc.paths` | Remove (use dlopen directly) |
| `glib.Str` | `gid.gid : Str = ZeroTermString` or direct D strings |

### Commonly Used GID Helper Imports

```d
import gid.gid : No, Yes;                    // Ownership flags
import gid.gid : Str = ZeroTermString;       // C string conversion
import gobject.object : ObjectG = ObjectWrap; // For getDObject
```

---

## 11. Signal Handler Block/Unblock

### GtkD Pattern
```d
import gobject.Signals;
Signals.handlerBlock(widget, handlerId);
Signals.handlerUnblock(widget, handlerId);
```

### GID Pattern
```d
import gobject.global : signalHandlerBlock, signalHandlerUnblock;
signalHandlerBlock(widget, handlerId);
signalHandlerUnblock(widget, handlerId);
```

---

## 12. GDK Key Constants (Keysyms)

GID does not provide a `gdk.keysyms` module. Key constants must be defined locally:

```d
// GtkD
import gdk.Keysyms;
if (keyval == GdkKeysyms.GDK_Escape) { ... }

// GID - define locally
enum GdkKeysyms {
    GDK_Escape = 0xff1b,
    GDK_Return = 0xff0d,
    GDK_Tab = 0xff09,
    GDK_BackSpace = 0xff08,
    GDK_Delete = 0xffff,
    GDK_Home = 0xff50,
    GDK_End = 0xff57,
    GDK_Page_Up = 0xff55,
    GDK_Page_Down = 0xff56,
    GDK_Up = 0xff52,
    GDK_Down = 0xff54,
    GDK_Left = 0xff51,
    GDK_Right = 0xff53,
}
```

---

## 13. Event Methods

### Getting Event Properties

```d
// GtkD
ScrollDirection direction;
event.getScrollDirection(direction);

uint keyval;
event.getKeyval(keyval);

// GID - direct return values
ScrollDirection direction = event.getScrollDirection();
uint keyval = event.getKeyval();
uint button = event.getButton();
GdkWindowState newState = event.getNewWindowState();
```

---

## 14. FileChooserDialog

GID doesn't have a high-level constructor for FileChooserDialog. Use C API:

```d
// GtkD
FileChooserDialog fcd = new FileChooserDialog(
    _("Open File"),
    parent,
    FileChooserAction.OPEN,
    [_("Open"), _("Cancel")]);

// GID
import gtk.c.functions : gtk_file_chooser_dialog_new;
import gtk.c.types : GtkFileChooserAction, GtkWidget, GtkWindow;

GtkWidget* widget = gtk_file_chooser_dialog_new(
    _("Open File").ptr,
    cast(GtkWindow*) parent.cPtr(No.Dup),
    GtkFileChooserAction.Open,
    _("_Cancel").ptr, ResponseType.Cancel,
    _("_Open").ptr, ResponseType.Accept,
    null
);
FileChooserDialog fcd = ObjectG.getDObject!FileChooserDialog(cast(void*) widget, No.Take);
```

---

## 15. Window Comparison

```d
// GtkD
if (window.getWindowStruct() == other.getWindowStruct()) { ... }

// GID
if (window.cPtr(No.Dup) == other.cPtr(No.Dup)) { ... }
```

---

## 16. List Toplevels

```d
// GtkD
ListG list = window.listToplevels();
Window[] windows = list.toArray!(Window)();

// GID - returns D array directly
Window[] windows = window.listToplevels();
```

---

## 17. Pango Types

```d
// GtkD
import gtk.PgFontDescription;
label.setEllipsize(PangoEllipsizeMode.START);

// GID
import pango.types : EllipsizeMode;
label.setEllipsize(EllipsizeMode.Start);
```

---

## 18. Cairo Types for Drawing

```d
// GtkD
import cairo.Context;
cr.selectFontFace("monospace", cairo_font_slant_t.NORMAL, cairo_font_weight_t.NORMAL);
cairo_text_extents_t extents;
cr.textExtents(text, &extents);

// GID
import cairo.context : Context;
import cairo.types : FontSlant, FontWeight, TextExtents;
cr.selectFontFace("Sans", FontSlant.Normal, FontWeight.Bold);
TextExtents extents;
cr.textExtents(text, extents);
```

---

## 19. Secret Service API (libsecret)

### Schema Creation

GID doesn't expose a high-level Schema constructor. Use C API:

```d
// GtkD
import secret.Schema;
string[string] ht;
ht["id"] = "";
ht["description"] = "";
schema = new Schema("com.example.Password", SecretSchemaFlags.NONE, ht);

// GID
import secret.schema : Schema;
import secret.c.types : SecretSchema, SecretSchemaAttributeType, SecretSchemaFlags;
import secret.c.functions : secret_schema_newv;
import glib.c.types : GHashTable;
import glib.c.functions : g_hash_table_new, g_hash_table_insert;
import std.string : toStringz;
import std.typecons : Flag, Yes;

GHashTable* ht = g_hash_table_new(null, null);
g_hash_table_insert(ht, cast(void*) toStringz("id"), cast(void*) SecretSchemaAttributeType.String);
g_hash_table_insert(ht, cast(void*) toStringz("description"), cast(void*) SecretSchemaAttributeType.String);
SecretSchema* cSchema = secret_schema_newv(toStringz("com.example.Password"), SecretSchemaFlags.None, ht);
schema = new Schema(cast(void*) cSchema, Yes.Take);
```

### Async Callbacks

GID async methods use D delegates instead of C function pointers with user data:

```d
// GtkD (C-style callbacks with user data)
extern(C) static void secretServiceCallback(GObject* sourceObject, GAsyncResult* res, void* userData) {
    PasswordDialog pd = cast(PasswordDialog) ObjectWrap.getDObject!(Dialog)(cast(GtkDialog*) userData, false);
    // ...
}
Service.get(SecretServiceFlags.OPEN_SESSION, cancellable, &secretServiceCallback, this.getDialogStruct());

// GID (D delegates, no user data needed - captures context)
import gio.async_result : AsyncResult;
void onSecretServiceReady(ObjectWrap sourceObject, AsyncResult res) {
    Service ss = Service.getFinish(res);
    // Access `this` directly since delegate captures context
}
Service.get(ServiceFlags.OpenSession, cancellable, &onSecretServiceReady);
```

### Secret Service Enums

```d
// GtkD
SecretSchemaFlags.NONE
SecretServiceFlags.OPEN_SESSION
SecretCollectionFlags.LOAD_ITEMS

// GID
import secret.types : SchemaFlags, ServiceFlags, CollectionFlags;
SchemaFlags.None
ServiceFlags.OpenSession
CollectionFlags.LoadItems
```

---

## 20. ListStore and TreeView

### ListStore Creation

```d
// GtkD
ls = new ListStore([GType.STRING, GType.STRING]);

// GID
import gx.gtk.util : GTypes;  // Custom helper enum
ls = ListStore.new_([GTypes.STRING, GTypes.STRING]);
```

### Appending Rows

```d
// GtkD
TreeIter iter = ls.createIter();
ls.setValue(iter, 0, "value");

// GID
TreeIter iter;
ls.append(iter);  // out parameter pattern
ls.setValue(iter, 0, new Value("value"));  // wrap in Value
```

### Getting Selected TreeIter

```d
// GtkD
TreeIter selected = treeView.getSelectedIter();

// GID - no method on TreeView, use helper function
TreeIter getSelectedIter(TreeView tv) {
    TreeSelection selection = tv.getSelection();
    if (selection is null) return null;
    TreeModel model;
    TreeIter iter;
    if (selection.getSelected(model, iter)) {
        return iter;
    }
    return null;
}
TreeIter selected = getSelectedIter(treeView);
```

---

## 21. GDK Atoms and Clipboard

### Atom Objects vs Raw Pointers

```d
// GtkD (raw GdkAtom pointers)
private __gshared GdkAtom GDK_SELECTION_CLIPBOARD;
shared static this() {
    auto clipboardAtom = Atom.intern("CLIPBOARD", false);
    GDK_SELECTION_CLIPBOARD = cast(GdkAtom)clipboardAtom.getAtomStruct();
}
Clipboard.get(GDK_SELECTION_CLIPBOARD);

// GID (Atom objects)
import gdk.atom : Atom;
private __gshared Atom GDK_SELECTION_CLIPBOARD;
shared static this() {
    GDK_SELECTION_CLIPBOARD = Atom.intern("CLIPBOARD", false);
}
Clipboard.get(GDK_SELECTION_CLIPBOARD);  // accepts Atom directly
```

---

## 22. VTE Terminal

### feedChild Method

```d
// GtkD
vte.feedChild(text);

// GID - requires ubyte[] not string
vte.feedChild(cast(ubyte[]) text);
```

### VTE Regex Creation

```d
// GtkD
VRegex.newMatch(pattern, -1, flags)
VRegex.newSearch(pattern, -1, flags)

// GID
VRegex.newForMatch(pattern, -1, flags)
VRegex.newForSearch(pattern, -1, flags)
```

### VTE Enums

```d
// GtkD
VteCursorShape.BLOCK
VteCursorShape.IBEAM
VteCursorShape.UNDERLINE

// GID
VteCursorShape.Block
VteCursorShape.Ibeam
VteCursorShape.Underline
```

---

## 23. File/URI Operations

### Filename to/from URI

```d
// GtkD
import glib.URI;
string uri = URI.filenameToUri(filename, null);
string filename = URI.filenameFromUri(uri, hostname);

// GID
import glib.global : filenameToUri, filenameFromUri;
string uri = filenameToUri(filename, null);
string hostname;
string filename = filenameFromUri(uri, hostname);  // out parameter
```

### Show URI

```d
// GtkD
import gio.MountOperation;
MountOperation.showUri(null, uri, timestamp);

// GID
import gtk.global : showUri, showUriOnWindow;
showUri(null, uri, cast(uint) timestamp);
// or with parent window:
showUriOnWindow(parentWindow, uri, cast(uint) timestamp);
```

---

## 24. GSpawn Flags

```d
// GtkD
GSpawnFlags.SEARCH_PATH_FROM_ENVP
GSpawnFlags.FILE_AND_ARGV_ZERO
GSpawnFlags.SEARCH_PATH

// GID
GSpawnFlags.SearchPathFromEnvp
GSpawnFlags.FileAndArgvZero
GSpawnFlags.SearchPath
```

---

## 25. GDK Modifier Types and Scroll Direction

```d
// GtkD
ModifierType.CONTROL_MASK
ModifierType.SHIFT_MASK
ModifierType.MOD1_MASK
ScrollDirection.UP
ScrollDirection.DOWN
ScrollDirection.SMOOTH

// GID
import gdk.c.types : GdkModifierType;
GdkModifierType.ControlMask
GdkModifierType.ShiftMask
GdkModifierType.Mod1Mask
ScrollDirection.Up
ScrollDirection.Down
ScrollDirection.Smooth
```

---

## 26. GTK State and Policy Types

```d
// GtkD
StateFlags.ACTIVE
PolicyType.NEVER
PolicyType.AUTOMATIC

// GID
StateFlags.Active
PolicyType.Never
PolicyType.Automatic
```

---

## 27. Cursor Types

```d
// GtkD
CursorType.HAND2

// GID
import gdk.types : CursorType;
CursorType.Hand2
```

---

## 28. Popover and Rectangle

### Popover Creation from Menu Model

```d
// GtkD
Popover popover = new Popover(widget, menuModel);

// GID
Popover popover = Popover.newFromModel(widget, menuModel);
```

### setPointingTo with Rectangle

```d
// GtkD
GdkRectangle rect = GdkRectangle(x, y, 1, 1);
popover.setPointingTo(&rect);

// GID
import gdk.rectangle : Rectangle;
// Need to create Rectangle object, not use GdkRectangle pointer
Rectangle rect = new Rectangle(x, y, 1, 1);
popover.setPointingTo(rect);
```

---

## 29. Frame Constructor

```d
// GtkD
Frame frame = new Frame(childWidget, null);

// GID - no child parameter in constructor
Frame frame = new Frame(null);  // label parameter only
frame.add(childWidget);
```

---

## 30. Image Creation

```d
// GtkD
Image img = new Image("icon-name", IconSize.Menu);

// GID
Image img = Image.newFromIconName("icon-name", IconSize.Menu);
```

---

## 31. Exception Types

```d
// GtkD
try { ... }
catch (GException e) { ... }

// GID
import glib.error : ErrorWrap;
try { ... }
catch (ErrorWrap e) { ... }
```

---

## 32. GSourceFunc Type

```d
// GtkD
import glib.Timeout;
Timeout.add(interval, delegate bool() { ... });

// GID
import glib.c.types : GSourceFunc;
import glib.c.functions : g_timeout_add;
// For C API callbacks, need extern(C) function or use delegate wrapper
```

---

## 33. DBusConnection and Signal Subscribe

### GID DBusConnection
```d
// GtkD
import gio.DBusConnection;
DBusConnection connection = new DBusConnection(address, flags, null, null);
connection.signalSubscribe(sender, iface, member, path, null,
    GDBusSignalFlags.NONE, cast(GDBusSignalCallback)&callback, userData, null);

// GID
import gio.dbus_connection : DBusConnection;
import gio.types : DBusConnectionFlags, DBusSignalFlags, DBusCallFlags;

// Use factory method instead of constructor
DBusConnection connection = DBusConnection.newForAddressSync(
    address,
    DBusConnectionFlags.AuthenticationClient | DBusConnectionFlags.MessageBusConnection,
    null, null);

// Use D delegate instead of C callback
connection.signalSubscribe(
    sender, iface, member, path, null,
    DBusSignalFlags.None,
    (DBusConnection conn, string senderName, string objectPath,
     string interfaceName, string signalName, GVariant parameters) {
        // Handle signal
    });
```

---

## 34. GVariant Construction

### Dict Entries
```d
// GtkD - could use nested constructor
new GVariant(new GVariant(key), new GVariant(value));

// GID - use factory method
import glib.variant : Variant;
auto keyVar = new Variant(key);
auto valVar = new Variant(value);
auto dictEntry = Variant.newDictEntry(keyVar, valVar);
```

### Using C API for Complex Variants
```d
// For complex variant patterns not supported by GID wrappers:
import glib.c.functions : g_variant_new;
import glib.c.types : GVariant_ = GVariant;

GVariant_* vs = g_variant_new("(^ay^aay@a{uh}@a{ss}u)",
    workingDir, args,
    cast(GVariant_*)fdVar._cPtr(),
    cast(GVariant_*)envVar._cPtr(),
    flags);

auto result = new Variant(cast(void*)vs, Yes.Take);
```

---

## 35. DragContext - listTargets

The `listTargets()` method is not wrapped in GID. Use the C API:
```d
// GID - access C API directly
import gdk.c.functions : gdk_drag_context_list_targets;
import gdk.c.types : GdkDragContext;
import glib.c.types : GList;

auto targetsList = gdk_drag_context_list_targets(cast(GdkDragContext*)dc._cPtr);
for (auto l = targetsList; l !is null; l = l.next) {
    auto targetAtom = new Atom(l.data, No.Take);
    if (targetAtom.name() == targetName) {
        // Found it
    }
}
```

---

## 36. Atom Methods

```d
// GtkD
import gdk.atom : intern, name;
GdkAtom atom = intern("text/plain", false);
string atomName = name(atom);

// GID - use Atom class methods
import gdk.atom : Atom;
Atom atom = Atom.intern("text/plain", false);
string atomName = atom.name();
```

---

## 37. SelectionData

### getData vs getDataWithLength
```d
// GtkD
char[] data = selectionData.getDataWithLength();

// GID - use getData which returns ubyte[]
ubyte[] rawData = selectionData.getData();
char[] data = cast(char[])rawData;
```

### Setting Selection Data
```d
// GtkD
data.set(intern(atomName, false), 8, buffer);

// GID
data.set(Atom.intern(atomName, false), 8, cast(ubyte[])buffer);
```

---

## 38. Cairo Operator Enum

```d
// GtkD
import cairo.c.types : cairo_operator_t;
cr.setOperator(cairo_operator_t.SOURCE);

// GID
import cairo.types : Operator;
cr.setOperator(Operator.Source);
```

---

## 39. Pango Scale and Types

```d
// GtkD
import pango.PgLayout;
pgl.setWidth(width * PANGO_SCALE);
pgl.setWrap(PangoWrapMode.WORD_CHAR);
pgl.setAlignment(PangoAlignment.RIGHT);

// GID
import pango.types : SCALE, WrapMode, Alignment;
pgl.setWidth(width * SCALE);
pgl.setWrap(WrapMode.WordChar);
pgl.setAlignment(Alignment.Right);
```

---

## 40. PangoCairo Functions

```d
// GtkD
import pango.PgCairo;
PgCairo.showLayout(cr, layout);

// GID
import pangocairo.global : showLayout;
showLayout(cr, layout);
```

---

## 41. VTE spawnSync

```d
// GtkD
vte.spawnSync(flags, workingDir, args, envv, spawnFlags, null, null, gpid, null);

// GID - childPid is an out parameter, not a pointer
int childPid;
bool result = vte.spawnSync(PtyFlags.Default, workingDir, args, envv,
    spawnFlags, null, childPid, null);
gpid = childPid;
```

---

## 42. VTE Version Functions

```d
// GtkD
import VteVersion = vte.Version;
VteVersion.Version.getMinorVersion();

// GID
import vte.global : getMinorVersion, getMicroVersion;
getMinorVersion();
```

---

## 43. InfoBar Constructor

```d
// GtkD
super([_("Relaunch")], [ResponseType.Ok]);

// GID - no convenience constructor, add buttons manually
super();
addButton(_("Relaunch"), ResponseType.Ok);
```

---

## 44. MessageDialog Creation

GID doesn't have a convenience constructor for MessageDialog. Use C API:
```d
// GID
import gtk.c.functions : gtk_message_dialog_new;
import gtk.c.types : GtkWindow, GtkDialogFlags, GtkMessageType, GtkButtonsType;

auto ptr = gtk_message_dialog_new(
    parent ? cast(GtkWindow*)parent._cPtr() : null,
    cast(GtkDialogFlags)(DialogFlags.Modal),
    cast(GtkMessageType)(MessageType.Warning),
    cast(GtkButtonsType)(ButtonsType.None),
    null);
super(cast(void*)ptr, Yes.Take);
```

---

## 45. GMarkup Parse Context

For XML parsing with GMarkup, import from GID's C bindings:
```d
// GID
import glib.c.types : GMarkupParser, GMarkupParseContext, GMarkupParseFlags,
                       GError, GDestroyNotify;
import glib.c.functions : g_markup_parse_context_new, g_markup_parse_context_free,
                          g_markup_parse_context_parse, g_markup_parse_context_end_parse,
                          g_error_free;

// Functions return bool, not int
bool result = g_markup_parse_context_parse(context, text.ptr, textLen, &error);
```

---

## 46. EventButton to Event Conversion

When APIs require a generic `Event` but you have a specific event type like `EventButton`:

```d
// GID - create Event wrapper from EventButton
import gdk.event : Event;
import gdk.event_button : EventButton;
import gid.gid : No;

bool onButtonPress(EventButton event, Widget widget) {
    // For APIs that need generic Event (like vte.matchCheckEvent)
    auto genericEvent = new Event(event._cPtr(), No.Take);

    // Now use genericEvent with APIs that expect Event
    match = vte.matchCheckEvent(genericEvent, tag);

    // Access EventButton properties directly (not through methods)
    uint buttonNum = event.button;      // not event.button() or event.getButton()
    ModifierType state = event.state;   // not event.getState()
    double x = event.x;
    double y = event.y;
    EventType type = event.type;        // not event.getEventType()

    return false;
}
```

---

## 47. GList Iteration (C API)

When using C API functions that return `GList*`:

```d
// GID - iterate through C GList
import glib.c.types : GList;
import gid.gid : No;

// Example: gdk_drag_context_list_targets returns GList*
auto glist = gdk_drag_context_list_targets(cast(GdkDragContext*)dc._cPtr);

for (auto l = glist; l !is null; l = l.next) {
    // Wrap the data in the appropriate GID class
    auto atom = new Atom(l.data, No.Take);
    string name = atom.name();
    // ... process item
}

// Note: Don't free the list if it's owned by the object (check API docs)
```

---

## 48. KeyFile Usage

```d
// GtkD
import glib.KeyFile;
KeyFile kf = new KeyFile();
kf.loadFromFile(filename, GKeyFileFlags.NONE);
string value = kf.getString("Group", "key");

// GID
import glib.key_file : KeyFile;
import glib.types : KeyFileFlags;

KeyFile kf = new KeyFile();
kf.loadFromFile(filename, KeyFileFlags.None);
string value = kf.getString("Group", "key");
```

---

## 49. Container Casting for Widget Methods

Some methods return `Widget` but you need `Container` methods like `add()`:

```d
// GtkD
dialog.getMessageArea().add(widget);

// GID - getMessageArea returns Widget, need to cast to Container
import gtk.container : Container;

(cast(Container)dialog.getMessageArea()).add(widget);

// Or use a local variable for clarity
auto msgArea = cast(Container)dialog.getMessageArea();
msgArea.add(widget);
```

---

## 50. Out Parameters vs Return Values

Some GID functions use `out` parameters instead of return values:

```d
// GtkD - some functions return values
int pid = vte.spawnSync(...);

// GID - pid is an out parameter
int childPid;
bool success = vte.spawnSync(PtyFlags.Default, workingDir, args, envv,
    spawnFlags, null, childPid, null);  // childPid is out parameter
gpid = childPid;

// Same pattern for other out parameters
int width, height;
widget.getSize(width, height);  // width and height are out parameters
```

---

## 51. GVariant Handle Creation

For file descriptor handles in GVariant:

```d
// GID
import glib.c.functions : g_variant_new_handle;
import glib.variant : Variant;

// Create a handle variant for a file descriptor
auto handleVar = new Variant(g_variant_new_handle(fd), true);

// Use in dict entry
auto keyVar = new Variant(cast(uint)index);
auto dictEntry = Variant.newDictEntry(keyVar, handleVar);
```

---

## 52. Flag Enum Combining

GID uses proper D enums that support bitwise operations:

```d
// GtkD
GDBusConnectionFlags.AUTHENTICATION_CLIENT | GDBusConnectionFlags.MESSAGE_BUS_CONNECTION

// GID - PascalCase enum values
import gio.types : DBusConnectionFlags;
DBusConnectionFlags.AuthenticationClient | DBusConnectionFlags.MessageBusConnection

// For modifier keys
import gdk.types : ModifierType;
if (state & ModifierType.ControlMask) { ... }
if (state & (ModifierType.ShiftMask | ModifierType.ControlMask)) { ... }
```

---

## 53. GID 0.9.7 Bug: Settings.getStrv() Returns Only 1 Element

**Bug**: GID 0.9.7's `Settings.getStrv()` has a bug in the loop that counts array length - it contains an erroneous `break` statement that causes it to return at most 1 element instead of all elements.

**Impact**: Any code retrieving string arrays from GSettings (like color palettes with 16 colors) will only get the first element.

**Workaround**: Create a custom function that correctly retrieves all elements:

```d
// In gx/gtk/util.d
import gio.settings : Settings;
import gio.c.functions : g_settings_get_strv;
import gio.c.types : GSettings;
import gid.gid : No;

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

// Usage
string[] colors = getSettingsStrv(gsProfile, "palette");  // Returns all 16 colors
```

---

## 54. GID Bug: VTE Terminal.setColors() Palette Array

**Bug**: GID's `vte.terminal.setColors()` doesn't correctly pass the RGBA palette array to the C function. The binding uses `obj._cPtr` (getting a delegate) instead of `obj._cPtr()` (calling the method to get the pointer).

**Impact**: Terminal palette colors appear all black because the C function receives garbage data.

**Workaround**: Create a custom function that correctly builds the GdkRGBA array:

```d
// In gx/gtk/vte.d
import vte.terminal : Terminal;
import vte.c.functions : vte_terminal_set_colors;
import vte.c.types : VteTerminal, GdkRGBA;
import gdk.rgba : RGBA;
import gid.gid : No;

void setTerminalColors(Terminal terminal, RGBA foreground, RGBA background, RGBA[] palette) {
    // Build palette array correctly
    GdkRGBA[] paletteArray;
    if (palette !is null) {
        paletteArray = new GdkRGBA[palette.length];
        foreach (i, rgba; palette) {
            if (rgba !is null) {
                paletteArray[i] = *cast(GdkRGBA*)rgba._cPtr(No.Dup);
            }
        }
    }

    // Call VTE C function directly
    vte_terminal_set_colors(
        cast(VteTerminal*)terminal._cPtr(No.Dup),
        foreground ? cast(const(GdkRGBA)*)foreground._cPtr(No.Dup) : null,
        background ? cast(const(GdkRGBA)*)background._cPtr(No.Dup) : null,
        paletteArray.length > 0 ? paletteArray.ptr : null,
        paletteArray.length
    );
}

// Usage
setTerminalColors(vte, vteFG, vteBG, vtePalette);
```

---

## 55. Editable to Entry Cast Doesn't Work in GID

**Problem**: In GtkD, you could cast the `Editable` parameter in a signal handler back to `Entry`. In GID, this cast fails.

```d
// GtkD - worked
Entry eName = new Entry();
eName.connectChanged(delegate(Editable editable) {
    Entry entry = cast(Entry) cast(void*) editable;  // Works in GtkD
    string text = entry.getText();
});

// GID - FAILS (entry will be null or crash)
Entry eName = new Entry();
eName.connectChanged(delegate(Editable editable) {
    Entry entry = cast(Entry) cast(void*) editable;  // DOESN'T WORK
    string text = entry.getText();  // Crash!
});
```

**Solution**: Capture the Entry variable from the enclosing scope instead of casting:

```d
// GID - correct approach
Entry eName = new Entry();
eName.connectChanged(delegate(Editable editable) {
    // Use eName directly from closure - don't cast the Editable
    string text = eName.getText();
    onNameChanged(text);
});
```

---

## 56. Static Array Slice Required for setStrv

**Problem**: When passing a static array (e.g., `string[16]`) to `setStrv()`, you must explicitly slice it.

```d
// GID - WRONG (may not compile or pass wrong data)
string[16] palette;
// ... fill palette ...
gsProfile.setStrv("palette-key", palette);  // Static array

// GID - CORRECT
string[16] palette;
// ... fill palette ...
gsProfile.setStrv("palette-key", palette[]);  // Explicit slice to dynamic array
```

---

## 57. Stateful Actions: Initial State in Constructor

**Problem**: In GID, stateful actions should have their initial state passed in the registration call, not set separately with `setState()`.

```d
// GtkD approach (also works in GID but less clean)
saViewSideBar = registerAction(actionMap, "win", "sidebar", ...);
saViewSideBar.setState(new GVariant(false));

// GID - preferred approach: pass initial state in registration
saViewSideBar = registerActionWithSettings(actionMap, "win", "sidebar", gsShortcuts,
    delegate(Variant value, SimpleAction sa) {
        bool newState = !sa.getState().getBoolean();
        sa.setState(new GVariant(newState));
        // ... handle state change
    },
    null,                    // parameterType
    new GVariant(false));    // initial state
```

---

## 58. Null Event Checks in Signal Handlers

**Problem**: In GID, event signal handlers may receive null events in some edge cases. Always check for null before accessing event properties.

```d
// GID - WRONG (may crash)
vte.connectKeyPressEvent(delegate(EventKey event) {
    uint keyval = event.keyval;  // Crash if event is null!
    return false;
});

// GID - CORRECT
vte.connectKeyPressEvent(delegate(EventKey event) {
    if (event is null) return false;  // Null check first
    uint keyval = event.keyval;
    return false;
});

// Same for other event types
connectButtonPressEvent(delegate(EventButton event, Widget widget) {
    if (event is null) return false;
    // ... safe to access event properties
});

connectWindowStateEvent(delegate(EventWindowState event, Widget w) {
    if (event is null) return false;
    WindowState newState = event.newWindowState;
    // ...
});
```

---

## 59. IconTheme.addResourcePath for GResource Icons

**Problem**: Custom icons bundled in a GResource file are not automatically discoverable by GTK's IconTheme.

**Solution**: After registering the GResource, add its icon path to the default IconTheme:

```d
import gtk.icon_theme : IconTheme;
import gx.gtk.resource : findResource;

// Register the gresource file
if (findResource("myapp/resources/myapp.gresource", true)) {
    // Register the gresource icon path with the icon theme
    IconTheme iconTheme = IconTheme.getDefault();
    if (iconTheme !is null) {
        iconTheme.addResourcePath("/com/myapp/icons");
        trace("Added icon resource path: /com/myapp/icons");
    }
}
```

**Note**: The path passed to `addResourcePath()` is the resource path inside the gresource, not a filesystem path.

---

## 60. Resource Loading: Search User Data Directory

**Problem**: GID's resource loading may only search system data directories, missing user-local resources.

**Solution**: When implementing resource finding, search user data directory first:

```d
import glib.global : getSystemDataDirs, getUserDataDir;

Resource findResource(string resourcePath, bool register = true) {
    // Search in user data dir first, then system data dirs
    string[] searchPaths = [getUserDataDir()] ~ getSystemDataDirs();
    foreach (path; searchPaths) {
        auto fullpath = buildPath(path, resourcePath);
        if (exists(fullpath)) {
            Resource resource = Resource.load(fullpath);
            if (register && resource) {
                resourcesRegister(resource);
            }
            return resource;
        }
    }
    return null;
}
```

This allows users to override system resources by placing files in `~/.local/share/`.

---

## 61. StyleContext Color Functions: Use ref Not out

**Problem**: When wrapping StyleContext color retrieval functions, using `out RGBA color` parameter resets the RGBA object to null before the function can fill it.

```d
// WRONG - out parameter resets color to null
void getStyleBackgroundColor(StyleContext context, StateFlags flags, out RGBA color) {
    // color is null here due to 'out' semantics!
    context.getBackgroundColor(flags, color);  // Crash or no-op
}

// CORRECT - ref parameter preserves the RGBA object
void getStyleBackgroundColor(StyleContext context, StateFlags flags, ref RGBA color) {
    with (context) {
        save();
        setState(flags);
        getBackgroundColor(getState(), color);  // color is valid
        restore();
    }
}
```

**Note**: In D, `out` parameters are reset to their `.init` value (null for class references) at function entry, while `ref` parameters preserve their incoming value.

---

## 62. Keyboard Shortcuts: Use registerActionWithSettings

**Problem**: Actions that need keyboard shortcuts from GSettings must use `registerActionWithSettings()`, not `registerAction()`. Using the wrong function will result in the shortcut not working even though it's defined in GSettings.

```d
// WRONG - shortcut won't be picked up from GSettings
registerAction(this, "win", ACTION_WIN_FULLSCREEN, null, delegate(Variant value, SimpleAction sa) {
    // F11 won't trigger this!
    bool newState = !sa.getState().getBoolean();
    sa.setState(new GVariant(newState));
    if (newState) fullscreen();
    else unfullscreen();
}, null, new GVariant(false));

// CORRECT - shortcut is picked up from GSettings
registerActionWithSettings(this, "win", ACTION_WIN_FULLSCREEN, gsShortcuts, delegate(Variant value, SimpleAction sa) {
    // F11 now works!
    bool newState = !sa.getState().getBoolean();
    sa.setState(new GVariant(newState));
    if (newState) fullscreen();
    else unfullscreen();
}, null, new GVariant(false));
```

**Note**: `registerActionWithSettings()` looks up the shortcut key in the GSettings object using the pattern `{prefix}-{actionName}` (e.g., `win-fullscreen`) and registers it with the application. Without this, you must manually call `app.setAccelsForAction()` to register shortcuts.
