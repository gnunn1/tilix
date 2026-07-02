/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.prefeditor.titleeditor;

import std.conv;
import std.experimental.logger;
import std.format;
import std.signals;

import gio.simple_action : SimpleAction;
import gio.simple_action_group : SimpleActionGroup;
import gio.menu : GMenu = Menu;
import gio.menu_item : GMenuItem = MenuItem;

import glib.variant : GVariant = Variant;
import glib.variant_type : GVariantType = VariantType;

import std.typecons : Yes, No;

import gtk.box : Box;
import gtk.entry : Entry;
import gtk.image : Image;
import gtk.global : getCurrentEventTime, showUri;
import gtk.menu_button : MenuButton;
import gtk.popover_menu : PopoverMenu;
import gtk.widget : Widget;
import gtk.types : IconSize, Orientation, ReliefStyle;

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
    GMenu createItems(immutable(string[]) localized, immutable(string[]) values, string actionPrefix) {
        GMenu section = new GMenu();
        foreach(index, variable; localized) {
            string actionName = format("%s-%02d", actionPrefix, index);
            SimpleAction action = new SimpleAction(actionName, null);
            action.connectActivate(delegate(GVariant param, SimpleAction sa) {
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
        GMenu model = new GMenu();

        // Terminal items
        GMenu terminalSection = createItems(VARIABLE_TERMINAL_LOCALIZED, VARIABLE_TERMINAL_VALUES, "terminal");
        model.appendSection(_("Terminal"), terminalSection);

        //Session menu items
        if (tes == TitleEditScope.SESSION || tes == TitleEditScope.WINDOW) {
            GMenu sessionSection = createItems(VARIABLE_SESSION_LOCALIZED, VARIABLE_SESSION_VALUES, "session");
            model.appendSection(_("Session"), sessionSection);
        }

        //App menu items
        if (tes == TitleEditScope.WINDOW) {
            GMenu windowSection = createItems(VARIABLE_WINDOW_LOCALIZED, VARIABLE_WINDOW_VALUES, "window");
            model.appendSection(_("Window"), windowSection);
        }

        // Help Menu Item
        GMenu helpSection = new GMenu();
        SimpleAction saHelp = new SimpleAction("help", null);
        saHelp.connectActivate(delegate(GVariant param, SimpleAction sa) {
            showUri(null, "https://gnunn1.github.io/tilix-web/manual/title/", getCurrentEventTime());
        });
        sagVariables.insert(saHelp);
        helpSection.append(_("Help"), getActionDetailedName(ACTION_PREFIX, "help"));
        model.appendSection(_("Help"), helpSection);

        PopoverMenu pm = new PopoverMenu();
        pm.connectMap(delegate() {
            onPopoverShow.emit();
        });
        pm.connectClosed(delegate() {
            entry.grabFocus();
            onPopoverClosed.emit();
        }, Yes.After);

        pm.bindModel(model, null);
        return pm;
    }


public:
    this(Entry entry, TitleEditScope tes) {
        super(Orientation.Horizontal, 0);
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