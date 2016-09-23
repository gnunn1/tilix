/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.sessionswitcher;

import std.algorithm.searching;
import std.conv;
import std.experimental.logger;
import std.format;
import std.path;
import std.regex;
import std.string;

import gdk.Event;
import gdk.Keysyms;

import gobject.ObjectG;

import gtk.Box;
import gtk.Frame;
import gtk.Image;
import gtk.Label;
import gtk.ListBox;
import gtk.ListBoxRow;
import gtk.Revealer;
import gtk.ScrolledWindow;
import gtk.SearchEntry;
import gtk.Version;
import gtk.Widget;

import gx.i18n.l10n;

static import gx.util.array;

import gx.terminix.common;
import gx.terminix.session;

/**
 * Event used when a session file is selected.
 */
alias OnSSSessionFileSelected = void delegate(string file);

/**
 * Event used when a session file is removed.
 */
alias OnSSSessionFileRemoved = void delegate(string file);

/**
 * Event used when an open session is selected.
 */
alias OnSSOpenSessionSelected = void delegate(string uuid);

/**
 * Event used when an open session is removed.
 */
alias OnSSOpenSessionRemoved = bool delegate(string uuid);

extern (C) alias FilterCallback = static int function(gtkc.gtktypes.GtkListBoxRow*, void*);
extern (C) alias DestroyNotify = static void function(void*);

/**
 * Provides the session loading drop down
 */
class SessionSwitcher : Revealer {
private:

    Box bSearch;

    ListBox lbSessions;

    ScrolledWindow sw;

    SearchEntry seSearch;

    OnSSSessionFileSelected[] sessionFileSelectedDelegates;

    OnSSSessionFileRemoved[] sessionFileRemovedDelegates;

    OnSSOpenSessionSelected[] openSessionSelectedDelegates;

    OnSSOpenSessionRemoved[] openSessionRemovedDelegates;

    void createUI() {
        addOnButtonPress(&onButtonPress);
        setTransitionType(RevealerTransitionType.SLIDE_DOWN);
        setHexpand(false);
        setVexpand(false);
        setHalign(Align.CENTER);
        setValign(Align.START);

        bSearch = new Box(Orientation.VERTICAL, 6);
        bSearch.setHalign(Align.CENTER);
        bSearch.setMarginLeft(12);
        bSearch.setMarginRight(12);
        bSearch.setMarginTop(12);
        bSearch.setMarginBottom(12);
        bSearch.setHexpand(true);
        bSearch.addOnKeyRelease(&onSearchBoxKeyRelease);

        seSearch = new SearchEntry();
        seSearch.setWidthChars(1);
        seSearch.setMaxWidthChars(50);
        if (Version.checkVersion(3, 20, 0).length != 0) {
            seSearch.getStyleContext().addClass("terminix-search-entry");
        }
        seSearch.addOnKeyRelease(&onSearchEntryKeyRelease);
        bSearch.add(seSearch);

        lbSessions = new ListBox();
        lbSessions.addOnRowActivated(delegate(ListBoxRow row, ListBox) {
            onRowActivated(row);
        });
        lbSessions.addOnKeyRelease(&onListBoxKeyRelease);
        lbSessions.addOnKeynavFailed(&onListBoxKeynavFailed);

        FilterCallback filter = function(pRow, pSearchEntry) {
            SessionListBoxRow row = cast(SessionListBoxRow)ObjectG.getDObject!(ListBoxRow)(cast(GtkListBoxRow*)pRow);
            SearchEntry searchEntry = ObjectG.getDObject!(SearchEntry)(cast(GtkSearchEntry*)pSearchEntry);

            string filter = searchEntry.getText();

            if (filter.length == 0) {
                row.setLabelText();
                return true;
            }

            if (row.matches(filter)) {
                row.setLabelText(filter);
                return true;
            }

            return false;
        };
        DestroyNotify dn = function(data){};
        lbSessions.setFilterFunc(filter, cast(void*)seSearch.getSearchEntryStruct(), dn);

        sw = new ScrolledWindow(lbSessions);
        sw.setShadowType(ShadowType.ETCHED_IN);
        sw.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sw.setHexpand(true);
        sw.setVexpand(true);
        bSearch.add(sw);

        Frame frame = new Frame(bSearch, null);
        frame.setShadowType(ShadowType.IN);
        frame.getStyleContext().addClass("terminix-session-switcher");
        add(frame);
    }

    bool onButtonPress(Event event, Widget w) {
        //If button press happened outside of the switcher close it
        if (event.getWindow() !is null && bSearch.getWindow() !is null && lbSessions.getWindow() !is null) {
            if (event.getWindow().getWindowStruct() != getWindow().getWindowStruct()
                && event.getWindow().getWindowStruct() != bSearch.getWindow().getWindowStruct()
                && event.getWindow().getWindowStruct() != lbSessions.getWindow().getWindowStruct()) {
                notifyOpenSessionSelected(null);
            }
        }
        return false;
    }

    void onRowActivated(ListBoxRow row) {
        if (auto fRow = cast(FileSessionListBoxRow)row) {
            notifySessionFileSelected(fRow.identifier);
        } else if (auto oRow = cast(OpenSessionListBoxRow)row) {
            notifyOpenSessionSelected(oRow.identifier);
        }
    }

    bool onSearchBoxKeyRelease(Event event, Widget) {
        uint keyval;
        if (event.getKeyval(keyval)) {
            switch (keyval) {
                case GdkKeysyms.GDK_Escape:
                    notifySessionFileSelected();
                    break;
                default:
            }
        }
        return false;
    }

    bool onSearchEntryKeyRelease(Event event, Widget) {
        uint keyval;
        if (event.getKeyval(keyval)) {
            switch (keyval) {
                case GdkKeysyms.GDK_Return:
                    // getRowAtY(0) is used as getRowAtIndex() doesn't take into account
                    // rows that have been hidden due to filtering.
                    SessionListBoxRow row = cast(SessionListBoxRow)lbSessions.getRowAtY(0);
                    if (row) {
                        onRowActivated(row);
                    }
                    break;
                default:
                    // The filter is invalidated on key release, rather than "onSearchChanged" to
                    // avoid the 150ms delay between keypress and filtering.
                    lbSessions.invalidateFilter();
                    break;
            }
        }
        return false;
    }

    bool onListBoxKeyRelease(Event event, Widget) {
        uint keyval;
        if (event.getKeyval(keyval)) {
            switch (keyval) {
                case GdkKeysyms.GDK_Delete:
                    SessionListBoxRow row = cast(SessionListBoxRow)lbSessions.getSelectedRow();
                    if (auto fRow = cast(FileSessionListBoxRow)row) {
                        notifySessionFileRemoved(fRow.identifier);
                    } else if (auto oRow = cast(OpenSessionListBoxRow)row) {
                        notifyOpenSessionRemoved(oRow.identifier);
                    }
                    seSearch.grabFocusWithoutSelecting();
                    break;
                default:
            }
        }
        return false;
    }

    bool onListBoxKeynavFailed(GtkDirectionType direction, Widget) {
        switch (direction) {
            case GtkDirectionType.DOWN:
            case GtkDirectionType.UP:
                seSearch.grabFocusWithoutSelecting();
                lbSessions.unselectAll();
                break;
            default:
        }
        return false;
    }

    void notifySessionFileSelected(string file = null) {
        foreach (sessionFileSelected; sessionFileSelectedDelegates) {
            sessionFileSelected(file);
        }
    }

    void notifySessionFileRemoved(string file = null) {
        foreach (sessionFileRemoved; sessionFileRemovedDelegates) {
            sessionFileRemoved(file);
        }
    }

    void notifyOpenSessionSelected(string uuid = null) {
        foreach (openSessionSelected; openSessionSelectedDelegates) {
            openSessionSelected(uuid);
        }
    }

    void notifyOpenSessionRemoved(string uuid = null) {
        foreach (openSessionRemoved; openSessionRemovedDelegates) {
            openSessionRemoved(uuid);
        }
    }

    void populateOpenSessions(Session[] sessions) {
        foreach (session; sessions) {
            OpenSessionListBoxRow row = new OpenSessionListBoxRow(session);
            lbSessions.add(row);
        }
    }

    void populateFileSessions(string[] files) {
        foreach (file; files) {
            FileSessionListBoxRow row = new FileSessionListBoxRow(file);
            lbSessions.add(row);
        }
    }

public:
    this() {
        super();
        createUI();
        addOnRealize(delegate(Widget) {
            sw.setSizeRequest(-1, 200);
        });
    }

    void focusSearchEntry() {
        seSearch.setText("");
        seSearch.grabFocus();
    }

    void populate(Session[] sessions, string[] files) {
        lbSessions.removeAll();
        populateOpenSessions(sessions);
        populateFileSessions(files);
        lbSessions.showAll();
    }

    void addOnSessionFileSelected(OnSSSessionFileSelected dlg) {
        sessionFileSelectedDelegates ~= dlg;
    }

    void removeOnSessionFileSelected(OnSSSessionFileSelected dlg) {
        gx.util.array.remove(sessionFileSelectedDelegates, dlg);
    }

    void addOnSessionFileRemoved(OnSSSessionFileRemoved dlg) {
        sessionFileRemovedDelegates ~= dlg;
    }

    void removeOnSessionFileRemoved(OnSSSessionFileRemoved dlg) {
        gx.util.array.remove(sessionFileRemovedDelegates, dlg);
    }

    void addOnOpenSessionSelected(OnSSOpenSessionSelected dlg) {
        openSessionSelectedDelegates ~= dlg;
    }

    void removeOnOpenSessionSelected(OnSSOpenSessionSelected dlg) {
        gx.util.array.remove(openSessionSelectedDelegates, dlg);
    }

    void addOnOpenSessionRemoved(OnSSOpenSessionRemoved dlg) {
        openSessionRemovedDelegates ~= dlg;
    }

    void removeOnOpenSessionRemoved(OnSSOpenSessionRemoved dlg) {
        gx.util.array.remove(openSessionRemovedDelegates, dlg);
    }

    override void setRevealChild(bool revealChild) {
        super.setRevealChild(revealChild);
        if (revealChild) {
            if (!hasGrab()) {
                grabAdd();
            }
            seSearch.grabFocus();
        } else {
            if (hasGrab()) {
                grabRemove();
            }
        }
    }
}

private:
class SessionListBoxRow : ListBoxRow {
private:
    /**
     * Unique ID of the item.
     */
    string _identifier;

    /**
     * String to be checked when filtering the list.
     */
    string _filterable;

    /**
     * Text to display on the label.
     */
    string _labelText;

    /**
     * Icon to display.
     */
    string _icon;

    Label label;

    void createUI() {
        Box hBox = new Box(Orientation.HORIZONTAL, 6);

        Image image = new Image(_icon, IconSize.LARGE_TOOLBAR);
        image.setMarginLeft(6);
        image.setMarginRight(6);
        image.setMarginTop(6);
        image.setMarginBottom(6);
        hBox.add(image);

        label = new Label("");
        setLabelText();

        hBox.add(label);
        add(hBox);
    }

public:
    this() {
        super();
        createUI();
    }

    bool matches(string filter) {
        return canFind(_filterable.toLower(), filter.toLower());
    }

    void setLabelText(string highlight = null) {
        if (highlight == null) {
            label.setText(_labelText);
        } else {
            label.setMarkup(_labelText.replaceAll(regex("(" ~ highlight ~ ")", "i"), "<b>$1</b>"));
        }
    }

    @property string identifier() {
        return _identifier;
    }
}

class FileSessionListBoxRow : SessionListBoxRow {
public:
    this(string path) {
        _identifier = path;
        _filterable = path;
        _labelText = baseName(path) ~ "\n" ~ path;
        _icon = "document-open-symbolic";
        super();
    }

}

class OpenSessionListBoxRow : SessionListBoxRow {
public:
    this(Session session) {
        _identifier = session.uuid;
        _filterable = session.displayName;
        _labelText = session.displayName;
        _icon = "document-open-symbolic";
        super();
    }
}
