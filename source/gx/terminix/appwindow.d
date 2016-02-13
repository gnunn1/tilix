/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.appwindow;

import core.memory;

import std.conv;
import std.experimental.logger;
import std.file;
import std.format;
import std.json;

import cairo.Context;

import gtk.Application : Application;
import gio.Application : GioApplication = Application;
import gtk.ApplicationWindow : ApplicationWindow;
import gtkc.giotypes : GApplicationFlags;

import gdk.Event;
import gdk.Screen;
import gdk.Visual;

import gio.ActionIF;
import gio.ActionMapIF;
import gio.Menu : GMenu = Menu;
import gio.MenuItem : GMenuItem = MenuItem;
import gio.Notification;
import gio.Settings : GSettings = Settings;
import gio.SimpleAction;
import gio.SimpleActionGroup;

import glib.Util;
import glib.Variant : GVariant = Variant;
import glib.VariantType : GVariantType = VariantType;

import gtk.Box;
import gtk.Button;
import gtk.EventBox;
import gtk.FileChooserDialog;
import gtk.FileFilter;
import gtk.HeaderBar;
import gtk.Image;
import gtk.Label;
import gtk.ListBox;
import gtk.ListBoxRow;
import gtk.MenuButton;
import gtk.MessageDialog;
import gtk.Notebook;
import gtk.Popover;
import gtk.ScrolledWindow;
import gtk.StyleContext;
import gtk.Widget;

import vte.Pty;
import vte.Terminal;

import gx.gtk.actions;
import gx.gtk.util;
import gx.i18n.l10n;

import gx.terminix.application;
import gx.terminix.common;
import gx.terminix.constants;
import gx.terminix.cmdparams;
import gx.terminix.preferences;
import gx.terminix.session;

/**
 * The GTK Application Window for Terminix. It is responsible for
 * managing sessions which are held as pages in a GTK Notebook. All
 * session actions are created and managed here but against the session
 * prefix rather then the win prefix which is typically used for
 * a AplicationWindow.
 */
class AppWindow : ApplicationWindow {

private:

    enum DEFAULT_SESSION_NAME = "Default";

    enum ACTION_PREFIX = "session";
    enum ACTION_SESSION_LIST = "list";
    enum ACTION_SESSION_CLOSE = "close";
    enum ACTION_SESSION_NAME = "name";
    enum ACTION_SESSION_NEXT_TERMINAL = "switch-to-next-terminal";
    enum ACTION_SESSION_PREV_TERMINAL = "switch-to-previous-terminal";
    enum ACTION_SESSION_TERMINAL_X = "switch-to-terminal-";
    enum ACTION_SESSION_SAVE = "save";
    enum ACTION_SESSION_SAVE_AS = "save-as";
    enum ACTION_SESSION_LOAD = "load";
    enum ACTION_SESSION_SYNC_INPUT = "synchronize-input";
    enum ACTION_WIN_SESSION_X = "switch-to-session-";

    Notebook nb;
    HeaderBar hb;

    GMenu sessionMenu;
    SimpleAction saSessionSelect;
    MenuButton mbSessions;

    SimpleActionGroup sessionActions;
    MenuButton mbSessionActions;
    SimpleAction saSyncInput;
    SimpleAction saCloseSession;

    MenuButton mbSessionNotifications;
    Label lblNotifications;
    SessionNotificationPopover poSessionNotifications;

    SessionNotification[string] sessionNotifications;

    GSettings gsSettings;

    /**
     * Create the user interface
     */
    void createUI() {
        GSettings gsShortcuts = new GSettings(SETTINGS_PROFILE_KEY_BINDINGS_ID);

        createWindowActions(gsShortcuts);
        createSessionActions(gsShortcuts);

        //View sessions button
        mbSessions = new MenuButton();
        mbSessions.setTooltipText(_("Switch to a new session"));
        mbSessions.setFocusOnClick(false);
        Image iList = new Image("view-list-symbolic", IconSize.MENU);
        mbSessions.add(iList);
        sessionMenu = new GMenu();
        Popover pm = new Popover(mbSessions, sessionMenu);
        pm.setModal(true);
        mbSessions.setPopover(pm);
        mbSessions.addOnButtonPress(delegate(Event e, Widget w) { buildSessionMenu(); return false; });

        //New tab button
        Button btnNew = new Button("tab-new-symbolic", IconSize.BUTTON);
        btnNew.setFocusOnClick(false);
        btnNew.setAlwaysShowImage(true);
        btnNew.addOnClicked(delegate(Button button) { createSession(); });
        btnNew.setTooltipText(_("Create a new session"));

        //Session Actions
        mbSessionActions = new MenuButton();
        mbSessionActions.setFocusOnClick(false);
        Image iHamburger = new Image("open-menu-symbolic", IconSize.MENU);
        mbSessionActions.add(iHamburger);
        mbSessionActions.setPopover(createPopover(mbSessionActions));

        //Session Notification
        mbSessionNotifications = new MenuButton();
        mbSessionNotifications.setFocusOnClick(false);
        mbSessionNotifications.setVisible(false);
        lblNotifications = new Label("0");
        lblNotifications.getStyleContext().addClass("terminix-notification-counter");
        lblNotifications.show();
        mbSessionNotifications.add(lblNotifications);
        mbSessionNotifications.setNoShowAll(true);
        poSessionNotifications = new SessionNotificationPopover(mbSessionNotifications, this);
        mbSessionNotifications.setPopover(poSessionNotifications);
        mbSessionNotifications.addOnButtonPress(delegate(Event e, Widget w) { poSessionNotifications.populate(sessionNotifications.values); return false; });

        //Notebook
        nb = new Notebook();
        nb.setShowTabs(false);
        nb.addOnSwitchPage(delegate(Widget page, uint pageNo, Notebook) {
            Session session = cast(Session) page;
            //Remove any sessions associated with current page
            sessionNotifications.remove(session.sessionUUID);
            updateTitle(session);
            updateUIState();
            session.focusRestore();
            saSyncInput.setState(new GVariant(session.synchronizeInput));
        }, ConnectFlags.AFTER);

        if (gsSettings.getBoolean(SETTINGS_DISABLE_CSD_KEY)) {
            Box tb = new Box(Orientation.HORIZONTAL, 0);
            tb.packStart(mbSessions, false, false, 4);
            tb.packStart(btnNew, false, false, 4);
            tb.packEnd(mbSessionActions, false, false, 4);
            tb.packEnd(mbSessionNotifications, false, false, 4);
            tb.setMarginBottom(4);

            Box spacer = new Box(Orientation.VERTICAL, 0);
            spacer.getStyleContext().addClass("terminix-toolbar");
            spacer.packStart(tb, true, true, 0);

            Box b = new Box(Orientation.VERTICAL, 0);
            b.add(spacer);
            b.add(nb);
            add(b);
        } else {
            //Header Bar
            hb = new HeaderBar();
            hb.setShowCloseButton(true);
            hb.setTitle(_(APPLICATION_NAME));
            hb.packStart(mbSessions);
            hb.packStart(btnNew);
            hb.packEnd(mbSessionActions);
            hb.packEnd(mbSessionNotifications);
            this.setTitlebar(hb);
            add(nb);
        }
    }

    /**
     * Create Window actions
     */
    void createWindowActions(GSettings gsShortcuts) {
        //Create Switch to Session (0..9) actions
        //Can't use :: action targets for this since action name needs to be preferences 
        for (int i = 0; i <= 9; i++) {
            registerActionWithSettings(this, "win", ACTION_WIN_SESSION_X ~ to!string(i), gsShortcuts, delegate(Variant, SimpleAction sa) {
                int index = to!int(sa.getName()[$ - 1 .. $]);
                if (nb.getNPages() <= index) {
                    nb.setCurrentPage(index);
                }
            });
        }
    }

    /**
     * Create all the session actions and corresponding actions
     */
    void createSessionActions(GSettings gsShortcuts) {
        sessionActions = new SimpleActionGroup();

        //Select Session
        GVariant pu = new GVariant(0);
        saSessionSelect = registerAction(sessionActions, ACTION_PREFIX, ACTION_SESSION_LIST, null, delegate(GVariant value, SimpleAction sa) {
            nb.setCurrentPage(value.getInt32());
            saSessionSelect.setState(value);
            mbSessions.setActive(false);
        }, pu.getType(), pu);

        //Create Switch to Terminal (0..9) actions
        //Can't use :: action targets for this since action name needs to be preferences 
        for (int i = 0; i <= 9; i++) {
            registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_TERMINAL_X ~ to!string(i), gsShortcuts, delegate(Variant, SimpleAction sa) {
                Session session = getCurrentSession();
                if (session !is null) {
                    ulong terminalID = to!ulong(sa.getName()[$ - 1 .. $]);
                    session.focusTerminal(terminalID);
                }
            });
        }
        /* TODO - GTK doesn't support settings Tab for accelerators, need to look into this more */
        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_NEXT_TERMINAL, gsShortcuts, delegate(Variant, SimpleAction) {
            Session session = getCurrentSession();
            if (session !is null)
                session.focusNext();
        });
        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_PREV_TERMINAL, gsShortcuts, delegate(Variant, SimpleAction) {
            Session session = getCurrentSession();
            if (session !is null)
                session.focusPrevious();
        });

        //Close Session
        saCloseSession = registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_CLOSE, gsShortcuts, delegate(Variant, SimpleAction) {
            if (nb.getNPages > 1) {
                closeSession(getCurrentSession());
            }
        });

        //Load Session
        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_LOAD, gsShortcuts, delegate(Variant, SimpleAction) { loadSession(); });

        //Save Session
        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_SAVE, gsShortcuts, delegate(Variant, SimpleAction) { saveSession(false); });

        //Save As Session
        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_SAVE_AS, gsShortcuts, delegate(Variant, SimpleAction) { saveSession(true); });

        //Change name of session
        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_NAME, gsShortcuts, delegate(Variant, SimpleAction) {
            Session session = getCurrentSession();
            string name = session.name;
            if (showInputDialog(this, name, name, _("Change Session Name"), _("Enter a new name for the session"))) {
                if (name.length > 0) {
                    session.name = name;
                    updateTitle(session);
                }
            }
        });

        //Synchronize Input
        saSyncInput = registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_SYNC_INPUT, gsShortcuts, delegate(GVariant value, SimpleAction sa) {
            bool newState = !sa.getState().getBoolean();
            sa.setState(new GVariant(newState));
            getCurrentSession().synchronizeInput = newState;
            mbSessionActions.setActive(false);
        }, null, new GVariant(false));

        insertActionGroup(ACTION_PREFIX, sessionActions);
    }

    /**
     * Creates the session action popover
     */
    Popover createPopover(Widget parent) {
        GMenu model = new GMenu();

        GMenu mFileSection = new GMenu();
        mFileSection.appendItem(new GMenuItem(_("Load") ~ "...", getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_LOAD)));
        mFileSection.appendItem(new GMenuItem(_("Save"), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_SAVE)));
        mFileSection.appendItem(new GMenuItem(_("Save As") ~ "...", getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_SAVE_AS)));
        mFileSection.appendItem(new GMenuItem(_("Close"), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_CLOSE)));
        model.appendSection(null, mFileSection);

        GMenu mSessionSection = new GMenu();
        mSessionSection.appendItem(new GMenuItem(_("Name") ~ "...", getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_NAME)));
        mSessionSection.appendItem(new GMenuItem(_("Synchronize Input"), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_SYNC_INPUT)));
        model.appendSection(null, mSessionSection);

        return new Popover(parent, model);
    }

    /**
     * This is required to get terminal transparency working
     */
    void updateVisual() {
        Screen screen = getScreen();
        Visual visual = screen.getRgbaVisual();
        if (visual && screen.isComposited()) {
            trace("Setting rgba visual");
            setVisual(visual);
            setAppPaintable(true);
        } else {
            setVisual(screen.getSystemVisual());
            setAppPaintable(false);
        }
    }

    void createNewSession(string name, string profileUUID, string workingDir) {
        //Set firstRun based on whether any sessions currently exist, i.e. no pages in NoteBook
        Session session = new Session(name, profileUUID, workingDir, nb.getNPages() == 0);
        addSession(session);
    }

    void addSession(Session session) {
        session.addOnSessionClose(&onSessionClose);
        session.addOnIsActionAllowed(&onSessionIsActionAllowed);
        session.addOnSessionDetach(&onSessionDetach);
        session.addOnProcessNotification(&onSessionProcessNotification);
        int index = nb.appendPage(session, session.name);
        nb.showAll();
        nb.setCurrentPage(index);
        updateUIState();
    }

    void removeSession(Session session) {
        //remove event handlers
        session.removeOnSessionClose(&onSessionClose);
        session.removeOnIsActionAllowed(&onSessionIsActionAllowed);
        session.removeOnSessionDetach(&onSessionDetach);
        session.removeOnProcessNotification(&onSessionProcessNotification);
        //remove session from Notebook
        nb.remove(session);
        updateUIState();
        //Close Window if there are no pages
        if (nb.getNPages() == 0) {
            trace("No more sessions, closing AppWindow");
            this.close();
        }
    }

    void closeSession(Session session) {
        removeSession(session);
        session.destroy();
        trace("Session closed");
    }

    void onSessionClose(Session session) {
        closeSession(session);
    }

    void onSessionDetach(Session session, int x, int y, bool isNewSession) {
        trace("Detaching session");
        //Detach an existing session, let's close it
        if (!isNewSession) {
            removeSession(session);
        }
        AppWindow window = new AppWindow(terminix);
        terminix.addAppWindow(window);
        window.initialize(session);
        window.move(x, y);
        window.showAll();
    }

    void updateUIState() {
        if (sessionNotifications.length > 0) {
            ulong count = 0;
            foreach (sn; sessionNotifications.values) {
                count = count + sn.messages.length;
                trace(format("Entry %s has %d messages", sn.sessionUUID, sn.messages.length));
            }
            trace(format("Total Notifications %d for entries %d", count, sessionNotifications.length));
            lblNotifications.setText(to!string(count));
            mbSessionNotifications.show();
        } else {
            mbSessionNotifications.hide();
        }
        saCloseSession.setEnabled(nb.getNPages > 1);
    }

    void updateTitle(Session session) {
        string title;
        if (session) {
            title = _(APPLICATION_NAME) ~ ": " ~ session.name;
        } else {
            title = _(APPLICATION_NAME);
        }
        if (hb !is null)
            hb.setTitle(title);
        else
            setTitle(title);
    }

    bool onSessionIsActionAllowed(ActionType actionType) {
        switch (actionType) {
        case ActionType.DETACH:
            //Only allow if there is more then one session
            return nb.getNPages() > 1;
        default:
            return false;
        }
    }

    void onSessionProcessNotification(string summary, string _body, string terminalUUID, string sessionUUID) {
        trace(format("Notification Received\n\tSummary=%s\n\tBody=%s", summary, _body));
        // If window not active, send notification to shell
        if (!isActive() && gsSettings.getBoolean(SETTINGS_NOTIFY_ON_PROCESS_COMPLETE_KEY)) {
            Notification n = new Notification(_(summary));
            n.setBody(_body);
            n.setDefaultAction("app.activate-session::" ~ sessionUUID);
            getApplication().sendNotification("command-completed", n);
            //if session not visible send to local handler
        }
        // If session not active, keep copy locally
        if (sessionUUID != getCurrentSession().sessionUUID) {
            trace(format("SessionUUID: %s versus Notification UUID: %s", sessionUUID, getCurrentSession().sessionUUID));
            //handle session level notifications here
            ProcessNotificationMessage msg = ProcessNotificationMessage(terminalUUID, summary, _body);
            if (sessionUUID in sessionNotifications) {
                SessionNotification sn = sessionNotifications[sessionUUID];
                sn.messages ~= msg;
                trace("Updated with new notification " ~ to!string(sn.messages.length));
            } else {
                SessionNotification sn = new SessionNotification(sessionUUID);
                sn.messages ~= msg;
                sessionNotifications[sessionUUID] = sn;
                trace("Session UUID " ~ sn.sessionUUID);
                trace("Messages " ~ to!string(sn.messages.length));
            }
            updateUIState();
        }
    }

    /**
     * Dynamically build session list menu items to show in list popover
     */
    void buildSessionMenu() {
        sessionMenu.removeAll();
        saSessionSelect.setState(new GVariant(nb.getCurrentPage()));
        for (int i = 0; i < nb.getNPages; i++) {
            Session session = cast(Session) nb.getNthPage(i);
            GMenuItem menuItem = new GMenuItem(format("%d: %s", i, session.name), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_LIST));
            menuItem.setActionAndTargetValue(getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_LIST), new GVariant(i));
            sessionMenu.appendItem(menuItem);
        }
    }

    bool onWindowClosed(Event event, Widget widget) {
        bool promptForClose = false;
        for (int i = 0; i < nb.getNPages(); i++) {
            Session session = cast(Session) nb.getNthPage(i);
            if (session.isProcessRunning()) {
                promptForClose = true;
                break;
            }
        }
        if (promptForClose) {
            MessageDialog dialog = new MessageDialog(this, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.OK_CANCEL,
                    _("There are processes that are still running, close anyway?"), null);

            dialog.setDefaultResponse(ResponseType.CANCEL);
            scope (exit) {
                dialog.destroy();
            }
            if (dialog.run() == ResponseType.CANCEL)
                return true;
        }
        return false;
    }

    void onWindowDestroyed(Widget widget) {
        terminix.removeAppWindow(this);
    }

    void onCompositedChanged(Widget widget) {
        trace("Composite changed");
        updateVisual();
    }

    Session getCurrentSession() {
        if (nb.getCurrentPage < 0)
            return null;
        else
            return cast(Session) nb.getNthPage(nb.getCurrentPage);
    }

    Session getSession(string sessionUUID) {
        for (int i = 0; i < nb.getNPages(); i++) {
            Session session = cast(Session) nb.getNthPage(i);
            if (session.sessionUUID == sessionUUID) {
                return session;
            }
        }
        return null;
    }

    void addFilters(FileChooserDialog fcd) {
        FileFilter ff = new FileFilter();
        ff.addPattern("*.json");
        ff.setName(_("All JSON Files"));
        fcd.addFilter(ff);
        ff = new FileFilter();
        ff.addPattern("*");
        ff.setName(_("All Files"));
        fcd.addFilter(ff);
    }

    /**
     * Loads session from a file
     */
    void loadSession(string filename) {
        if (!exists(filename))
            throw new SessionCreationException(format(_("Filename '%s' does not exist"), filename));
        string text = readText(filename);
        JSONValue value = parseJSON(text);
        int width = nb.getAllocatedWidth();
        int height = nb.getAllocatedHeight();
        // If no sessions then we are loading our first session,
        // set the window size to what was saved in session JSON file
        if (nb.getNPages() == 0) {
            try {
                Session.getPersistedSessionSize(value, width, height);
                setDefaultSize(width, height);
            }
            catch (Exception e) {
                throw new SessionCreationException("Session could not be created due to error: " ~ e.msg, e);
            }
        }
        trace("Session dimensions: w=%d, h=%d", width, height);
        Session session = new Session(value, filename, width, height, nb.getNPages() == 0);
        addSession(session);
    }

    /**
     * Loads session from a file, prompt user to select file
     */
    void loadSession() {
        FileChooserDialog fcd = new FileChooserDialog(_("Load Session"), this, FileChooserAction.OPEN);
        scope (exit) {
            fcd.destroy();
        }
        addFilters(fcd);
        fcd.setDefaultResponse(ResponseType.OK);
        if (fcd.run() == ResponseType.OK) {
            try {
                loadSession(fcd.getFilename());
            }
            catch (Exception e) {
                fcd.hide();
                error(e);
                showErrorDialog(this, _("Could not load session due to unexpected error.") ~ "\n" ~ e.msg, _("Error Loading Session"));
            }
        }
    }

    /**
     * Saves session to a file
     *
     * Params:
     *  showSaveAsDialog = Determines if save as dialog is shown. Note dialog may be shown even if false is passed if the session filename is not set
     */
    void saveSession(bool showSaveAsDialog = true) {
        Session session = getCurrentSession();
        string filename = session.filename;
        if (filename.length <= 0 || showSaveAsDialog) {
            FileChooserDialog fcd = new FileChooserDialog(_("Save Session"), this, FileChooserAction.SAVE);
            scope (exit)
                fcd.destroy();

            addFilters(fcd);

            fcd.setDoOverwriteConfirmation(true);
            fcd.setDefaultResponse(ResponseType.OK);
            fcd.setCurrentName(session.name ~ ".json");

            if (fcd.run() == ResponseType.OK) {
                filename = fcd.getFilename();
            } else {
                return;
            }
        }
        string json = session.serialize().toPrettyString();
        write(filename, json);
        session.filename = filename;
    }

    /**
     * Creates a new session based on parameters, user is not prompted
     */
    void createSession(string name, string profileUUID) {
        createNewSession(name, profileUUID, Util.getHomeDir());
    }

public:

    this(Application application) {
        super(application);
        terminix.addAppWindow(this);
        gsSettings = new GSettings(SETTINGS_ID);
        setTitle(_("Terminix"));
        setIconName("terminal");

        if (gsSettings.getBoolean(SETTINGS_ENABLE_TRANSPARENCY_KEY)) {
            updateVisual();
        }
        createUI();

        addOnDelete(&onWindowClosed);
        addOnDestroy(&onWindowDestroyed);
        addOnCompositedChanged(&onCompositedChanged);
    }

    void initialize() {
        if (terminix.getGlobalOverrides().session.length > 0) {
            loadSession(terminix.getGlobalOverrides().session);
            return;
        }
        //Create an initial session using default session name and profile
        createSession(_(DEFAULT_SESSION_NAME), prfMgr.getDefaultProfile());
    }

    void initialize(Session session) {
        addSession(session);
    }

    /**
     * Activates the specified sessionUUID
     */
    bool activateSession(string sessionUUID) {
        for (int i = 0; i < nb.getNPages(); i++) {
            Session session = cast(Session) nb.getNthPage(i);
            if (session.sessionUUID == sessionUUID) {
                nb.setCurrentPage(i);
                return true;
            }
        }
        return false;
    }

    /**
     * Activates the specified terminal
     */
    bool activateTerminal(string sessionUUID, string terminalUUID) {
        if (activateSession(sessionUUID)) {
            return getCurrentSession().focusTerminal(terminalUUID);
        }
        return false;
    }

    /**
     * Finds the widget matching a specific UUID, typically
     * a Session or Terminal
     */
    Widget findWidgetForUUID(string uuid) {
        for (int i = 0; i < nb.getNPages(); i++) {
            Session session = cast(Session) nb.getNthPage(i);
            if (session.sessionUUID == uuid)
                return session;
            trace("Searching session");
            Widget result = session.findWidgetForUUID(uuid);
            if (result !is null)
                return result;
        }
        return null;
    }

    /**
     * Creates a new session and prompts the user for session properties
     */
    void createSession() {
        if (gsSettings.getBoolean(SETTINGS_PROMPT_ON_NEW_SESSION_KEY)) {
            SessionProperties sp = new SessionProperties(this, _(DEFAULT_SESSION_NAME), prfMgr.getDefaultProfile());
            scope (exit) {
                sp.destroy();
            }
            sp.showAll();
            if (sp.run() == ResponseType.OK) {
                createSession(sp.name, sp.profileUUID);
            }
        } else {
            createSession(_(DEFAULT_SESSION_NAME), prfMgr.getDefaultProfile());
        }
    }
}

// ***************************************************************************
// This block deals with session notification messages. These are messages
// that are raised after a process is completed.
// ***************************************************************************
private:

/**
 * Represents a single process notification
 */
immutable struct ProcessNotificationMessage {
    string terminalUUID;
    string summary;
    string _body;
}

class SessionNotification {
    string sessionUUID;
    ProcessNotificationMessage[] messages;

    this(string sessionUUID) {
        this.sessionUUID = sessionUUID;
    }
}

class SessionNotificationPopover : Popover {

private:
    SessionNotification[] sns;
    AppWindow window;
    ListBox lb;

    void createUI() {
        Box b = new Box(Orientation.VERTICAL, 0);
        b.setBorderWidth(6);
        ScrolledWindow sw = new ScrolledWindow();
        sw.setShadowType(ShadowType.ETCHED_IN);
        sw.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sw.setHexpand(true);
        //TODO - This is quick and dirty, really need to calculate 
        //an appropriate height as this will bekind of ugh on HiDPI 
        //displays
        sw.setMinContentHeight(200);

        lb = new ListBox();
        lb.setVexpand(true);
        lb.setHexpand(true);
        lb.setActivateOnSingleClick(true);
        lb.setSelectionMode(SelectionMode.NONE);
        lb.addOnRowActivated(delegate(ListBoxRow lbr, ListBox lb) {
            SessionRow sr = cast(SessionRow) lbr;
            if (sr !is null) {
                window.activateSession(sr.sessionUUID);
            } else {
                TerminalRow tr = cast(TerminalRow) lbr;
                window.activateTerminal(tr.sessionUUID, tr.terminalUUID);
            }
        });

        sw.add(lb);
        b.add(sw);
        b.showAll();
        add(b);
        trace("Popover CreateUI called");
    }

    void createListRows() {
        foreach (sn; sns) {
            Session session = window.getSession(sn.sessionUUID);
            if (session !is null) {
                lb.add(new SessionRow(sn.sessionUUID, session.name));
                foreach (msg; sn.messages) {
                    lb.add(new TerminalRow(msg, sn.sessionUUID));
                }
            }
        }
        lb.showAll();
        lb.selectRow(null);
    }

    /* Used for close button, removed
    void removeSession(string sessionUUID) {
        int count = 0;
        //Iterate over rows removing all rows whose sessionUUID 
        //matches this one
        BaseRow row = cast(BaseRow) lb.getRowAtIndex(count);
        while (row !is null) {
            if (row.sessionUUID == sessionUUID) {
                lb.remove(row);
            } else {
                count++;
            }
            row = cast(BaseRow) lb.getRowAtIndex(count);
        }
        if (lb.getRowAtIndex(0) is null) {
            hide();
        }
    }
    */

public:

    this(Widget relativeTo, AppWindow window) {
        super(relativeTo);
        this.window = window;
        createUI();
    }

    void populate(SessionNotification[] sns) {
        lb.removeAll();
        this.sns = sns;
        createListRows();
    }

}

class BaseRow : ListBoxRow {

private:
    string sessionUUID;

public:
    this(string sessionUUID) {
        this.sessionUUID = sessionUUID;
    }

}

class SessionRow : BaseRow {

private:
    SessionNotificationPopover popover;

    void createUI(string sessionName) {
        Box b = new Box(Orientation.HORIZONTAL, 0);
        b.setBorderWidth(6);
        //b.getStyleContext().addClass("notebook");
        //b.getStyleContext().addClass("header");
        Image imgSession = new Image("view-grid-symbolic", IconSize.MENU);
        b.packStart(imgSession, false, false, 4);

        Label lbl = new Label(format("<b>%s</b>", sessionName));
        lbl.setHalign(Align.START);
        lbl.setUseMarkup(true);
        b.packStart(lbl, true, true, 4);

        /* Don't do close button, total pain in the ass to keep synchronized
           and not really needed. Just comment out for now in case it needs
           to be brought back for some reason.
           
           Not needed because we remove notifications when switching sessions
           
        Button btnClose = new Button("window-close-symbolic", IconSize.MENU);
        btnClose.setRelief(ReliefStyle.NONE);
        btnClose.setFocusOnClick(false);
        btnClose.addOnClicked(delegate(Button) {
            popover.removeSession(sessionUUID);
        });
        b.packEnd(btnClose, false, false, 0);
        */
        add(b);
        setHalign(Align.FILL);
        setValign(Align.FILL);
    }

public:
    this(string sessionUUID, string sessionName) {
        super(sessionUUID);
        createUI(sessionName);
    }
}

class TerminalRow : BaseRow {

private:
    string terminalUUID;

    void createUI(ProcessNotificationMessage msg) {
        Box b = new Box(Orientation.HORIZONTAL, 0);
        b.setBorderWidth(6);
        Image imgTerminal = new Image("utilities-terminal-symbolic", IconSize.MENU);
        b.packStart(imgTerminal, false, false, 4);

        Label label = new Label(msg._body);
        label.setSensitive(false);
        b.setMarginLeft(18);
        b.add(label);
        add(b);
    }

public:
    this(ProcessNotificationMessage msg, string sessionUUID) {
        super(sessionUUID);
        this.terminalUUID = msg.terminalUUID;
        createUI(msg);
    }
}
