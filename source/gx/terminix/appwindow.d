/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.appwindow;

import core.memory;

import std.conv;
import std.experimental.logger;
import std.file;
import std.math;
import std.format;
import std.json;
import std.string;

import cairo.Context;

import gtk.Application : Application;
import gio.Application : GioApplication = Application;
import gtk.ApplicationWindow : ApplicationWindow;
import gtkc.giotypes : GApplicationFlags;

import gdk.Event;
import gdk.RGBA;
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
import gtk.Frame;
import gtk.HeaderBar;
import gtk.Image;
import gtk.ListBox;
import gtk.ListBoxRow;
import gtk.MenuButton;
import gtk.MessageDialog;
import gtk.Notebook;
import gtk.Overlay;
import gtk.Popover;
import gtk.Revealer;
import gtk.ScrolledWindow;
import gtk.StyleContext;
import gtk.ToggleButton;
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
import gx.terminix.sidebar;

/**
 * The GTK Application Window for Terminix. It is responsible for
 * managing sessions which are held as pages in a GTK Notebook. All
 * session actions are created and managed here but against the session
 * prefix rather then the win prefix which is typically used for
 * a AplicationWindow.
 */
class AppWindow : ApplicationWindow {

private:

    enum CSS_CLASS_NEEDS_ATTENTION = "needs-attention";

    enum DEFAULT_SESSION_NAME = N_("Default");

    enum ACTION_PREFIX = "session";
    enum ACTION_SESSION_CLOSE = "close";
    enum ACTION_SESSION_NAME = "name";
    enum ACTION_SESSION_NEXT_TERMINAL = "switch-to-next-terminal";
    enum ACTION_SESSION_PREV_TERMINAL = "switch-to-previous-terminal";
    enum ACTION_SESSION_TERMINAL_X = "switch-to-terminal-";
    enum ACTION_RESIZE_TERMINAL_DIRECTION = "resize-terminal-";
    enum ACTION_SESSION_SAVE = "save";
    enum ACTION_SESSION_SAVE_AS = "save-as";
    enum ACTION_SESSION_LOAD = "load";
    enum ACTION_SESSION_SYNC_INPUT = "synchronize-input";
    enum ACTION_WIN_SESSION_X = "switch-to-session-";
    enum ACTION_WIN_FULLSCREEN = "fullscreen";
    enum ACTION_WIN_SIDEBAR = "view-sidebar";
    enum ACTION_WIN_NEXT_SESSION = "switch-to-next-session";
    enum ACTION_WIN_PREVIOUS_SESSION = "switch-to-previous-session";

    Notebook nb;
    HeaderBar hb;
    SideBar sb;
    ToggleButton tbSideBar;

    SimpleActionGroup sessionActions;
    MenuButton mbSessionActions;
    SimpleAction saSyncInput;
    SimpleAction saCloseSession;
    SimpleAction saViewSideBar;

    SessionNotification[string] sessionNotifications;

    GSettings gsSettings;

    /**
     * Create the user interface
     */
    void createUI() {
        GSettings gsShortcuts = new GSettings(SETTINGS_PROFILE_KEY_BINDINGS_ID);

        createWindowActions(gsShortcuts);
        createSessionActions(gsShortcuts);

        //Notebook
        nb = new Notebook();
        nb.setShowTabs(false);
        nb.setShowBorder(false);
        nb.addOnSwitchPage(delegate(Widget page, uint, Notebook) {
            trace("Switched Sessions");
            Session session = cast(Session) page;
            //Remove any sessions associated with current page
            sessionNotifications.remove(session.sessionUUID);
            updateTitle();
            updateUIState();
            session.focusRestore();
            saSyncInput.setState(new GVariant(session.synchronizeInput));
        }, ConnectFlags.AFTER);

        sb = new SideBar();
        sb.addOnSessionSelected(delegate(string sessionUUID) {
            trace("Session selected " ~ sessionUUID);
            saViewSideBar.activate(null);
            if (sessionUUID.length > 0) {
                activateSession(sessionUUID);
            } else {
                getCurrentSession().focusRestore();
            }
        });

        Overlay overlay = new Overlay();
        overlay.add(nb);
        overlay.addOverlay(sb);

        //Could be a Box or a Headerbar depending on value of disable_csd
        Widget toolbar = createHeaderBar();

        if (gsSettings.getBoolean(SETTINGS_DISABLE_CSD_KEY)) {
            Box b = new Box(Orientation.VERTICAL, 0);
            b.add(toolbar);
            b.add(overlay);
            add(b);
        } else {
            this.setTitlebar(toolbar);
            add(overlay);
        }
    }

    Widget createHeaderBar() {
        //View sessions button
        tbSideBar = new ToggleButton();
        tbSideBar.setTooltipText(_("View session sidebar"));
        tbSideBar.setFocusOnClick(false);
        Image iList = new Image("view-list-symbolic", IconSize.MENU);
        tbSideBar.add(iList);
        tbSideBar.setActionName(getActionDetailedName("win", ACTION_WIN_SIDEBAR));
        tbSideBar.addOnDraw(&drawSideBarBadge, ConnectFlags.AFTER);

        //New tab button
        Button btnNew = new Button("tab-new-symbolic", IconSize.BUTTON);
        btnNew.setFocusOnClick(false);
        btnNew.setAlwaysShowImage(true);
        btnNew.addOnClicked(delegate(Button) { createSession(); });
        btnNew.setTooltipText(_("Create a new session"));

        //Session Actions
        mbSessionActions = new MenuButton();
        mbSessionActions.setFocusOnClick(false);
        Image iHamburger = new Image("open-menu-symbolic", IconSize.MENU);
        mbSessionActions.add(iHamburger);
        mbSessionActions.setPopover(createPopover(mbSessionActions));

        if (gsSettings.getBoolean(SETTINGS_DISABLE_CSD_KEY)) {
            Box tb = new Box(Orientation.HORIZONTAL, 0);
            tb.packStart(tbSideBar, false, false, 4);
            tb.packStart(btnNew, false, false, 4);
            tb.packEnd(mbSessionActions, false, false, 4);
            tb.setMarginBottom(4);

            Box spacer = new Box(Orientation.VERTICAL, 0);
            spacer.getStyleContext().addClass("terminix-toolbar");
            spacer.packStart(tb, true, true, 0);

            return spacer;
        } else {
            //Header Bar
            hb = new HeaderBar();
            hb.setShowCloseButton(true);
            hb.setTitle(_(APPLICATION_NAME));
            hb.packStart(tbSideBar);
            hb.packStart(btnNew);
            hb.packEnd(mbSessionActions);
            return hb;
        }
    }

    /**
     * Create Window actions
     */
    void createWindowActions(GSettings gsShortcuts) {
        static if (SHOW_DEBUG_OPTIONS) {
            registerAction(this, "win", "gc", null, delegate(GVariant, SimpleAction) { trace("Performing collection"); core.memory.GC.collect(); });
        }

        //Create Switch to Session (0..9) actions
        //Can't use :: action targets for this since action name needs to be preferences 
        for (int i = 0; i <= 9; i++) {
            registerActionWithSettings(this, "win", ACTION_WIN_SESSION_X ~ to!string(i), gsShortcuts, delegate(GVariant, SimpleAction sa) {
                int index = to!int(sa.getName()[$ - 1 .. $]);
                if (index == 0)
                    index = 9;
                else
                    index--;
                if (index <= nb.getNPages()) {
                    nb.setCurrentPage(index);
                }
            });
        }

        registerActionWithSettings(this, "win", ACTION_WIN_NEXT_SESSION, gsShortcuts, delegate(GVariant, SimpleAction) {
            if (nb.getCurrentPage() < nb.getNPages() - 1) {
                nb.nextPage();
            } else {
                nb.setCurrentPage(0);
            }
        });
        registerActionWithSettings(this, "win", ACTION_WIN_PREVIOUS_SESSION, gsShortcuts, delegate(GVariant, SimpleAction) {
            if (nb.getCurrentPage() > 0) {
                nb.prevPage();
            } else {
                nb.setCurrentPage(nb.getNPages() - 1);
            }
        });

        registerActionWithSettings(this, "win", ACTION_WIN_FULLSCREEN, gsShortcuts, delegate(GVariant value, SimpleAction sa) {
            trace("Setting fullscreen");
            bool newState = !sa.getState().getBoolean();
            sa.setState(new GVariant(newState));
            if (newState) {
                fullscreen();
            } else {
                unfullscreen();
            }
        }, null, new GVariant(false));

        saViewSideBar = registerActionWithSettings(this, "win", ACTION_WIN_SIDEBAR, gsShortcuts, delegate(GVariant value, SimpleAction sa) {
            bool newState = !sa.getState().getBoolean();
            trace("Sidebar action activated " ~ to!string(newState));
            // Note that populate sessions does some weird shit with event
            // handling, don't trigger UI activity until after it is done
            // See comments in gx.gtk.cairo.getWidgetImage
            if (newState) {
                sb.populateSessions(getSessions(), getCurrentSession().sessionUUID, sessionNotifications, nb.getAllocatedWidth(), nb.getAllocatedHeight());
                sb.showAll();
            } 
            sb.setRevealChild(newState);
            sa.setState(new GVariant(newState));
            tbSideBar.setActive(newState);
            if (!newState) {
                //Hiding session, restore focus
                getCurrentSession().focusRestore();
            }
        }, null, new GVariant(false));
    }

    /**
     * Create all the session actions and corresponding actions
     */
    void createSessionActions(GSettings gsShortcuts) {
        sessionActions = new SimpleActionGroup();

        //Create Switch to Terminal (0..9) actions
        //Can't use :: action targets for this since action name needs to be preferences 
        for (int i = 0; i <= 9; i++) {
            registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_TERMINAL_X ~ to!string(i), gsShortcuts, delegate(GVariant, SimpleAction sa) {
                Session session = getCurrentSession();
                if (session !is null) {
                    ulong terminalID = to!ulong(sa.getName()[$ - 1 .. $]);
                    if (terminalID == 0)
                        terminalID = 10;
                    session.focusTerminal(terminalID);
                }
            });
        }

        //Create directional Switch to Terminal actions
        const string[] directions = ["up", "down", "left", "right"];
        foreach (string direction; directions) {
            registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_TERMINAL_X ~ direction, gsShortcuts, delegate(GVariant, SimpleAction sa) {
                Session session = getCurrentSession();
                if (session !is null) {
                    string actionName = sa.getName();
                    string direction = actionName[lastIndexOf(actionName, '-') + 1 .. $];
                    session.focusDirection(direction);
                }
            });
        }

        //Create directional Resize to Terminal actions
        foreach (string direction; directions) {
            registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_RESIZE_TERMINAL_DIRECTION ~ direction, gsShortcuts, delegate(GVariant, SimpleAction sa) {
                Session session = getCurrentSession();
                if (session !is null) {
                    string actionName = sa.getName();
                    string direction = actionName[lastIndexOf(actionName, '-') + 1 .. $];
                    session.resizeTerminal(direction);
                }
            });
        }

        /* TODO - GTK doesn't support settings Tab for accelerators, need to look into this more */
        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_NEXT_TERMINAL, gsShortcuts, delegate(GVariant, SimpleAction) {
            Session session = getCurrentSession();
            if (session !is null)
                session.focusNext();
        });
        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_PREV_TERMINAL, gsShortcuts, delegate(GVariant, SimpleAction) {
            Session session = getCurrentSession();
            if (session !is null)
                session.focusPrevious();
        });

        //Close Session
        saCloseSession = registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_CLOSE, gsShortcuts, delegate(GVariant, SimpleAction) {
            if (nb.getNPages > 1) {
                closeSession(getCurrentSession());
            }
        });

        //Load Session
        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_LOAD, gsShortcuts, delegate(GVariant, SimpleAction) { loadSession(); });

        //Save Session
        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_SAVE, gsShortcuts, delegate(GVariant, SimpleAction) { saveSession(false); });

        //Save As Session
        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_SAVE_AS, gsShortcuts, delegate(GVariant, SimpleAction) { saveSession(true); });

        //Change name of session
        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_NAME, gsShortcuts, delegate(GVariant, SimpleAction) {
            Session session = getCurrentSession();
            string name = session.name;
            if (showInputDialog(this, name, name, _("Change Session Name"), _("Enter a new name for the session"))) {
                if (name.length > 0) {
                    session.name = name;
                    updateTitle();
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
        mFileSection.appendItem(new GMenuItem(_("Load…"), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_LOAD)));
        mFileSection.appendItem(new GMenuItem(_("Save"), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_SAVE)));
        mFileSection.appendItem(new GMenuItem(_("Save As…"), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_SAVE_AS)));
        mFileSection.appendItem(new GMenuItem(_("Close"), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_CLOSE)));
        model.appendSection(null, mFileSection);

        GMenu mSessionSection = new GMenu();
        mSessionSection.appendItem(new GMenuItem(_("Name…"), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_NAME)));
        mSessionSection.appendItem(new GMenuItem(_("Synchronize Input"), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_SYNC_INPUT)));
        model.appendSection(null, mSessionSection);

        static if (SHOW_DEBUG_OPTIONS) {
            GMenu mDebugSection = new GMenu();
            mDebugSection.appendItem(new GMenuItem(_("GC"), getActionDetailedName("win", "gc")));
            model.appendSection(null, mDebugSection);
        }

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

    Session[] getSessions() {
        Session[] result = new Session[](nb.getNPages());
        for (int i = 0; i < nb.getNPages(); i++) {
            result[i] = getSession(i);
        }
        return result;
    }

    Session getSession(int i) {
        return cast(Session) nb.getNthPage(i);
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
        tbSideBar.queueDraw();
        saCloseSession.setEnabled(nb.getNPages > 1);
    }

    void updateTitle() {
        string title;
        Session session = getCurrentSession();
        if (session && nb.getNPages() == 1) {
            title = _(APPLICATION_NAME) ~ ": " ~ session.name;
        } else if (session) { 
            title = _(APPLICATION_NAME) ~ " " ~ to!string(nb.getCurrentPage()+1) ~ ": " ~ session.name;
        } else {
            title = _(APPLICATION_NAME);
        }
        if (hb !is null)
            hb.setTitle(title);
        else
            setTitle(title);
    }

    bool drawSideBarBadge(Scoped!Context cr, Widget widget) {
        
        // pw, ph, ps = percent width, height, size
        void drawBadge(double pw, double ph, double ps, RGBA fg, RGBA bg, int value) {
            int w = widget.getAllocatedWidth();
            int h = widget.getAllocatedHeight();

            double x = w * pw;
            double y = h * ph;
            double radius = w * ps;
            
            cr.save();
            cr.setSourceRgba(bg.red, bg.green, bg.blue, bg.alpha);
            cr.arc(x, y, radius, 0.0, 2.0 * PI);
            cr.fillPreserve();
            cr.stroke();
            cr.selectFontFace("monospace", cairo_font_slant_t.NORMAL, cairo_font_weight_t.NORMAL);
            cr.setFontSize(11);
            cr.setSourceRgba(fg.red, fg.green, fg.blue, 1.0);
            string text = to!string(value);
            cairo_text_extents_t extents;
            cr.textExtents(text, &extents);
            cr.moveTo(x - extents.width / 2, y + extents.height / 2);
            cr.showText(text);
            cr.restore();
            cr.newPath();
        }
        
        RGBA fg;
        RGBA bg;
        if (nb.getNPages() > 1) {
            widget.getStyleContext().lookupColor("theme_fg_color", bg);
            widget.getStyleContext().lookupColor("theme_bg_color", fg);
            bg.alpha = 0.9;
            drawBadge(0.72, 0.70, 0.19, fg, bg, nb.getNPages());
        }
        ulong count = 0;
        foreach (sn; sessionNotifications.values) {
            count = count + sn.messages.length;
        }
        if (count > 0) {
            widget.getStyleContext().lookupColor("theme_selected_fg_color", fg);
            widget.getStyleContext().lookupColor("theme_selected_bg_color", bg);
            bg.alpha = 0.9;
            drawBadge(0.28, 0.70, 0.19, fg, bg, to!int(count));
        }
        return false;
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

    bool onWindowClosed(Event event, Widget widget) {
        bool promptForClose = false;
        for (int i = 0; i < nb.getNPages(); i++) {
            if (getSession(i).isProcessRunning()) {
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
            if (dialog.run() != ResponseType.OK) {
                trace("Abort close");
                return true;
            }
        }
        return false;
    }

    void onWindowDestroyed(Widget) {
        terminix.removeAppWindow(this);
    }

    void onCompositedChanged(Widget) {
        trace("Composite changed");
        updateVisual();
    }

    Session getCurrentSession() {
        if (nb.getCurrentPage < 0)
            return null;
        else
            return getSession(nb.getCurrentPage());
    }

    Session getSession(string sessionUUID) {
        for (int i = 0; i < nb.getNPages(); i++) {
            Session session = getSession(i);
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
        //createNewSession(name, profileUUID, Util.getHomeDir());
        createNewSession(name, profileUUID, null);
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
            foreach (sessionFilename; terminix.getGlobalOverrides().session) {
                loadSession(sessionFilename);
            }
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
            Session session = getSession(i);
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
    
    string getActiveTerminalUUID() {
        Session session = getCurrentSession();
        return session.getActiveTerminalUUID();
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
