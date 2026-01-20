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

// GID imports - cairo
import cairo.context : Context;
import cairo.global : create, imageSurfaceCreate, imageSurfaceGetWidth, imageSurfaceGetHeight;
import cairo.pattern : Pattern;
import cairo.surface : Surface;
import cairo.types : Content, Extend, Filter, Format, Operator;

// GID imports - gdk
import gdk.event_expose : EventExpose;
import gdk.global : cairoSetSourcePixbuf, pixbufGetFromSurface;
import gdk.window : GdkWindow = Window;

// GID imports - gdkpixbuf
import gdkpixbuf.pixbuf : Pixbuf;

// GID imports - gtk
import gtk.container : Container;
import gtk.global : eventsPending, mainIterationDo;
import gtk.offscreen_window : OffscreenWindow;
import gtk.widget : Widget;

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
        static if (__VERSION__ >= 2075) {
            tracef("Total time getting thumbnail: %d msecs", sw.peek.total!"msecs");
        }
    }
    if (widget.isDrawable()) {
        widget.queueDraw();
        static if (__VERSION__ >= 2075) {
            while (eventsPending() && sw.peek.total!"msecs" < 100) {
                mainIterationDo(false);
            }
        } else {
            while (eventsPending() && sw.peek().msecs < 100) {
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
                while (!window.canDraw && eventsPending() && sw.peek.total!"msecs" < 100) {
                    mainIterationDo(false);
                }
            } else {
                while (eventsPending() && sw.peek().msecs < 100) {
                    mainIterationDo(false);
                }
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
            window = null;
        }
    }
}

enum ImageLayoutMode {SCALE, TILE, CENTER, STRETCH}

Surface renderImage(Pixbuf pb, bool alpha = false) {
    Format format = alpha ? Format.Argb32 : Format.Rgb24;
    Surface surface = imageSurfaceCreate(format, pb.getWidth(), pb.getHeight());
    Context cr = create(surface);
    scope(exit) {
        cr = null;
    }
    cairoSetSourcePixbuf(cr, pb, 0, 0);
    cr.setOperator(Operator.Source);
    cr.paint();
    return surface;
}

/**
 * Renders an image onto a Surface using different modes
 */
Surface renderImage(Pixbuf pbSource, int outputWidth, int outputHeight, ImageLayoutMode mode, bool alpha = false, Filter scaleMode = Filter.Bilinear) {
    Surface surface = renderImage(pbSource);
    scope(exit) {
        surface = null;
    }
    return renderImage(surface, outputWidth, outputHeight, mode, alpha, scaleMode);
}

Surface renderImage(Surface isSource, int outputWidth, int outputHeight, ImageLayoutMode mode, bool alpha = false, Filter scaleMode = Filter.Bilinear) {
    Format format = alpha ? Format.Argb32 : Format.Rgb24;
    Surface surface = imageSurfaceCreate(format, outputWidth, outputHeight);
    Context cr = create(surface);
    scope(exit) {
        cr = null;
    }
    if (alpha) {
        cr.setOperator(Operator.Source);
    }
    renderImage(cr, isSource, outputWidth, outputHeight, mode, scaleMode);
    return surface;
}

void renderImage(Context cr, Surface isSource, int outputWidth, int outputHeight, ImageLayoutMode mode, Filter scaleMode = Filter.Bilinear) {
    StopWatch sw = StopWatch(AutoStart.yes);
    scope (exit) {
        sw.stop();
        static if (__VERSION__ >= 2075) {
            tracef("Total time getting image: %d msecs", sw.peek.total!"msecs");
        }
    }
    int sourceWidth = imageSurfaceGetWidth(isSource);
    int sourceHeight = imageSurfaceGetHeight(isSource);
    final switch (mode) {
        case ImageLayoutMode.SCALE:
            double xScale = to!double(outputWidth) / to!double(sourceWidth);
            double yScale = to!double(outputHeight) / to!double(sourceHeight);
            double ratio = max(xScale, yScale);
            double xOffset = (outputWidth - (sourceWidth * ratio)) / 2.0;
            double yOffset = (outputHeight - (sourceHeight * ratio)) / 2.0;
            cr.translate(xOffset, yOffset);
            cr.scale(ratio, ratio);
            cr.setSourceSurface(isSource, 0, 0);
            cr.getSource().setFilter(scaleMode);
            cr.paint();
            break;
        case ImageLayoutMode.TILE:
            cr.setSourceSurface(isSource, 0, 0);
            cr.getSource().setExtend(Extend.Repeat);
            cr.paint();
            break;
        case ImageLayoutMode.CENTER:
            double x = (outputWidth - sourceWidth) / 2;
            double y = (outputHeight - sourceHeight) / 2;
            cr.translate(x, y);
            cr.setSourceSurface(isSource, 0, 0);
            cr.paint();
            break;
        case ImageLayoutMode.STRETCH:
            double xScale = to!double(outputWidth) / to!double(sourceWidth);
            double yScale = to!double(outputHeight) / to!double(sourceHeight);
            cr.scale(xScale, yScale);
            cr.setSourceSurface(isSource, 0, 0);
            cr.getSource().setFilter(scaleMode);
            cr.paint();
            break;
    }
}

private:
Pixbuf getDrawableWidgetImage(Widget widget, double factor, int width, int height) {
    int w = width;
    int h = height;
    tracef("Original: %d, %d", w, h);
    int pw = to!int(w * factor);
    int ph = to!int(h * factor);
    tracef("Factor: %f, New: %d, %d", factor, pw, ph);

    GdkWindow window = widget.getWindow();
    Surface surface = window.createSimilarSurface(Content.Color, pw, ph);
    Context cr = create(surface);
    scope(exit) {
        surface = null;
        cr = null;
    }
    cr.scale(factor, factor);
    widget.draw(cr);
    Pixbuf pb = pixbufGetFromSurface(surface, 0, 0, pw, ph);
    return pb;
}

class RenderWindow : OffscreenWindow {
    bool _canDraw = false;

    bool onDamage(EventExpose event, Widget w) {
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
            import std.stdio : writeln;
            writeln("******** RenderWindow Destructor");
        }
    }

    @property bool canDraw() {
        return _canDraw;
    }
}