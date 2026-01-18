/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.search;

import std.experimental.logger;
import std.format;

import gdk.event : Event;
import gdk.event_key : EventKey;
import gdk.event_focus : EventFocus;
import gdk.c.types : GdkModifierType;
// GID does not provide gdk.keysyms, define required constants locally
private enum GdkKeysyms { GDK_Return = 0xff0d, GDK_Escape = 0xff1b }

import gio.action_group : ActionGroup;
import gio.menu : GMenu = Menu;
import gio.settings : GSettings = Settings;
import gio.simple_action : SimpleAction;
import gio.simple_action_group : SimpleActionGroup;

import glib.error : ErrorWrap;
import glib.regex: GRegex = Regex;
import glib.variant : GVariant = Variant;

import gtk.box : Box;
import gtk.button : Button;
import gtk.check_button : CheckButton;
import gtk.frame : Frame;
import gtk.image : Image;
import gtk.menu_button : MenuButton;
import gtk.popover : Popover;
import gtk.revealer : Revealer;
import gtk.search_entry : SearchEntry;
import gtk.toggle_button : ToggleButton;
import gtk.widget : Widget;
import gtk.global : checkVersion;
import gtk.types : Align, IconSize, Orientation, ReliefStyle, ShadowType;

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

    GSettings gsSettings;

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

        Box bSearch = new Box(Orientation.Horizontal, 6);
        bSearch.setHalign(Align.Center);
        bSearch.setMarginLeft(4);
        bSearch.setMarginRight(4);
        bSearch.setMarginTop(4);
        bSearch.setMarginBottom(4);
        bSearch.setHexpand(true);

        Box bEntry = new Box(Orientation.Horizontal, 0);
        bEntry.getStyleContext().addClass("linked");

        seSearch = new SearchEntry();
        seSearch.setWidthChars(1);
        seSearch.setMaxWidthChars(30);
        if (checkVersion(3, 20, 0).length != 0) {
            seSearch.getStyleContext().addClass("tilix-search-entry");
        }
        seSearch.connectSearchChanged(delegate() {
            setTerminalSearchCriteria();
        });
        seSearch.connectKeyReleaseEvent(delegate(EventKey event) {
            uint keyval = event.keyval;
            switch (keyval) {
                case GdkKeysyms.GDK_Escape:
                    setRevealChild(false);
                    vte.grabFocus();
                    break;
                case GdkKeysyms.GDK_Return:
                    if (event.state & GdkModifierType.ShiftMask) {
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

        Box bButtons = new Box(Orientation.Horizontal, 0);
        bButtons.getStyleContext().addClass("linked");

        Button btnUp = Button.newFromIconName("go-up-symbolic", IconSize.Menu);
        btnUp.setTooltipText(_("Find next"));
        btnUp.setActionName(getActionDetailedName(ACTION_PREFIX, ACTION_FIND_PREVIOUS));
        btnUp.setCanFocus(false);
        bButtons.add(btnUp);

        Button btnDown = Button.newFromIconName("go-down-symbolic", IconSize.Menu);
        btnDown.setTooltipText(_("Find previous"));
        btnDown.setActionName(getActionDetailedName(ACTION_PREFIX, ACTION_FIND_NEXT));
        btnDown.setCanFocus(false);
        bButtons.add(btnDown);

        bSearch.add(bButtons);

        Button btnClose = Button.newFromIconName("window-close-symbolic", IconSize.Menu);
        btnClose.setRelief(ReliefStyle.None);
        btnClose.setFocusOnClick(false);
        btnClose.connectClicked(delegate() {
            this.setRevealChild(false);
            this.vte.grabFocus();
        });
        bSearch.packEnd(btnClose, false, false, 0);

        Frame frame = new Frame(null);
        frame.add(bSearch);
        frame.setShadowType(ShadowType.None);
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
        GMenu model = new GMenu();
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

        gsSettings = new GSettings(SETTINGS_ID);
        createUI();
        gsSettings.connectChanged(null, delegate(string key) {
            if (key == SETTINGS_ALWAYS_USE_REGEX_IN_SEARCH)
                updateActionsState();
        });

        connectDestroy(delegate() {
            this.vte = null;
            this.terminalActions = null;
        });
        seSearch.connectFocusInEvent(delegate(EventFocus event) {
            onSearchEntryFocusIn.emit(this);
            return false;
        });
        seSearch.connectFocusOutEvent(delegate(EventFocus event) {
            onSearchEntryFocusOut.emit(this);
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
