module gx.gtk.types;

import gobject.types;
public import gio.types;

public alias GType = gobject.types.GType;
public alias BasicType = GTypeEnum;

enum GDK_EVENT_PROPAGATE = false;
enum GDK_EVENT_STOP = true;
