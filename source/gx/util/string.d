/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

module gx.util.string;

import std.string;

/**
 * Escape a string to include a CSV according to the rules expected
 * by std.csv.
 */
string escapeCSV(string value) {
    value = value.replace("\"\"", "\"\"\"\"");
    if (value.indexOf('\n') >= 0 || value.indexOf(',')  >= 0 || value.indexOf("\"\"") >= 0) {
        value = "\"\"" ~ value ~ "\"\"";
    }
    return value;
}
