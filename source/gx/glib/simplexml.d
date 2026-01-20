/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.glib.simplexml;

import glib.c.types : GMarkupParser, GMarkupParseContext, GMarkupParseFlags, GError, GDestroyNotify;
import glib.c.functions : g_markup_parse_context_new, g_markup_parse_context_free,
                          g_markup_parse_context_parse, g_markup_parse_context_end_parse,
                          g_error_free;

/**
 * Simple wrapper around GLib's markup parser (GMarkupParseContext).
 * This provides a D-friendly interface to parse XML/markup content.
 */
class SimpleXML {
private:
    GMarkupParseContext* context;

public:
    /**
     * Creates a new SimpleXML parser.
     *
     * Params:
     *   parser = Pointer to a GMarkupParser struct with callback functions
     *   flags = GMarkupParseFlags to control parsing behavior
     *   userData = User data to pass to callback functions
     *   userDataDnotify = Optional destroy notify function (can be null)
     */
    this(const(GMarkupParser)* parser, GMarkupParseFlags flags, void* userData, GDestroyNotify userDataDnotify) {
        context = g_markup_parse_context_new(parser, flags, userData, userDataDnotify);
        if (context is null) {
            throw new Exception("Failed to create GMarkupParseContext");
        }
    }

    ~this() {
        if (context !is null) {
            g_markup_parse_context_free(context);
            context = null;
        }
    }

    /**
     * Parse the given markup text.
     *
     * Params:
     *   text = The markup text to parse
     *   textLen = Length of the text (use text.length for D strings)
     *
     * Throws: Exception if parsing fails
     */
    void parse(string text, size_t textLen) {
        GError* error = null;
        bool result = g_markup_parse_context_parse(context, text.ptr, cast(ptrdiff_t)textLen, &error);
        if (!result) {
            string errorMsg = "Markup parse error";
            if (error !is null) {
                import std.string : fromStringz;
                errorMsg = error.message.fromStringz.idup;
                g_error_free(error);
            }
            throw new Exception(errorMsg);
        }
    }

    /**
     * End parsing and check for any remaining errors.
     *
     * Throws: Exception if there are unclosed elements or other errors
     */
    void endParse() {
        GError* error = null;
        bool result = g_markup_parse_context_end_parse(context, &error);
        if (!result) {
            string errorMsg = "Markup end parse error";
            if (error !is null) {
                import std.string : fromStringz;
                errorMsg = error.message.fromStringz.idup;
                g_error_free(error);
            }
            throw new Exception(errorMsg);
        }
    }
}