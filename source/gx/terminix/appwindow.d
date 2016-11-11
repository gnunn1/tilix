/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.appwindow;

import core.memory;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.file;
import std.math;
import std.format;
import std.json;
import std.path;
import std.process;
import std.string;

import cairo.Context;
import cairo.ImageSurface;

import gtk.Application : Application;
import gio.Application : GioApplication = Application;
import gtk.ApplicationWindow : ApplicationWindow;
import gtkc.giotypes : GApplicationFlags;

import gdkpixbuf.Pixbuf;

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

import glib.GException;
import glib.ListG;
import glib.Util;
import glib.Variant : GVariant = Variant;
import glib.VariantType : GVariantType = VariantType;

import gobject.Value;

import gtk.Box;
import gtk.Button;
import gtk.CheckButton;
import gtk.Dialog;
import gtk.EventBox;
import gtk.FileChooserDialog;
import gtk.FileFilter;
import gtk.Frame;
import gtk.Grid;
import gtk.HeaderBar;
import gtk.Image;
import gtk.Label;
import gtk.ListBox;
import gtk.ListBoxRow;
import gtk.MenuButton;
import gtk.MessageDialog;
import gtk.Notebook;
import gtk.Overlay;
import gtk.Popover;
import gtk.Revealer;
import gtk.ScrolledWindow;
import gtk.Settings;
import gtk.StyleContext;
import gtk.ToggleButton;
import gtk.Version;
import gtk.Widget;
import gtk.Window;

import vte.Pty;
import vte.Terminal;

import gx.gtk.actions;
import gx.gtk.cairo;
import gx.gtk.dialog;
import gx.gtk.threads;
import gx.gtk.util;
import gx.i18n.l10n;

import gx.terminix.application;
import gx.terminix.common;
import gx.terminix.constants;
import gx.terminix.cmdparams;
import gx.terminix.preferences;
import gx.terminix.session;
import gx.terminix.sessionswitcher;
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

    enum ACTION_PREFIX = "session";
    enum ACTION_SESSION_CLOSE = "close";
    enum ACTION_SESSION_NAME = "name";
    enum ACTION_SESSION_NEXT_TERMINAL = "switch-to-next-terminal";
    enum ACTION_SESSION_PREV_TERMINAL = "switch-to-previous-terminal";
    enum ACTION_SESSION_TERMINAL_X = "switch-to-terminal-";
    enum ACTION_SESSION_ADD_RIGHT = "add-right";
    enum ACTION_SESSION_ADD_DOWN = "add-down";
    enum ACTION_RESIZE_TERMINAL_DIRECTION = "resize-terminal-";
    enum ACTION_SESSION_SAVE = "save";
    enum ACTION_SESSION_SAVE_AS = "save-as";
    enum ACTION_SESSION_OPEN = "open";
    enum ACTION_SESSION_SYNC_INPUT = "synchronize-input";
    enum ACTION_WIN_SESSION_X = "switch-to-session-";
    enum ACTION_WIN_SIDEBAR = "view-sidebar";
    enum ACTION_WIN_SESSIONSWITCHER = "view-session-switcher";
    enum ACTION_WIN_NEXT_SESSION = "switch-to-next-session";
    enum ACTION_WIN_PREVIOUS_SESSION = "switch-to-previous-session";
    enum ACTION_WIN_FULLSCREEN = "fullscreen";

    Notebook nb;
    HeaderBar hb;
    SideBar sb;
    SessionSwitcher ss;
    ToggleButton tbSideBar;

    SimpleActionGroup sessionActions;
    MenuButton mbSessionActions;
    SimpleAction saSyncInput;
    SimpleAction saCloseSession;
    SimpleAction saViewSideBar;
    SimpleAction saViewSessionSwitcher;
    SimpleAction saSessionAddRight;
    SimpleAction saSessionAddDown;

    Label lblSideBar;

    SessionNotification[string] sessionNotifications;

    GSettings gsSettings;

    // Cached rendered background image
    ImageSurface isBGImage;
    // Track size changes, only invalidate if size really changed
    int lastWidth, lastHeight;

    // True if window is in quake mode
    bool _quake;
    
    string[] recentSessionFiles;


    /**
     * Forces the app menu in the decoration layouts so in environments without an app-menu
     * it will be rendered by GTK as part of the window.
     */
    void forceAppMenu() {
        Settings settings = Settings.getDefault();
        if (settings !is null) {
            Value value = new Value("");
            settings.getProperty(GTK_DECORATION_LAYOUT, value);
            string layout = value.getString();
            if (layout.indexOf("menu") < 0) {
                size_t index = layout.indexOf(":"); 
                if (index > 0) {
                    layout = "menu," ~ layout;
                } else if (index == 0) {
                    layout = "menu" ~ layout;
                } else {
                    layout = "menu:" ~ layout;
                }
            }
            tracef("Updating layout to %s", layout);
            value.setString(layout);
            settings.setProperty(GTK_DECORATION_LAYOUT, value);

            string desktop;
            try {
                desktop = environment["XDG_CURRENT_DESKTOP"];
            } catch (Exception e) {
                //Just ignore it
            }

            // Unity specific workaround, force app window when using Headerbar and setting to display menus in titlebar in Unity is active
            if (desktop.indexOf("Unity") >= 0 && !gsSettings.getBoolean(SETTINGS_DISABLE_CSD_KEY)) {
                try {
                    GSettings unity = new GSettings("com.canonical.Unity");
                    if (unity !is null && unity.getBoolean("integrated-menus")) {
                        settings.setProperty(GTK_SHELL_SHOWS_APP_MENU, new Value(false));
                    }
                } catch (GException e) {
                    //Ignore
                }
            }
        }
    }

    /**
     * Create the user interface
     */
    void createUI() {
        GSettings gsShortcuts = new GSettings(SETTINGS_PROFILE_KEY_BINDINGS_ID);

        createWindowActions(gsShortcuts);
        createSessionActions(gsShortcuts);
        createDelegatedTerminalActions(gsShortcuts);

        //Notebook
        nb = new Notebook();
        nb.setShowTabs(false);
        nb.setShowBorder(false);
        nb.addOnSwitchPage(delegate(Widget page, uint, Notebook) {
            trace("Switched Sessions");
            Session session = cast(Session) page;
            //Remove any sessions associated with current page
            sessionNotifications.remove(session.uuid);
            updateTitle();
            updateUIState();
            session.notifyActive();
            session.focusRestore();
            saSyncInput.setState(new GVariant(session.synchronizeInput));
            if (sb.getChildRevealed() && getCurrentSession() !is null) {
                sb.selectSession(getCurrentSession().uuid);
            }
        }, ConnectFlags.AFTER);

        sb = new SideBar();
        sb.addOnSessionSelected(delegate(string sessionUUID) {
            trace("Session selected " ~ sessionUUID);
            saViewSideBar.activate(null);
            if (sessionUUID.length > 0) {
                activateSession(sessionUUID);
            } else {
                Session session = getCurrentSession();
                if (session !is null) {
                    getCurrentSession().focusRestore();
                }
            }
        });
        sb.addOnSessionClose(&onUserSessionClose);

        ss = new SessionSwitcher();
        ss.addOnSessionFileSelected(delegate(string file) {
            saViewSessionSwitcher.activate(null);
            if (file) {
                try {
                    loadSession(file);
                }
                catch (SessionCreationException e) {
                    removeRecentSessionFile(file);

                    showErrorDialog(this, e.msg);
                }
            }
        });
        ss.addOnSessionFileRemoved(delegate(string file) {
            removeRecentSessionFile(file);
            ss.populate(getSessions(), recentSessionFiles);
        });
        ss.addOnOpenSessionSelected(delegate(string uuid) {
            saViewSessionSwitcher.activate(null);
            if (uuid) {
                activateSession(uuid);
            }
        });
        ss.addOnOpenSessionRemoved(&onUserSessionClose);

        Overlay overlay = new Overlay();
        overlay.add(nb);
        overlay.addOverlay(sb);
        overlay.addOverlay(ss);

        //Could be a Box or a Headerbar depending on value of disable_csd
        hb = createHeaderBar();

        if (isQuake() || gsSettings.getBoolean(SETTINGS_DISABLE_CSD_KEY)) {
            hb.getStyleContext().addClass("terminix-embedded-headerbar");
            Grid grid = new Grid();
            grid.setOrientation(Orientation.VERTICAL);
            grid.add(hb);
            grid.add(overlay);
            if (isQuake()) {
                Frame f = new Frame(grid, null);
                f.setShadowType(ShadowType.NONE);
                f.getStyleContext().addClass("terminix-quake-frame");
                add(f);
            } else {
                add(grid);
            }
        } else {
            this.setTitlebar(hb);
            hb.setShowCloseButton(true);
            hb.setTitle(_(APPLICATION_NAME));
            add(overlay);
        }
    }

    HeaderBar createHeaderBar() {
        //View sessions button
        tbSideBar = new ToggleButton();
        Box b = new Box(Orientation.HORIZONTAL, 6);
        lblSideBar = new Label("1 / 1");
        Image img = new Image("pan-down-symbolic", IconSize.MENU);
        b.add(lblSideBar);
        b.add(img);
        tbSideBar.add(b);
        tbSideBar.setTooltipText(_("View session sidebar"));
        tbSideBar.setFocusOnClick(false);
        tbSideBar.setActionName(getActionDetailedName("win", ACTION_WIN_SIDEBAR));
        tbSideBar.addOnDraw(&drawSideBarBadge, ConnectFlags.AFTER);
        tbSideBar.addOnScroll(delegate(Event event, Widget w) {
            ScrollDirection direction;
            event.getScrollDirection(direction);

            if (direction == ScrollDirection.UP) {
                focusPreviousSession();
            } else if (direction == ScrollDirection.DOWN) {
                focusNextSession();
            }

            return false;
        });
        tbSideBar.addEvents(EventType.SCROLL);

        //New tab button
        Button btnNew = new Button("list-add-symbolic", IconSize.BUTTON);
        btnNew.setFocusOnClick(false);
        btnNew.setAlwaysShowImage(true);
        btnNew.addOnClicked(delegate(Button) {
            createSession();
        });
        btnNew.setTooltipText(_("Create a new session"));

        //Session Actions
        mbSessionActions = new MenuButton();
        mbSessionActions.setFocusOnClick(false);
        Image iHamburger = new Image("open-menu-symbolic", IconSize.MENU);
        mbSessionActions.add(iHamburger);
        mbSessionActions.setPopover(createPopover(mbSessionActions));

        Box bSessionButtons = new Box(Orientation.HORIZONTAL, 0);
        bSessionButtons.getStyleContext().addClass("linked");
        btnNew.getStyleContext().addClass("session-new-button");
        bSessionButtons.packStart(tbSideBar, false, false, 0);
        bSessionButtons.packStart(btnNew, false, false, 0);

        Button btnAddHorizontal = new Button("terminix-add-horizontal-symbolic", IconSize.MENU);
        btnAddHorizontal.setDetailedActionName(getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_ADD_RIGHT));
        btnAddHorizontal.setFocusOnClick(false);
        btnAddHorizontal.setTooltipText(_("Add terminal right"));

        Button btnAddVertical = new Button("terminix-add-vertical-symbolic", IconSize.MENU);
        btnAddVertical.setDetailedActionName(getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_ADD_DOWN));
        btnAddVertical.setTooltipText(_("Add terminal down"));
        btnAddVertical.setFocusOnClick(false);

        // Add find button
        Button btnFind = new Button("edit-find-symbolic", IconSize.MENU);
        btnFind.setTooltipText(_("Find text in terminal"));
        btnFind.setFocusOnClick(false);
        btnFind.addOnClicked(delegate(Button) {
            if (getCurrentSession() !is null) {
                getCurrentSession().toggleTerminalFind();
            }
        });

        //Header Bar
        HeaderBar header = new HeaderBar();
        header.packStart(bSessionButtons);
        header.packStart(btnAddHorizontal);
        header.packStart(btnAddVertical);
        header.packEnd(mbSessionActions);
        header.packEnd(btnFind);
        return header;
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
            focusNextSession();
        });
        registerActionWithSettings(this, "win", ACTION_WIN_PREVIOUS_SESSION, gsShortcuts, delegate(GVariant, SimpleAction) {
            focusPreviousSession();
        });

        registerActionWithSettings(this, "win", ACTION_WIN_FULLSCREEN, gsShortcuts, delegate(GVariant value, SimpleAction sa) {
            if (isQuake()) {
                warning("Fullscreen is not supported in quake mode");
                return;
            }
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
                sb.populateSessions(getSessions(), getCurrentSession().uuid, sessionNotifications, nb.getAllocatedWidth(), nb.getAllocatedHeight());
                sb.showAll();
            }
            sb.setRevealChild(newState);
            sa.setState(new GVariant(newState));
            tbSideBar.setActive(newState);
            if (!newState) {
                //Hiding session, restore focus
                Session session = getCurrentSession(); 
                if (session !is null) {
                    session.focusRestore();
                }
            }
        }, null, new GVariant(false));

        saViewSessionSwitcher = registerActionWithSettings(this, "win", ACTION_WIN_SESSIONSWITCHER, gsShortcuts, delegate(GVariant value, SimpleAction sa) {
            bool newState = !sa.getState().getBoolean();
            trace("Session switcher action activated " ~ to!string(newState));
            if (newState) {
                ss.populate(getSessions(), recentSessionFiles);
                ss.showAll();
            }
            ss.setRevealChild(newState);
            sa.setState(new GVariant(newState));
            ss.focusSearchEntry();
            if (!newState) {
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
                    auto terminalID = to!size_t(sa.getName()[$ - 1 .. $]);
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

        //Add Terminal Actions
        saSessionAddRight = registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_ADD_RIGHT, gsShortcuts, delegate(GVariant, SimpleAction) {
            Session session = getCurrentSession();
            if (session !is null)
                session.addTerminal(Orientation.HORIZONTAL);
        });
        saSessionAddDown = registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_ADD_DOWN, gsShortcuts, delegate(GVariant, SimpleAction) {
            Session session = getCurrentSession();
            if (session !is null)
                session.addTerminal(Orientation.VERTICAL);
        });

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
                onUserSessionClose(getCurrentSession().uuid);
            }
        });

        //Load Session
        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_OPEN, gsShortcuts, delegate(GVariant, SimpleAction) { loadSession(); });

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
     * Create actions that will be delegated to the active terminal.
     * This is required due to a bug in GTK+ < 3.5.15.
     *
     * https://bugzilla.gnome.org/show_bug.cgi?id=740682
     * https://github.com/gnunn1/terminix/issues/342
     */
    void createDelegatedTerminalActions(GSettings gsShortcuts) {
        if (Version.checkVersion(3, 15, 3).length != 0) {
            SimpleActionGroup terminalActions = new SimpleActionGroup();

            foreach (string action; gsShortcuts.listKeys) {
                if (action.startsWith("terminal-")) {
                    logf(LogLevel.trace, "Registering terminal shortcut delegation for action %s", action[9..$]);
                    registerActionWithSettings(terminalActions, "terminal", action[9..$], gsShortcuts, delegate(GVariant va, SimpleAction sa) {
                        string terminalUUID = getActiveTerminalUUID();
                        logf(LogLevel.trace, "Delegating terminal action '%s' to terminal '%s'", sa.getName(), terminalUUID);
                        gx.terminix.terminal.terminal.Terminal terminal = cast(gx.terminix.terminal.terminal.Terminal)findWidgetForUUID(terminalUUID);
                        if (terminal !is null) {
                            terminal.triggerAction(sa.getName(), va);
                        }
                    });
                }
            }

            insertActionGroup("terminal", terminalActions);
        }
    }

    /**
     * Creates the session action popover
     */
    Popover createPopover(Widget parent) {
        GMenu model = new GMenu();

        GMenu mFileSection = new GMenu();
        mFileSection.appendItem(new GMenuItem(_("Open…"), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_OPEN)));
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
        Session session = new Session(name);
        session.initSession(profileUUID, workingDir, nb.getNPages() == 0);
        addSession(session);
    }

    void addSession(Session session) {
        session.addOnSessionClose(&onSessionClose);
        session.addOnIsActionAllowed(&onSessionIsActionAllowed);
        session.addOnSessionDetach(&onSessionDetach);
        session.addOnProcessNotification(&onSessionProcessNotification);
        session.addOnSessionStateChange(&onSessionStateChange);
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
        session.removeOnSessionStateChange(&onSessionStateChange);
        //remove session from Notebook
        nb.remove(session);
        updateUIState();
        //Close Window if there are no pages
        if (nb.getNPages() == 0) {
            if (gsSettings.getBoolean(SETTINGS_CLOSE_WITH_LAST_SESSION_KEY)) {
                trace("No more sessions, closing AppWindow");
                this.close();
            } else {
                createSession();
            }
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

    /**
     * Used to handle cases where the user requests a session be closed
     */
    bool onUserSessionClose(string sessionUUID) {
        trace("Sidebar requested to close session " ~ sessionUUID);
        if (sessionUUID.length > 0) {
            Session session = getSession(sessionUUID);
            if (session !is null) {
                if (session.isProcessRunning()) {
                    if (!showCanClosePrompt) return false;
                }
                closeSession(session);
                ss.populate(getSessions(), recentSessionFiles);
                return true;
            }
        }
        return false;
    }

    void closeSession(Session session) {
        bool isCurrentSession = (session == getCurrentSession());
        removeSession(session);
        session.destroy();
        if (!isCurrentSession) {
            updateTitle();
            updateUIState();
        }
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

    void onSessionStateChange(Session session, SessionStateChange stateChange) {
        if (getCurrentSession() == session) {
            updateUIState();
            updateTitle();
        }
    }

    void updateUIState() {
        tbSideBar.queueDraw();
        saCloseSession.setEnabled(nb.getNPages > 1);
        Session session = getCurrentSession();
        if (session !is null) {
            saSessionAddRight.setEnabled(!session.maximized);
            saSessionAddDown.setEnabled(!session.maximized);
        }
        lblSideBar.setLabel(format("%d / %d", nb.getCurrentPage() + 1, nb.getNPages()));
    }

    void updateTitle() {
        string title;
        Session session = getCurrentSession();
        if (session && nb.getNPages() == 1) {
            title = _(APPLICATION_NAME) ~ ": " ~ session.displayName;
        } else if (session) {
            title = _(APPLICATION_NAME) ~ " " ~ to!string(nb.getCurrentPage()+1) ~ ": " ~ session.displayName;
        } else {
            title = _(APPLICATION_NAME);
        }
        if (gsSettings.getBoolean(SETTINGS_DISABLE_CSD_KEY))
            setTitle(title);
        else
            hb.setTitle(title);
    }

    bool drawSideBarBadge(Scoped!Context cr, Widget widget) {

        // pw, ph, ps = percent width, height, size
        void drawBadge(double pw, double ph, double ps, RGBA fg, RGBA bg, int value) {
            int w = widget.getAllocatedWidth();
            int h = widget.getAllocatedHeight();

            double x = w * pw;
            double y = h * ph;
            double radius = min(w,h) * ps;

            cr.save();
            cr.setSourceRgba(bg.red, bg.green, bg.blue, bg.alpha);
            cr.arc(x, y, radius, 0.0, 2.0 * PI);
            cr.fillPreserve();
            cr.stroke();
            cr.selectFontFace("monospace", cairo_font_slant_t.NORMAL, cairo_font_weight_t.NORMAL);
            cr.setFontSize(10);
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
        //Draw number of notifications on button
        ulong count = 0;
        foreach (sn; sessionNotifications.values) {
            count = count + sn.messages.length;
        }
        if (count > 0) {
            widget.getStyleContext().lookupColor("theme_selected_fg_color", fg);
            widget.getStyleContext().lookupColor("theme_selected_bg_color", bg);
            bg.alpha = 0.9;
            drawBadge(0.87, 0.68, 0.15, fg, bg, to!int(count));
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
        tracef("Notification Received\n\tSummary=%s\n\tBody=%s", summary, _body);
        // If window not active, send notification to shell
        if (!isActive() && gsSettings.getBoolean(SETTINGS_NOTIFY_ON_PROCESS_COMPLETE_KEY)) {
            Notification n = new Notification(_(summary));
            n.setBody(_body);
            n.setDefaultAction("app.activate-session::" ~ sessionUUID);
            getApplication().sendNotification("command-completed", n);
            //if session not visible send to local handler
        }
        // If session not active, keep copy locally
        if (sessionUUID != getCurrentSession().uuid) {
            tracef("SessionUUID: %s versus Notification UUID: %s", sessionUUID, getCurrentSession().uuid);
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

    bool showCanCloseMultipleSessions() {
        if (!gsSettings.getBoolean(SETTINGS_PROMPT_ON_CLOSE_KEY)) return true;

        MessageDialog dialog = new MessageDialog(this, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.OK_CANCEL,
                _("There are multiple sessions open, close anyway?"), null);
        CheckButton cbIgnore = new CheckButton(_("Do not show this again"));
        cbIgnore.setMarginLeft(12);
        dialog.getContentArea().add(cbIgnore);
        dialog.setDefaultResponse(ResponseType.CANCEL);
        scope (exit) {
            dialog.destroy();
        }
        dialog.showAll();
        bool result = true;
        if (dialog.run() != ResponseType.OK) {
            result = false;
        }
        gsSettings.setBoolean(SETTINGS_PROMPT_ON_CLOSE_KEY, !cbIgnore.getActive());
        return result;
    }

    /**
     * Prompts the user if we can close. This is used both when closing a single
     * session and when closing the application window
     */
    bool showCanClosePrompt() {
        MessageDialog dialog = new MessageDialog(this, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.OK_CANCEL,
                _("There are processes that are still running, close anyway?"), null);

        dialog.setDefaultResponse(ResponseType.CANCEL);
        scope (exit) {
            dialog.destroy();
        }
        if (dialog.run() != ResponseType.OK) {
            return false;
        }
        return true;
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
            return !showCanClosePrompt();
        } else if (nb.getNPages() > 1) {
            return !showCanCloseMultipleSessions();
        }
        return false;
    }

    void onWindowDestroyed(Widget) {
        terminix.removeAppWindow(this);
    }

    void onWindowShow(Widget) {
        if (terminix.getGlobalOverrides().maximize) {
            maximize();
        } else if (terminix.getGlobalOverrides().minimize) {
            iconify();
        } else if (terminix.getGlobalOverrides().fullscreen) {
            changeActionState(ACTION_WIN_FULLSCREEN, new GVariant(true));
            fullscreen();
        } else if (isQuake()) {
            if (gsSettings.getBoolean(SETTINGS_QUAKE_ACTIVE_MONITOR_KEY)) {
                moveAndSizeQuake();
            }
            trace("Focus terminal");
            activate();
            activateFocus();
            getActiveTerminal().focusTerminal();
        }
    }

    void onWindowRealized(Widget) {
        if (isQuake()) {
            applyPreference(SETTINGS_QUAKE_HEIGHT_PERCENT_KEY);
        } else if (terminix.getGlobalOverrides().x > 0) {
            move(terminix.getGlobalOverrides().x, terminix.getGlobalOverrides().y);
        }
    }

    void onCompositedChanged(Widget) {
        trace("Composite changed");
        updateVisual();
    }

    void applyPreference(string key) {
        switch(key) {
            case SETTINGS_QUAKE_WIDTH_PERCENT_KEY, SETTINGS_QUAKE_HEIGHT_PERCENT_KEY, SETTINGS_QUAKE_ACTIVE_MONITOR_KEY, SETTINGS_QUAKE_SPECIFIC_MONITOR_KEY, SETTINGS_QUAKE_ALIGNMENT_KEY:
                if (isQuake) {
                    moveAndSizeQuake();
                }
                break;
            case SETTINGS_QUAKE_SHOW_ON_ALL_WORKSPACES_KEY:
                if (isQuake) {
                    if (gsSettings.getBoolean(SETTINGS_QUAKE_SHOW_ON_ALL_WORKSPACES_KEY)) stick();
                    else unstick();
                }
                break;
            case SETTINGS_QUAKE_DISABLE_ANIMATION_KEY:
                if (isQuake) {
                    if (gsSettings.getBoolean(SETTINGS_QUAKE_DISABLE_ANIMATION_KEY)) {
                        setTypeHint(GdkWindowTypeHint.UTILITY);
                    } else {
                        setTypeHint(GdkWindowTypeHint.NORMAL);
                    }
                }
                break;
            /*
            case SETTINGS_QUAKE_KEEP_ON_TOP_KEY:
                if (isQuake) {
                    bool keepOnTop = gsSettings.getBoolean(SETTINGS_QUAKE_KEEP_ON_TOP_KEY);
                    setKeepAbove(keepOnTop);
                    //setSkipTaskbarHint(keepOnTop);
                    //setSkipPagerHint(keepOnTop);
                }
                break;
            */
            default:
                break;
        }
    }

    void moveAndSizeQuake() {
        GdkRectangle rect;
        getQuakePosition(rect);
        if (getWindow() !is null) {
            getWindow().moveResize(rect.x, rect.y, rect.width, rect.height);
            trace("moveResize for quake mode");
        } else {
            move(rect.x, rect.y);
            resize(rect.width, rect.height);
        }
    }

    void getQuakePosition(out GdkRectangle rect) {
        Screen screen = getScreen();

        int monitor = screen.getPrimaryMonitor();
        if (!isWayland(this)) {
            if (gsSettings.getBoolean(SETTINGS_QUAKE_ACTIVE_MONITOR_KEY)) {
                if (screen.getActiveWindow() !is null) {
                    monitor = screen.getMonitorAtWindow(screen.getActiveWindow());
                }
            } else {
                int altMonitor = gsSettings.getInt(SETTINGS_QUAKE_SPECIFIC_MONITOR_KEY);
                if (altMonitor>=0 && altMonitor < getScreen().getNMonitors()) {
                    monitor = altMonitor;
                }
            }
        }
        getScreen().getMonitorGeometry(monitor, rect);

        //Height
        double percent = to!double(gsSettings.getInt(SETTINGS_QUAKE_HEIGHT_PERCENT_KEY))/100.0;
        rect.height = to!int(rect.height * percent);
        
        //Width

        // Window only gets positioned properly in Wayland when width is 100%, 
        // not sure if this kludge is really a good idea and will work consistently. 
        if (isWayland(this)) {
            percent = 1;
        } else {
            percent = to!double(gsSettings.getInt(SETTINGS_QUAKE_WIDTH_PERCENT_KEY))/100.0;
        }
        if (percent < 1) {
            int width = to!int(rect.width * percent);
            tracef("Calculated width %d", width);
            switch (gsSettings.getString(SETTINGS_QUAKE_ALIGNMENT_KEY)) {
                case SETTINGS_QUAKE_ALIGNMENT_LEFT_VALUE:
                    break;
                case SETTINGS_QUAKE_ALIGNMENT_CENTER_VALUE:
                    rect.x = rect.x + (rect.width - width)/2;
                    break;
                case SETTINGS_QUAKE_ALIGNMENT_RIGHT_VALUE:
                    rect.x = rect.x + rect.width - width;
                    break;
                default:
                    break;
            }
            rect.width = width;
        }
        tracef("Quake window: monitor=%d, x=%d, y=%d, width=%d, height=%d", monitor, rect.x, rect.y, rect.width, rect.height);
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
            if (session.uuid == sessionUUID) {
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
        if (!nb.getRealized()) {
            try {
                Session.getPersistedSessionSize(value, width, height);
                if (nb.getNPages() == 0) {
                    setDefaultSize(width, height);
                }
            }
            catch (Exception e) {
                throw new SessionCreationException("Session could not be created due to error: " ~ e.msg, e);
            }
        }
		addRecentSessionFile(filename);
        tracef("Session dimensions: w=%d, h=%d", width, height);
        Session session = new Session("");
        session.initSession(value, filename, width, height, nb.getNPages() == 0);
        addSession(session);
    }

    /**
     * Loads session from a file, prompt user to select file
     */
    void loadSession() {
        FileChooserDialog fcd = new FileChooserDialog(
          _("Load Session"),
          this,
          FileChooserAction.OPEN,
          [_("Open"), _("Cancel")]);
        scope (exit) {
            fcd.destroy();
        }
        addFilters(fcd);
        fcd.setDefaultResponse(ResponseType.OK);
        if (fcd.run() == ResponseType.OK) {
            try {
                loadSession(fcd.getFilename());
                addRecentSessionFile(fcd.getFilename());
            }
            catch (Exception e) {
                fcd.hide();
                removeRecentSessionFile(fcd.getFilename());
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
            FileChooserDialog fcd = new FileChooserDialog(
              _("Save Session"),
              this,
              FileChooserAction.SAVE,
              [_("Save"), _("Cancel")]);
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
        addRecentSessionFile(filename);
        string json = session.serialize().toPrettyString();
        write(filename, json);
        session.filename = filename;
    }

    /**
     * Creates a new session based on parameters, user is not prompted
     */
    void createSession(string name, string profileUUID, string workingDir = null) {
        createNewSession(name, profileUUID, workingDir);
    }

    void loadRecentSessionFileList() {
        recentSessionFiles = gsSettings.getStrv(SETTINGS_RECENT_SESSION_FILES_KEY);
    }

    void saveRecentSessionFileList() {
        gsSettings.setStrv(SETTINGS_RECENT_SESSION_FILES_KEY, recentSessionFiles);
    }

    /**
     * Prepends a file path to the recent session files list
     */
    void addRecentSessionFile(string path, bool save = true) {
        // Don't save after removing as the list will be saved later
        removeRecentSessionFile(path, false);

        recentSessionFiles = path ~ recentSessionFiles;

        if (save) {
            saveRecentSessionFileList();
        }
    }

    /**
     * Removes a file path from from the recent session files list
     */
    void removeRecentSessionFile(string path, bool save = true) {
        string[] temp;

        foreach (int i, string aPath; recentSessionFiles) {
            if (aPath != path) {
                temp ~= aPath;
            }
        }

        recentSessionFiles = temp;

        if (save) {
            saveRecentSessionFileList();
        }
    }

public:

    this(Application application) {
        super(application);
        terminix.addAppWindow(this);
        gsSettings = new GSettings(SETTINGS_ID);
        gsSettings.addOnChanged(delegate(string key, GSettings) {
            applyPreference(key);
        });
        setTitle(_("Terminix"));
        setIconName("com.gexperts.Terminix");

        loadRecentSessionFileList();
        gsSettings.addOnChanged(delegate(string key, GSettings) {
            if (key == SETTINGS_RECENT_SESSION_FILES_KEY) {
                loadRecentSessionFileList();
            }
        });

        if (gsSettings.getBoolean(SETTINGS_ENABLE_TRANSPARENCY_KEY)) {
            updateVisual();
        }
        if (terminix.getGlobalOverrides().quake) {
            _quake = true;
            setDecorated(false);
            setGravity(GdkGravity.STATIC);
            setKeepAbove(true);
            //applyPreference(SETTINGS_QUAKE_KEEP_ON_TOP_KEY);
            applyPreference(SETTINGS_QUAKE_DISABLE_ANIMATION_KEY);
            setSkipTaskbarHint(true);
            setSkipPagerHint(true);
            applyPreference(SETTINGS_QUAKE_HEIGHT_PERCENT_KEY);
            applyPreference(SETTINGS_QUAKE_SHOW_ON_ALL_WORKSPACES_KEY);
        } 

        forceAppMenu();
        createUI();

        addOnDelete(&onWindowClosed);
        addOnDestroy(&onWindowDestroyed);
        addOnRealize(&onWindowRealized);

        addOnShow(&onWindowShow, ConnectFlags.AFTER);
        addOnSizeAllocate(delegate(GdkRectangle* rect, Widget) {
            if (lastWidth != rect.width || lastHeight != rect.height) {
                //invalidate rendered background
                if (isBGImage !is null) {
                    isBGImage.destroy();
                    isBGImage = null;
                }
                lastWidth = rect.width;
                lastHeight = rect.height;
            }
        }, ConnectFlags.AFTER);
        addOnCompositedChanged(&onCompositedChanged);
        addOnFocusOut(delegate(Event e, Widget widget) {
            if (isQuake && gsSettings.getBoolean(SETTINGS_QUAKE_HIDE_LOSE_FOCUS_KEY)) {
                Window window = terminix.getActiveWindow();
                if (window !is null) {
                    if (window.getWindowStruct() == this.getWindowStruct()) {
                        ListG list = window.listToplevels();
                        Window[] windows = list.toArray!(Window)();
                        tracef("Top level windows = %d", windows.length);
                        foreach(Window child; windows) {
                            Dialog dialog = cast(Dialog)child;
                            if (dialog !is null && dialog.getTransientFor() !is null && dialog.getTransientFor().getWindowStruct() == this.getWindowStruct()) return false;
                        } 
                    }
                }
                trace("Focus lost, hiding quake window");
                threadsAddTimeoutDelegate(100, delegate() {
                    this.hide();
                    return false;
                });
            }
            return false;
        }, ConnectFlags.AFTER);
    }

    void initialize() {
        if (terminix.getGlobalOverrides().session.length > 0) {
            foreach (sessionFilename; terminix.getGlobalOverrides().session) {
                try {
                    if (!exists(sessionFilename)) {
                        string filename = buildPath(terminix.getGlobalOverrides().cwd, sessionFilename);
                        tracef("Trying filename %s", filename);
                        if (exists(filename)) sessionFilename = filename;
                    }
                    loadSession(sessionFilename);
                } catch (SessionCreationException e) {
                    errorf("Could not load session from file '%s', error occurred", sessionFilename);
                    error(e.msg);
                }
            }
            return;
        }
        //Create an initial session using default session name and profile
        createSession(gsSettings.getString(SETTINGS_SESSION_NAME_KEY), prfMgr.getDefaultProfile());
    }

    void initialize(Session session) {
        addSession(session);
    }

    /**
     * Returns true if this window is in quake mode.
     */
    bool isQuake() {
        return _quake;
    }

    /**
     * Activates the specified sessionUUID
     */
    bool activateSession(string sessionUUID) {
        for (int i = 0; i < nb.getNPages(); i++) {
            Session session = getSession(i);
            if (session.uuid == sessionUUID) {
                nb.setCurrentPage(i);
                return true;
            }
        }
        return false;
    }

    /**
     * Focus the previous session
     */
    void focusPreviousSession() {
        if (nb.getCurrentPage() > 0) {
            nb.prevPage();
        } else {
            nb.setCurrentPage(nb.getNPages() - 1);
        }
    }

    /**
     * Focus the next session
     */
    void focusNextSession() {
        if (nb.getCurrentPage() < nb.getNPages() - 1) {
            nb.nextPage();
        } else {
            nb.setCurrentPage(0);
        }
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

    bool activateTerminal(string terminalUUID) {
        for (int i = 0; i < nb.getNPages(); i++) {
            Session session = cast(Session) nb.getNthPage(i);
            Widget result = session.findWidgetForUUID(terminalUUID);
            if (result !is null) {
                activateTerminal(session.uuid, terminalUUID);
                return true;
            }
        }
        return false;
    }

    ITerminal getActiveTerminal() {
        Session session = getCurrentSession();
        if (session !is null) {
            return session.getActiveTerminal();
        }
        return null;
    }

    string getActiveTerminalUUID() {
        ITerminal terminal = getActiveTerminal();
        if (terminal !is null) return terminal.uuid;
        return null;
    }

    /**
     * Finds the widget matching a specific UUID, typically
     * a Session or Terminal
     */
    Widget findWidgetForUUID(string uuid) {
        for (int i = 0; i < nb.getNPages(); i++) {
            Session session = cast(Session) nb.getNthPage(i);
            if (session.uuid == uuid)
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
        // Hide the sidebar if it is open
        if (sb.getRevealChild()) {
            saViewSideBar.activate(null);
        }

        string workingDir;
        // Inherit current session directory unless overrides exist, fix #343
        if (terminix.getGlobalOverrides().cwd.length ==0 && terminix.getGlobalOverrides().workingDir.length == 0) {
            ITerminal terminal = getActiveTerminal();
            if (terminal !is null) {
                workingDir = terminal.currentLocalDirectory;
            }
        }
        if (gsSettings.getBoolean(SETTINGS_PROMPT_ON_NEW_SESSION_KEY)) {
            SessionProperties sp = new SessionProperties(this, gsSettings.getString(SETTINGS_SESSION_NAME_KEY), prfMgr.getDefaultProfile());
            scope (exit) {
                sp.destroy();
            }
            sp.showAll();
            if (sp.run() == ResponseType.OK) {
                createSession(sp.name, sp.profileUUID, workingDir);
            }
        } else {
            createSession(gsSettings.getString(SETTINGS_SESSION_NAME_KEY), prfMgr.getDefaultProfile(), workingDir);
        }
    }

    /**
     * Invaidates background image cache and redraws
     */
    void updateBackgroundImage() {
        if (isBGImage !is null) {
            trace("Destroying cached background image");
            isBGImage.destroy();
            isBGImage = null;
        }
        queueDraw();
    }

    /**
     * Returns an image surface that contains the rendered background
     * image. This returns null if no background image has been set.
     *
     * The image surface is cached between invocations to improve draw
     * performance as per #340.
     */
    ImageSurface getBackgroundImage(Widget widget) {
        if (isBGImage !is null) {
            return isBGImage;
        }

        ImageSurface surface = terminix.getBackgroundImage();
        if (surface is null) {
            if (isBGImage !is null) {
                isBGImage.destroy();
                isBGImage = null;
            }
            return isBGImage;
        }

        ImageLayoutMode mode;
        string bgMode = gsSettings.getString(SETTINGS_BACKGROUND_IMAGE_MODE_KEY);
        final switch (bgMode) {
            case SETTINGS_BACKGROUND_IMAGE_MODE_SCALE_VALUE:
                mode = ImageLayoutMode.SCALE;
                break;
            case SETTINGS_BACKGROUND_IMAGE_MODE_TILE_VALUE:
                mode = ImageLayoutMode.TILE;
                break;
            case SETTINGS_BACKGROUND_IMAGE_MODE_CENTER_VALUE:
                mode = ImageLayoutMode.CENTER;
                break;
            case SETTINGS_BACKGROUND_IMAGE_MODE_STRETCH_VALUE:
                mode = ImageLayoutMode.STRETCH;
                break;
        }
        int scale = gsSettings.getEnum(SETTINGS_BACKGROUND_IMAGE_SCALE_KEY);
        isBGImage = renderImage(surface, widget.getAllocatedWidth(), widget.getAllocatedHeight(), mode, false, cast(cairo_filter_t) scale);
        return isBGImage;
    }
}
