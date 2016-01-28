module gx.gtk.cairo;

import std.algorithm;
import std.conv;
import std.experimental.logger;

import cairo.Context;
import cairo.Surface;

import gdk.Cairo;

import gdkpixbuf.Pixbuf;

import gtk.Widget;

Pixbuf getWidgetImage(Widget widget, double factor) {
    int w = widget.getAllocatedWidth();
    int h = widget.getAllocatedHeight();
    int longest = max(w, h);
    int pw = to!int(w * factor);
    int ph = to!int(h * factor);
    Surface surface = widget.getWindow().createSimilarSurface(gtkc.cairotypes.cairo_content_t.COLOR, pw, ph);
    Context cr = Context.create(surface);
    cr.scale(factor, factor);
    widget.draw(cr);
    Pixbuf pb = gdk.Pixbuf.getFromSurface(surface, 0, 0, pw, ph);
    return pb;
        
    /*
    gdk.Window.Window window = widget.getWindow();
    int w = window.getWidth();
    int h = window.getHeight();
    int longest = max(w, h);
    int pw = to!int(w * factor);
    int ph = to!int(h * factor);
            
    Surface surface = window.createSimilarSurface(gtkc.cairotypes.cairo_content_t.COLOR, pw, ph);
    Context cr = Context.create(surface);
    cr.scale(factor, factor);
    setSourceWindow(cr, window, 0, 0);
    cr.paint();
    Pixbuf pb = gdk.Pixbuf.getFromSurface(surface, 0, 0, pw, ph);
    return pb;
    */
}