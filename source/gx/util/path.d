/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.util.path;

import std.path;
import std.process;
import std.string;

/**
 * Resolves the path by converting tilde and environment
 * variables in the path.
 */
string resolvePath(string path) {
    string result = expandTilde(path);
    string[string] env = environment.toAA();
    foreach(name; env.keys) {
        result = result.replace('$' ~ name, env[name]);
        result = result.replace("${" ~ name ~ "}", env[name]);
    }
    return result;
}
