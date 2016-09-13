/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.util.array;

import std.algorithm;
import std.array;

/**
 * Removes the specified element from the array (once).
 *
 * Params:
 *  array   = The array to remove the item from.
 *  element = The item to look for and remove.
 *
 * Adapted from grestful, modified to explicitly check index
 */
void remove(T)(ref T[] array, T element) {
    auto index = array.countUntil(element);
    if (index >= 0)
        array = std.algorithm.remove(array, index);
}

unittest {
    string[] test = ["test1", "test2", "test3"];

    remove(test, "test1");
    assert(test == ["test2", "test3"]);
    remove(test, "test4");
    assert(test == ["test2", "test3"]);
}
