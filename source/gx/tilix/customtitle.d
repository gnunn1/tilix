/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.customtitle;

import std.experimental.logger;
import std.typecons;

import gdk.event;
import gdk.event_button;
import gdk.event_focus;
import gdk.event_key;
import gdk.types;
import gdk.types;

import gio.settings : Settings = Settings;

import gobject.global;
import gobject.types;
import gobject.value;
import gobject.types;

import gtk.box;
import gtk.types;
import gtk.entry;
import gtk.types;
import gtk.event_box;
import gtk.types;
import gtk.label;
import gtk.types;
import gtk.settings;
import gtk.types;
import gtk.stack;
import gtk.types;
import gtk.widget;
import gtk.types;
import gtk.window;
import gtk.types;
import gtk.global;

import pango.types;

import glib.c.functions;

import gx.gtk.eventsignals;
import gx.gtk.keys;
import gx.gtk.types;
import gx.gtk.util;
import gx.i18n.l10n;

import gx.tilix.common;
import gx.tilix.constants;
import gx.tilix.preferences;
import gx.tilix.prefeditor.titleeditor;

/**
 * Custom title for AppWindow that allows the user
 * to click on the label in the headerbar and edit
 * the application title directly. Note this feature
 * is not available when CSD is disabled.
 */
public class CustomTitle: Stack {

private:
    enum PAGE_LABEL = "label";
    enum PAGE_EDIT = "edit";

    Entry eTitle;
    EventBox eb;
    Label lblTitle;

    uint timeoutID;

    bool buttonDown;

    TitleEditBox titleEditor;

    ulong focusOutHandlerId;

    Settings gsSettings;
    bool controlRequired;

    void createUI() {
        setHalign(Align.Fill);

        lblTitle = new Label(_(APPLICATION_NAME));
        lblTitle.setHalign(Align.Center);
        lblTitle.getStyleContext().addClass("title");
        lblTitle.setEllipsize(pango.types.EllipsizeMode.Start);
        eb = new EventBox();
        // `gid` currently unmarshals `GdkEventButton` using `g_value_get_pointer`.
        // Use boxed marshalling to avoid GLib criticals / invalid events.
        connectButtonPressEventBoxed(eb, &onButtonPress);
        connectButtonReleaseEventBoxed(eb, &onButtonRelease);
        eb.add(lblTitle);
        eb.setHalign(Align.Fill);
        addNamed(eb, PAGE_LABEL);

        eTitle = new Entry();
        eTitle.setWidthChars(5);
        eTitle.setHexpand(true);
        connectKeyPressEventBoxed(eTitle, delegate (EventKey event, Widget widget) {
            uint keyval = event.keyval;
            switch (keyval) {
                case Keys.Escape:
                    setViewMode(ViewMode.LABEL);
                    onCancelEdit.emit();
                    return true;
                case Keys.Return:
                    onTitleChange.emit(eTitle.getText());
                    setViewMode(ViewMode.LABEL);
                    return true;
                default:
            }
            return false;
        });
        // `gid` currently unmarshals `GdkEventFocus` using `g_value_get_pointer`,
        // which triggers GLib criticals. We don't need the event payload.
        focusOutHandlerId = eTitle.connectFocusOutEvent(&onFocusOut, Yes.After);
        if (gtk.global.checkVersion(3,16, 0).length == 0) {
            titleEditor = createTitleEditHelper(eTitle, TitleEditScope.WINDOW);
            titleEditor.onPopoverShow .connect(&onPopoverShow);
            titleEditor.onPopoverClosed .connect(&onPopoverClosed);
            addNamed(titleEditor, PAGE_EDIT);
        } else {
            addNamed(eTitle, PAGE_EDIT);
        }
        setViewMode(ViewMode.LABEL);
    }

    bool onButtonRelease(EventButton event, Widget widget) {
        trace("Button release");
        if (event.button != 1 || !buttonDown) {
            tracef("Ignoring release %b", buttonDown);
            return false;
        }
        if (controlRequired && !(event.state & gdk.types.ModifierType.ControlMask)) {
            tracef("No control modifier, ignoring: %d", event.state);
             return false;
        }
        removeTimeout();

        Value value = new Value(500);
        getSettings().getProperty(GTK_DOUBLE_CLICK_TIME, value);
        uint doubleClickTime = value.getInt();
        timeoutID = g_timeout_add(doubleClickTime, cast(GSourceFunc)&timeoutCallback, cast(void*)this);
        buttonDown = false;
        return false;
    }

    bool onButtonPress(EventButton event, Widget widget) {
        if (event.button != 1) return false;

        if (event.type == EventType.DoubleButtonPress) {
            trace("Double click press");
            buttonDown = false;
            removeTimeout();
        } else {
            trace("Single click press");
            buttonDown = true;
        }
        return false;
    }

    bool onFocusOut() {
        trace("Focus out");
        removeTimeout();
        setViewMode(ViewMode.LABEL);
        onCancelEdit.emit();
        return false;
    }

    bool onSingleClickTimer() {
        doEdit();
        return false;
    }

    enum ViewMode {LABEL, EDITOR}

    void setViewMode(ViewMode mode) {
        final switch (mode) {
            case ViewMode.LABEL:
                setVisibleChildName(PAGE_LABEL);
                setHexpand(false);
                break;
            case ViewMode.EDITOR:
                setHexpand(true);
                setVisibleChildName(PAGE_EDIT);
                eTitle.grabFocus();
        }
    }

    void doEdit() {
        buttonDown = false;

        string value;
        CumulativeResult!string result = new CumulativeResult!string();
        onEdit.emit(result);
        if (result.getResults().length == 0) return;
        else value = result.getResults()[0];

        if (value.length > 0) {
            eTitle.setText(value);
        }
        setViewMode(ViewMode.EDITOR);
    }

    void removeTimeout() {
        if (timeoutID > 0) {
            g_source_remove(timeoutID);
            timeoutID = 0;
        }
    }

    void onPopoverShow() {
        trace("Popover showing");
        gobject.global.signalHandlerBlock(eTitle, focusOutHandlerId);
    }

    void onPopoverClosed() {
        trace("Popover closing");
        gobject.global.signalHandlerUnblock(eTitle, focusOutHandlerId);
    }

	extern(C) static bool timeoutCallback(CustomTitle ct) {
        trace("Timeout callback received");
        ct.doEdit();
        ct.timeoutID = 0;
        return false;
	}

public:
    this() {
        super();
        gsSettings = new Settings(SETTINGS_ID);
        gsSettings.connectChanged(null, delegate(string key, Settings s) {
            if (key == SETTINGS_CONTROL_CLICK_TITLE_KEY) {
                controlRequired = gsSettings.getBoolean(SETTINGS_CONTROL_CLICK_TITLE_KEY);
            }
        });
        controlRequired = gsSettings.getBoolean(SETTINGS_CONTROL_CLICK_TITLE_KEY);
        createUI();
        connectDestroy(delegate(Widget w) {
            removeTimeout();
            gsSettings.destroy();
            gsSettings = null;
        });
    }

    @property string title() {
        return lblTitle.getText();
    }

    @property void title(string title) {
        lblTitle.setText(title);
    }

    GenericEvent!() onCancelEdit;

    GenericEvent!(CumulativeResult!string) onEdit;

    GenericEvent!(string) onTitleChange;
}
