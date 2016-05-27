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
import cairo.ImageSurface;
import cairo.Surface;

import gdk.Cairo;
import gdk.Pixbuf;
import gdk.RGBA;
import gdk.Screen;
import gdk.Visual;
import gdk.Window;

import gdkpixbuf.Pixbuf;

import gtkc.cairotypes;

import gtk.Container;
import gtk.Main;
import gtk.OffscreenWindow;
import gtk.Widget;


Pixbuf getWidgetImage(Widget widget, double factor) {
    return getWidgetImage(widget, factor, widget.getAllocatedWidth(), widget.getAllocatedHeight());
}

// Added support for specifying width and height explicitly in cases
// where container has been realized but widget has not been, for example
// pages added to Notebook but never shown
Pixbuf getWidgetImage(Widget widget, double factor, int width, int height) {
    StopWatch sw = StopWatch(AutoStart.yes);
    scope (exit) {
        sw.stop();
        trace(format("Total time getting thumbnail: %d msecs", sw.peek().msecs));
    }
    if (widget.isDrawable()) {
        return getDrawableWidgetImage(widget, factor, width, height);
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
            window.setDefaultSize(width, height);
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
            while (!window.canDraw && gtk.Main.Main.eventsPending() && sw.peek().msecs<100) {
                Main.iterationDo(false);
            }
            // While we could call getPixBuf() on Offscreen Window, drawing 
            // it ourselves gives better results when dealing with transparency
            Pixbuf pb = getDrawableWidgetImage(widget, factor, width, height);
            if (pb is null) {
                error("Pixbuf from renderwindow is null");
                return pb;
            } 
            return pb;
        } finally {
            window.remove(widget);
            parent.add(widget);
            window.destroy();
        }
    }
}

enum ImageLayoutMode {SCALE, TILE, CENTER, STRETCH};

/**
 * Renders an image onto an ImageSurface using different modes
 */ 
ImageSurface renderImage(Pixbuf pb, int outputWidth, int outputHeight, ImageLayoutMode mode) {
    ImageSurface surface = ImageSurface.create(cairo_format_t.ARGB32, outputWidth, outputHeight);
    Context cr = Context.create(surface);
    
    final switch (mode) {
        case ImageLayoutMode.SCALE:
            double xScale = to!double(outputWidth) / to!double(pb.getWidth());
            double yScale = to!double(outputHeight) / to!double(pb.getHeight());
        
            double ratio = max(xScale, yScale);
            double xOffset = outputWidth - (pb.getWidth() * ratio);
            double yOffset = outputHeight - (pb.getHeight() * ratio);
            cr.translate(xOffset, yOffset);
            cr.scale(ratio, ratio);
            setSourcePixbuf(cr, pb, 0, 0);
            cr.paint();
            break;            
        case ImageLayoutMode.TILE:
            for (double y = 0; y <= outputHeight; y = y + pb.getHeight()) {
                for (double x = 0; x <= outputWidth; x = x + pb.getWidth()) {
                    cr.save();
                    cr.translate(x,y);
                    setSourcePixbuf(cr, pb, 0, 0);
                    cr.paint();
                    cr.restore();
                }
            }
            break;
        case ImageLayoutMode.CENTER:
            double x = (outputWidth - pb.getWidth())/2;
            double y = (outputHeight - pb.getHeight())/2;
            //cr.rectangle(0, 0, width, height);
            //cr.clip();
            cr.translate(x,y);
            setSourcePixbuf(cr, pb, 0, 0);
            cr.paint();
            break;
        case ImageLayoutMode.STRETCH:
            double xScale = to!double(outputWidth) / to!double(pb.getWidth());
            double yScale = to!double(outputHeight) / to!double(pb.getHeight());
            cr.scale(xScale, yScale);
            setSourcePixbuf(cr, pb, 0, 0);
            cr.paint();
            break;
    }
    return surface;
}

private:
Pixbuf getDrawableWidgetImage(Widget widget, double factor, int width, int height) {
    int w = width;
    int h = height;
    trace(format("Original: %d, %d", w, h));
    int pw = to!int(w * factor);
    int ph = to!int(h * factor);
    trace(format("Factor: %f, New: %d, %d", factor, pw, ph));
   
    Window window = widget.getWindow();
    Surface surface = window.createSimilarSurface(cairo_content_t.COLOR, pw, ph);
    Context cr = Context.create(surface);
    cr.scale(factor, factor);
    widget.draw(cr);
    return getFromSurface(surface, 0, 0, pw, ph);
}

class RenderWindow: OffscreenWindow {
    bool _canDraw = false;
    
    bool onDamage(gdk.Event.Event, Widget) {
        trace("Damage event received");
        _canDraw = true;
        return false;
    }

public:
    this() {
        super();
        addOnDamage(&onDamage);
        show();
    }
    
    @property bool canDraw() {
        return _canDraw;
    }
}
