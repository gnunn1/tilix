/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.threads;

import core.memory;

import std.algorithm;
import std.experimental.logger;
import std.stdio;

import glib.global;
import glib.types;

/**
 * Convenience method that allows scheduling a delegate to be executed with glib.global.idleAdd instead of a
 * traditional callback with C linkage.
 *
 * @param theDelegate The delegate to schedule.
 * @param parameters  A tuple of parameters to pass to the delegate when it is invoked.
 *
 * @example
 *     auto myMethod = delegate(string name, string value) { do_something_with_name_and_value(); }
 *     threadsAddIdleDelegate(myMethod, "thisIsAName", "thisIsAValue");
 *
 */
void threadsAddIdleDelegate(T, parameterTuple...)(T theDelegate, parameterTuple parameters)
{
    idleAdd(PRIORITY_DEFAULT_IDLE, delegate() {
        return theDelegate(parameters);
    });
}

/**
 * Convenience method that allows scheduling a delegate to be executed with glib.global.timeoutAdd instead of a
 * traditional callback with C linkage.
 *
 * @param interval The interval to call the delegate in ms
 * @param theDelegate The delegate to schedule.
 * @param parameters  A tuple of parameters to pass to the delegate when it is invoked.
 *
 * @example
 *     auto myMethod = delegate(string name, string value) { do_something_with_name_and_value(); }
 *     threadsAddIdleDelegate(myMethod, "thisIsAName", "thisIsAValue");
 *
 */
uint threadsAddTimeoutDelegate(T, parameterTuple...)(uint interval, T theDelegate, parameterTuple parameters)
{
    return timeoutAdd(PRIORITY_DEFAULT, interval, delegate() {
        return theDelegate(parameters);
    });
}
