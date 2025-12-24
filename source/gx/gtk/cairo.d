/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.cairo;

import std.algorithm;
import std.conv;
static if (__VERSION__ >= 2075) {
    import std.datetime.date;
    import std.datetime.stopwatch;
} else {
    import std.datetime;
}
import std.experimental.logger;

import cairo.context;
import cairo.surface;
import cairo.global;

import pango.context : PangoContext = Context;
import pango.layout : PangoLayout = Layout;

import gdk.event;
import gdk.types;
import gdk.event_expose;
import gdk.types;
import gdk.global;
import gdk.types;
import gdkpixbuf.pixbuf;
import gdk.rgba;
import gdk.types;
import gdk.screen;
import gdk.types;
import gdk.visual;
import gdk.types;
import gdk.window;
import gdk.types;

import cairo.c.types;

import gtk.container;
import gtk.types;
import gtk.global;
import gtk.types;
import gtk.offscreen_window;
import gtk.types;
import gtk.widget;
import gtk.types;
import gtk.types;

gdkpixbuf.pixbuf.Pixbuf getWidgetImage(Widget widget, double factor) {
    return getWidgetImage(widget, factor, widget.getAllocatedWidth(), widget.getAllocatedHeight());
}

// Added support for specifying width and height explicitly in cases
// where container has been realized but widget has not been, for example
// pages added to Notebook but never shown
gdkpixbuf.pixbuf.Pixbuf getWidgetImage(Widget widget, double factor, int width, int height) {
    StopWatch sw = StopWatch(AutoStart.yes);
    scope (exit) {
        sw.stop();
        static if (__VERSION__ >= 2075) {
            tracef("Total time getting thumbnail: %d msecs", sw.peek.total!"msecs");
        }
    }
    if (widget.isDrawable()) {
        widget.queueDraw();
        static if (__VERSION__ >= 2075) {
            while (gtk.global.eventsPending() && sw.peek.total!"msecs"<100) {
                mainIterationDo(false);
            }
        } else {
            while (gtk.global.eventsPending() && sw.peek().msecs<100) {
                mainIterationDo(false);
            }
        }
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
            static if (__VERSION__ >= 2075) {
                while (!window.canDraw && gtk.global.eventsPending() && sw.peek.total!"msecs"<100) {
                    mainIterationDo(false);
                }
            } else {
                while (gtk.global.eventsPending() && sw.peek().msecs<100) {
                    mainIterationDo(false);
                }
            }
            // While we could call getPixBuf() on Offscreen Window, drawing
            // it ourselves gives better results when dealing with transparency
            gdkpixbuf.pixbuf.Pixbuf pb = getDrawableWidgetImage(widget, factor, width, height);
            if (pb is null) {
                error("gdkpixbuf.pixbuf.Pixbuf from renderwindow is null");
                return pb;
            }
            return pb;
        } finally {
            window.remove(widget);
            parent.add(widget);
            window.destroy();
            window = null;
        }
    }
}

enum ImageLayoutMode {SCALE, TILE, CENTER, STRETCH};

Surface renderImage(gdkpixbuf.pixbuf.Pixbuf pb, bool alpha = false) {
    cairo_format_t format = alpha?cairo_format_t.Argb32:cairo_format_t.Rgb24;
    Surface surface = imageSurfaceCreate(format, pb.getWidth(), pb.getHeight());
    cairo.context.Context cr = cairo.global.create(surface);
    scope(exit) {
        cr.destroy();
    }
    gdk.global.cairoSetSourcePixbuf(cr, pb, 0, 0);
    cr.setOperator(cairo_operator_t.Source);
    cr.paint();
    return surface;
}

/**
 * Renders an image onto an Surface using different modes
 */
Surface renderImage(gdkpixbuf.pixbuf.Pixbuf pbSource, int outputWidth, int outputHeight, ImageLayoutMode mode, bool alpha = false, cairo_filter_t scaleMode = cairo_filter_t.Bilinear) {
    Surface surface = renderImage(pbSource);
    scope(exit) {
        surface.destroy();
    }
    return renderImage(surface, outputWidth, outputHeight, mode, alpha, scaleMode);
}

Surface renderImage(Surface isSource, int outputWidth, int outputHeight, ImageLayoutMode mode, bool alpha = false, cairo_filter_t scaleMode = cairo_filter_t.Bilinear) {
    cairo_format_t format = alpha?cairo_format_t.Argb32:cairo_format_t.Rgb24;
    Surface surface = imageSurfaceCreate(format, outputWidth, outputHeight);
    cairo.context.Context cr = cairo.global.create(surface);
    scope(exit) {
        cr.destroy();
    }
    if (alpha) {
        cr.setOperator(cairo_operator_t.Source);
    }
    renderImage(cr, isSource, outputWidth, outputHeight, mode, scaleMode);
    return surface;
}

void renderImage(cairo.context.Context cr, Surface isSource, int outputWidth, int outputHeight, ImageLayoutMode mode, cairo_filter_t scaleMode = cairo_filter_t.Bilinear) {
    StopWatch sw = StopWatch(AutoStart.yes);
    scope (exit) {
        sw.stop();
        static if (__VERSION__ >= 2075) {
            tracef("Total time getting image: %d msecs", sw.peek.total!"msecs");
        }
    }
    final switch (mode) {
        case ImageLayoutMode.SCALE:
            double xScale = to!double(outputWidth) / to!double(imageSurfaceGetWidth(isSource));
            double yScale = to!double(outputHeight) / to!double(imageSurfaceGetHeight(isSource));
            double ratio = max(xScale, yScale);
            double xOffset = (outputWidth - (imageSurfaceGetWidth(isSource) * ratio)) / 2.0;
            double yOffset = (outputHeight - (imageSurfaceGetHeight(isSource) * ratio)) / 2.0;
            cr.translate(xOffset, yOffset);
            cr.scale(ratio, ratio);
            cr.setSourceSurface(isSource, 0, 0);
            cr.getSource().setFilter(scaleMode);
            cr.paint();
            break;
        case ImageLayoutMode.TILE:
            cr.setSourceSurface(isSource, 0, 0);
            cr.getSource().setExtend(cairo_extend_t.Repeat);
            cr.paint();
            break;
        case ImageLayoutMode.CENTER:
            double x = (outputWidth - imageSurfaceGetWidth(isSource))/2;
            double y = (outputHeight - imageSurfaceGetHeight(isSource))/2;
            cr.translate(x,y);
            cr.setSourceSurface(isSource, 0, 0);
            cr.paint();
            break;
        case ImageLayoutMode.STRETCH:
            double xScale = to!double(outputWidth) / to!double(imageSurfaceGetWidth(isSource));
            double yScale = to!double(outputHeight) / to!double(imageSurfaceGetHeight(isSource));
            cr.scale(xScale, yScale);
            cr.setSourceSurface(isSource, 0, 0);
            cr.getSource().setFilter(scaleMode);
            cr.paint();
            break;
    }
}

private:
gdkpixbuf.pixbuf.Pixbuf getDrawableWidgetImage(Widget widget, double factor, int width, int height) {
    int w = width;
    int h = height;
    tracef("Original: %d, %d", w, h);
    int pw = to!int(w * factor);
    int ph = to!int(h * factor);
    tracef("Factor: %f, New: %d, %d", factor, pw, ph);

    Window window = widget.getWindow();
    Surface surface = window.createSimilarSurface(cairo_content_t.Color, pw, ph);
    cairo.context.Context cr = cairo.global.create(surface);
    scope(exit) {
        surface.destroy();
        cr.destroy();
    }
    cr.scale(factor, factor);
    widget.draw(cr);
    gdkpixbuf.pixbuf.Pixbuf pb = gdk.global.pixbufGetFromSurface(surface, 0, 0, pw, ph);
    return pb;
}

class RenderWindow: OffscreenWindow {
    bool _canDraw = false;

    bool onDamage(gdk.event_expose.EventExpose, Widget) {
        trace("Damage event received");
        _canDraw = true;
        return false;
    }

public:
    this() {
        super();
        connectDamageEvent(&onDamage);
        show();
    }

    debug(Destructors) {
        ~this() {
            import std.stdio: writeln;
            writeln("******** RenderWindow Destructor");
        }
    }

    @property bool canDraw() {
        return _canDraw;
    }
}
