module gx.gtk.cairo;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.format;

import cairo.Context;
import cairo.Surface;

import gdk.Cairo;
import gdk.Window;

import gdkpixbuf.Pixbuf;

import gtk.Container;
import gtk.OffscreenWindow;
import gtk.Widget;

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
        window.setDefaultSize(w,h);
        Container parent = cast(Container) widget.getParent();
        if (parent is null) {
            error("Parent is not a Container, cannot draw offscreen image");
            return null;        
        }
        parent.remove(widget);
        window.add(widget);
        window.showAll();
        Pixbuf pb = window.pixbuf;
        // Need to process events here until Window is drawn
        // Gives me a bit of the shudders, any potential for infinite loop?
        // TODO: Look at this a lot more, use idle instead to retrieve?
        while (pb is null) {
            trace("Iterate loop");
            gtk.Main.Main.iteration();
            pb = window.pixbuf;
        }
        if (pb is null) {
            error("Pixbuf from renderwindow is null");
        } else {
            pb = pb.scaleSimple(pw, ph , GdkInterpType.BILINEAR);
        }
        window.remove(widget);
        parent.add(widget);
        window.destroy();
        return pb;
    }
}

private:
class RenderWindow: OffscreenWindow {
    Pixbuf pb;
    
    bool onDamage(gdk.Event.Event, Widget) {
        trace("Damage event received");
        pb = getPixbuf();
        return true;
    }

public:
    this() {
        super();
        addOnDamage(&onDamage);
    }
    
    @property Pixbuf pixbuf() {
        return pb;
    }

}