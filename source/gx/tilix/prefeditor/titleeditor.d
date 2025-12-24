/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.prefeditor.titleeditor;

import std.conv;
import std.experimental.logger;
import std.format;
import std.signals;
import std.typecons : Yes, No;

import gio.simple_action;
import gio.simple_action_group;
import gio.menu: Menu = Menu;
import gio.menu_item : MenuItem = MenuItem;

import glib.variant: Variant = Variant;
import glib.variant_type: VariantType = VariantType;

import gtk.box;
import gtk.entry;
import gtk.image;
import gtk.global;
import gtk.menu_button;
import gtk.mount_operation;
import gtk.popover;
alias Popover = gtk.popover.Popover;
import gtk.popover_menu;
import gtk.types;
import gtk.widget;
alias Widget = gtk.widget.Widget;
import gtk.window;
alias Window = gtk.window.Window;

import gx.gtk.actions;

import gx.i18n.l10n;

import gx.tilix.common;
import gx.tilix.constants;

/**
 * Scope of the title to be edited
 */
enum TitleEditScope {WINDOW, SESSION, TERMINAL}

/**
 * Wraps an entry into a box that includes other
 * helper widgets to edit the title.
 */
TitleEditBox createTitleEditHelper(Entry entry, TitleEditScope tes) {
    return new TitleEditBox(entry, tes);
}


/**
 * Wraps an entry with helpers for editing various titles
 * like terminal title, window title, etc where variables can be used.
 *
 * Note that this editor is not supported in GTK 3.14 so version check it
 * before using it.
 */
class TitleEditBox: Box {
private:
    Entry entry;
    SimpleActionGroup sagVariables;

    enum ACTION_PREFIX = "variables";

    void createUI(TitleEditScope tes) {
        sagVariables = new SimpleActionGroup();
        this.insertActionGroup(ACTION_PREFIX, sagVariables);

        add(entry);

        MenuButton mbVariables = new MenuButton();
        mbVariables.add(Image.newFromIconName("pan-down-symbolic", IconSize.Menu));
        mbVariables.setFocusOnClick(false);
        mbVariables.setPopover(createPopover(tes));
        add(mbVariables);
    }

    /**
     * Create menu items from array for each section (window, session, terminal)
     */
    Menu createItems(immutable(string[]) localized, immutable(string[]) values, string actionPrefix) {
        Menu section = new Menu();
        foreach(index, variable; localized) {
            string actionName = format("%s-%02d", actionPrefix, index);
            SimpleAction action = new SimpleAction(actionName, null);
            action.connectActivate(delegate(Variant v, SimpleAction sa) {
                string name = sa.getName();
                int i = to!int("" ~ name[$-2 .. $]);
                int position = entry.getPosition();
                string value = values[i];
                entry.insertText(value, to!int(value.length), position);
            });
            sagVariables.insert(action);
            section.append(_(variable), getActionDetailedName(ACTION_PREFIX, actionName));
        }
        return section;
    }

    /**
     * Create all menu items in popover to help editing menu items
     */
    PopoverMenu createPopover(TitleEditScope tes) {
        Menu model = new Menu();

        // Terminal items
        Menu terminalSection = createItems(VARIABLE_TERMINAL_LOCALIZED, VARIABLE_TERMINAL_VALUES, "terminal");
        model.appendSection(_("Terminal"), terminalSection);

        //Session menu items
        if (tes == TitleEditScope.SESSION || tes == TitleEditScope.WINDOW) {
            Menu sessionSection = createItems(VARIABLE_SESSION_LOCALIZED, VARIABLE_SESSION_VALUES, "session");
            model.appendSection(_("Session"), sessionSection);
        }

        //App menu items
        if (tes == TitleEditScope.WINDOW) {
            Menu windowSection = createItems(VARIABLE_WINDOW_LOCALIZED, VARIABLE_WINDOW_VALUES, "window");
            model.appendSection(_("Window"), windowSection);
        }

        // Help Menu Item
        Menu helpSection = new Menu();
        SimpleAction saHelp = new SimpleAction("help", null);
        saHelp.connectActivate(delegate(Variant v, SimpleAction sa) {
            import gtk.global : showUriOnWindow, getCurrentEventTime;
            showUriOnWindow(cast(Window)getToplevel(), "https://gnunn1.github.io/tilix-web/manual/title/", getCurrentEventTime());
        });
        sagVariables.insert(saHelp);
        helpSection.append(_("Help"), getActionDetailedName(ACTION_PREFIX, "help"));
        model.appendSection(_("Help"), helpSection);

        PopoverMenu pm = new PopoverMenu();
        pm.connectMap(delegate(Widget w) {
            onPopoverShow.emit();
        });
        pm.connectClosed(delegate(Popover p) {
            entry.grabFocus();
            onPopoverClosed.emit();
        }, Yes.After);

        pm.bindModel(model, null);
        return pm;
    }


public:
    this(Entry entry, TitleEditScope tes) {
        super(gtk.types.Orientation.Horizontal, 0);
        this.entry = entry;
        getStyleContext().addClass("linked");
        setHexpand(true);
        createUI(tes);
        connectDestroy(delegate() {
            sagVariables.destroy();
            sagVariables = null;
        });
    }

    GenericEvent!() onPopoverShow;

    GenericEvent!() onPopoverClosed;

}