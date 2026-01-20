/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.customtitle;

import std.experimental.logger;
import std.typecons : Yes;

import gdk.event : Event;
import gdk.event_button : EventButton;
import gdk.event_focus : EventFocus;
import gdk.event_key : EventKey;

import gio.settings : GSettings = Settings, Settings;

import glib.source : Source;

import gobject.global : signalHandlerBlock, signalHandlerUnblock;
import gobject.value : Value;

import gtk.entry : Entry;
import gtk.event_box : EventBox;
import gtk.global : checkVersion;
import gtk.label : Label;
import gtk.settings : GtkSettings = Settings;
import gtk.stack : Stack;
import gtk.types : Align;
import pango.types : EllipsizeMode;
import gobject.types : ConnectFlags;
import gdk.types : ModifierType, EventType;
import glib.c.types : gulong;
import gtk.widget : Widget;

import glib.c.functions : g_timeout_add;
import glib.c.types : GSourceFunc;

// GID does not provide gdk.keysyms, so define the required key constants locally
private enum GdkKeysyms {
    GDK_Escape = 0xff1b,
    GDK_Return = 0xff0d,
}

private enum MouseButton {
    PRIMARY = 1,
}

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

    gulong focusOutHandlerId;

    GSettings gsSettings;
    bool controlRequired;

    void createUI() {
        setHalign(Align.Fill);
        lblTitle = new Label(_(APPLICATION_NAME));
        lblTitle.setHalign(Align.Center);
        lblTitle.getStyleContext().addClass("title");
        lblTitle.setEllipsize(EllipsizeMode.Start);
        eb = new EventBox();
        eb.connectButtonPressEvent(&onButtonPress);
        eb.connectButtonReleaseEvent(&onButtonRelease);
        eb.add(lblTitle);
        eb.setHalign(Align.Fill);
        addNamed(eb, PAGE_LABEL);

        eTitle = new Entry();
        eTitle.setWidthChars(5);
        eTitle.setHexpand(true);
        eTitle.connectKeyPressEvent(delegate (EventKey event, Widget widget) {
            uint keyval = event.keyval;
            switch (keyval) {
                case GdkKeysyms.GDK_Escape:
                    setViewMode(ViewMode.LABEL);
                    onCancelEdit.emit();
                    return true;
                case GdkKeysyms.GDK_Return:
                    onTitleChange.emit(eTitle.getText());
                    setViewMode(ViewMode.LABEL);
                    return true;
                default:
            }
            return false;
        });
        focusOutHandlerId = eTitle.connectFocusOutEvent(&onFocusOut, Yes.After);
        if (checkVersion(3,16, 0).length == 0) {
            titleEditor = createTitleEditHelper(eTitle, TitleEditScope.WINDOW);
            titleEditor.onPopoverShow.connect(&onPopoverShow);
            titleEditor.onPopoverClosed.connect(&onPopoverClosed);
            addNamed(titleEditor, PAGE_EDIT);
        } else {
            addNamed(eTitle, PAGE_EDIT);
        }
        setViewMode(ViewMode.LABEL);
    }

    bool onButtonRelease(EventButton event, Widget widget) {
        trace("Button release");
        if (event.button != MouseButton.PRIMARY || !buttonDown) {
            tracef("Ignoring release %b", buttonDown);
            return false;
        }
        if (controlRequired && !(event.state & ModifierType.ControlMask)) {
            tracef("No control modifier, ignoring: %d", event.state);
             return false;
        }
        removeTimeout();

        Value value = new Value(500);
        (cast(GtkSettings)getSettings()).getProperty(GTK_DOUBLE_CLICK_TIME, value);
        uint doubleClickTime = value.getInt();
        timeoutID = g_timeout_add(doubleClickTime, cast(GSourceFunc)&timeoutCallback, cast(void*)this);
        buttonDown = false;
        return false;
    }

    bool onButtonPress(EventButton event, Widget widget) {
        if (event is null || event.button != MouseButton.PRIMARY) return false;
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

    bool onFocusOut(EventFocus event, Widget widget) {
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
            Source.remove(timeoutID);
            timeoutID = 0;
        }
    }

    void onPopoverShow() {
        trace("Popover showing");
        signalHandlerBlock(eTitle, focusOutHandlerId);
    }

    void onPopoverClosed() {
        trace("Popover closing");
        signalHandlerUnblock(eTitle, focusOutHandlerId);
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
        gsSettings = new GSettings(SETTINGS_ID);
        gsSettings.connectChanged(null, delegate(string key, Settings settings) {
            if (key == SETTINGS_CONTROL_CLICK_TITLE_KEY) {
                controlRequired = gsSettings.getBoolean(SETTINGS_CONTROL_CLICK_TITLE_KEY);
            }
        });
        controlRequired = gsSettings.getBoolean(SETTINGS_CONTROL_CLICK_TITLE_KEY);
        createUI();
        connectDestroy(delegate(Widget w) {
            removeTimeout();
            gsSettings.destroy();
        });
    }

    @property string title() {
        return lblTitle.getText();
    }
    @property void title(string value) {
        lblTitle.setText(value);
    }
    void setTitle(string value) {
        title = value;
    }

    GenericEvent!() onCancelEdit;

    GenericEvent!(CumulativeResult!string) onEdit;

    GenericEvent!(string) onTitleChange;
}
