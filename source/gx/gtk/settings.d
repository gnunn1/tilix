/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.settings;

import std.experimental.logger;

import gtkc.giotypes;

import gobject.ObjectG;
import gio.Settings: GSettings = Settings;

/**
 * Bookkeeping class that keps track of objects which are
 * binded to a GSettings object so they can be unbinded later.
 */
class BindingHelper {

private:
    Binding[] bindings;
    GSettings _settings;

    void bindAll() {
        if (_settings !is null) {
            foreach(binding; bindings) {
                _settings.bind(binding.key, binding.object, binding.property, binding.flags);
            }
        }
    }

public:

    this() {
    }

    this(GSettings settings) {
        this();
        _settings = settings;
    }

    @property GSettings settings() {
        return _settings;
    }

    /**
     * Setting a new GSettings object will cause this class to unbind
     * previously set bindings and re-bind to the new settings automatically.
     */
    @property void settings(GSettings value) {
        if (value != _settings) {
            if (_settings !is null && bindings.length > 0) unbind();
            _settings = value;
            if (_settings !is null) bindAll();
        }
    }

    void addBind(string key, ObjectG object, string property, GSettingsBindFlags flags) {
        bindings ~= Binding(key, object, property, flags);
    }

    void unbind() {
        foreach(binding; bindings) {
            _settings.unbind(binding.object, binding.property);
        }
    }

    void clear() {
        unbind();
        bindings.length = 0;
    }
}

private:
struct Binding {
    string key;
    ObjectG object;
    string property;
    GSettingsBindFlags flags;
}
