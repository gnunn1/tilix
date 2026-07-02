/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.threads;

import std.experimental.logger;

// GID imports - gdk
import gdk.global : threadsAddIdle, threadsAddTimeout;

// GID imports - glib
import glib.types : SourceFunc, PRIORITY_DEFAULT_IDLE;

/**
 * Convenience method that allows scheduling a delegate to be executed with gdk.global.threadsAddIdle.
 * The delegate should return true to be called again, or false to stop.
 *
 * @param theDelegate The delegate to schedule.
 * @param parameters  A tuple of parameters to pass to the delegate when it is invoked.
 *
 * @example
 *     auto myMethod = delegate(string name, string value) { do_something_with_name_and_value(); return false; }
 *     threadsAddIdleDelegate(myMethod, "thisIsAName", "thisIsAValue");
 */
void threadsAddIdleDelegate(T, parameterTuple...)(T theDelegate, parameterTuple parameters)
{
    // Wrap the user's delegate in a SourceFunc (bool delegate())
    SourceFunc wrappedDelegate = delegate bool() {
        try
        {
            return theDelegate(parameters);
        }
        catch (Exception e)
        {
            warning("Unexpected exception occurred in idle callback: " ~ e.msg);
            return false;
        }
    };

    threadsAddIdle(PRIORITY_DEFAULT_IDLE, wrappedDelegate);
}

/**
 * Convenience method that allows scheduling a delegate to be executed with gdk.global.threadsAddTimeout.
 * The delegate should return true to be called again, or false to stop.
 *
 * @param interval The interval to call the delegate in ms
 * @param theDelegate The delegate to schedule.
 * @param parameters  A tuple of parameters to pass to the delegate when it is invoked.
 *
 * @example
 *     auto myMethod = delegate(string name, string value) { do_something_with_name_and_value(); return false; }
 *     threadsAddTimeoutDelegate(1000, myMethod, "thisIsAName", "thisIsAValue");
 *
 * @return The ID of the event source.
 */
uint threadsAddTimeoutDelegate(T, parameterTuple...)(uint interval, T theDelegate, parameterTuple parameters)
{
    // Wrap the user's delegate in a SourceFunc (bool delegate())
    SourceFunc wrappedDelegate = delegate bool() {
        try
        {
            return theDelegate(parameters);
        }
        catch (Exception e)
        {
            warning("Unexpected exception occurred in timeout callback: " ~ e.msg);
            return false;
        }
    };

    return threadsAddTimeout(PRIORITY_DEFAULT_IDLE, interval, wrappedDelegate);
}