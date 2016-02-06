/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.cairo;

import std.conv;
import std.experimental.logger;
import std.format;

import cairo.Context;
import cairo.Surface;

import gdkpixbuf.Pixbuf;

import gtk.Widget;

/**
 * Returns a pixbuf image for the passed widget. The widget must
 * be in a drawable state for this to work, otherwise null
 * is returned.
 */
Pixbuf getWidgetImage(Widget widget, double factor) {
    int w = widget.getAllocatedWidth();
    int h = widget.getAllocatedHeight();
    int pw = to!int(w * factor);
    int ph = to!int(h * factor);
    trace(format("Thumbnail dimensionsL w=%d, h=%d", pw, ph));

    if (widget.isDrawable()) {
        Surface surface = widget.getWindow().createSimilarSurface(gtkc.cairotypes.cairo_content_t.COLOR, pw, ph);
        Context cr = Context.create(surface);
        cr.scale(factor, factor);
        widget.draw(cr);
        return gdk.Pixbuf.getFromSurface(surface, 0, 0, pw, ph);
    } else {
        error("Widget is not drawable");
        return null;
    }
}
