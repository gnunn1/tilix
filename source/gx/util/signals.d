/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.util.signals;

import std.algorithm : countUntil;

/**
 * Lightweight signal/slot implementation used by Tilix.
 *
 * This replaces `std.signals` which is currently not compatible with newer
 * druntime versions due to a conflicting `_d_toObject` symbol.
 */
mixin template Signal(TArgs...) {
private:
    alias Slot = void delegate(TArgs);
    Slot[] slots;

public:
    void connect(Slot slot) {
        slots ~= slot;
    }

    void disconnect(Slot slot) {
        const idx = slots.countUntil!(s => s == slot);
        if (idx < 0) return;
        slots = slots[0 .. idx] ~ slots[idx + 1 .. $];
    }

    void emit(TArgs args) {
        // Iterate over a snapshot so slots can connect/disconnect during emit.
        auto snapshot = slots.dup;
        foreach (slot; snapshot) {
            slot(args);
        }
    }

    alias opCall = emit;
}
