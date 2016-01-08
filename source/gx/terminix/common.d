/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.common;

import gx.util.array;

enum ActionType {
    DETACH
}

/**
 * Certain actions to be percolated up the widget heirarchy with
 * every level having to sign off on the action before it can be 
 * performed. This delegate is for that purpose.
 */
alias OnIsActionAllowed = bool delegate(ActionType actionType);

/**
 * Mixin to handle the boiler plate of IsActionAllowed event 
 * handlers
 */
mixin template IsActionAllowedHandler() {

private:
    OnIsActionAllowed[] isActionAllowedDelegates;

    bool notifyIsActionAllowed(ActionType actionType) {
        foreach (dlg; isActionAllowedDelegates) {
            if (!dlg(actionType))
                return false;
        }
        return true;
    }

public:

    void addOnIsActionAllowed(OnIsActionAllowed dlg) {
        isActionAllowedDelegates ~= dlg;
    }

    void removeOnIsActionAllowed(OnIsActionAllowed dlg) {
        gx.util.array.remove(isActionAllowedDelegates, dlg);
    }
}
