/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.terminal.search;

import std.experimental.logger;
import std.format;

import gdk.Event;
import gdk.Keysyms;

import gio.Settings: GSettings = Settings;

import glib.Regex;

import gtk.Box;
import gtk.Button;
import gtk.CheckButton;
import gtk.Frame;
import gtk.Revealer;
import gtk.SearchEntry;
import gtk.ToggleButton;

import vte.Terminal: VTE = Terminal;

import gx.i18n.l10n;

import gx.terminix.terminal.actions;
import gx.terminix.preferences;

/**
 * Widget that displays the Find UI for a terminal and manages the search actions
 */
class SearchRevealer: Revealer {

private:
    VTE vte;

    SearchEntry seSearch;
    CheckButton cbMatchCase;
    CheckButton cbEntireWordOnly;
    CheckButton cbMatchAsRegex;

    /**
     * Creates the find overlay
     */
    void createUI() {
        GSettings gsGeneral = new GSettings(SETTINGS_ID);
        
        setHexpand(false);
        setVexpand(false);
        setHalign(Align.END);
        setValign(Align.START);
              
        Box bSearch = new Box(Orientation.VERTICAL, 12);
        bSearch.setHexpand(false);
        bSearch.setVexpand(false);

        Box bEntry = new Box(Orientation.HORIZONTAL, 0);            
        seSearch = new SearchEntry();
        seSearch.setWidthChars(30);
        seSearch.addOnSearchChanged(delegate(SearchEntry se) {
            setTerminalSearchCriteria();
        });
        seSearch.addOnKeyRelease(delegate(Event event, Widget) {
            uint keyval;
            if (event.getKeyval(keyval) && keyval == GdkKeysyms.GDK_Escape)
                setRevealChild(false);
            return false;
        });
        bEntry.add(seSearch);

        Button upButton = new Button("go-up-symbolic", IconSize.MENU);
        upButton.setActionName(ACTION_PREFIX ~ "." ~ ACTION_FIND_PREVIOUS);
        upButton.setCanFocus(false);
        bEntry.add(upButton);
        
        Button downButton = new Button("go-down-symbolic", IconSize.MENU);
        downButton.setActionName(ACTION_PREFIX ~ "." ~ ACTION_FIND_NEXT);
        downButton.setCanFocus(false);
        bEntry.add(downButton);
        
        bSearch.add(bEntry);
        
        Box bOptions = new Box(Orientation.VERTICAL, 6);

        cbMatchCase = new CheckButton(_("Match case"));
        cbMatchCase.setActive(gsGeneral.getBoolean(SETTINGS_SEARCH_DEFAULT_MATCH_CASE));
        cbMatchCase.addOnToggled(delegate(ToggleButton cb) {
            setTerminalSearchCriteria();
        });
        bOptions.add(cbMatchCase);

        cbEntireWordOnly = new CheckButton(_("Match entire word only"));
        cbEntireWordOnly.setActive(gsGeneral.getBoolean(SETTINGS_SEARCH_DEFAULT_MATCH_ENTIRE_WORD));
        cbEntireWordOnly.addOnToggled(delegate(ToggleButton cb) {
            setTerminalSearchCriteria();
        });
        bOptions.add(cbEntireWordOnly);
        
        cbMatchAsRegex = new CheckButton(_("Match as regular expression"));
        cbMatchAsRegex.setActive(gsGeneral.getBoolean(SETTINGS_SEARCH_DEFAULT_MATCH_AS_REGEX));
        cbMatchAsRegex.addOnToggled(delegate(ToggleButton cb) {
            setTerminalSearchCriteria();        
        });
        bOptions.add(cbMatchAsRegex);
        
        CheckButton cbWrapAround = new CheckButton(_("Wrap around"));
        cbWrapAround.setActive(gsGeneral.getBoolean(SETTINGS_SEARCH_DEFAULT_WRAP_AROUND));
        cbWrapAround.addOnToggled(delegate(ToggleButton cb) {
            vte.searchSetWrapAround(cb.getActive());        
        });
        bOptions.add(cbWrapAround);

        bSearch.add(bOptions);
        
        Frame frame = new Frame(bSearch, null);
        frame.getStyleContext().addClass("notebook");
        frame.getStyleContext().addClass("header");
        frame.getStyleContext().addClass("terminix-search-slider");
        add(frame);
    }
    
    void setTerminalSearchCriteria() {
        string text = seSearch.getText();
        if (!cbMatchAsRegex.getActive())
            text = Regex.escapeString(text);
        if (cbEntireWordOnly.getActive())
            text = format("\\b%s\\b", text);
        GRegexCompileFlags flags;
        if (!cbMatchCase.getActive()) flags = flags | GRegexCompileFlags.CASELESS;
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
}