/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.settings;

import std.experimental.logger;

import gx.gtk.types;
import gio.types;
import gobject.object;
import gobject.types;
import gio.settings: Settings = Settings;

/**
 * Bookkeeping class that keps track of objects which are
 * binded to a Settings object so they can be unbinded later. it
 * also supports the concept of deferred bindings where a binding
 * can be added but is not actually attached to a Settings object
 * until one is set.
 */
class BindingHelper {

private:
    Binding[] bindings;
    Settings _settings;

    void bindAll() {
        if (_settings !is null) {
            foreach(binding; bindings) {
                _settings.bind(binding.key, binding.object, binding.property, binding.flags);
            }
        }
    }

    /**
     * Adds a binding to the list
     */
    void addBind(string key, ObjectWrap object, string property, SettingsBindFlags flags) {
        bindings ~= Binding(key, object, property, flags);
    }

public:

    this() {
    }

    this(Settings settings) {
        this();
        _settings = settings;
    }

    /**
     * The current Settings object being used.
     */
    @property Settings settings() {
        return _settings;
    }

    /**
     * Setting a new Settings object will cause this class to unbind
     * previously set bindings and re-bind to the new settings automatically.
     */
    @property void settings(Settings value) {
        if (value != _settings) {
            if (_settings !is null && bindings.length > 0) unbind();
            _settings = value;
            if (_settings !is null) bindAll();
        }
    }

    /**
     * Add a binding to list and binds to Settings if it is set.
     */
    void bind(string key, ObjectWrap object, string property, SettingsBindFlags flags) {
        addBind(key, object, property, flags);
        if (settings !is null) {
            _settings.bind(key, object, property, flags);
        }
    }

    /**
     * Unbinds all added binds from settings object
     */
    void unbind() {
        foreach(binding; bindings) {
            _settings.unbind(binding.object, binding.property);
        }
    }

    /**
     * Unbinds all bindings and clears list of bindings.
     */
    void clear() {
        unbind();
        bindings.length = 0;
    }
}

private:

struct Binding {
    string key;
    ObjectWrap object;
    string property;
    SettingsBindFlags flags;
}
