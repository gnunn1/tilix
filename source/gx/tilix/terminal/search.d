/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.search;

import std.experimental.logger;
import std.format;

import gdk.event;
import gdk.event_focus;
import gdk.event_key;
import gdk.types;
import gx.gtk.keys;
import gx.gtk.types;
import gdk.types;

import gio.action_group;
import gio.menu;
import gio.settings : Settings = Settings;
import gio.simple_action;
import gio.simple_action_group;

import glib.error;
import glib.regex: Regex = Regex;
import glib.variant : Variant = Variant;

import gtk.box;
import gtk.global;
import gtk.types;
import gtk.button;
import gtk.types;
import gtk.check_button;
import gtk.types;
import gtk.frame;
import gtk.types;
import gtk.image;
import gtk.types;
import gtk.menu_button;
import gtk.types;
import gtk.popover;
import gtk.types;
import gtk.revealer;
import gtk.types;
import gtk.search_entry;
import gtk.types;
import gtk.toggle_button;
import gtk.types;
import gtk.widget;
import gtk.types;


import vte.regex: VRegex = Regex;
import vte.terminal : VTE = Terminal;

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

    Settings gsSettings;

    VTE vte;
    ActionGroup terminalActions;
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
        setHalign(Align.Fill);
        setValign(Align.Start);

        Box bSearch = new Box(gtk.types.Orientation.Horizontal, 6);
        bSearch.setHalign(Align.Center);
        bSearch.setMarginLeft(4);
        bSearch.setMarginRight(4);
        bSearch.setMarginTop(4);
        bSearch.setMarginBottom(4);
        bSearch.setHexpand(true);

        Box bEntry = new Box(gtk.types.Orientation.Horizontal, 0);
        bEntry.getStyleContext().addClass("linked");

        seSearch = new SearchEntry();
        seSearch.setWidthChars(1);
        seSearch.setMaxWidthChars(30);
        if (gtk.global.checkVersion(3, 20, 0).length != 0) {
            seSearch.getStyleContext().addClass("tilix-search-entry");
        }
        seSearch.connectSearchChanged(delegate(SearchEntry se) {
            setTerminalSearchCriteria();
        });
        seSearch.connectKeyReleaseEvent(delegate(EventKey event, Widget w) {
            uint keyval = event.keyval;
            switch (keyval) {
                case Keys.Escape:
                    setRevealChild(false);
                    vte.grabFocus();
                    break;
                case Keys.Return:
                    if (event.state & gdk.types.ModifierType.ShiftMask) {
                        terminalActions.activateAction(ACTION_FIND_NEXT, null);
                    } else {
                        terminalActions.activateAction(ACTION_FIND_PREVIOUS, null);
                    }
                    break;
                default:
            }
            return false;
        });
        bEntry.add(seSearch);

        mbOptions = new MenuButton();
        mbOptions.setTooltipText(_("Search Options"));
        mbOptions.setFocusOnClick(false);
        Image iHamburger = Image.newFromIconName("pan-down-symbolic", IconSize.Menu);
        mbOptions.add(iHamburger);
        mbOptions.setPopover(createPopover);
        bEntry.add(mbOptions);

        bSearch.add(bEntry);

        Box bButtons = new Box(gtk.types.Orientation.Horizontal, 0);
        bButtons.getStyleContext().addClass("linked");

        Button btnNext = new Button();
        btnNext.setImage(Image.newFromIconName("go-up-symbolic", IconSize.Menu));
        btnNext.setTooltipText(_("Find next"));
        btnNext.setActionName(getActionDetailedName(ACTION_PREFIX, ACTION_FIND_PREVIOUS));
        btnNext.setCanFocus(false);
        bButtons.add(btnNext);

        Button btnPrevious = new Button();
        btnPrevious.setImage(Image.newFromIconName("go-down-symbolic", IconSize.Menu));
        btnPrevious.setTooltipText(_("Find previous"));
        btnPrevious.setActionName(getActionDetailedName(ACTION_PREFIX, ACTION_FIND_NEXT));
        btnPrevious.setCanFocus(false);
        bButtons.add(btnPrevious);

        bSearch.add(bButtons);

        Button btnClose = new Button();
        btnClose.setImage(Image.newFromIconName("window-close-symbolic", IconSize.Menu));
        btnClose.setTooltipText(_("Close search box"));
        btnClose.setRelief(ReliefStyle.None);
        btnClose.setFocusOnClick(true);
        btnClose.connectClicked(delegate(Button btn) {
            setRevealChild(false);
            vte.grabFocus();
        });
        bSearch.packEnd(btnClose, false, false, 0);

        Frame frame = new Frame(null);
        frame.add(bSearch);
        frame.setShadowType(ShadowType.None);
        frame.getStyleContext().addClass("tilix-search-frame");
        add(frame);
    }

    void createActions() {
        Settings gsGeneral = new Settings(SETTINGS_ID);

        sagSearch = new SimpleActionGroup();

        registerAction(sagSearch, ACTION_SEARCH_PREFIX, ACTION_SEARCH_MATCH_CASE, null, delegate(Variant value, SimpleAction sa) {
            matchCase = !sa.getState().getBoolean();
            sa.setState(new Variant(matchCase));
            setTerminalSearchCriteria();
        }, null, gsGeneral.getValue(SETTINGS_SEARCH_DEFAULT_MATCH_CASE));

        registerAction(sagSearch, ACTION_SEARCH_PREFIX, ACTION_SEARCH_ENTIRE_WORD_ONLY, null, delegate(Variant value, SimpleAction sa) {
            entireWordOnly = !sa.getState().getBoolean();
            sa.setState(new Variant(entireWordOnly));
            setTerminalSearchCriteria();
        }, null, gsGeneral.getValue(SETTINGS_SEARCH_DEFAULT_MATCH_ENTIRE_WORD));

        registerAction(sagSearch, ACTION_SEARCH_PREFIX, ACTION_SEARCH_MATCH_REGEX, null, delegate(Variant value, SimpleAction sa) {
            matchAsRegex = !sa.getState().getBoolean();
            sa.setState(new Variant(matchAsRegex));
            setTerminalSearchCriteria();
        }, null, gsGeneral.getValue(SETTINGS_SEARCH_DEFAULT_MATCH_AS_REGEX));

        registerAction(sagSearch, ACTION_SEARCH_PREFIX, ACTION_SEARCH_WRAP_AROUND, null, delegate(Variant value, SimpleAction sa) {
            bool newState = !sa.getState().getBoolean();
            sa.setState(new Variant(newState));
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

        return Popover.newFromModel(mbOptions, model);
    }

    void updateActionsState()
    {
        auto action = cast(SimpleAction) sagSearch.lookup(ACTION_SEARCH_MATCH_REGEX);
        bool alwaysUseRegex = gsSettings.getBoolean(SETTINGS_ALWAYS_USE_REGEX_IN_SEARCH);
        action.setEnabled(!alwaysUseRegex);
        action.setState(new Variant(alwaysUseRegex));
        matchAsRegex = alwaysUseRegex;
    }

    void setTerminalSearchCriteria() {
        string text = seSearch.getText();
        if (text.length == 0) {
            vte.searchSetRegex(null, 0);
            return;
        }

        if (!matchAsRegex)
            text = Regex.escapeString(text);
        if (entireWordOnly)
            text = format("\\b%s\\b", text);

        try {
            uint flags = PCRE2Flags.UTF | PCRE2Flags.MULTILINE | PCRE2Flags.NO_UTF_CHECK;
            if (!matchCase) {
                flags |= PCRE2Flags.CASELESS;
            }
            trace("Setting VTE.Regex for pattern %s", text);
            vte.searchSetRegex(VRegex.newForSearch(text, -1, flags), 0);
            seSearch.getStyleContext().removeClass("error");
        } catch (ErrorWrap ge) {
            string message = format(_("Search '%s' is not a valid regex\n%s"), text, ge.msg);
            seSearch.getStyleContext().addClass("error");
            error(message);
            error(ge.msg);
        }
    }

public:

    this(VTE vte, ActionGroup terminalActions) {
        super();

        this.vte = vte;
        this.terminalActions = terminalActions;

        gsSettings = new Settings(SETTINGS_ID);
        createUI();
        gsSettings.connectChanged(null, delegate(string key, Settings s) {
            if (key == SETTINGS_ALWAYS_USE_REGEX_IN_SEARCH)
                updateActionsState();
        });

        this.connectDestroy(delegate() {
            this.vte = null;
            this.terminalActions = null;
        });
        seSearch.connectFocusInEvent(delegate(EventFocus event, Widget widget) {
            onSearchEntryFocusIn.emit(widget);
            return false;
        });
        seSearch.connectFocusOutEvent(delegate(EventFocus event, Widget widget) {
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
