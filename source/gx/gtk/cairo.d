/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.cairo;

import std.algorithm;
import std.conv;
import std.datetime;
import std.experimental.logger;

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
        tracef("Total time getting thumbnail: %d msecs", sw.peek().msecs);
    }
    if (widget.isDrawable()) {
        widget.queueDraw();
        while (gtk.Main.Main.eventsPending() && sw.peek().msecs<100) {
            Main.iterationDo(false);
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

ImageSurface renderImage(Pixbuf pb, bool alpha = false) {
    cairo_format_t format = alpha?cairo_format_t.ARGB32:cairo_format_t.RGB24;
    ImageSurface surface = ImageSurface.create(format, pb.getWidth(), pb.getHeight());
    Context cr = Context.create(surface);
    scope(exit) {
        cr.destroy();
    }
    setSourcePixbuf(cr, pb, 0, 0);
    cr.setOperator(cairo_operator_t.SOURCE);
    cr.paint();
    return surface;
}

/**
 * Renders an image onto an ImageSurface using different modes
 */
ImageSurface renderImage(Pixbuf pbSource, int outputWidth, int outputHeight, ImageLayoutMode mode, bool alpha = false, cairo_filter_t scaleMode = cairo_filter_t.BILINEAR) {
    ImageSurface surface = renderImage(pbSource);
    scope(exit) {
        surface.destroy();
    }
    return renderImage(surface, outputWidth, outputHeight, mode, alpha, scaleMode);
}

ImageSurface renderImage(ImageSurface isSource, int outputWidth, int outputHeight, ImageLayoutMode mode, bool alpha = false, cairo_filter_t scaleMode = cairo_filter_t.BILINEAR) {
    cairo_format_t format = alpha?cairo_format_t.ARGB32:cairo_format_t.RGB24;
    ImageSurface surface = ImageSurface.create(format, outputWidth, outputHeight);
    Context cr = Context.create(surface);
    scope(exit) {
        cr.destroy();
    }
    if (alpha) {
        cr.setOperator(cairo_operator_t.SOURCE);
    }
    renderImage(cr, isSource, outputWidth, outputHeight, mode, scaleMode);
    return surface;
}

void renderImage(Context cr, ImageSurface isSource, int outputWidth, int outputHeight, ImageLayoutMode mode, cairo_filter_t scaleMode = cairo_filter_t.BILINEAR) {
    StopWatch sw = StopWatch(AutoStart.yes);
    scope (exit) {
        sw.stop();
        tracef("Total time getting image: %d msecs", sw.peek().msecs);
    }
    final switch (mode) {
        case ImageLayoutMode.SCALE:
            double xScale = to!double(outputWidth) / to!double(isSource.getWidth());
            double yScale = to!double(outputHeight) / to!double(isSource.getHeight());
            double ratio = max(xScale, yScale);
            double xOffset = (outputWidth - (isSource.getWidth() * ratio)) / 2.0;
            double yOffset = (outputHeight - (isSource.getHeight() * ratio)) / 2.0;
            cr.translate(xOffset, yOffset);
            cr.scale(ratio, ratio);
            cr.setSourceSurface(isSource, 0, 0);
            cr.getSource().setFilter(scaleMode);
            cr.paint();
            break;
        case ImageLayoutMode.TILE:
            cr.setSourceSurface(isSource, 0, 0);
            cr.getSource().setExtend(cairo_extend_t.REPEAT);
            cr.paint();
            break;
        case ImageLayoutMode.CENTER:
            double x = (outputWidth - isSource.getWidth())/2;
            double y = (outputHeight - isSource.getHeight())/2;
            cr.translate(x,y);
            cr.setSourceSurface(isSource, 0, 0);
            cr.paint();
            break;
        case ImageLayoutMode.STRETCH:
            double xScale = to!double(outputWidth) / to!double(isSource.getWidth());
            double yScale = to!double(outputHeight) / to!double(isSource.getHeight());
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
