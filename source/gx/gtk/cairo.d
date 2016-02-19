/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.cairo;

import std.algorithm;
import std.conv;
import std.datetime;
import std.experimental.logger;
import std.format;

import cairo.Context;
import cairo.Surface;

import gdk.Cairo;
import gdk.RGBA;
import gdk.Screen;
import gdk.Visual;
import gdk.Window;

import gdkpixbuf.Pixbuf;

import gtk.Container;
import gtk.OffscreenWindow;
import gtk.Widget;

Pixbuf getWindowImage(Window window, double factor) {
    int w = window.getWidth();
    int h = window.getHeight();
    trace(format("Original: %d, %d", w, h));
    int pw = to!int(w * factor);
    int ph = to!int(h * factor);
    trace(format("Factor: %f, New: %d, %d", factor, pw, ph));
            
    Surface surface = window.createSimilarSurface(gtkc.cairotypes.cairo_content_t.COLOR, pw, ph);
    Context cr = Context.create(surface);
    cr.scale(factor, factor);
    setSourceWindow(cr, window, 0, 0);
    cr.paint();
    return gdk.Pixbuf.getFromSurface(surface, 0, 0, pw, ph);
}

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
        trace("Widget is not drawable, using OffscreenWindow for thumbnail");
        RenderWindow window = new RenderWindow();
        Container parent = cast(Container) widget.getParent();
        if (parent is null) {
            error("Parent is not a Container, cannot draw offscreen image");
            return null;        
        }
        parent.remove(widget);
        window.add(widget);
        try {
            window.setDefaultSize(w,h);
            StopWatch sw = StopWatch(AutoStart.yes);
            /*
            Need to process events here until Window is drawn
            Not overly pleased with this solution, use timer
            as a guard to make sure we don't get caught up 
            in an infinite loop
            
            Considered using an idle handler here but because the
            widget needs to stay parented to the OffscreenWindow that
            gives me even more shudders then the less then optimal
            solution implemented here.
            */
            while (gtk.Main.Main.eventsPending() && sw.peek().msecs<100) {
                gtk.Main.Main.iterationDo(false);
            }
            sw.stop();
            trace(format("Total time processing events: %d msecs", sw.peek().msecs));
            // While we could call getPixBuf() on Offscreen Window, drawing 
            // it ourselves gives better results when dealing with transparency
            Pixbuf pb = getWindowImage(widget.getWindow(), factor);
            if (pb is null) {
                error("Pixbuf from renderwindow is null");
                return pb;
            } 
            pb = pb.scaleSimple(pw, ph , GdkInterpType.BILINEAR);
            return pb;
        } finally {
            window.remove(widget);
            parent.add(widget);
            window.destroy();
        }
    }
}

private:
class RenderWindow: OffscreenWindow {
    Pixbuf pb;
    
    bool onDamage(gdk.Event.Event, Widget) {
        trace("Damage event received");
        pb = getPixbuf();
        return false;
    }

public:
    this() {
        super();
        addOnDamage(&onDamage);
        show();
    }
    
    @property Pixbuf pixbuf() {
        return pb;
    }

}
