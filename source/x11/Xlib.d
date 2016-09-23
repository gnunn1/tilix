module x11.Xlib;
import core.stdc.config;
import core.stdc.stdarg;
import x11.X;

extern (C) nothrow:

const int XlibSpecificationRelease  = 6;
const int X_HAVE_UTF8_STRING        = 1;

alias char* XPointer;
alias int Status;

alias int Bool;
enum {
    False,
    True
}

alias int QueueMode;
enum {
    QueuedAlready,
    QueuedAfterReading,
    QueuedAfterFlush
}

int         ConnectionNumber            ( Display* dpy           )   { return dpy.fd;                                            }
Window      RootWindow                  ( Display* dpy,int scr   )   { return ScreenOfDisplay( dpy,scr ).root;                   }
int         DefaultScreen               ( Display* dpy           )   { return dpy.default_screen;                                }
Window      DefaultRootWindow           ( Display* dpy           )   { return ScreenOfDisplay( dpy,DefaultScreen( dpy ) ).root;  }
Visual*     DefaultVisual               ( Display* dpy,int scr   )   { return ScreenOfDisplay( dpy,scr ).root_visual;            }
GC          DefaultGC                   ( Display* dpy,int scr   )   { return ScreenOfDisplay( dpy,scr ).default_gc;             }
c_ulong     BlackPixel                  ( Display* dpy,int scr   )   { return cast(c_ulong)ScreenOfDisplay( dpy,scr ).black_pixel;  }
c_ulong     WhitePixel                  ( Display* dpy,int scr   )   { return cast(c_ulong)ScreenOfDisplay( dpy,scr ).white_pixel;  }
c_ulong     AllPlanes                   (                        )   { return 0xFFFFFFFF;                                        }
int         QLength                     ( Display* dpy           )   { return dpy.qlen;                                          }
int         DisplayWidth                ( Display* dpy,int scr   )   { return ScreenOfDisplay( dpy,scr ).width;                  }
int         DisplayHeight               ( Display* dpy,int scr   )   { return ScreenOfDisplay( dpy,scr ).height;                 }
int         DisplayWidthMM              ( Display* dpy,int scr   )   { return ScreenOfDisplay( dpy,scr ).mwidth;                 }
int         DisplayHeightMM             ( Display* dpy,int scr   )   { return ScreenOfDisplay( dpy,scr ).mheight;                }
int         DisplayPlanes               ( Display* dpy,int scr   )   { return ScreenOfDisplay( dpy,scr ).root_depth;             }
int         DisplayCells                ( Display* dpy,int scr   )   { return DefaultVisual( dpy,scr ).map_entries;              }
int         ScreenCount                 ( Display* dpy           )   { return dpy.nscreens;                                      }
char*       ServerVendor                ( Display* dpy           )   { return dpy.vendor;                                        }
int         ProtocolVersion             ( Display* dpy           )   { return dpy.proto_major_version;                           }
int         ProtocolRevision            ( Display* dpy           )   { return dpy.proto_minor_version;                           }
int         VendorRelease               ( Display* dpy           )   { return dpy.release;                                       }
char*       DisplayString               ( Display* dpy           )   { return dpy.display_name;                                  }
int         DefaultDepth                ( Display* dpy,int scr   )   { return ScreenOfDisplay( dpy,scr ).root_depth;             }
Colormap    DefaultColormap             ( Display* dpy,int scr   )   { return ScreenOfDisplay( dpy,scr ).cmap;                   }
int         BitmapUnit                  ( Display* dpy           )   { return dpy.bitmap_unit;                                   }
int         BitmapBitOrder              ( Display* dpy           )   { return dpy.bitmap_bit_order;                              }
int         BitmapPad                   ( Display* dpy           )   { return dpy.bitmap_pad;                                    }
int         ImagecharOrder              ( Display* dpy           )   { return dpy.char_order;                                    }
uint        NextRequest                 ( Display* dpy           )   { return cast(uint)dpy.request + 1;                         }
uint        LastKnownRequestProcessed   ( Display* dpy           )   { return cast(uint)dpy.last_request_read;                   }

/* macros for screen oriented applications ( toolkit ) */
Screen*     ScreenOfDisplay             ( Display* dpy,int scr   )   { return &dpy.screens[scr];                                 }
Screen*     DefaultScreenOfDisplay      ( Display* dpy           )   { return ScreenOfDisplay( dpy,DefaultScreen( dpy ) );       }
Display*    DisplayOfScreen             ( Screen* s              )   { return s.display;                                         }
Window      RootWindowOfScreen          ( Screen* s              )   { return s.root;                                            }
c_ulong     BlackPixelOfScreen          ( Screen* s              )   { return cast(c_ulong)s.black_pixel;                        }
c_ulong     WhitePixelOfScreen          ( Screen* s              )   { return cast(c_ulong)s.white_pixel;                        }
Colormap    DefaultColormapOfScreen     ( Screen* s              )   { return s.cmap;                                            }
int         DefaultDepthOfScreen        ( Screen* s              )   { return s.root_depth;                                      }
GC          DefaultGCOfScreen           ( Screen* s              )   { return s.default_gc;                                      }
Visual*     DefaultVisualOfScreen       ( Screen* s              )   { return s.root_visual;                                     }
int         WidthOfScreen               ( Screen* s              )   { return s.width;                                           }
int         HeightOfScreen              ( Screen* s              )   { return s.height;                                          }
int         WidthMMOfScreen             ( Screen* s              )   { return s.mwidth;                                          }
int         HeightMMOfScreen            ( Screen* s              )   { return s.mheight;                                         }
int         PlanesOfScreen              ( Screen* s              )   { return s.root_depth;                                      }
int         CellsOfScreen               ( Screen* s              )   { return DefaultVisualOfScreen( s ).map_entries;            }
int         MinCmapsOfScreen            ( Screen* s              )   { return s.min_maps;                                        }
int         MaxCmapsOfScreen            ( Screen* s              )   { return s.max_maps;                                        }
Bool        DoesSaveUnders              ( Screen* s              )   { return s.save_unders;                                     }
int         DoesBackingStore            ( Screen* s              )   { return s.backing_store;                                   }
c_long      EventMaskOfScreen           ( Screen* s              )   { return s.root_input_mask;                                 }

/*
 * Extensions need a way to hang private data on some structures.
 */
struct XExtData{
    int number;                                         /* number returned by XRegisterExtension                        */
    XExtData* next;                                     /* next item on list of data for structure                      */
    extern (C) nothrow int function( XExtData* extension ) free_private;   /* called to free private storage                               */
    XPointer private_data;                              /* data private to this extension.                              */
}

/*
 * This file contains structures used by the extension mechanism.
 */
struct XExtCodes{                                       /* public to extension, cannot be changed                       */
    int extension;                                      /* extension number                                             */
    int major_opcode;                                   /* major op-code assigned by server                             */
    int first_event;                                    /* first event number for the extension                         */
    int first_error;                                    /* first error number for the extension                         */

}

/*
 * Data structure for retrieving info about pixmap formats.
 */
struct XPixmapFormatValues{
    int depth;
    int bits_per_pixel;
    int scanline_pad;
}

/*
 * Data structure for setting graphics context.
 */

struct XGCValues{
    int function_;                                      /* logical operation                                            */
    c_ulong  plane_mask;                                /* plane mask                                                   */
    c_ulong  foreground;                                /* foreground pixel                                             */
    c_ulong  background;                                /* background pixel                                             */
    int line_width;                                     /* line width                                                   */
    int line_style;                                     /* LineSolid; LineOnOffDash; LineDoubleDash                     */
    int cap_style;                                      /* CapNotLast; CapButt; CapRound; CapProjecting                 */
    int join_style;                                     /* JoinMiter; JoinRound; JoinBevel                              */
    int fill_style;                                     /* FillSolid; FillTiled; FillStippled; FillOpaeueStippled       */
    int fill_rule;                                      /* EvenOddRule; WindingRule                                     */
    int arc_mode;                                       /* ArcChord; ArcPieSlice                                        */
    Pixmap tile;                                        /* tile pixmap for tiling operations                            */
    Pixmap stipple;                                     /* stipple 1 plane pixmap for stipping                          */
    int ts_x_origin;                                    /* offset for tile or stipple operations                        */
    int ts_y_origin;
    Font font;                                          /* default text font for text operations                        */
    int subwindow_mode;                                 /* ClipByChildren; IncludeInferiors                             */
    Bool graphics_exposures;                            /* boolean; should exposures be generated                       */
    int clip_x_origin;                                  /* origin for clipping                                          */
    int clip_y_origin;
    Pixmap clip_mask;                                   /* bitmap clipping; other calls for rects                       */
    int dash_offset;                                    /* patterned/dashed line information                            */
    char dashes;
}
version (XLIB_ILLEGAL_ACCESS){
    struct _XGC {
        XExtData* ext_data;                             /* hook for extension to hang data                              */
        GContext gid;                                   /* protocol ID for graphics context                             */
                                                        /* there is more to this structure, but it is private to Xlib   */
    }
}
else{
    struct _XGC;
}

alias _XGC* GC;

/*
 * Visual structure; contains information about colormapping possible.
 */
struct Visual{
    XExtData* ext_data;                                 /* hook for extension to hang data                              */
    VisualID visualid;                                  /* visual id of this visual                                     */
    int c_class;                                        /* class of screen (monochrome, etc.)                           */
    c_ulong  red_mask, green_mask, blue_mask;            /* mask values                                                  */
    int bits_per_rgb;                                   /* log base 2 of distinct color values                          */
    int map_entries;                                    /* color map entries                                            */
}

/*
 * Depth structure; contains information for each possible depth.
 */
struct Depth {
    int depth;                                          /* this depth (Z) of the depth                                  */
    int nvisuals;                                       /* number of Visual types at this depth                         */
    Visual* visuals;                                    /* list of visuals possible at this depth                       */
}

alias Display XDisplay;

struct Screen {
    XExtData* ext_data;                                 /* hook for extension to hang data                              */
    XDisplay* display;                                  /* back pointer to display structure                            */
    Window root;                                        /* Root window id.                                              */
    int width, height;                                  /* width and height of screen                                   */
    int mwidth, mheight;                                /* width and height of  in millimeters                          */
    int ndepths;                                        /* number of depths possible                                    */
    Depth* depths;                                      /* list of allowable depths on the screen                       */
    int root_depth;                                     /* bits per pixel                                               */
    Visual* root_visual;                                /* root visual                                                  */
    GC default_gc;                                      /* GC for the root root visual                                  */
    Colormap cmap;                                      /* default color map                                            */
    c_ulong  white_pixel;
    c_ulong  black_pixel;                               /* White and Black pixel values                                 */
    int max_maps, min_maps;                             /* max and min color maps                                       */
    int backing_store;                                  /* Never, WhenMapped, Always                                    */
    Bool save_unders;
    c_long root_input_mask;                               /* initial root input mask                                      */
}

/*
 * Format structure; describes ZFormat data the screen will understand.
 */
struct ScreenFormat{
    XExtData* ext_data;                                 /* hook for extension to hang data                              */
    int depth;                                          /* depth of this image format                                   */
    int bits_per_pixel;                                 /* bits/pixel at this depth                                     */
    int scanline_pad;                                   /* scanline must padded to this multiple                        */
}
/*
 * Data structure for setting window attributes.
 */
struct XSetWindowAttributes{
    Pixmap background_pixmap;                           /* background or None or ParentRelative                         */
    c_ulong  background_pixel;                          /* background pixel                                             */
    Pixmap border_pixmap;                               /* border of the window                                         */
    c_ulong  border_pixel;                              /* border pixel value                                           */
    int bit_gravity;                                    /* one of bit gravity values                                    */
    int win_gravity;                                    /* one of the window gravity values                             */
    int backing_store;                                  /* NotUseful, WhenMapped, Always                                */
    c_ulong  backing_planes;                            /* planes to be preseved if possible                            */
    c_ulong  backing_pixel;                             /* value to use in restoring planes                             */
    Bool save_under;                                    /* should bits under be saved? (popups)                         */
    c_long event_mask;                                    /* set of events that should be saved                           */
    c_long do_not_propagate_mask;                         /* set of events that should not propagate                      */
    Bool override_redirect;                             /* boolean value for override-redirect                          */
    Colormap colormap;                                  /* color map to be associated with window                       */
    Cursor cursor;                                      /* cursor to be displayed (or None)                             */
}

struct XWindowAttributes{
    int x, y;                                           /* location of window                                           */
    int width, height;                                  /* width and height of window                                   */
    int border_width;                                   /* border width of window                                       */
    int depth;                                          /* depth of window                                              */
    Visual* visual;                                     /* the associated visual structure                              */
    Window root;                                        /* root of screen containing window                             */
    int c_class;                                        /* InputOutput, InputOnly                                       */
    int bit_gravity;                                    /* one of bit gravity values                                    */
    int win_gravity;                                    /* one of the window gravity values                             */
    int backing_store;                                  /* NotUseful, WhenMapped, Always                                */
    c_ulong  backing_planes;                            /* planes to be preserved if possible                           */
    c_ulong  backing_pixel;                             /* value to be used when restoring planes                       */
    Bool save_under;                                    /* boolean, should bits under be saved?                         */
    Colormap colormap;                                  /* color map to be associated with window                       */
    Bool map_installed;                                 /* boolean, is color map currently installed                    */
    int map_state;                                      /* IsUnmapped, IsUnviewable, IsViewable                         */
    c_long all_event_masks;                               /* set of events all people have interest in                    */
    c_long your_event_mask;                               /* my event mask                                                */
    c_long do_not_propagate_mask;                         /* set of events that should not propagate                      */
    Bool override_redirect;                             /* boolean value for override-redirect                          */
    Screen* screen;                                     /* back pointer to correct screen                               */
}

/*
 * Data structure for host setting; getting routines.
 *
 */
struct XHostAddress{
    int family;                                         /* for example FamilyInternet                                   */
    int length;                                         /* length of address, in chars                                  */
    char* address;                                      /* pointer to where to find the chars                           */
}

/*
 * Data structure for ServerFamilyInterpreted addresses in host routines
 */
struct XServerInterpretedAddress{
    int typelength;                                     /* length of type string, in chars                              */
    int valuelength;                                    /* length of value string, in chars                             */
    char* type;                                         /* pointer to where to find the type string                     */
    char* value;                                        /* pointer to where to find the address                         */
}

struct XImage{
    int width, height;                                  /* size of image                                                */
    int xoffset;                                        /* number of pixels offset in X direction                       */
    int format;                                         /* XYBitmap, XYPixmap, ZPixmap                                  */
    char* data;                                         /* pointer to image data                                        */
    int char_order;                                     /* data char order, LSBFirst, MSBFirst                          */
    int bitmap_unit;                                    /* quant. of scanline 8, 16, 32                                 */
    int bitmap_bit_order;                               /* LSBFirst, MSBFirst                                           */
    int bitmap_pad;                                     /* 8, 16, 32 either XY or ZPixmap                               */
    int depth;                                          /* depth of image                                               */
    int chars_per_line;                                 /* accelarator to next line                                     */
    int bits_per_pixel;                                 /* bits per pixel (ZPixmap)                                     */
    c_ulong  red_mask;                                  /* bits in z arrangment                                         */
    c_ulong  green_mask;
    c_ulong  blue_mask;
    XPointer obdata;                                    /* hook for the object routines to hang on                      */
    struct F {                                          /* image manipulation routines                                  */
        extern (C) nothrow:
		XImage* function(
                            XDisplay*   /* display          */,
                            Visual*     /* visual           */,
                            uint        /* depth            */,
                            int         /* format           */,
                            int         /* offset           */,
                            char*       /* data             */,
                            uint        /* width            */,
                            uint        /* height           */,
                            int         /* bitmap_pad       */,
                            int         /* chars_per_line   */
                        )                                   create_image;
        int     function(XImage*)                           destroy_image;
        c_ulong function(XImage*, int, int)                 get_pixel;
        int     function(XImage*, int, int, c_ulong )       put_pixel;
        XImage  function(XImage*, int, int, uint, uint)     sub_image;
        int     function(XImage*, c_long)                   add_pixel;
    }
    F f;
}

/*
 * Data structure for XReconfigureWindow
 */
struct XWindowChanges{
    int x, y;
    int width, height;
    int border_width;
    Window sibling;
    int stack_mode;
}


/*
 * Data structure used by color operations
 */
struct XColor{
    c_ulong  pixel;
    ushort red, green, blue;
    char flags;                                         /* do_red, do_green, do_blue                                    */
    char pad;
}

/*
 * Data structures for graphics operations.  On most machines, these are
 * congruent with the wire protocol structures, so reformatting the data
 * can be avoided on these architectures.
 */
struct XSegment{
    short x1, y1, x2, y2;
}

struct XPoint{
    short x, y;
}

struct XRectangle{
    short x, y;
    ushort width, height;
}

struct XArc{
    short x, y;
    ushort width, height;
    short angle1, angle2;
}


/* Data structure for XChangeKeyboardControl */

struct XKeyboardControl{
        int key_click_percent;
        int bell_percent;
        int bell_pitch;
        int bell_duration;
        int led;
        int led_mode;
        int key;
        int auto_repeat_mode;                           /* On, Off, Default                                             */
}
/* Data structure for XGetKeyboardControl */

struct XKeyboardState{
    int key_click_percent;
    int bell_percent;
    uint bell_pitch, bell_duration;
    c_ulong led_mask;
    int global_auto_repeat;
    char[32] auto_repeats;
}

/* Data structure for XGetMotionEvents.  */

struct XTimeCoord{
    Time time;
    short x, y;
}

/* Data structure for X{Set,Get}ModifierMapping */

struct XModifierKeymap{
    int max_keypermod;                                  /* The server's max # of keys per modifier                      */
    KeyCode* modifiermap;                               /* An 8 by max_keypermod array of modifiers                     */
}


/*
 * Display datatype maintaining display specific data.
 * The contents of this structure are implementation dependent.
 * A Display should be treated as opaque by application code.
 */

struct _XPrivate;                                        /* Forward declare before use for C++                          */
struct _XrmHashBucketRec;

struct _XDisplay{
    XExtData* ext_data;                                 /* hook for extension to hang data                              */
    _XPrivate* private1;
    int fd;                                             /* Network socket.                                              */
    int private2;
    int proto_major_version;                            /* major version of server's X protocol */
    int proto_minor_version;                            /* minor version of servers X protocol */
    char* vendor;                                       /* vendor of the server hardware */
    XID private3;
    XID private4;
    XID private5;
    int private6;
    extern (C) nothrow XID function(_XDisplay*) resource_alloc;             /* allocator function */
    int char_order;                                     /* screen char order, LSBFirst, MSBFirst */
    int bitmap_unit;                                    /* padding and data requirements */
    int bitmap_pad;                                     /* padding requirements on bitmaps */
    int bitmap_bit_order;                               /* LeastSignificant or MostSignificant */
    int nformats;                                       /* number of pixmap formats in list */
    ScreenFormat* pixmap_format;                        /* pixmap format list */
    int private8;
    int release;                                        /* release of the server */
    _XPrivate* private9, private10;
    int qlen;                                           /* Length of input event queue */
    c_ulong  last_request_read;                         /* seq number of last event read */
    c_ulong  request;                                   /* sequence number of last request. */
    XPointer private11;
    XPointer private12;
    XPointer private13;
    XPointer private14;
    uint max_request_size;                          /* maximum number 32 bit words in request*/
    _XrmHashBucketRec* db;
    extern (C) nothrow int function( _XDisplay* )private15;
    char* display_name;                             /* "host:display" string used on this connect*/
    int default_screen;                             /* default screen for operations */
    int nscreens;                                   /* number of screens on this server*/
    Screen* screens;                                /* pointer to list of screens */
    c_ulong motion_buffer;                          /* size of motion buffer */
    c_ulong private16;
    int min_keycode;                                /* minimum defined keycode */
    int max_keycode;                                /* maximum defined keycode */
    XPointer private17;
    XPointer private18;
    int private19;
    char* xdefaults;                                /* contents of defaults from server */
    /* there is more to this structure, but it is private to Xlib */
}
alias _XDisplay Display;
alias _XDisplay* _XPrivDisplay;

struct XKeyEvent{
    int type;                                           /* of event                                                     */
    c_ulong  serial;                                    /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window window;                                      /* "event" window it is reported relative to                    */
    Window root;                                        /* root window that the event occurred on                       */
    Window subwindow;                                   /* child window                                                 */
    Time time;                                          /* milliseconds                                                 */
    int x, y;                                           /* pointer x, y coordinates in event window                     */
    int x_root, y_root;                                 /* coordinates relative to root                                 */
    uint state;                                         /* key or button mask                                           */
    uint keycode;                                       /* detail                                                       */
    Bool same_screen;                                   /* same screen flag                                             */
}

alias XKeyEvent XKeyPressedEvent;
alias XKeyEvent XKeyReleasedEvent;

struct XButtonEvent{
    int type;                                           /* of event                                                     */
    c_ulong  serial;                                    /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window window;                                      /* "event" window it is reported relative to                    */
    Window root;                                        /* root window that the event occurred on                       */
    Window subwindow;                                   /* child window                                                 */
    Time time;                                          /* milliseconds                                                 */
    int x, y;                                           /* pointer x, y coordinates in event window                     */
    int x_root, y_root;                                 /* coordinates relative to root                                 */
    uint state;                                         /* key or button mask                                           */
    uint button;                                        /* detail                                                       */
    Bool same_screen;                                   /* same screen flag                                             */
}
alias XButtonEvent XButtonPressedEvent;
alias XButtonEvent XButtonReleasedEvent;

struct XMotionEvent{
    int type;                                           /* of event                                                     */
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window window;                                      /* "event" window reported relative to                          */
    Window root;                                        /* root window that the event occurred on                       */
    Window subwindow;                                   /* child window                                                 */
    Time time;                                          /* milliseconds                                                 */
    int x, y;                                           /* pointer x, y coordinates in event window                     */
    int x_root, y_root;                                 /* coordinates relative to root                                 */
    uint state;                                         /* key or button mask                                           */
    char is_hint;                                       /* detail                                                       */
    Bool same_screen;                                   /* same screen flag                                             */
}
alias XMotionEvent XPointerMovedEvent;

struct XCrossingEvent{
    int type;                                           /* of event                                                     */
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window window;                                      /* "event" window reported relative to                          */
    Window root;                                        /* root window that the event occurred on                       */
    Window subwindow;                                   /* child window                                                 */
    Time time;                                          /* milliseconds                                                 */
    int x, y;                                           /* pointer x, y coordinates in event window                     */
    int x_root, y_root;                                 /* coordinates relative to root                                 */
    int mode;                                           /* NotifyNormal, NotifyGrab, NotifyUngrab                       */
    int detail;
    /*
     * NotifyAncestor, NotifyVirtual, NotifyInferior,
     * NotifyNonlinear,NotifyNonlinearVirtual
     */
    Bool same_screen;                                   /* same screen flag                                             */
    Bool focus;                                         /* boolean focus                                                */
    uint state;                                         /* key or button mask                                           */
}
alias XCrossingEvent XEnterWindowEvent;
alias XCrossingEvent XLeaveWindowEvent;

struct XFocusChangeEvent{
    int type;                                           /* FocusIn or FocusOut                                          */
    c_ulong serial;                                     /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window window;                                      /* window of event                                              */
    int mode;                                           /* NotifyNormal, NotifyWhileGrabbed,*/
                                                        /* NotifyGrab, NotifyUngrab */
    int detail;
    /*
     * NotifyAncestor, NotifyVirtual, NotifyInferior,
     * NotifyNonlinear,NotifyNonlinearVirtual, NotifyPointer,
     * NotifyPointerRoot, NotifyDetailNone
     */
}
alias  XFocusChangeEvent XFocusInEvent;
alias  XFocusChangeEvent XFocusOutEvent;

                                                        /* generated on EnterWindow and FocusIn  when KeyMapState selected */
struct XKeymapEvent{
    int type;
    c_ulong serial;                                     /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window window;
    char[32] key_vector;
}

struct XExposeEvent{
    int type;
    c_ulong serial;                                     /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window window;
    int x, y;
    int width, height;
    int count;                                          /* if non-zero, at least this many more                         */
}

struct XGraphicsExposeEvent{
    int type;
    c_ulong serial;                                     /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Drawable drawable;
    int x, y;
    int width, height;
    int count;                                          /* if non-zero, at least this many more                         */
    int major_code;                                     /* core is CopyArea or CopyPlane                                */
    int minor_code;                                     /* not defined in the core                                      */
}

struct XNoExposeEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Drawable drawable;
    int major_code;                                     /* core is CopyArea or CopyPlane                                */
    int minor_code;                                     /* not defined in the core                                      */
}

struct XVisibilityEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window window;
    int state;                                          /* Visibility state                                             */
}

struct XCreateWindowEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window parent;                                      /* parent of the window                                         */
    Window window;                                      /* window id of window created                                  */
    int x, y;                                           /* window location                                              */
    int width, height;                                  /* size of window                                               */
    int border_width;                                   /* border width                                                 */
    Bool override_redirect;                             /* creation should be overridden                                */
}

struct XDestroyWindowEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window event;
    Window window;
}

struct XUnmapEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window event;
    Window window;
    Bool from_configure;
}

struct XMapEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window event;
    Window window;
    Bool override_redirect;                             /* boolean, is override set...                                  */
}

struct XMapRequestEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window parent;
    Window window;
}

struct XReparentEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window event;
    Window window;
    Window parent;
    int x, y;
    Bool override_redirect;
}

struct XConfigureEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window event;
    Window window;
    int x, y;
    int width, height;
    int border_width;
    Window above;
    Bool override_redirect;
}

struct XGravityEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window event;
    Window window;
    int x, y;
}

struct XResizeRequestEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window window;
    int width, height;
}

struct XConfigureRequestEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window parent;
    Window window;
    int x, y;
    int width, height;
    int border_width;
    Window above;
    int detail;                                         /* Above, Below, TopIf, BottomIf, Opposite                      */
    c_ulong value_mask;
}

struct XCirculateEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window event;
    Window window;
    int place;                                          /* PlaceOnTop, PlaceOnBottom                                    */
}

struct XCirculateRequestEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window parent;
    Window window;
    int place;                                          /* PlaceOnTop, PlaceOnBottom                                    */
}

struct XPropertyEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window window;
    Atom atom;
    Time time;
    int state;                                          /* NewValue, Deleted                                            */
}

struct XSelectionClearEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window window;
    Atom selection;
    Time time;
}

struct XSelectionRequestEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window owner;
    Window requestor;
    Atom selection;
    Atom target;
    Atom property;
    Time time;
}

struct XSelectionEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window requestor;
    Atom selection;
    Atom target;
    Atom property;                                      /* ATOM or None                                                 */
    Time time;
}

struct XColormapEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window window;
    Colormap colormap;                                  /* COLORMAP or None                                             */
    Bool c_new;                                         /* C++                                                          */
    int state;                                          /* ColormapInstalled, ColormapUninstalled                       */
}

struct XClientMessageEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window window;
    Atom message_type;
    int format;
    union _data  {
                    char[20] b;
                    short[10] s;
                    c_long[5] l;
                }
	_data data;
}

struct XMappingEvent{
    int type;
    c_ulong serial;                                       /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window window;                                      /* unused                                                       */
    int request;                                        /* one of MappingModifier, MappingKeyboard, MappingPointer      */
    int first_keycode;                                  /* first keycode                                                */
    int count;                                          /* defines range of change w. first_keycode                     */
}

struct XErrorEvent{
    int type;
    Display* display;                                   /* Display the event was read from                              */
    XID resourceid;                                     /* resource id                                                  */
    c_ulong  serial;                                    /* serial number of failed request                              */
    ubyte error_code;                                   /* error code of failed request                                 */
    ubyte request_code;                                 /* Major op-code of failed request                              */
    ubyte minor_code;                                   /* Minor op-code of failed request                              */
}

struct XAnyEvent{
    int type;
    c_ulong serial;                                      /* # of last request processed by server                        */
    Bool send_event;                                    /* true if this came from a SendEvent request                   */
    Display* display;                                   /* Display the event was read from                              */
    Window window;                                      /* window on which event was requested in event mask            */
}


/***************************************************************
 *
 * GenericEvent.  This event is the standard event for all newer extensions.
 */

struct XGenericEvent {
    int            type;                                /* of event. Always GenericEvent                                */
    c_ulong        serial;                              /* # of last request processed                                  */
    Bool           send_event;                          /* true if from SendEvent request                               */
    Display*       display;                             /* Display the event was read from                              */
    int            extension;                           /* major opcode of extension that caused the event              */
    int            evtype;                              /* actual event type.                                           */
}

struct XGenericEventCookie{
    int            type;                                /* of event. Always GenericEvent                                */
    c_ulong        serial;                              /* # of last request processed                                  */
    Bool           send_event;                          /* true if from SendEvent request                               */
    Display*       display;                             /* Display the event was read from                              */
    int            extension;                           /* major opcode of extension that caused the event              */
    int            evtype;                              /* actual event type.                                           */
    uint           cookie;
    void*          data;
}

/*
 * this union is defined so Xlib can always use the same sized
 * event structure internally, to avoid memory fragmentation.
 */
 union XEvent {
    int type;                                           /* must not be changed; first element                           */
    XAnyEvent xany;
    XKeyEvent xkey;
    XButtonEvent xbutton;
    XMotionEvent xmotion;
    XCrossingEvent xcrossing;
    XFocusChangeEvent xfocus;
    XExposeEvent xexpose;
    XGraphicsExposeEvent xgraphicsexpose;
    XNoExposeEvent xnoexpose;
    XVisibilityEvent xvisibility;
    XCreateWindowEvent xcreatewindow;
    XDestroyWindowEvent xdestroywindow;
    XUnmapEvent xunmap;
    XMapEvent xmap;
    XMapRequestEvent xmaprequest;
    XReparentEvent xreparent;
    XConfigureEvent xconfigure;
    XGravityEvent xgravity;
    XResizeRequestEvent xresizerequest;
    XConfigureRequestEvent xconfigurerequest;
    XCirculateEvent xcirculate;
    XCirculateRequestEvent xcirculaterequest;
    XPropertyEvent xproperty;
    XSelectionClearEvent xselectionclear;
    XSelectionRequestEvent xselectionrequest;
    XSelectionEvent xselection;
    XColormapEvent xcolormap;
    XClientMessageEvent xclient;
    XMappingEvent xmapping;
    XErrorEvent xerror;
    XKeymapEvent xkeymap;
    XGenericEvent xgeneric;
    XGenericEventCookie xcookie;
    c_long[24] pad;
};

int XAllocID(Display* dpy) {return cast(int) dpy.resource_alloc(dpy);}

/*
 * per character font metric information.
 */
struct XCharStruct{
    short    lbearing;                                  /* origin to left edge of raster                                */
    short    rbearing;                                  /* origin to right edge of raster                               */
    short    width;                                     /* advance to next char's origin                                */
    short    ascent;                                    /* baseline to top edge of raster                               */
    short    descent;                                   /* baseline to bottom edge of raster                            */
    ushort   attributes;                                /* per char flags (not predefined)                              */
}

/*
 * To allow arbitrary information with fonts, there are additional properties
 * returned.
 */
struct XFontProp{
    Atom name;
    c_ulong card32;
}

struct XFontStruct{
    XExtData*       ext_data;                           /* hook for extension to hang data                              */
    Font            fid;                                /* Font id for this font                                        */
    uint            direction;                          /* hint about direction the font is painted                     */
    uint            min_char_or_char2;                  /* first character                                              */
    uint            max_char_or_char2;                  /* last character                                               */
    uint            min_char1;                          /* first row that exists                                        */
    uint            max_char1;                          /* last row that exists                                         */
    Bool            all_chars_exist;                    /* flag if all characters have non-zero size                    */
    uint            default_char;                       /* char to print for undefined character                        */
    int             n_properties;                       /* how many properties there are                                */
    XFontProp*      properties;                         /* pointer to array of additional properties                    */
    XCharStruct     min_bounds;                         /* minimum bounds over all existing char                        */
    XCharStruct     max_bounds;                         /* maximum bounds over all existing char                        */
    XCharStruct*    per_char;                           /* first_char to last_char information                          */
    int             ascent;                             /* log. extent above baseline for spacing                       */
    int             descent;                            /* log. descent below baseline for spacing                      */
}

/*
 * PolyText routines take these as arguments.
 */
struct XTextItem{
    char* chars;                                        /* pointer to string                                            */
    int nchars;                                         /* number of characters                                         */
    int delta;                                          /* delta between strings                                        */
    Font font;                                          /* font to print it in, None don't change                       */
}

struct XChar2b{                                               /* normal 16 bit characters are two chars                       */
    ubyte char1;
    ubyte char2;
}

struct XTextItem16{
    XChar2b* chars;                                     /* two char characters                                          */
    int nchars;                                         /* number of characters                                         */
    int delta;                                          /* delta between strings                                        */
    Font font;                                          /* font to print it in, None don't change                       */
}


union XEDataObject{
    Display* display;
    GC gc;
    Visual* visual;
    Screen* screen;
    ScreenFormat* pixmap_format;
    XFontStruct* font;
}

struct XFontSetExtents{
    XRectangle      max_ink_extent;
    XRectangle      max_logical_extent;
}

/* unused:
 void (*XOMProc)();
 */

struct _XOM{}
struct _XOC{}
alias _XOM*   XOM;
alias _XOC*   XOC;
alias _XOC*   XFontSet;

struct XmbTextItem{
    char*           chars;
    int             nchars;
    int             delta;
    XFontSet        font_set;
}

struct XwcTextItem{
    wchar*          chars;
    int             nchars;
    int             delta;
    XFontSet        font_set;
}

const char* XNRequiredCharSet                = "requiredCharSet";
const char* XNQueryOrientation               = "queryOrientation";
const char* XNBaseFontName                   = "baseFontName";
const char* XNOMAutomatic                    = "omAutomatic";
const char* XNMissingCharSet                 = "missingCharSet";
const char* XNDefaultString                  = "defaultString";
const char* XNOrientation                    = "orientation";
const char* XNDirectionalDependentDrawing    = "directionalDependentDrawing";
const char* XNContextualDrawing              = "contextualDrawing";
const char* XNFontInfo                       = "fontInfo";

struct XOMCharSetList{
    int charset_count;
    char** charset_list;
}

alias int XOrientation;
enum {
    XOMOrientation_LTR_TTB,
    XOMOrientation_RTL_TTB,
    XOMOrientation_TTB_LTR,
    XOMOrientation_TTB_RTL,
    XOMOrientation_Context
}

struct XOMOrientation{
    int num_orientation;
    XOrientation* orientation;                          /* Input Text description                                       */
}

struct XOMFontInfo{
    int num_font;
    XFontStruct **font_struct_list;
    char** font_name_list;
}

struct _XIM{}
struct _XIC{}
alias _XIM *XIM;
alias _XIC *XIC;

alias void function(
    XIM,
    XPointer,
    XPointer
) XIMProc;

alias Bool function(
    XIC,
    XPointer,
    XPointer
) XICProc;

alias void function(
    Display*,
    XPointer,
    XPointer
) XIDProc;

struct XIMStyles{
    ushort count_styles;
    XIMStyle* supported_styles;
}

alias c_ulong XIMStyle;
enum {
    XIMPreeditArea      = 0x0001L,
    XIMPreeditCallbacks = 0x0002L,
    XIMPreeditPosition  = 0x0004L,
    XIMPreeditNothing   = 0x0008L,
    XIMPreeditNone      = 0x0010L,
    XIMStatusArea       = 0x0100L,
    XIMStatusCallbacks  = 0x0200L,
    XIMStatusNothing    = 0x0400L,
    XIMStatusNone       = 0x0800L
}

const char* XNVaNestedList                 = "XNVaNestedList";
const char* XNQueryInputStyle              = "queryInputStyle";
const char* XNClientWindow                 = "clientWindow";
const char* XNInputStyle                   = "inputStyle";
const char* XNFocusWindow                  = "focusWindow";
const char* XNResourceName                 = "resourceName";
const char* XNResourceClass                = "resourceClass";
const char* XNGeometryCallback             = "geometryCallback";
const char* XNDestroyCallback              = "destroyCallback";
const char* XNFilterEvents                 = "filterEvents";
const char* XNPreeditStartCallback         = "preeditStartCallback";
const char* XNPreeditDoneCallback          = "preeditDoneCallback";
const char* XNPreeditDrawCallback          = "preeditDrawCallback";
const char* XNPreeditCaretCallback         = "preeditCaretCallback";
const char* XNPreeditStateNotifyCallback   = "preeditStateNotifyCallback";
const char* XNPreeditAttributes            = "preeditAttributes";
const char* XNStatusStartCallback          = "statusStartCallback";
const char* XNStatusDoneCallback           = "statusDoneCallback";
const char* XNStatusDrawCallback           = "statusDrawCallback";
const char* XNStatusAttributes             = "statusAttributes";
const char* XNArea                         = "area";
const char* XNAreaNeeded                   = "areaNeeded";
const char* XNSpotLocation                 = "spotLocation";
const char* XNColormap                     = "colorMap";
const char* XNStdColormap                  = "stdColorMap";
const char* XNForeground                   = "foreground";
const char* XNBackground                   = "background";
const char* XNBackgroundPixmap             = "backgroundPixmap";
const char* XNFontSet                      = "fontSet";
const char* XNLineSpace                    = "lineSpace";
const char* XNCursor                       = "cursor";

const char* XNQueryIMValuesList            = "queryIMValuesList";
const char* XNQueryICValuesList            = "queryICValuesList";
const char* XNVisiblePosition              = "visiblePosition";
const char* XNR6PreeditCallback            = "r6PreeditCallback";
const char* XNStringConversionCallback     = "stringConversionCallback";
const char* XNStringConversion             = "stringConversion";
const char* XNResetState                   = "resetState";
const char* XNHotKey                       = "hotKey";
const char* XNHotKeyState                  = "hotKeyState";
const char* XNPreeditState                 = "preeditState";
const char* XNSeparatorofNestedList        = "separatorofNestedList";

const int XBufferOverflow                   = -1;
const int XLookupNone                       = 1;
const int XLookupChars                      = 2;
const int XLookupKeySym                     = 3;
const int XLookupBoth                       = 4;

alias XVaNestedList = void*;

struct XIMCallback{
    XPointer client_data;
    XIMProc callback;
}

struct XICCallback{
    XPointer client_data;
    XICProc callback;
}

alias int XIMFeedback;
enum {
    XIMReverse              = 1L,
    XIMUnderline            = (1L<<1),
    XIMHighlight            = (1L<<2),
    XIMPrimary              = (1L<<5),
    XIMSecondary            = (1L<<6),
    XIMTertiary             = (1L<<7),
    XIMVisibleToForward     = (1L<<8),
    XIMVisibleToBackword    = (1L<<9),
    XIMVisibleToCenter      = (1L<<10)
}

struct XIMText {
    ushort length;
    XIMFeedback* feedback;
    Bool encoding_is_wchar;
    union c_string{
        char* multi_char;
        wchar*   wide_char;
    }
}


alias c_ulong XIMPreeditState;
enum {
    XIMPreeditUnKnown   = 0L,
    XIMPreeditEnable    = 1L,
    XIMPreeditDisable   = (1L<<1)
}

struct XIMPreeditStateNotifyCallbackStruct {
    XIMPreeditState state;
}

alias c_ulong XIMResetState;
enum {
    XIMInitialState = 1L,
    XIMPreserveState= 1L<<1
}

alias c_ulong XIMStringConversionFeedback;
enum {
    XIMStringConversionLeftEdge     = 0x00000001,
    XIMStringConversionRightEdge    = 0x00000002,
    XIMStringConversionTopEdge      = 0x00000004,
    XIMStringConversionBottomEdge   = 0x00000008,
    XIMStringConversionConcealed    = 0x00000010,
    XIMStringConversionWrapped      = 0x00000020
}

struct XIMStringConversionText{
    ushort length;
    XIMStringConversionFeedback* feedback;
    Bool encoding_is_wchar;
    union c_string{
        char* mbs;
        wchar*   wcs;
    };
}

alias ushort XIMStringConversionPosition;

alias ushort XIMStringConversionType;
enum {
    XIMStringConversionBuffer   = 0x0001,
    XIMStringConversionLine     = 0x0002,
    XIMStringConversionWord     = 0x0003,
    XIMStringConversionChar     = 0x0004
}

alias ushort XIMStringConversionOperation;
enum {
    XIMStringConversionSubstitution     = 0x0001,
    XIMStringConversionRetrieval        = 0x0002
}

alias int XIMCaretDirection;
enum {
    XIMForwardChar, XIMBackwardChar,
    XIMForwardWord, XIMBackwardWord,
    XIMCaretUp,     XIMCaretDown,
    XIMNextLine,    XIMPreviousLine,
    XIMLineStart,   XIMLineEnd,
    XIMAbsolutePosition,
    XIMDontChange
}

struct XIMStringConversionCallbackStruct{
    XIMStringConversionPosition position;
    XIMCaretDirection direction;
    XIMStringConversionOperation operation;
    ushort factor;
    XIMStringConversionText* text;
}

struct XIMPreeditDrawCallbackStruct{
    int caret;                                          /* Cursor offset within pre-edit string                         */
    int chg_first;                                      /* Starting change position                                     */
    int chg_length;                                     /* Length of the change in character count                      */
    XIMText* text;
}

alias int XIMCaretStyle;
enum {
    XIMIsInvisible,                                     /* Disable caret feedback                                       */
    XIMIsPrimary,                                       /* UI defined caret feedback                                    */
    XIMIsSecondary                                      /* UI defined caret feedback                                    */
}

struct XIMPreeditCaretCallbackStruct{
    int position;                                       /* Caret offset within pre-edit string                          */
    XIMCaretDirection direction;                        /* Caret moves direction                                        */
    XIMCaretStyle style;                                /* Feedback of the caret                                        */
}

alias int XIMStatusDataType;
enum {
    XIMTextType,
    XIMBitmapType
}

struct XIMStatusDrawCallbackStruct {
    XIMStatusDataType type;
    union data{
        XIMText*    text;
        Pixmap      bitmap;
    };
}

struct XIMHotKeyTrigger {
    KeySym      keysym;
    int         modifier;
    int         modifier_mask;
}

struct XIMHotKeyTriggers {
    int                 num_hot_key;
    XIMHotKeyTrigger*   key;
}

alias c_ulong XIMHotKeyState;
enum {
    XIMHotKeyStateON    = 0x0001L,
    XIMHotKeyStateOFF   = 0x0002L
}

struct XIMValuesList{
    ushort count_values;
    char** supported_values;
}

version( Windows ){
	extern int	*_Xdebug_p;
} else {
	extern int _Xdebug;
}

extern XFontStruct* XLoadQueryFont(
    Display*                                            /* display                                                      */,
    char*                                               /* name                                                         */
);

extern XFontStruct* XQueryFont(
    Display*                                            /* display                                                      */,
    XID                                                 /* font_ID                                                      */
);


extern XTimeCoord* XGetMotionEvents(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Time                                                /* start                                                        */,
    Time                                                /* stop                                                         */,
    int*                                                /* nevents_return                                               */
);

extern XModifierKeymap* XDeleteModifiermapEntry(
    XModifierKeymap*                                    /* modmap                                                       */,
    KeyCode                                             /* keycode_entry                                                */,
    int                                                 /* modifier                                                     */
);

extern XModifierKeymap* XGetModifierMapping(
    Display*                                            /* display                                                      */
);

extern XModifierKeymap* XInsertModifiermapEntry(
    XModifierKeymap*                                    /* modmap                                                       */,
    KeyCode                                             /* keycode_entry                                                */,
    int                                                 /* modifier                                                     */
);

extern XModifierKeymap* XNewModifiermap(
    int                                                 /* max_keys_per_mod                                             */
);

extern XImage* XCreateImage(
    Display*                                            /* display                                                      */,
    Visual*                                             /* visual                                                       */,
    uint                                                /* depth                                                        */,
    int                                                 /* format                                                       */,
    int                                                 /* offset                                                       */,
    char*                                               /* data                                                         */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    int                                                 /* bitmap_pad                                                   */,
    int                                                 /* chars_per_line                                               */
);
extern Status XInitImage(
    XImage*                                             /* image                                                        */
);
extern XImage* XGetImage(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    c_ulong                                             /* plane_mask                                                   */,
    int                                                 /* format                                                       */
);
extern XImage* XGetSubImage(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    c_ulong                                             /* plane_mask                                                   */,
    int                                                 /* format                                                       */,
    XImage*                                             /* dest_image                                                   */,
    int                                                 /* dest_x                                                       */,
    int                                                 /* dest_y                                                       */
);

/*
 * X function declarations.
 */
extern Display* XOpenDisplay(
    char*                                               /* display_name                                                 */
);

extern void XrmInitialize( );

extern char* XFetchchars(
    Display*                                            /* display                                                      */,
    int*                                                /* nchars_return                                                */
);
extern char* XFetchBuffer(
    Display*                                            /* display                                                      */,
    int*                                                /* nchars_return                                                */,
    int                                                 /* buffer                                                       */
);
extern char* XGetAtomName(
    Display*                                            /* display                                                      */,
    Atom                                                /* atom                                                         */
);
extern Status XGetAtomNames(
    Display*                                            /* dpy                                                          */,
    Atom*                                               /* atoms                                                        */,
    int                                                 /* count                                                        */,
    char**                                              /* names_return                                                 */
);
extern char* XGetDefault(
    Display*                                            /* display                                                      */,
    char*                                               /* program                                                      */,
    char*                                               /* option                                                       */
);
extern char* XDisplayName(
    char*                                               /* string                                                       */
);
extern char* XKeysymToString(
    KeySym                                              /* keysym                                                       */
);

extern int function(
    Display*                                            /* display                                                      */
)XSynchronize(
    Display*                                            /* display                                                      */,
    Bool                                                /* onoff                                                        */
);
extern int function(
    Display*                                            /* display                                                      */
)XSetAfterFunction(
    Display*                                            /* display                                                      */,
    int function(
         Display*                                       /* display                                                      */
    )                                                   /* procedure                                                    */
);
extern Atom XInternAtom(
    Display*                                            /* display                                                      */,
    const char*                                         /* atom_name                                                    */,
    Bool                                                /* only_if_exists                                               */
);
extern Status XInternAtoms(
    Display*                                            /* dpy                                                          */,
    char**                                              /* names                                                        */,
    int                                                 /* count                                                        */,
    Bool                                                /* onlyIfExists                                                 */,
    Atom*                                               /* atoms_return                                                 */
);
extern Colormap XCopyColormapAndFree(
    Display*                                            /* display                                                      */,
    Colormap                                            /* colormap                                                     */
);
extern Colormap XCreateColormap(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Visual*                                             /* visual                                                       */,
    int                                                 /* alloc                                                        */
);
extern Cursor XCreatePixmapCursor(
    Display*                                            /* display                                                      */,
    Pixmap                                              /* source                                                       */,
    Pixmap                                              /* mask                                                         */,
    XColor*                                             /* foreground_color                                             */,
    XColor*                                             /* background_color                                             */,
    uint                                                /* x                                                            */,
    uint                                                /* y                                                            */
);
extern Cursor XCreateGlyphCursor(
    Display*                                            /* display                                                      */,
    Font                                                /* source_font                                                  */,
    Font                                                /* mask_font                                                    */,
    uint                                                /* source_char*                                                 */,
    uint                                                /* mask_char*                                                   */,
    XColor*                                             /* foreground_color                                             */,
    XColor*                                             /* background_color                                             */
);
extern Cursor XCreateFontCursor(
    Display*                                            /* display                                                      */,
    uint                                                /* shape                                                        */
);
extern Font XLoadFont(
    Display*                                            /* display                                                      */,
    char*                                               /* name                                                         */
);
extern GC XCreateGC(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    c_ulong                                             /* valuemask                                                    */,
    XGCValues*                                          /* values                                                       */
);
extern GContext XGContextFromGC(
    GC                                                  /* gc                                                           */
);
extern void XFlushGC(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */
);
extern Pixmap XCreatePixmap(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    uint                                                /* depth                                                        */
);
extern Pixmap XCreateBitmapFromData(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    char*                                               /* data                                                         */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */
);
extern Pixmap XCreatePixmapFromBitmapData(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    char*                                               /* data                                                         */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    c_ulong                                             /* fg                                                           */,
    c_ulong                                             /* bg                                                           */,
    uint                                                /* depth                                                        */
);
extern Window XCreateSimpleWindow(
    Display*                                            /* display                                                      */,
    Window                                              /* parent                                                       */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    uint                                                /* border_width                                                 */,
    c_ulong                                             /* border                                                       */,
    c_ulong                                             /* background                                                   */
);
extern Window XGetSelectionOwner(
    Display*                                            /* display                                                      */,
    Atom                                                /* selection                                                    */
);
extern Window XCreateWindow(
    Display*                                            /* display                                                      */,
    Window                                              /* parent                                                       */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    uint                                                /* border_width                                                 */,
    int                                                 /* depth                                                        */,
    uint                                                /* class                                                        */,
    Visual*                                             /* visual                                                       */,
    c_ulong                                             /* valuemask                                                    */,
    XSetWindowAttributes*                               /* attributes                                                   */
);

extern Colormap* XListInstalledColormaps(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    int*                                                /* num_return                                                   */
);
extern char** XListFonts(
    Display*                                            /* display                                                      */,
    char*                                               /* pattern                                                      */,
    int                                                 /* maxnames                                                     */,
    int*                                                /* actual_count_return                                          */
);
extern char* XListFontsWithInfo(
    Display*                                            /* display                                                      */,
    char*                                               /* pattern                                                      */,
    int                                                 /* maxnames                                                     */,
    int*                                                /* count_return                                                 */,
    XFontStruct**                                       /* info_return                                                  */
);
extern char** XGetFontPath(
    Display*                                            /* display                                                      */,
    int*                                                /* npaths_return                                                */
);
extern char** XListExtensions(
    Display*                                            /* display                                                      */,
    int*                                                /* nextensions_return                                           */
);
extern Atom* XListProperties(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    int*                                                /* num_prop_return                                              */
);
extern XHostAddress* XListHosts(
    Display*                                            /* display                                                      */,
    int*                                                /* nhosts_return                                                */,
    Bool*                                               /* state_return                                                 */
);
extern KeySym XKeycodeToKeysym(
    Display*                                            /* display                                                      */,
    KeyCode                                             /* keycode                                                      */,
    int                                                 /* index                                                        */
);
extern KeySym XLookupKeysym(
    XKeyEvent*                                          /* key_event                                                    */,
    int                                                 /* index                                                        */
);
extern KeySym* XGetKeyboardMapping(
    Display*                                            /* display                                                      */,
    KeyCode                                             /* first_keycode                                                */,
    int                                                 /* keycode_count                                                */,
    int*                                                /* keysyms_per_keycode_return                                   */
);
extern KeySym XStringToKeysym(
    char*                                               /* string                                                       */
);
extern c_long XMaxRequestSize(
    Display*                                            /* display                                                      */
);
extern c_long XExtendedMaxRequestSize(
    Display*                                            /* display                                                      */
);
extern char* XResourceManagerString(
    Display*                                            /* display                                                      */
);
extern char* XScreenResourceString(
    Screen*                                             /* screen                                                       */
);
extern c_ulong XDisplayMotionBufferSize(
    Display*                                            /* display                                                      */
);
extern VisualID XVisualIDFromVisual(
    Visual*                                             /* visual                                                       */
);

                                                        /* multithread routines                                         */

extern Status XInitThreads( );

extern void XLockDisplay(
    Display*                                            /* display                                                      */
);

extern void XUnlockDisplay(
    Display*                                            /* display                                                      */
);

                                                        /* routines for dealing with extensions                         */

extern XExtCodes* XInitExtension(
    Display*                                            /* display                                                      */,
    char*                                               /* name                                                         */
);

extern XExtCodes* XAddExtension(
    Display*                                            /* display                                                      */
);
extern XExtData* XFindOnExtensionList(
    XExtData**                                          /* structure                                                    */,
    int                                                 /* number                                                       */
);
extern XExtData **XEHeadOfExtensionList(
    XEDataObject                                        /* object                                                       */
);

                                                        /* these are routines for which there are also macros           */
extern Window XRootWindow(
    Display*                                            /* display                                                      */,
    int                                                 /* screen_number                                                */
);
extern Window XDefaultRootWindow(
    Display*                                            /* display                                                      */
);
extern Window XRootWindowOfScreen(
    Screen*                                             /* screen                                                       */
);
extern Visual* XDefaultVisual(
    Display*                                            /* display                                                      */,
    int                                                 /* screen_number                                                */
);
extern Visual* XDefaultVisualOfScreen(
    Screen*                                             /* screen                                                       */
);
extern GC XDefaultGC(
    Display*                                            /* display                                                      */,
    int                                                 /* screen_number                                                */
);
extern GC XDefaultGCOfScreen(
    Screen*                                             /* screen                                                       */
);
extern c_ulong XBlackPixel(
    Display*                                            /* display                                                      */,
    int                                                 /* screen_number                                                */
);
extern c_ulong XWhitePixel(
    Display*                                            /* display                                                      */,
    int                                                 /* screen_number                                                */
);
extern c_ulong XAllPlanes( );
extern c_ulong XBlackPixelOfScreen(
    Screen*                                             /* screen                                                       */
);
extern c_ulong XWhitePixelOfScreen(
    Screen*                                             /* screen                                                       */
);
extern uint XNextRequest(
    Display*                                            /* display                                                      */
);
extern uint XLastKnownRequestProcessed(
    Display*                                            /* display                                                      */
);
extern char* XServerVendor(
    Display*                                            /* display                                                      */
);
extern char* XDisplayString(
    Display*                                            /* display                                                      */
);
extern Colormap XDefaultColormap(
    Display*                                            /* display                                                      */,
    int                                                 /* screen_number                                                */
);
extern Colormap XDefaultColormapOfScreen(
    Screen*                                             /* screen                                                       */
);
extern Display* XDisplayOfScreen(
    Screen*                                             /* screen                                                       */
);
extern Screen* XScreenOfDisplay(
    Display*                                            /* display                                                      */,
    int                                                 /* screen_number                                                */
);
extern Screen* XDefaultScreenOfDisplay(
    Display*                                            /* display                                                      */
);
extern c_long XEventMaskOfScreen(
    Screen*                                             /* screen                                                       */
);

extern int XScreenNumberOfScreen(
    Screen*                                             /* screen                                                       */
);

alias int function (                                          /* WARNING, this type not in Xlib spec                          */
    Display*                                            /* display                                                      */,
    XErrorEvent*                                        /* error_event                                                  */
) XErrorHandler;

extern XErrorHandler XSetErrorHandler (
    XErrorHandler                                       /* handler                                                      */
);


alias int function (                                          /* WARNING, this type not in Xlib spec                          */
    Display*                                            /* display                                                      */
)XIOErrorHandler;

extern XIOErrorHandler XSetIOErrorHandler (
    XIOErrorHandler                                     /* handler                                                      */
);


extern XPixmapFormatValues* XListPixmapFormats(
    Display*                                            /* display                                                      */,
    int*                                                /* count_return                                                 */
);
extern int* XListDepths(
    Display*                                            /* display                                                      */,
    int                                                 /* screen_number                                                */,
    int*                                                /* count_return                                                 */
);

                                                        /* ICCCM routines for things that don't require special include files; */
                                                        /* other declarations are given in Xutil.h                             */
extern Status XReconfigureWMWindow(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    int                                                 /* screen_number                                                */,
    uint                                                /* mask                                                         */,
    XWindowChanges*                                     /* changes                                                      */
);

extern Status XGetWMProtocols(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Atom**                                              /* protocols_return                                             */,
    int*                                                /* count_return                                                 */
);
extern Status XSetWMProtocols(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Atom*                                               /* protocols                                                    */,
    int                                                 /* count                                                        */
);
extern Status XIconifyWindow(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    int                                                 /* screen_number                                                */
);
extern Status XWithdrawWindow(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    int                                                 /* screen_number                                                */
);
extern Status XGetCommand(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    char***                                             /* argv_return                                                  */,
    int*                                                /* argc_return                                                  */
);
extern Status XGetWMColormapWindows(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Window**                                            /* windows_return                                               */,
    int*                                                /* count_return                                                 */
);
extern Status XSetWMColormapWindows(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Window*                                             /* colormap_windows                                             */,
    int                                                 /* count                                                        */
);
extern void XFreeStringList(
    char**                                              /* list                                                         */
);
extern int XSetTransientForHint(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Window                                              /* prop_window                                                  */
);

                                                        /* The following are given in alphabetical order                */

extern int XActivateScreenSaver(
    Display*                                            /* display                                                      */
);

extern int XAddHost(
    Display*                                            /* display                                                      */,
    XHostAddress*                                       /* host                                                         */
);

extern int XAddHosts(
    Display*                                            /* display                                                      */,
    XHostAddress*                                       /* hosts                                                        */,
    int                                                 /* num_hosts                                                    */
);

extern int XAddToExtensionList(
    XExtData**                                          /* structure                                                    */,
    XExtData*                                           /* ext_data                                                     */
);

extern int XAddToSaveSet(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */
);

extern Status XAllocColor(
    Display*                                            /* display                                                      */,
    Colormap                                            /* colormap                                                     */,
    XColor*                                             /* screen_in_out                                                */
);

extern Status XAllocColorCells(
    Display*                                            /* display                                                      */,
    Colormap                                            /* colormap                                                     */,
    Bool                                                /* contig                                                       */,
    c_ulong*                                            /* plane_masks_return                                           */,
    uint                                                /* nplanes                                                      */,
    c_ulong*                                            /* pixels_return                                                */,
    uint                                                /* npixels                                                      */
);

extern Status XAllocColorPlanes(
    Display*                                            /* display                                                      */,
    Colormap                                            /* colormap                                                     */,
    Bool                                                /* contig                                                       */,
    c_ulong*                                            /* pixels_return                                                */,
    int                                                 /* ncolors                                                      */,
    int                                                 /* nreds                                                        */,
    int                                                 /* ngreens                                                      */,
    int                                                 /* nblues                                                       */,
    c_ulong*                                            /* rmask_return                                                 */,
    c_ulong*                                            /* gmask_return                                                 */,
    c_ulong*                                            /* bmask_return                                                 */
);

extern Status XAllocNamedColor(
    Display*                                            /* display                                                      */,
    Colormap                                            /* colormap                                                     */,
    char*                                               /* color_name                                                   */,
    XColor*                                             /* screen_def_return                                            */,
    XColor*                                             /* exact_def_return                                             */
);

extern int XAllowEvents(
    Display*                                            /* display                                                      */,
    int                                                 /* event_mode                                                   */,
    Time                                                /* time                                                         */
);

extern int XAutoRepeatOff(
    Display*                                            /* display                                                      */
);

extern int XAutoRepeatOn(
    Display*                                            /* display                                                      */
);

extern int XBell(
    Display*                                            /* display                                                      */,
    int                                                 /* percent                                                      */
);

extern int XBitmapBitOrder(
    Display*                                            /* display                                                      */
);

extern int XBitmapPad(
    Display*                                            /* display                                                      */
);

extern int XBitmapUnit(
    Display*                                            /* display                                                      */
);

extern int XCellsOfScreen(
    Screen*                                             /* screen                                                       */
);

extern int XChangeActivePointerGrab(
    Display*                                            /* display                                                      */,
    uint                                                /* event_mask                                                   */,
    Cursor                                              /* cursor                                                       */,
    Time                                                /* time                                                         */
);

extern int XChangeGC(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    c_ulong                                             /* valuemask                                                    */,
    XGCValues*                                          /* values                                                       */
);

extern int XChangeKeyboardControl(
    Display*                                            /* display                                                      */,
    c_ulong                                             /* value_mask                                                   */,
    XKeyboardControl*                                   /* values                                                       */
);

extern int XChangeKeyboardMapping(
    Display*                                            /* display                                                      */,
    int                                                 /* first_keycode                                                */,
    int                                                 /* keysyms_per_keycode                                          */,
    KeySym*                                             /* keysyms                                                      */,
    int                                                 /* num_codes                                                    */
);

extern int XChangePointerControl(
    Display*                                            /* display                                                      */,
    Bool                                                /* do_accel                                                     */,
    Bool                                                /* do_threshold                                                 */,
    int                                                 /* accel_numerator                                              */,
    int                                                 /* accel_denominator                                            */,
    int                                                 /* threshold                                                    */
);

extern int XChangeProperty(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Atom                                                /* property                                                     */,
    Atom                                                /* type                                                         */,
    int                                                 /* format                                                       */,
    int                                                 /* mode                                                         */,
    ubyte*                                              /* data                                                         */,
    int                                                 /* nelements                                                    */
);

extern int XChangeSaveSet(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    int                                                 /* change_mode                                                  */
);

extern int XChangeWindowAttributes(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    uint                                                /* valuemask                                                    */,
    XSetWindowAttributes*                               /* attributes                                                   */
);

extern Bool XCheckIfEvent(
    Display*                                            /* display                                                      */,
    XEvent*                                             /* event_return                                                 */,
    Bool function(
        Display*                                        /* display                                                      */,
        XEvent*                                         /* event                                                        */,
        XPointer                                        /* arg                                                          */
    )                                                   /* predicate                                                    */,
    XPointer                                            /* arg                                                          */
);

extern Bool XCheckMaskEvent(
    Display*                                            /* display                                                      */,
    c_long                                              /* event_mask                                                   */,
    XEvent*                                             /* event_return                                                 */
);

extern Bool XCheckTypedEvent(
    Display*                                            /* display                                                      */,
    int                                                 /* event_type                                                   */,
    XEvent*                                             /* event_return                                                 */
);

extern Bool XCheckTypedWindowEvent(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    int                                                 /* event_type                                                   */,
    XEvent*                                             /* event_return                                                 */
);

extern Bool XCheckWindowEvent(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    c_long                                              /* event_mask                                                   */,
    XEvent*                                             /* event_return                                                 */
);

extern int XCirculateSubwindows(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    int                                                 /* direction                                                    */
);

extern int XCirculateSubwindowsDown(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */
);

extern int XCirculateSubwindowsUp(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */
);

extern int XClearArea(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    Bool                                                /* exposures                                                    */
);

extern int XClearWindow(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */
);

extern int XCloseDisplay(
    Display*                                            /* display                                                      */
);

extern int XConfigureWindow(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    c_ulong                                             /* value_mask                                                   */,
    XWindowChanges*                                     /* values                                                       */
);

extern int XConnectionNumber(
    Display*                                            /* display                                                      */
);

extern int XConvertSelection(
    Display*                                            /* display                                                      */,
    Atom                                                /* selection                                                    */,
    Atom                                                /* target                                                       */,
    Atom                                                /* property                                                     */,
    Window                                              /* requestor                                                    */,
    Time                                                /* time                                                         */
);

extern int XCopyArea(
    Display*                                            /* display                                                      */,
    Drawable                                            /* src                                                          */,
    Drawable                                            /* dest                                                         */,
    GC                                                  /* gc                                                           */,
    int                                                 /* src_x                                                        */,
    int                                                 /* src_y                                                        */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    int                                                 /* dest_x                                                       */,
    int                                                 /* dest_y                                                       */
);

extern int XCopyGC(
    Display*                                            /* display                                                      */,
    GC                                                  /* src                                                          */,
    uint                                                /* valuemask                                                    */,
    GC                                                  /* dest                                                         */
);

extern int XCopyPlane(
    Display*                                            /* display                                                      */,
    Drawable                                            /* src                                                          */,
    Drawable                                            /* dest                                                         */,
    GC                                                  /* gc                                                           */,
    int                                                 /* src_x                                                        */,
    int                                                 /* src_y                                                        */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    int                                                 /* dest_x                                                       */,
    int                                                 /* dest_y                                                       */,
    c_ulong                                             /* plane                                                        */
);

extern int XDefaultDepth(
    Display*                                            /* display                                                      */,
    int                                                 /* screen_number                                                */
);

extern int XDefaultDepthOfScreen(
    Screen*                                             /* screen                                                       */
);

extern int XDefaultScreen(
    Display*                                            /* display                                                      */
);

extern int XDefineCursor(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Cursor                                              /* cursor                                                       */
);

extern int XDeleteProperty(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Atom                                                /* property                                                     */
);

extern int XDestroyWindow(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */
);

extern int XDestroySubwindows(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */
);

extern int XDoesBackingStore(
    Screen*                                             /* screen                                                       */
);

extern Bool XDoesSaveUnders(
    Screen*                                             /* screen                                                       */
);

extern int XDisableAccessControl(
    Display*                                            /* display                                                      */
);


extern int XDisplayCells(
    Display*                                            /* display                                                      */,
    int                                                 /* screen_number                                                */
);

extern int XDisplayHeight(
    Display*                                            /* display                                                      */,
    int                                                 /* screen_number                                                */
);

extern int XDisplayHeightMM(
    Display*                                            /* display                                                      */,
    int                                                 /* screen_number                                                */
);

extern int XDisplayKeycodes(
    Display*                                            /* display                                                      */,
    int*                                                /* min_keycodes_return                                          */,
    int*                                                /* max_keycodes_return                                          */
);

extern int XDisplayPlanes(
    Display*                                            /* display                                                      */,
    int                                                 /* screen_number                                                */
);

extern int XDisplayWidth(
    Display*                                            /* display                                                      */,
    int                                                 /* screen_number                                                */
);

extern int XDisplayWidthMM(
    Display*                                            /* display                                                      */,
    int                                                 /* screen_number                                                */
);

extern int XDrawArc(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    int                                                 /* angle1                                                       */,
    int                                                 /* angle2                                                       */
);

extern int XDrawArcs(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    XArc*                                               /* arcs                                                         */,
    int                                                 /* narcs                                                        */
);

extern int XDrawImageString(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    char*                                               /* string                                                       */,
    int                                                 /* length                                                       */
);

extern int XDrawImageString16(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    XChar2b*                                            /* string                                                       */,
    int                                                 /* length                                                       */
);

extern int XDrawLine(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x1                                                           */,
    int                                                 /* y1                                                           */,
    int                                                 /* x2                                                           */,
    int                                                 /* y2                                                           */
);

extern int XDrawLines(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    XPoint*                                             /* points                                                       */,
    int                                                 /* npoints                                                      */,
    int                                                 /* mode                                                         */
);

extern int XDrawPoint(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */
);

extern int XDrawPoints(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    XPoint*                                             /* points                                                       */,
    int                                                 /* npoints                                                      */,
    int                                                 /* mode                                                         */
);

extern int XDrawRectangle(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */
);

extern int XDrawRectangles(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    XRectangle*                                         /* rectangles                                                   */,
    int                                                 /* nrectangles                                                  */
);

extern int XDrawSegments(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    XSegment*                                           /* segments                                                     */,
    int                                                 /* nsegments                                                    */
);

extern int XDrawString(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    char*                                               /* string                                                       */,
    int                                                 /* length                                                       */
);

extern int XDrawString16(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    XChar2b*                                            /* string                                                       */,
    int                                                 /* length                                                       */
);

extern int XDrawText(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    XTextItem*                                          /* items                                                        */,
    int                                                 /* nitems                                                       */
);

extern int XDrawText16(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    XTextItem16*                                        /* items                                                        */,
    int                                                 /* nitems                                                       */
);

extern int XEnableAccessControl(
    Display*                                            /* display                                                      */
);

extern int XEventsQueued(
    Display*                                            /* display                                                      */,
    int                                                 /* mode                                                         */
);

extern Status XFetchName(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    char**                                              /* window_name_return                                           */
);

extern int XFillArc(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    int                                                 /* angle1                                                       */,
    int                                                 /* angle2                                                       */
);

extern int XFillArcs(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    XArc*                                               /* arcs                                                         */,
    int                                                 /* narcs                                                        */
);

extern int XFillPolygon(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    XPoint*                                             /* points                                                       */,
    int                                                 /* npoints                                                      */,
    int                                                 /* shape                                                        */,
    int                                                 /* mode                                                         */
);

extern int XFillRectangle(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */
);

extern int XFillRectangles(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    XRectangle*                                         /* rectangles                                                   */,
    int                                                 /* nrectangles                                                  */
);

extern int XFlush(
    Display*                                            /* display                                                      */
);

extern int XForceScreenSaver(
    Display*                                            /* display                                                      */,
    int                                                 /* mode                                                         */
);

extern int XFree(
    void*                                               /* data                                                         */
);

extern int XFreeColormap(
    Display*                                            /* display                                                      */,
    Colormap                                            /* colormap                                                     */
);

extern int XFreeColors(
    Display*                                            /* display                                                      */,
    Colormap                                            /* colormap                                                     */,
    c_ulong*                                            /* pixels                                                       */,
    int                                                 /* npixels                                                      */,
    c_ulong                                             /* planes                                                       */
);

extern int XFreeCursor(
    Display*                                            /* display                                                      */,
    Cursor                                              /* cursor                                                       */
);

extern int XFreeExtensionList(
    char**                                              /* list                                                         */
);

extern int XFreeFont(
    Display*                                            /* display                                                      */,
    XFontStruct*                                        /* font_struct                                                  */
);

extern int XFreeFontInfo(
    char**                                              /* names                                                        */,
    XFontStruct*                                        /* free_info                                                    */,
    int                                                 /* actual_count                                                 */
);

extern int XFreeFontNames(
    char**                                              /* list                                                         */
);

extern int XFreeFontPath(
    char**                                              /* list                                                         */
);

extern int XFreeGC(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */
);

extern int XFreeModifiermap(
    XModifierKeymap*                                    /* modmap                                                       */
);

extern int XFreePixmap(
    Display*                                            /* display                                                      */,
    Pixmap                                              /* pixmap                                                       */
);

extern int XGeometry(
    Display*                                            /* display                                                      */,
    int                                                 /* screen                                                       */,
    char*                                               /* position                                                     */,
    char*                                               /* default_position                                             */,
    uint                                                /* bwidth                                                       */,
    uint                                                /* fwidth                                                       */,
    uint                                                /* fheight                                                      */,
    int                                                 /* xadder                                                       */,
    int                                                 /* yadder                                                       */,
    int*                                                /* x_return                                                     */,
    int*                                                /* y_return                                                     */,
    int*                                                /* width_return                                                 */,
    int*                                                /* height_return                                                */
);

extern int XGetErrorDatabaseText(
    Display*                                            /* display                                                      */,
    char*                                               /* name                                                         */,
    char*                                               /* message                                                      */,
    char*                                               /* default_string                                               */,
    char*                                               /* buffer_return                                                */,
    int                                                 /* length                                                       */
);

extern int XGetErrorText(
    Display*                                            /* display                                                      */,
    int                                                 /* code                                                         */,
    char*                                               /* buffer_return                                                */,
    int                                                 /* length                                                       */
);

extern Bool XGetFontProperty(
    XFontStruct*                                        /* font_struct                                                  */,
    Atom                                                /* atom                                                         */,
    c_ulong*                                            /* value_return                                                 */
);

extern Status XGetGCValues(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    c_ulong                                             /* valuemask                                                    */,
    XGCValues*                                          /* values_return                                                */
);

extern Status XGetGeometry(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    Window*                                             /* root_return                                                  */,
    int*                                                /* x_return                                                     */,
    int*                                                /* y_return                                                     */,
    uint*                                               /* width_return                                                 */,
    uint*                                               /* height_return                                                */,
    uint*                                               /* border_width_return                                          */,
    uint*                                               /* depth_return                                                 */
);

extern Status XGetIconName(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    char**                                              /* icon_name_return                                             */
);

extern int XGetInputFocus(
    Display*                                            /* display                                                      */,
    Window*                                             /* focus_return                                                 */,
    int*                                                /* revert_to_return                                             */
);

extern int XGetKeyboardControl(
    Display*                                            /* display                                                      */,
    XKeyboardState*                                     /* values_return                                                */
);

extern int XGetPointerControl(
    Display*                                            /* display                                                      */,
    int*                                                /* accel_numerator_return                                       */,
    int*                                                /* accel_denominator_return                                     */,
    int*                                                /* threshold_return                                             */
);

extern int XGetPointerMapping(
    Display*                                            /* display                                                      */,
    ubyte*                                          /* map_return                                                   */,
    int                                                 /* nmap                                                         */
);

extern int XGetScreenSaver(
    Display*                                            /* display                                                      */,
    int*                                                /* timeout_return                                               */,
    int*                                                /* interval_return                                              */,
    int*                                                /* prefer_blanking_return                                       */,
    int*                                                /* allow_exposures_return                                       */
);

extern Status XGetTransientForHint(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Window*                                             /* prop_window_return                                           */
);

extern int XGetWindowProperty(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Atom                                                /* property                                                     */,
    c_long                                              /* c_long_offset                                                  */,
    c_long                                              /* c_long_length                                                  */,
    Bool                                                /* delete                                                       */,
    Atom                                                /* req_type                                                     */,
    Atom*                                               /* actual_type_return                                           */,
    int*                                                /* actual_format_return                                         */,
    c_ulong*                                            /* nitems_return                                                */,
    c_ulong*                                            /* chars_after_return                                           */,
    ubyte**                                             /* prop_return                                                  */
);

extern Status XGetWindowAttributes(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    XWindowAttributes*                                  /* window_attributes_return                                     */
);

extern int XGrabButton(
    Display*                                            /* display                                                      */,
    uint                                                /* button                                                       */,
    uint                                                /* modifiers                                                    */,
    Window                                              /* grab_window                                                  */,
    Bool                                                /* owner_events                                                 */,
    uint                                                /* event_mask                                                   */,
    int                                                 /* pointer_mode                                                 */,
    int                                                 /* keyboard_mode                                                */,
    Window                                              /* confine_to                                                   */,
    Cursor                                              /* cursor                                                       */
);

extern int XGrabKey(
    Display*                                            /* display                                                      */,
    int                                                 /* keycode                                                      */,
    uint                                                /* modifiers                                                    */,
    Window                                              /* grab_window                                                  */,
    Bool                                                /* owner_events                                                 */,
    int                                                 /* pointer_mode                                                 */,
    int                                                 /* keyboard_mode                                                */
);

extern int XGrabKeyboard(
    Display*                                            /* display                                                      */,
    Window                                              /* grab_window                                                  */,
    Bool                                                /* owner_events                                                 */,
    int                                                 /* pointer_mode                                                 */,
    int                                                 /* keyboard_mode                                                */,
    Time                                                /* time                                                         */
);

extern int XGrabPointer(
    Display*                                            /* display                                                      */,
    Window                                              /* grab_window                                                  */,
    Bool                                                /* owner_events                                                 */,
    uint                                                /* event_mask                                                   */,
    int                                                 /* pointer_mode                                                 */,
    int                                                 /* keyboard_mode                                                */,
    Window                                              /* confine_to                                                   */,
    Cursor                                              /* cursor                                                       */,
    Time                                                /* time                                                         */
);

extern int XGrabServer(
    Display*                                            /* display                                                      */
);

extern int XHeightMMOfScreen(
    Screen*                                             /* screen                                                       */
);

extern int XHeightOfScreen(
    Screen*                                             /* screen                                                       */
);

extern int XIfEvent(
    Display*                                            /* display                                                      */,
    XEvent*                                             /* event_return                                                 */,
    Bool function(
        Display*                                        /* display                                                      */,
        XEvent*                                         /* event                                                        */,
        XPointer                                        /* arg                                                          */
    )                                                   /* predicate                                                    */,
    XPointer                                            /* arg                                                          */
);

extern int XImagecharOrder(
    Display*                                            /* display                                                      */
);

extern int XInstallColormap(
    Display*                                            /* display                                                      */,
    Colormap                                            /* colormap                                                     */
);

extern KeyCode XKeysymToKeycode(
    Display*                                            /* display                                                      */,
    KeySym                                              /* keysym                                                       */
);

extern int XKillClient(
    Display*                                            /* display                                                      */,
    XID                                                 /* resource                                                     */
);

extern Status XLookupColor(
    Display*                                            /* display                                                      */,
    Colormap                                            /* colormap                                                     */,
    char*                                               /* color_name                                                   */,
    XColor*                                             /* exact_def_return                                             */,
    XColor*                                             /* screen_def_return                                            */
);

extern int XLowerWindow(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */
);

extern int XMapRaised(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */
);

extern int XMapSubwindows(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */
);

extern int XMapWindow(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */
);

extern int XMaskEvent(
    Display*                                            /* display                                                      */,
    c_long                                              /* event_mask                                                   */,
    XEvent*                                             /* event_return                                                 */
);

extern int XMaxCmapsOfScreen(
    Screen*                                             /* screen                                                       */
);

extern int XMinCmapsOfScreen(
    Screen*                                             /* screen                                                       */
);

extern int XMoveResizeWindow(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */
);

extern int XMoveWindow(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */
);

extern int XNextEvent(
    Display*                                            /* display                                                      */,
    XEvent*                                             /* event_return                                                 */
);

extern int XNoOp(
    Display*                                            /* display                                                      */
);

extern Status XParseColor(
    Display*                                            /* display                                                      */,
    Colormap                                            /* colormap                                                     */,
    char*                                               /* spec                                                         */,
    XColor*                                             /* exact_def_return                                             */
);

extern int XParseGeometry(
    char*                                               /* parsestring                                                  */,
    int*                                                /* x_return                                                     */,
    int*                                                /* y_return                                                     */,
    uint*                                               /* width_return                                                 */,
    uint*                                               /* height_return                                                */
);

extern int XPeekEvent(
    Display*                                            /* display                                                      */,
    XEvent*                                             /* event_return                                                 */
);

extern int XPeekIfEvent(
    Display*                                            /* display                                                      */,
    XEvent*                                             /* event_return                                                 */,
    Bool function(
        Display*                                        /* display                                                      */,
        XEvent*                                         /* event                                                        */,
        XPointer                                        /* arg                                                          */
    )                                                   /* predicate                                                    */,
    XPointer                                            /* arg                                                          */
);

extern int XPending(
    Display*                                            /* display                                                      */
);

extern int XPlanesOfScreen(
    Screen*                                             /* screen                                                       */
);

extern int XProtocolRevision(
    Display*                                            /* display                                                      */
);

extern int XProtocolVersion(
    Display*                                            /* display                                                      */
);


extern int XPutBackEvent(
    Display*                                            /* display                                                      */,
    XEvent*                                             /* event                                                        */
);

extern int XPutImage(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    XImage*                                             /* image                                                        */,
    int                                                 /* src_x                                                        */,
    int                                                 /* src_y                                                        */,
    int                                                 /* dest_x                                                       */,
    int                                                 /* dest_y                                                       */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */
);

extern int XQLength(
    Display*                                            /* display                                                      */
);

extern Status XQueryBestCursor(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    uint*                                               /* width_return                                                 */,
    uint*                                               /* height_return                                                */
);

extern Status XQueryBestSize(
    Display*                                            /* display                                                      */,
    int                                                 /* class                                                        */,
    Drawable                                            /* which_screen                                                 */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    uint*                                               /* width_return                                                 */,
    uint*                                               /* height_return                                                */
);

extern Status XQueryBestStipple(
    Display*                                            /* display                                                      */,
    Drawable                                            /* which_screen                                                 */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    uint*                                               /* width_return                                                 */,
    uint*                                               /* height_return                                                */
);

extern Status XQueryBestTile(
    Display*                                            /* display                                                      */,
    Drawable                                            /* which_screen                                                 */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    uint*                                               /* width_return                                                 */,
    uint*                                               /* height_return                                                */
);

extern int XQueryColor(
    Display*                                            /* display                                                      */,
    Colormap                                            /* colormap                                                     */,
    XColor*                                             /* def_in_out                                                   */
);

extern int XQueryColors(
    Display*                                            /* display                                                      */,
    Colormap                                            /* colormap                                                     */,
    XColor*                                             /* defs_in_out                                                  */,
    int                                                 /* ncolors                                                      */
);

extern Bool XQueryExtension(
    Display*                                            /* display                                                      */,
    char*                                               /* name                                                         */,
    int*                                                /* major_opcode_return                                          */,
    int*                                                /* first_event_return                                           */,
    int*                                                /* first_error_return                                           */
);

extern int XQueryKeymap(
    Display*                                            /* display                                                      */,
    char [32]                                           /* keys_return                                                  */
);

extern Bool XQueryPointer(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Window*                                             /* root_return                                                  */,
    Window*                                             /* child_return                                                 */,
    int*                                                /* root_x_return                                                */,
    int*                                                /* root_y_return                                                */,
    int*                                                /* win_x_return                                                 */,
    int*                                                /* win_y_return                                                 */,
    uint*                                               /* mask_return                                                  */
);

extern int XQueryTextExtents(
    Display*                                            /* display                                                      */,
    XID                                                 /* font_ID                                                      */,
    char*                                               /* string                                                       */,
    int                                                 /* nchars                                                       */,
    int*                                                /* direction_return                                             */,
    int*                                                /* font_ascent_return                                           */,
    int*                                                /* font_descent_return                                          */,
    XCharStruct*                                        /* overall_return                                               */
);

extern int XQueryTextExtents16(
    Display*                                            /* display                                                      */,
    XID                                                 /* font_ID                                                      */,
    XChar2b*                                            /* string                                                       */,
    int                                                 /* nchars                                                       */,
    int*                                                /* direction_return                                             */,
    int*                                                /* font_ascent_return                                           */,
    int*                                                /* font_descent_return                                          */,
    XCharStruct*                                        /* overall_return                                               */
);

extern Status XQueryTree(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Window*                                             /* root_return                                                  */,
    Window*                                             /* parent_return                                                */,
    Window**                                            /* children_return                                              */,
    uint*                                               /* nchildren_return                                             */
);

extern int XRaiseWindow(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */
);

extern int XReadBitmapFile(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    ubyte*                                              /* filename                                                     */,
    uint*                                               /* width_return                                                 */,
    uint*                                               /* height_return                                                */,
    Pixmap*                                             /* bitmap_return                                                */,
    int*                                                /* x_hot_return                                                 */,
    int*                                                /* y_hot_return                                                 */
);

extern int XReadBitmapFileData(
    char*                                               /* filename                                                     */,
    uint*                                               /* width_return                                                 */,
    uint*                                               /* height_return                                                */,
    ubyte**                                             /* data_return                                                  */,
    int*                                                /* x_hot_return                                                 */,
    int*                                                /* y_hot_return                                                 */
);

extern int XRebindKeysym(
    Display*                                            /* display                                                      */,
    KeySym                                              /* keysym                                                       */,
    KeySym*                                             /* list                                                         */,
    int                                                 /* mod_count                                                    */,
    ubyte*                                              /* string                                                       */,
    int                                                 /* chars_string                                                 */
);

extern int XRecolorCursor(
    Display*                                            /* display                                                      */,
    Cursor                                              /* cursor                                                       */,
    XColor*                                             /* foreground_color                                             */,
    XColor*                                             /* background_color                                             */
);

extern int XRefreshKeyboardMapping(
    XMappingEvent*                                      /* event_map                                                    */
);

extern int XRemoveFromSaveSet(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */
);

extern int XRemoveHost(
    Display*                                            /* display                                                      */,
    XHostAddress*                                       /* host                                                         */
);

extern int XRemoveHosts(
    Display*                                            /* display                                                      */,
    XHostAddress*                                       /* hosts                                                        */,
    int                                                 /* num_hosts                                                    */
);

extern int XReparentWindow(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Window                                              /* parent                                                       */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */
);

extern int XResetScreenSaver(
    Display*                                            /* display                                                      */
);

extern int XResizeWindow(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */
);

extern int XRestackWindows(
    Display*                                            /* display                                                      */,
    Window*                                             /* windows                                                      */,
    int                                                 /* nwindows                                                     */
);

extern int XRotateBuffers(
    Display*                                            /* display                                                      */,
    int                                                 /* rotate                                                       */
);

extern int XRotateWindowProperties(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Atom*                                               /* properties                                                   */,
    int                                                 /* num_prop                                                     */,
    int                                                 /* npositions                                                   */
);

extern int XScreenCount(
    Display*                                            /* display                                                      */
);

extern int XSelectInput(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    c_long                                              /* event_mask                                                   */
);

extern Status XSendEvent(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Bool                                                /* propagate                                                    */,
    c_long                                              /* event_mask                                                   */,
    XEvent*                                             /* event_send                                                   */
);

extern int XSetAccessControl(
    Display*                                            /* display                                                      */,
    int                                                 /* mode                                                         */
);

extern int XSetArcMode(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    int                                                 /* arc_mode                                                     */
);

extern int XSetBackground(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    c_ulong                                             /* background                                                   */
);

extern int XSetClipMask(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    Pixmap                                              /* pixmap                                                       */
);

extern int XSetClipOrigin(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    int                                                 /* clip_x_origin                                                */,
    int                                                 /* clip_y_origin                                                */
);

extern int XSetClipRectangles(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    int                                                 /* clip_x_origin                                                */,
    int                                                 /* clip_y_origin                                                */,
    XRectangle*                                         /* rectangles                                                   */,
    int                                                 /* n                                                            */,
    int                                                 /* ordering                                                     */
);

extern int XSetCloseDownMode(
    Display*                                            /* display                                                      */,
    int                                                 /* close_mode                                                   */
);

extern int XSetCommand(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    char**                                              /* argv                                                         */,
    int                                                 /* argc                                                         */
);

extern int XSetDashes(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    int                                                 /* dash_offset                                                  */,
    char*                                               /* dash_list                                                    */,
    int                                                 /* n                                                            */
);

extern int XSetFillRule(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    int                                                 /* fill_rule                                                    */
);

extern int XSetFillStyle(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    int                                                 /* fill_style                                                   */
);

extern int XSetFont(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    Font                                                /* font                                                         */
);

extern int XSetFontPath(
    Display*                                            /* display                                                      */,
    char**                                              /* directories                                                  */,
    int                                                 /* ndirs                                                        */
);

extern int XSetForeground(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    c_ulong                                             /* foreground                                                   */
);

extern int XSetFunction(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    int                                                 /* function                                                     */
);

extern int XSetGraphicsExposures(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    Bool                                                /* graphics_exposures                                           */
);

extern int XSetIconName(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    char*                                               /* icon_name                                                    */
);

extern int XSetInputFocus(
    Display*                                            /* display                                                      */,
    Window                                              /* focus                                                        */,
    int                                                 /* revert_to                                                    */,
    Time                                                /* time                                                         */
);

extern int XSetLineAttributes(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    uint                                                /* line_width                                                   */,
    int                                                 /* line_style                                                   */,
    int                                                 /* cap_style                                                    */,
    int                                                 /* join_style                                                   */
);

extern int XSetModifierMapping(
    Display*                                            /* display                                                      */,
    XModifierKeymap*                                    /* modmap                                                       */
);

extern int XSetPlaneMask(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    c_ulong                                             /* plane_mask                                                   */
);

extern int XSetPointerMapping(
    Display*                                            /* display                                                      */,
    ubyte*                                              /* map                                                          */,
    int                                                 /* nmap                                                         */
);

extern int XSetScreenSaver(
    Display*                                            /* display                                                      */,
    int                                                 /* timeout                                                      */,
    int                                                 /* interval                                                     */,
    int                                                 /* prefer_blanking                                              */,
    int                                                 /* allow_exposures                                              */
);

extern int XSetSelectionOwner(
    Display*                                            /* display                                                      */,
    Atom                                                /* selection                                                    */,
    Window                                              /* owner                                                        */,
    Time                                                /* time                                                         */
);

extern int XSetState(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    c_ulong                                             /* foreground                                                   */,
    c_ulong                                             /* background                                                   */,
    int                                                 /* function                                                     */,
    c_ulong                                             /* plane_mask                                                   */
);

extern int XSetStipple(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    Pixmap                                              /* stipple                                                      */
);

extern int XSetSubwindowMode(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    int                                                 /* subwindow_mode                                               */
);

extern int XSetTSOrigin(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    int                                                 /* ts_x_origin                                                  */,
    int                                                 /* ts_y_origin                                                  */
);

extern int XSetTile(
    Display*                                            /* display                                                      */,
    GC                                                  /* gc                                                           */,
    Pixmap                                              /* tile                                                         */
);

extern int XSetWindowBackground(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    c_ulong                                             /* background_pixel                                             */
);

extern int XSetWindowBackgroundPixmap(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Pixmap                                              /* background_pixmap                                            */
);

extern int XSetWindowBorder(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    c_ulong                                             /* border_pixel                                                 */
);

extern int XSetWindowBorderPixmap(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Pixmap                                              /* border_pixmap                                                */
);

extern int XSetWindowBorderWidth(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    uint                                                /* width                                                        */
);

extern int XSetWindowColormap(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    Colormap                                            /* colormap                                                     */
);

extern int XStoreBuffer(
    Display*                                            /* display                                                      */,
    char*                                               /* chars                                                        */,
    int                                                 /* nchars                                                       */,
    int                                                 /* buffer                                                       */
);

extern int XStorechars(
    Display*                                            /* display                                                      */,
    char*                                               /* chars                                                        */,
    int                                                 /* nchars                                                       */
);

extern int XStoreColor(
    Display*                                            /* display                                                      */,
    Colormap                                            /* colormap                                                     */,
    XColor*                                             /* color                                                        */
);

extern int XStoreColors(
    Display*                                            /* display                                                      */,
    Colormap                                            /* colormap                                                     */,
    XColor*                                             /* color                                                        */,
    int                                                 /* ncolors                                                      */
);

extern int XStoreName(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    char*                                               /* window_name                                                  */
);

extern int XStoreNamedColor(
    Display*                                            /* display                                                      */,
    Colormap                                            /* colormap                                                     */,
    char*                                               /* color                                                        */,
    c_ulong                                             /* pixel                                                        */,
    int                                                 /* flags                                                        */
);

extern int XSync(
    Display*                                            /* display                                                      */,
    Bool                                                /* discard                                                      */
);

extern int XTextExtents(
    XFontStruct*                                        /* font_struct                                                  */,
    char*                                               /* string                                                       */,
    int                                                 /* nchars                                                       */,
    int*                                                /* direction_return                                             */,
    int*                                                /* font_ascent_return                                           */,
    int*                                                /* font_descent_return                                          */,
    XCharStruct*                                        /* overall_return                                               */
);

extern int XTextExtents16(
    XFontStruct*                                        /* font_struct                                                  */,
    XChar2b*                                            /* string                                                       */,
    int                                                 /* nchars                                                       */,
    int*                                                /* direction_return                                             */,
    int*                                                /* font_ascent_return                                           */,
    int*                                                /* font_descent_return                                          */,
    XCharStruct*                                        /* overall_return                                               */
);

extern int XTextWidth(
    XFontStruct*                                        /* font_struct                                                  */,
    char*                                               /* string                                                       */,
    int                                                 /* count                                                        */
);

extern int XTextWidth16(
    XFontStruct*                                        /* font_struct                                                  */,
    XChar2b*                                            /* string                                                       */,
    int                                                 /* count                                                        */
);

extern Bool XTranslateCoordinates(
    Display*                                            /* display                                                      */,
    Window                                              /* src_w                                                        */,
    Window                                              /* dest_w                                                       */,
    int                                                 /* src_x                                                        */,
    int                                                 /* src_y                                                        */,
    int*                                                /* dest_x_return                                                */,
    int*                                                /* dest_y_return                                                */,
    Window*                                             /* child_return                                                 */
);

extern int XUndefineCursor(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */
);

extern int XUngrabButton(
    Display*                                            /* display                                                      */,
    uint                                                /* button                                                       */,
    uint                                                /* modifiers                                                    */,
    Window                                              /* grab_window                                                  */
);

extern int XUngrabKey(
    Display*                                            /* display                                                      */,
    int                                                 /* keycode                                                      */,
    uint                                                /* modifiers                                                    */,
    Window                                              /* grab_window                                                  */
);

extern int XUngrabKeyboard(
    Display*                                            /* display                                                      */,
    Time                                                /* time                                                         */
);

extern int XUngrabPointer(
    Display*                                            /* display                                                      */,
    Time                                                /* time                                                         */
);

extern int XUngrabServer(
    Display*                                            /* display                                                      */
);

extern int XUninstallColormap(
    Display*                                            /* display                                                      */,
    Colormap                                            /* colormap                                                     */
);

extern int XUnloadFont(
    Display*                                            /* display                                                      */,
    Font                                                /* font                                                         */
);

extern int XUnmapSubwindows(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */
);

extern int XUnmapWindow(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */
);

extern int XVendorRelease(
    Display*                                            /* display                                                      */
);

extern int XWarpPointer(
    Display*                                            /* display                                                      */,
    Window                                              /* src_w                                                        */,
    Window                                              /* dest_w                                                       */,
    int                                                 /* src_x                                                        */,
    int                                                 /* src_y                                                        */,
    uint                                                /* src_width                                                    */,
    uint                                                /* src_height                                                   */,
    int                                                 /* dest_x                                                       */,
    int                                                 /* dest_y                                                       */
);

extern int XWidthMMOfScreen(
    Screen*                                             /* screen                                                       */
);

extern int XWidthOfScreen(
    Screen*                                             /* screen                                                       */
);

extern int XWindowEvent(
    Display*                                            /* display                                                      */,
    Window                                              /* w                                                            */,
    c_long                                              /* event_mask                                                   */,
    XEvent*                                             /* event_return                                                 */
);

extern int XWriteBitmapFile(
    Display*                                            /* display                                                      */,
    char*                                               /* filename                                                     */,
    Pixmap                                              /* bitmap                                                       */,
    uint                                                /* width                                                        */,
    uint                                                /* height                                                       */,
    int                                                 /* x_hot                                                        */,
    int                                                 /* y_hot                                                        */
);

extern Bool XSupportsLocale ( );

extern char* XSetLocaleModifiers(
    const char*                                         /* modifier_list                                                */
);

extern XOM XOpenOM(
    Display*                                            /* display                                                      */,
    _XrmHashBucketRec*                                  /* rdb                                                          */,
    char*                                               /* res_name                                                     */,
    char*                                               /* res_class                                                    */
);

extern Status XCloseOM(
    XOM                                                 /* om                                                           */
);

extern char* XSetOMValues(
    XOM                                                 /* om                                                           */,
    ...
);

extern char* XGetOMValues(
    XOM                                                 /* om                                                           */,
    ...
);

extern Display* XDisplayOfOM(
    XOM                                                 /* om                                                           */
);

extern char* XLocaleOfOM(

    XOM                                                 /* om                                                           */
);

extern XOC XCreateOC(
    XOM                                                 /* om                                                           */,
    ...
);

extern void XDestroyOC(
    XOC                                                 /* oc                                                           */
);

extern XOM XOMOfOC(
    XOC                                                 /* oc                                                           */
);

extern char* XSetOCValues(
    XOC                                                 /* oc                                                           */,
    ...
);

extern char* XGetOCValues(
    XOC                                                 /* oc                                                           */,
    ...
);

extern XFontSet XCreateFontSet(
    Display*                                            /* display                                                      */,
    char*                                               /* base_font_name_list                                          */,
    char***                                             /* missing_charset_list                                         */,
    int*                                                /* missing_charset_count                                        */,
    char**                                              /* def_string                                                   */
);

extern void XFreeFontSet(
    Display*                                            /* display                                                      */,
    XFontSet                                            /* font_set                                                     */
);

extern int XFontsOfFontSet(
    XFontSet                                            /* font_set                                                     */,
    XFontStruct***                                      /* font_struct_list                                             */,
    char***                                             /* font_name_list                                               */
);

extern char* XBaseFontNameListOfFontSet(
    char                                                /* font_set                                                     */
);

extern char* XLocaleOfFontSet(
    XFontSet                                            /* font_set                                                     */
);

extern Bool XContextDependentDrawing(
    XFontSet                                            /* font_set                                                     */
);

extern Bool XDirectionalDependentDrawing(
    XFontSet                                            /* font_set                                                     */
);

extern Bool XContextualDrawing(
    XFontSet                                            /* font_set                                                     */
);

extern XFontSetExtents* XExtentsOfFontSet(
    XFontSet                                            /* font_set                                                     */
);

extern int XmbTextEscapement(
    XFontSet                                            /* font_set                                                     */,
    char*                                               /* text                                                         */,
    int                                                 /* chars_text                                                   */
);

extern int XwcTextEscapement(
    XFontSet                                            /* font_set                                                     */,
    wchar*                                              /* text                                                         */,
    int                                                 /* num_wchars                                                   */
);

extern int Xutf8TextEscapement(
    XFontSet                                            /* font_set                                                     */,
    char*                                               /* text                                                         */,
    int                                                 /* chars_text                                                   */
);

extern int XmbTextExtents(
    XFontSet                                            /* font_set                                                     */,
    char*                                               /* text                                                         */,
    int                                                 /* chars_text                                                   */,
    XRectangle*                                         /* overall_ink_return                                           */,
    XRectangle*                                         /* overall_logical_return                                       */
);

extern int XwcTextExtents(
    XFontSet                                            /* font_set                                                     */,
    wchar*                                              /* text                                                         */,
    int                                                 /* num_wchars                                                   */,
    XRectangle*                                         /* overall_ink_return                                           */,
    XRectangle*                                         /* overall_logical_return                                       */
);

extern int Xutf8TextExtents(
    XFontSet                                            /* font_set                                                     */,
    char*                                               /* text                                                         */,
    int                                                 /* chars_text                                                   */,
    XRectangle*                                         /* overall_ink_return                                           */,
    XRectangle*                                         /* overall_logical_return                                       */
);

extern Status XmbTextPerCharExtents(
    XFontSet                                            /* font_set                                                     */,
    char*                                               /* text                                                         */,
    int                                                 /* chars_text                                                   */,
    XRectangle*                                         /* ink_extents_buffer                                           */,
    XRectangle*                                         /* logical_extents_buffer                                       */,
    int                                                 /* buffer_size                                                  */,
    int*                                                /* num_chars                                                    */,
    XRectangle*                                         /* overall_ink_return                                           */,
    XRectangle*                                         /* overall_logical_return                                       */
);

extern Status XwcTextPerCharExtents(
    XFontSet                                            /* font_set                                                     */,
    wchar*                                              /* text                                                         */,
    int                                                 /* num_wchars                                                   */,
    XRectangle*                                         /* ink_extents_buffer                                           */,
    XRectangle*                                         /* logical_extents_buffer                                       */,
    int                                                 /* buffer_size                                                  */,
    int*                                                /* num_chars                                                    */,
    XRectangle*                                         /* overall_ink_return                                           */,
    XRectangle*                                         /* overall_logical_return                                       */
);

extern Status Xutf8TextPerCharExtents(
    XFontSet                                            /* font_set                                                     */,
    char*                                               /* text                                                         */,
    int                                                 /* chars_text                                                   */,
    XRectangle*                                         /* ink_extents_buffer                                           */,
    XRectangle*                                         /* logical_extents_buffer                                       */,
    int                                                 /* buffer_size                                                  */,
    int*                                                /* num_chars                                                    */,
    XRectangle*                                         /* overall_ink_return                                           */,
    XRectangle*                                         /* overall_logical_return                                       */
);

extern void XmbDrawText(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    XmbTextItem*                                        /* text_items                                                   */,
    int                                                 /* nitems                                                       */
);

extern void XwcDrawText(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    XwcTextItem*                                        /* text_items                                                   */,
    int                                                 /* nitems                                                       */
);

extern void Xutf8DrawText(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    XmbTextItem*                                        /* text_items                                                   */,
    int                                                 /* nitems                                                       */
);

extern void XmbDrawString(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    XFontSet                                            /* font_set                                                     */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    char*                                       /* text                                                         */,
    int                                                 /* chars_text                                                   */
);

extern void XwcDrawString(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    XFontSet                                            /* font_set                                                     */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    wchar*                                              /* text                                                         */,
    int                                                 /* num_wchars                                                   */
);

extern void Xutf8DrawString(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    XFontSet                                            /* font_set                                                     */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    char*                                               /* text                                                         */,
    int                                                 /* chars_text                                                   */
);

extern void XmbDrawImageString(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    XFontSet                                            /* font_set                                                     */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    char*                                               /* text                                                         */,
    int                                                 /* chars_text                                                   */
);

extern void XwcDrawImageString(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    XFontSet                                            /* font_set                                                     */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    wchar*                                              /* text                                                         */,
    int                                                 /* num_wchars                                                   */
);

extern void Xutf8DrawImageString(
    Display*                                            /* display                                                      */,
    Drawable                                            /* d                                                            */,
    XFontSet                                            /* font_set                                                     */,
    GC                                                  /* gc                                                           */,
    int                                                 /* x                                                            */,
    int                                                 /* y                                                            */,
    char*                                               /* text                                                         */,
    int                                                 /* chars_text                                                   */
);

extern XIM XOpenIM(
    Display*                                            /* dpy                                                          */,
    _XrmHashBucketRec*                                  /* rdb                                                          */,
    char*                                               /* res_name                                                     */,
    char*                                               /* res_class                                                    */
);

extern Status XCloseIM(
    XIM                                                 /* im                                                           */
);

extern char* XGetIMValues(
    XIM                                                 /* im                                                           */,
	...
);

extern char* XSetIMValues(
    XIM                                                 /* im                                                           */,
	...
);

extern Display* XDisplayOfIM(
    XIM                                                 /* im                                                           */
);

extern char* XLocaleOfIM(
    XIM                                                 /* im                                                           */
);

extern XIC XCreateIC(
    XIM,                                                 /* im                                                           */
	...
);

extern void XDestroyIC(
    XIC                                                 /* ic                                                           */
);

extern void XSetICFocus(
    XIC                                                 /* ic                                                           */
);

extern void XUnsetICFocus(
    XIC                                                 /* ic                                                           */
);

extern wchar*   XwcResetIC(
    XIC                                                 /* ic                                                           */
);

extern char* XmbResetIC(
    XIC                                                 /* ic                                                           */
);

extern char* Xutf8ResetIC(
    XIC                                                 /* ic                                                           */
);

extern char* XSetICValues(
    XIC                                                 /* ic                                                           */,
	...
);

extern char* XGetICValues(
    XIC                                                 /* ic                                                           */,
	...
);

extern XIM XIMOfIC(
    XIC                                                 /* ic                                                           */
);

extern Bool XFilterEvent(
    XEvent*                                             /* event                                                        */,
    Window                                              /* window                                                       */
);

extern int XmbLookupString(
    XIC                                                 /* ic                                                           */,
    XKeyPressedEvent*                                   /* event                                                        */,
    char*                                               /* buffer_return                                                */,
    int                                                 /* chars_buffer                                                 */,
    KeySym*                                             /* keysym_return                                                */,
    Status*                                             /* status_return                                                */
);

extern int XwcLookupString(
    XIC                                                 /* ic                                                           */,
    XKeyPressedEvent*                                   /* event                                                        */,
    wchar*                                              /* buffer_return                                                */,
    int                                                 /* wchars_buffer                                                */,
    KeySym*                                             /* keysym_return                                                */,
    Status*                                             /* status_return                                                */
);

extern int Xutf8LookupString(
    XIC                                                 /* ic                                                           */,
    XKeyPressedEvent*                                   /* event                                                        */,
    char*                                               /* buffer_return                                                */,
    int                                                 /* chars_buffer                                                 */,
    KeySym*                                             /* keysym_return                                                */,
    Status*                                             /* status_return                                                */
);

extern XVaNestedList XVaCreateNestedList(
    int                                                 /*unused                                                        */,
	... 
);
                                                        /* internal connections for IMs                                 */

extern Bool XRegisterIMInstantiateCallback(
    Display*                                            /* dpy                                                          */,
    _XrmHashBucketRec*                                  /* rdb                                                          */,
    char*                                               /* res_name                                                     */,
    char*                                               /* res_class                                                    */,
    XIDProc                                             /* callback                                                     */,
    XPointer                                            /* client_data                                                  */
);

extern Bool XUnregisterIMInstantiateCallback(
    Display*                                            /* dpy                                                          */,
    _XrmHashBucketRec*                                  /* rdb                                                          */,
    char*                                               /* res_name                                                     */,
    char*                                               /* res_class                                                    */,
    XIDProc                                             /* callback                                                     */,
    XPointer                                            /* client_data                                                  */
);

alias void function(
    Display*                                            /* dpy                                                          */,
    XPointer                                            /* client_data                                                  */,
    int                                                 /* fd                                                           */,
    Bool                                                /* opening, open or close flag                                  */,
    XPointer*                                           /* watch_data, open sets, close uses                            */
) XConnectionWatchProc;


extern Status XInternalConnectionNumbers(
    Display*                                            /* dpy                                                          */,
    int**                                               /* fd_return                                                    */,
    int*                                                /* count_return                                                 */
);

extern void XProcessInternalConnection(
    Display*                                            /* dpy                                                          */,
    int                                                 /* fd                                                           */
);

extern Status XAddConnectionWatch(
    Display*                                            /* dpy                                                          */,
    XConnectionWatchProc                                /* callback                                                     */,
    XPointer                                            /* client_data                                                  */
);

extern void XRemoveConnectionWatch(
    Display*                                            /* dpy                                                          */,
    XConnectionWatchProc                                /* callback                                                     */,
    XPointer                                            /* client_data                                                  */
);

extern void XSetAuthorization(
    char*                                               /* name                                                         */,
    int                                                 /* namelen                                                      */,
    char*                                               /* data                                                         */,
    int                                                 /* datalen                                                      */
);

extern int _Xmbtowc(
    wchar*                                              /* wstr                                                         */,
    char*                                               /* str                                                          */,
    int                                                 /* len                                                          */
);

extern int _Xwctomb(
    char*                                               /* str                                                          */,
    wchar                                               /* wc                                                           */
);

extern Bool XGetEventData(
    Display*                                            /* dpy                                                          */,
    XGenericEventCookie*                                /* cookie                                                       */
);

extern void XFreeEventData(
    Display*                                            /* dpy                                                          */,
    XGenericEventCookie*                                /* cookie                                                       */
);