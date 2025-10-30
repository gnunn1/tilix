﻿/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.search;

import std.experimental.logger;
import std.format;

import gdk.Event;
import gdk.Keysyms;

import gio.ActionGroupIF;
import gio.Menu;
import gio.Settings : GSettings = Settings;
import gio.SimpleAction;
import gio.SimpleActionGroup;

import glib.GException;
import glib.Regex: GRegex = Regex;
import glib.Variant : GVariant = Variant;

import gtk.Box;
import gtk.Button;
import gtk.CheckButton;
import gtk.Frame;
import gtk.Image;
import gtk.MenuButton;
import gtk.Popover;
import gtk.Revealer;
import gtk.SearchEntry;
import gtk.ToggleButton;
import gtk.Widget;
import gtk.Version;

import vte.Regex: VRegex = Regex;
import vte.Terminal : VTE = Terminal;

import gx.gtk.actions;
import gx.gtk.vte;
import gx.i18n.l10n;

import gx.tilix.common;
import gx.tilix.constants;
import gx.tilix.preferences;
import gx.tilix.terminal.actions;

/**
 * Widget that displays the Find UI for a terminal and manages the search actions
 */
class SearchRevealer : Revealer {

private:

    enum ACTION_SEARCH_PREFIX = "search";
    enum ACTION_SEARCH_MATCH_CASE = "match-case";
    enum ACTION_SEARCH_ENTIRE_WORD_ONLY = "entire-word";
    enum ACTION_SEARCH_MATCH_REGEX = "match-regex";
    enum ACTION_SEARCH_WRAP_AROUND = "wrap-around";

    GSettings gsSettings;

    VTE vte;
    ActionGroupIF terminalActions;
    SimpleActionGroup sagSearch;

    SearchEntry seSearch;

    MenuButton mbOptions;
    bool matchCase;
    bool entireWordOnly;
    bool matchAsRegex;

    /**
     * Creates the find overlay
     */
    void createUI() {
        createActions();

        setHexpand(true);
        setVexpand(false);
        setHalign(GtkAlign.FILL);
        setValign(GtkAlign.START);

        Box bSearch = new Box(Orientation.HORIZONTAL, 6);
        bSearch.setHalign(GtkAlign.CENTER);
        bSearch.setMarginLeft(4);
        bSearch.setMarginRight(4);
        bSearch.setMarginTop(4);
        bSearch.setMarginBottom(4);
        bSearch.setHexpand(true);

        Box bEntry = new Box(Orientation.HORIZONTAL, 0);
        bEntry.getStyleContext().addClass("linked");

        seSearch = new SearchEntry();
        seSearch.setWidthChars(1);
        seSearch.setMaxWidthChars(30);
        if (Version.checkVersion(3, 20, 0).length != 0) {
            seSearch.getStyleContext().addClass("tilix-search-entry");
        }
        seSearch.addOnSearchChanged(delegate(SearchEntry) {
            setTerminalSearchCriteria();
        });
        seSearch.addOnKeyRelease(delegate(Event event, Widget) {
            uint keyval;
            if (event.getKeyval(keyval)) {
                switch (keyval) {
                    case GdkKeysyms.GDK_Escape:
                        setRevealChild(false);
                        vte.grabFocus();
                        break;
                    case GdkKeysyms.GDK_Return:
                        if (event.key.state & GdkModifierType.SHIFT_MASK) {
                            terminalActions.activateAction(ACTION_FIND_NEXT, null);
                        } else {
                            terminalActions.activateAction(ACTION_FIND_PREVIOUS, null);
                        }
                        break;
                    default:
                }
            }
            return false;
        });
        bEntry.add(seSearch);

        mbOptions = new MenuButton();
        mbOptions.setTooltipText(_("Search Options"));
        mbOptions.setFocusOnClick(false);
        Image iHamburger = new Image("pan-down-symbolic", IconSize.MENU);
        mbOptions.add(iHamburger);
        mbOptions.setPopover(createPopover);
        bEntry.add(mbOptions);

        bSearch.add(bEntry);

        Box bButtons = new Box(Orientation.HORIZONTAL, 0);
        bButtons.getStyleContext().addClass("linked");

        Button btnNext = new Button("go-up-symbolic", IconSize.MENU);
        btnNext.setTooltipText(_("Find next"));
        btnNext.setActionName(getActionDetailedName(ACTION_PREFIX, ACTION_FIND_PREVIOUS));
        btnNext.setCanFocus(false);
        bButtons.add(btnNext);

        Button btnPrevious = new Button("go-down-symbolic", IconSize.MENU);
        btnPrevious.setTooltipText(_("Find previous"));
        btnPrevious.setActionName(getActionDetailedName(ACTION_PREFIX, ACTION_FIND_NEXT));
        btnPrevious.setCanFocus(false);
        bButtons.add(btnPrevious);

        bSearch.add(bButtons);

        Button btnClose = new Button("window-close-symbolic", IconSize.MENU);
        btnClose.setTooltipText(_("Close search box"));
        btnClose.setRelief(ReliefStyle.NONE);
        btnClose.setFocusOnClick(true);
        btnClose.addOnClicked(delegate(Button) {
            setRevealChild(false);
            vte.grabFocus();
        });
        bSearch.packEnd(btnClose, false, false, 0);

        Frame frame = new Frame(bSearch, null);
        frame.setShadowType(ShadowType.NONE);
        frame.getStyleContext().addClass("tilix-search-frame");
        add(frame);
    }

    void createActions() {
        GSettings gsGeneral = new GSettings(SETTINGS_ID);

        sagSearch = new SimpleActionGroup();

        registerAction(sagSearch, ACTION_SEARCH_PREFIX, ACTION_SEARCH_MATCH_CASE, null, delegate(GVariant value, SimpleAction sa) {
            matchCase = !sa.getState().getBoolean();
            sa.setState(new GVariant(matchCase));
            setTerminalSearchCriteria();
        }, null, gsGeneral.getValue(SETTINGS_SEARCH_DEFAULT_MATCH_CASE));

        registerAction(sagSearch, ACTION_SEARCH_PREFIX, ACTION_SEARCH_ENTIRE_WORD_ONLY, null, delegate(GVariant value, SimpleAction sa) {
            entireWordOnly = !sa.getState().getBoolean();
            sa.setState(new GVariant(entireWordOnly));
            setTerminalSearchCriteria();
        }, null, gsGeneral.getValue(SETTINGS_SEARCH_DEFAULT_MATCH_ENTIRE_WORD));

        registerAction(sagSearch, ACTION_SEARCH_PREFIX, ACTION_SEARCH_MATCH_REGEX, null, delegate(GVariant value, SimpleAction sa) {
            matchAsRegex = !sa.getState().getBoolean();
            sa.setState(new GVariant(matchAsRegex));
            setTerminalSearchCriteria();
        }, null, gsGeneral.getValue(SETTINGS_SEARCH_DEFAULT_MATCH_AS_REGEX));

        registerAction(sagSearch, ACTION_SEARCH_PREFIX, ACTION_SEARCH_WRAP_AROUND, null, delegate(GVariant value, SimpleAction sa) {
            bool newState = !sa.getState().getBoolean();
            sa.setState(new GVariant(newState));
            vte.searchSetWrapAround(newState);
        }, null, gsGeneral.getValue(SETTINGS_SEARCH_DEFAULT_WRAP_AROUND));

        updateActionsState ();
        insertActionGroup(ACTION_SEARCH_PREFIX, sagSearch);
    }

    Popover createPopover() {
        Menu model = new Menu();
        model.append(_("Match case"), getActionDetailedName(ACTION_SEARCH_PREFIX, ACTION_SEARCH_MATCH_CASE));
        model.append(_("Match entire word only"), getActionDetailedName(ACTION_SEARCH_PREFIX, ACTION_SEARCH_ENTIRE_WORD_ONLY));
        model.append(_("Wrap around"), getActionDetailedName(ACTION_SEARCH_PREFIX, ACTION_SEARCH_WRAP_AROUND));
        model.append(_("Match as regular expression"), getActionDetailedName(ACTION_SEARCH_PREFIX, ACTION_SEARCH_MATCH_REGEX));

        return new Popover(mbOptions, model);
    }

    void updateActionsState()
    {
        auto action = cast(SimpleAction) sagSearch.lookup(ACTION_SEARCH_MATCH_REGEX);
        bool alwaysUseRegex = gsSettings.getBoolean(SETTINGS_ALWAYS_USE_REGEX_IN_SEARCH);
        action.setEnabled(!alwaysUseRegex);
        action.setState(new GVariant(alwaysUseRegex));
        matchAsRegex = alwaysUseRegex;
    }

    void setTerminalSearchCriteria() {
        string text = seSearch.getText();
        if (text.length == 0) {
            vte.searchSetRegex(null, 0);
            return;
        }

        if (!matchAsRegex)
            text = GRegex.escapeString(text);
        if (entireWordOnly)
            text = format("\\b%s\\b", text);

        try {
            uint flags = PCRE2Flags.UTF | PCRE2Flags.MULTILINE | PCRE2Flags.NO_UTF_CHECK;
            if (!matchCase) {
                flags |= PCRE2Flags.CASELESS;
            }
            trace("Setting VTE.Regex for pattern %s", text);
            vte.searchSetRegex(VRegex.newSearch(text, -1, flags), 0);
            seSearch.getStyleContext().removeClass("error");
        } catch (GException ge) {
            string message = format(_("Search '%s' is not a valid regex\n%s"), text, ge.msg);
            seSearch.getStyleContext().addClass("error");
            error(message);
            error(ge.msg);
        }
    }

public:

    this(VTE vte, ActionGroupIF terminalActions) {
        super();

        this.vte = vte;
        this.terminalActions = terminalActions;

        gsSettings = new GSettings(SETTINGS_ID);
        createUI();
        gsSettings.addOnChanged(delegate(string key, GSettings) {
            if (key == SETTINGS_ALWAYS_USE_REGEX_IN_SEARCH)
                updateActionsState();
        });

        this.addOnDestroy(delegate(Widget) {
            this.vte = null;
            this.terminalActions = null;
        });
        seSearch.addOnFocusIn(delegate(Event event, Widget widget) {
            onSearchEntryFocusIn.emit(widget);
            return false;
        });
        seSearch.addOnFocusIn(delegate(Event event, Widget widget) {
            onSearchEntryFocusOut.emit(widget);
            return false;
        });
    }

    void focusSearchEntry() {
        seSearch.grabFocus();
    }

    bool hasSearchEntryFocus() {
        return seSearch.hasFocus();
    }

    bool isSearchEntryFocus() {
        return seSearch.isFocus();
    }

    GenericEvent!(Widget) onSearchEntryFocusIn;

    GenericEvent!(Widget) onSearchEntryFocusOut;
}
