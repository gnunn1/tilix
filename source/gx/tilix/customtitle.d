/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.customtitle;

import std.experimental.logger;

import gdk.Event;
import gdk.Keysyms;

import gio.Settings : GSettings = Settings;

import gobject.Signals;
import gobject.Value;

import gtk.Box;
import gtk.Entry;
import gtk.EventBox;
import gtk.Label;
import gtk.Settings;
import gtk.Stack;
import gtk.Widget;
import gtk.Window;
import gtk.Version;

import gtkc.glib;

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
        setHalign(Align.FILL);
        
        lblTitle = new Label(_(APPLICATION_NAME));
        lblTitle.setHalign(Align.CENTER);
        lblTitle.getStyleContext().addClass("title");
        lblTitle.setEllipsize(PangoEllipsizeMode.START);
        eb = new EventBox();
        eb.addOnButtonPress(&onButtonPress);
        eb.addOnButtonRelease(&onButtonRelease);
        eb.add(lblTitle);
        eb.setHalign(Align.FILL);
        addNamed(eb, PAGE_LABEL);
        
        eTitle = new Entry();
        eTitle.setWidthChars(5);
        eTitle.setHexpand(true);
        eTitle.addOnKeyPress(delegate (Event event, Widget widget) {
            uint keyval;
            if (event.getKeyval(keyval)) {
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
            }
            return false;
        });
        focusOutHandlerId = eTitle.addOnFocusOut(&onFocusOut, ConnectFlags.AFTER);
        if (Version.checkVersion(3,16, 0).length == 0) {
            titleEditor = createTitleEditHelper(eTitle, TitleEditScope.WINDOW);
            titleEditor.onPopoverShow.connect(&onPopoverShow);
            titleEditor.onPopoverClosed.connect(&onPopoverClosed);
            addNamed(titleEditor, PAGE_EDIT);
        } else {
            addNamed(eTitle, PAGE_EDIT);
        }
        setViewMode(ViewMode.LABEL);
    }

    bool onButtonRelease(Event event, Widget widget) {
        trace("Button release");
        if (event.button.button != MouseButton.PRIMARY || !buttonDown) {
            tracef("Ignoring release %b", buttonDown);
            return false;
        }
        if (controlRequired && !(event.button.state & ModifierType.CONTROL_MASK)) {
            tracef("No control modifier, ignoring: %d", event.button.state);
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

    bool onButtonPress(Event event, Widget widget) {
        if (event.button.button != MouseButton.PRIMARY) return false;

        if (event.getEventType() == EventType.DOUBLE_BUTTON_PRESS) {
            trace("Double click press");
            buttonDown = false;
            removeTimeout();
        } else {
            trace("Single click press");
            buttonDown = true;
        }
        return false;
    }

    bool onFocusOut(Event event, Widget widget) {
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
        Signals.handlerBlock(eTitle, focusOutHandlerId);
    }

    void onPopoverClosed() {
        trace("Popover closing");
        Signals.handlerUnblock(eTitle, focusOutHandlerId);
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
        gsSettings.addOnChanged(delegate(string key, GSettings) {
            if (key == SETTINGS_CONTROL_CLICK_TITLE_KEY) {
                controlRequired = gsSettings.getBoolean(SETTINGS_CONTROL_CLICK_TITLE_KEY);
            }
        });
        controlRequired = gsSettings.getBoolean(SETTINGS_CONTROL_CLICK_TITLE_KEY);
        createUI();
        addOnDestroy(delegate(Widget) {
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
