/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

module gx.gtk.color;

import std.conv;
import std.experimental.logger;
import std.format;

import gdk.RGBA;

public:

/**
 * Converts an RGBA structure to a 8 bit HEX string, i.e #2E3436
 *
 * Params:
 * RGBA	 = The color to convert
 * includeAlpha = Whether to include the alpha channel
 * includeHash = Whether to preface the color string with a #
 */
string rgbaTo8bitHex(RGBA color, bool includeAlpha = false, bool includeHash = false) {
    string prepend = includeHash ? "#" : "";
    int red = to!(int)(color.red() * 255);
    int green = to!(int)(color.green() * 255);
    int blue = to!(int)(color.blue() * 255);
    if (includeAlpha) {
        int alpha = to!(int)(color.alpha() * 255);
        return prepend ~ format("%02X%02X%02X%02X", red, green, blue, alpha);
    } else {
        return prepend ~ format("%02X%02X%02X", red, green, blue);
    }
}

/**
 * Converts an RGBA structure to a 16 bit HEX string, i.e #2E2E34343636
 * Right now this just takes an 8 bit string and repeats each channel
 *
 * Params:
 * RGBA	 = The color to convert
 * includeAlpha = Whether to include the alpha channel
 * includeHash = Whether to preface the color string with a #
 */
string rgbaTo16bitHex(RGBA color, bool includeAlpha = false, bool includeHash = false) {
    string prepend = includeHash ? "#" : "";
    int red = to!(int)(color.red() * 255);
    int green = to!(int)(color.green() * 255);
    int blue = to!(int)(color.blue() * 255);
    if (includeAlpha) {
        int alpha = to!(int)(color.alpha() * 255);
        return prepend ~ format("%02X%02X%02X%02X%02X%02X%02X%02X", red, red, green, green, blue, blue, alpha, alpha);
    } else {
        return prepend ~ format("%02X%02X%02X%02X%02X%02X", red, red, green, green, blue, blue);
    }
}

RGBA getOppositeColor(RGBA rgba) {
    RGBA result = new RGBA(1.0 - rgba.red, 1 - rgba.green, 1 - rgba.red, rgba.alpha);
    tracef("Original: %s, New: %s", rgbaTo8bitHex(rgba, true, true), rgbaTo8bitHex(result, true, true));
    return result;
}

void lighten(double percent, RGBA rgba, out double r, out double g, out double b) {
    adjustColor(percent, rgba, r, g, b);
}

void darken(double percent, RGBA rgba, out double r, out double g, out double b) {
    adjustColor(-percent, rgba, r, g, b);
}

void adjustColor(double cf, RGBA rgba, out double r, out double g, out double b) {
    if (cf < 0) {
        cf = 1 + cf;
        r = rgba.red * cf;
        g = rgba.green * cf;
        b = rgba.blue * cf;
    } else {
        r = (1 - rgba.red) * cf + rgba.red;
        g = (1 - rgba.green) * cf + rgba.green;
        b = (1 - rgba.blue) * cf + rgba.blue;
    }
}

void desaturate(double percent, RGBA rgba, out double r, out double g, out double b) {
    tracef("desaturate: %f, %f, %f, %f", percent, rgba.red, rgba.green, rgba.blue);
    double L = 0.3 * rgba.red + 0.6 * rgba.green + 0.1 * rgba.blue;
    r = rgba.red + percent * (L - rgba.red);
    g = rgba.green + percent * (L - rgba.green);
    b = rgba.blue + percent * (L - rgba.blue);
    tracef("Desaturated color: %f, %f, %f", r, g, b);
}