/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.terminal.search;

import std.experimental.logger;
import std.format;

import gdk.Event;
import gdk.Keysyms;

import gio.Menu;
import gio.Settings : GSettings = Settings;
import gio.SimpleAction;
import gio.SimpleActionGroup;

import glib.Regex;
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

import vte.Terminal : VTE = Terminal;

import gx.gtk.actions;
import gx.i18n.l10n;

import gx.terminix.terminal.actions;
import gx.terminix.preferences;

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

    VTE vte;

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
        setHalign(Align.FILL);
        setValign(Align.START);

        Box bSearch = new Box(Orientation.HORIZONTAL, 6);
        bSearch.setHalign(Align.CENTER);
        bSearch.setMarginLeft(4);
        bSearch.setMarginRight(4);
        bSearch.setMarginTop(4);
        bSearch.setMarginBottom(4);
        bSearch.setHexpand(true);

        Box bEntry = new Box(Orientation.HORIZONTAL, 0);
        bEntry.getStyleContext().addClass("linked");

        seSearch = new SearchEntry();
        //seSearch.setHexpand(true);
        seSearch.setWidthChars(30);
        seSearch.addOnSearchChanged(delegate(SearchEntry) { setTerminalSearchCriteria(); });
        seSearch.addOnKeyRelease(delegate(Event event, Widget) {
            uint keyval;
            if (event.getKeyval(keyval) && keyval == GdkKeysyms.GDK_Escape)
                setRevealChild(false);
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

        Button btnUp = new Button("go-up-symbolic", IconSize.MENU);
        btnUp.setActionName(getActionDetailedName(ACTION_PREFIX, ACTION_FIND_PREVIOUS));
        btnUp.setCanFocus(false);
        bButtons.add(btnUp);

        Button btnDown = new Button("go-down-symbolic", IconSize.MENU);
        btnDown.setActionName(getActionDetailedName(ACTION_PREFIX, ACTION_FIND_NEXT));
        btnDown.setCanFocus(false);
        bButtons.add(btnDown);

        bSearch.add(bButtons);

        Frame frame = new Frame(bSearch, null);
        frame.getStyleContext().addClass("notebook");
        frame.getStyleContext().addClass("header");
        frame.getStyleContext().addClass("terminix-search-slider");

        add(frame);
    }

    void createActions() {
        GSettings gsGeneral = new GSettings(SETTINGS_ID);

        SimpleActionGroup sagSearch = new SimpleActionGroup();

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

        insertActionGroup(ACTION_SEARCH_PREFIX, sagSearch);
    }

    Popover createPopover() {
        Menu model = new Menu();
        model.append(_("Match case"), getActionDetailedName(ACTION_SEARCH_PREFIX, ACTION_SEARCH_MATCH_CASE));
        model.append(_("Match entire word only"), getActionDetailedName(ACTION_SEARCH_PREFIX, ACTION_SEARCH_ENTIRE_WORD_ONLY));
        model.append(_("Match as regular expression"), getActionDetailedName(ACTION_SEARCH_PREFIX, ACTION_SEARCH_MATCH_REGEX));
        model.append(_("Wrap around"), getActionDetailedName(ACTION_SEARCH_PREFIX, ACTION_SEARCH_WRAP_AROUND));

        return new Popover(mbOptions, model);
    }

    void setTerminalSearchCriteria() {
        string text = seSearch.getText();
        if (!matchAsRegex)
            text = Regex.escapeString(text);
        if (entireWordOnly)
            text = format("\\b%s\\b", text);
        GRegexCompileFlags flags;
        if (!matchCase)
            flags = flags | GRegexCompileFlags.CASELESS;
        if (text.length > 0) {
            Regex regex = new Regex(text, flags, cast(GRegexMatchFlags) 0);
            vte.searchSetGregex(regex, cast(GRegexMatchFlags) 0);
        } else {
            vte.searchSetGregex(null, cast(GRegexMatchFlags) 0);
        }
    }

public:

    this(VTE vte) {
        super();
        this.vte = vte;
        createUI();
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

    void addOnSearchEntryFocusIn(bool delegate(Event, Widget) dlg) {
        seSearch.addOnFocusIn(dlg);
    }

    void addOnSearchEntryFocusOut(bool delegate(Event, Widget) dlg) {
        seSearch.addOnFocusOut(dlg);
    }
}
