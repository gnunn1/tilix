/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.actions;

import std.experimental.logger;
import std.string;

import gio.ActionMapIF;
import gio.SimpleAction;
import gio.Settings : GSettings = Settings;

import glib.Variant: GVariant = Variant;
import glib.VariantType: GVariantType = VariantType;

import gtk.AccelGroup;
import gtk.Application;
import gtk.ApplicationWindow;

import gx.i18n.l10n;

private Application app = null;

enum SHORTCUT_DISABLED = N_("disabled");

/**
 * Convert an accelerator name to a label
 */
string acceleratorNameToLabel(string acceleratorName) {
    uint acceleratorKey;
    GdkModifierType acceleratorMods;
    AccelGroup.acceleratorParse(acceleratorName, acceleratorKey, acceleratorMods);
    string label = AccelGroup.acceleratorGetLabel(acceleratorKey, acceleratorMods);
    if (label == "") {
      label = _(SHORTCUT_DISABLED);
    }
    return label;
}

/**
 * Given an action prefix and id returns the detailed name
 */
string getActionDetailedName(string prefix, string id) {
    return prefix ~ "." ~ id;
}

/**
 * Returns the key for the corresponding prefix and id. The string
 * that is returned is the key to locate the shortcut in a
 * GSettings object
 */
string getActionKey(string prefix, string id) {
    return prefix ~ "-" ~ id;
}

/**
  * Given a GSettings key, returns the coresponding action prefix and id.
  */
void getActionNameFromKey(string key, out string prefix, out string id) {
    ptrdiff_t index = key.indexOf("-");
    if (index >= 0) {
        prefix = key[0 .. index];
        id = key[index + 1 .. $];
    }
}

string keyToDetailedActionName(string key) {
    string prefix, id;
    getActionNameFromKey(key, prefix, id);
    return prefix ~ "." ~ id;
}

/**
    * Adds a new action to the specified menu. An action is automatically added to the application that invokes the
    * specified callback when the actual menu item is activated.
    *
    * This code from grestful (https://github.com/Gert-dev/grestful)
    *
    * Params:
    * actionMap =            The map that is holding the action
    * prefix =               The prefix part of the action name that comes before the ".", i.e. "app" for GtkApplication, etc
    * id =                   The ID to give to the action. This can be used in other places to refer to the action
    *                             by a string. Must always start with "app.".
    * settings =             A GIO GSettings object where shortcuts can be looked up using the key name "{prefix}-{id}"
    * callback =             The callback to invoke when the action is invoked.
    * parameterType =        The type of data passed as parameter to the action when activated.
    * state =                The state of the action
    *
    * Returns: The registered action.
    */
SimpleAction registerActionWithSettings(ActionMapIF actionMap, string prefix, string id, GSettings settings, void delegate(GVariant,
        SimpleAction) cbActivate = null, GVariantType type = null, GVariant state = null, void delegate(GVariant,
        SimpleAction) cbStateChange = null) {

    string[] shortcuts;
    try {
        string shortcut = settings.getString(getActionKey(prefix, id));
        if (shortcut.length > 0 && shortcut != SHORTCUT_DISABLED)
            shortcuts = [shortcut];
    }
    catch (Exception e) {
        //TODO - This does not work, figure out to catch GLib-GIO-ERROR
        tracef("No shortcut for action %s.%s", prefix, id);
    }

    return registerAction(actionMap, prefix, id, shortcuts, cbActivate, type, state, cbStateChange);
}

/**
    * Adds a new action to the specified menu. An action is automatically added to the application that invokes the
    * specified callback when the actual menu item is activated.
    *
    * This code from grestful (https://github.com/Gert-dev/grestful)
    *
    * Params:
    * actionMap =            The map that is holding the action
    * prefix =               The prefix part of the action name that comes before the ".", i.e. "app" for GtkApplication, etc
    * id =                   The ID to give to the action. This can be used in other places to refer to the action
    *                             by a string. Must always start with "app.".
    * accelerator =          The (application wide) keyboard accelerator to activate the action.
    * callback =             The callback to invoke when the action is invoked.
    * parameterType =        The type of data passed as parameter to the action when activated.
    * state =                The state of the action, creates a stateful action
    *
    * Returns: The registered action.
    */
SimpleAction registerAction(ActionMapIF actionMap, string prefix, string id, string[] accelerators = null, void delegate(GVariant,
        SimpleAction) cbActivate = null, GVariantType parameterType = null, GVariant state = null, void delegate(GVariant,
        SimpleAction) cbStateChange = null) {
    SimpleAction action;
    if (state is null)
        action = new SimpleAction(id, parameterType);
    else {
        action = new SimpleAction(id, parameterType, state);
    }

    if (cbActivate !is null)
        action.addOnActivate(cbActivate);

    if (cbStateChange !is null)
        action.addOnChangeState(cbStateChange);

    actionMap.addAction(action);

    if (accelerators.length > 0) {
        if (app is null) {
            app = cast(Application) Application.getDefault();
        }
        if (app !is null) {
            app.setAccelsForAction(prefix.length == 0 ? id : getActionDetailedName(prefix, id), accelerators);
        } else {
            errorf("Accelerator for action %s could not be registered", id);
        }
    }
    return action;
}

unittest {
    string prefix, id;
    getActionNameFromKey("terminal-split-horizontal", prefix, id);
    assert("terminal" == prefix);
    assert("split-horizontal" == id);
}
