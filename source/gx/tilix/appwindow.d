/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.appwindow;

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
import std.uuid;

import cairo.Context;
import cairo.ImageSurface;

import gtk.Application : Application;
import gio.Application : GioApplication = Application;
import gtk.ApplicationWindow : ApplicationWindow;
import gtkc.giotypes : GApplicationFlags;

import gdkpixbuf.Pixbuf;

import gdk.Event;
import gdk.Keysyms;
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

import gobject.Signals;
import gobject.Value;

import gtk.AspectFrame;
import gtk.Box;
import gtk.Button;
import gtk.CheckButton;
import gtk.Dialog;
import gtk.Entry;
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
import gtk.Stack;
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

import gx.tilix.application;
import gx.tilix.closedialog;
import gx.tilix.cmdparams;
import gx.tilix.common;
import gx.tilix.constants;
import gx.tilix.customtitle;
import gx.tilix.prefeditor.titleeditor;
import gx.tilix.preferences;
import gx.tilix.session;
import gx.tilix.sidebar;

/**
 * The GTK Application Window for Tilix. It is responsible for
 * managing sessions which are held as pages in a GTK Notebook. All
 * session actions are created and managed here but against the session
 * prefix rather then the win prefix which is typically used for
 * a AplicationWindow.
 */
class AppWindow : ApplicationWindow, IIdentifiable {

public:
    //Public Actions
    enum ACTION_PREFIX = "session";
    enum ACTION_SESSION_ADD_RIGHT = "add-right";
    enum ACTION_SESSION_ADD_DOWN = "add-down";

private:

    // GTK CSS Style to flag attention
    enum CSS_CLASS_NEEDS_ATTENTION = "needs-attention";

    // Private Actions
    enum ACTION_SESSION_CLOSE = "close";
    enum ACTION_SESSION_NAME = "name";
    enum ACTION_SESSION_NEXT_TERMINAL = "switch-to-next-terminal";
    enum ACTION_SESSION_PREV_TERMINAL = "switch-to-previous-terminal";
    enum ACTION_SESSION_TERMINAL_X = "switch-to-terminal-";
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
    enum ACTION_SESSION_REORDER_PREVIOUS = "reorder-previous-session";
    enum ACTION_SESSION_REORDER_NEXT = "reorder-next-session";

    string _windowUUID;

    bool useTabs = false;

    Notebook nb;
    HeaderBar hb;
    SideBar sb;
    ToggleButton tbSideBar;
    ToggleButton tbFind;
    CustomTitle cTitle;

    SimpleActionGroup sessionActions;
    MenuButton mbSessionActions;
    SimpleAction saSyncInput;
    SimpleAction saCloseSession;
    SimpleAction saViewSideBar;
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

    // True if window is being destroyed
    bool _destroyed;

    string[] recentSessionFiles;

    // The user overridden application title, specific to the window only
    string _overrideTitle;

    // Tells the window when closing not to prompt the user, just close
    bool _noPrompt = false;

    // Handler of the Find button "toggled" signal
    gulong _tbFindToggledId;

    // Preference for the Window Style, i.e normal,disable-csd,disable-csd-hide-toolbar,borderless
    size_t windowStyle = 0;

    enum DialogPath {
        SAVE_SESSION,
        LOAD_SESSION
    }

    // Save file dialog paths between invocations
    string[DialogPath] dialogPaths;

    /**
     * Forces the app menu in the decoration layouts so in environments without an app-menu
     * it will be rendered by GTK as part of the window.
     */
    void forceAppMenu() {
        Settings settings = getSettings();
        if (settings !is null) {
            Value value = new Value("");
            settings.getProperty(GTK_DECORATION_LAYOUT, value);
            string layout = value.getString();
            tracef("Layout: %s", layout);
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
            if (desktop.indexOf("Unity") >= 0 && !isCSDDisabled()) {
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

    bool isCSDDisabled() {
        return windowStyle > 0;
    }

    bool hideToolbar() {
        return gsSettings.getBoolean(SETTINGS_QUAKE_HIDE_HEADERBAR_KEY) || windowStyle > 1;
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
        if (useTabs) {
            nb.getStyleContext().addClass("tilix-background");
            nb.setScrollable(true);
            nb.setGroupName("tilix");
            nb.addOnCreateWindow(&onCreateWindow);
            nb.setCanFocus(false);
        }
        nb.addOnPageAdded(&onPageAdded);
        nb.addOnPageRemoved(&onPageRemoved);
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
            if (!useTabs && sb.getChildRevealed() && getCurrentSession() !is null) {
                sb.selectSession(getCurrentSession().uuid);
            }
            if (useTabs) {
                threadsAddIdleDelegate(delegate() {
                    // Delay focus restore
                    trace("Delayed focus restore");
                    session.focusRestore();
                    return false;
                });
            }
        }, ConnectFlags.AFTER);
        if (!useTabs) {
            sb = new SideBar();
            sb.onSelected.connect(&onSessionSelected);
            sb.onClose.connect(&onUserSessionClose);
            sb.onRequestReorder.connect(&onSessionReorder);
            sb.onSessionDetach.connect(&onSessionDetach);
            sb.onIsActionAllowed.connect(&onIsActionAllowed);
        } else {
            if (isQuake) {
                nb.setTabPos(cast(GtkPositionType) gsSettings.getEnum(SETTINGS_QUAKE_TAB_POSITION_KEY));
            } else {
                nb.setTabPos(cast(GtkPositionType) gsSettings.getEnum(SETTINGS_TAB_POSITION_KEY));
            }
        }

        Overlay overlay;
        if (!useTabs) {
            overlay = new Overlay();
            overlay.add(nb);
            overlay.addOverlay(sb);
        }

        //Could be a Box or a Headerbar depending on value of disable_csd
        hb = createHeaderBar();

        if (isQuake() || isCSDDisabled()) {
            hb.getStyleContext().addClass("tilix-embedded-headerbar");
            Box box = new Box(Orientation.VERTICAL, 0);
            box.add(hb);
            if (overlay !is null) box.add(overlay);
            else box.add(nb);
            if (isQuake()) {
                box.getStyleContext().addClass("tilix-quake-frame");
            }
            add(box);
            hb.setNoShowAll(hideToolbar());
        } else {
            this.setTitlebar(hb);
            hb.setShowCloseButton(true);
            hb.setTitle(_(APPLICATION_NAME));
            if (overlay !is null) add(overlay);
            else add(nb);
        }
    }

    HeaderBar createHeaderBar() {
        //New tab button
        Button btnNew;
        if (useTabs) {
            btnNew = new Button("tab-new-symbolic", IconSize.BUTTON);
        } else {
            btnNew = new Button("list-add-symbolic", IconSize.BUTTON);
        }
        btnNew.setFocusOnClick(false);
        btnNew.setAlwaysShowImage(true);
        btnNew.addOnClicked(delegate(Button) {
            createSession();
        });
        btnNew.setTooltipText(_("Create a new session"));

        Box bSessionButtons;

        if (!useTabs) {
            //View sessions button
            tbSideBar = new ToggleButton();
            tbSideBar.getStyleContext().addClass("session-sidebar-button");
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

            bSessionButtons = new Box(Orientation.HORIZONTAL, 0);
            bSessionButtons.getStyleContext().addClass("linked");
            btnNew.getStyleContext().addClass("session-new-button");
            bSessionButtons.packStart(tbSideBar, false, false, 0);
            bSessionButtons.packStart(btnNew, false, false, 0);
        } 

        //Session Actions
        mbSessionActions = new MenuButton();
        mbSessionActions.setFocusOnClick(false);
        Image iHamburger = new Image("open-menu-symbolic", IconSize.MENU);
        mbSessionActions.add(iHamburger);
        mbSessionActions.setPopover(createPopover(mbSessionActions));

        Button btnAddHorizontal = new Button("tilix-add-horizontal-symbolic", IconSize.MENU);
        btnAddHorizontal.setDetailedActionName(getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_ADD_RIGHT));
        btnAddHorizontal.setFocusOnClick(false);
        btnAddHorizontal.setTooltipText(_("Add terminal right"));

        Button btnAddVertical = new Button("tilix-add-vertical-symbolic", IconSize.MENU);
        btnAddVertical.setDetailedActionName(getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_ADD_DOWN));
        btnAddVertical.setTooltipText(_("Add terminal down"));
        btnAddVertical.setFocusOnClick(false);

        // Add find button
        tbFind = new ToggleButton();
        tbFind.setImage(new Image("edit-find-symbolic", IconSize.MENU));
        tbFind.setTooltipText(_("Find text in terminal"));
        tbFind.setFocusOnClick(false);
        _tbFindToggledId = tbFind.addOnToggled(delegate(ToggleButton) {
            if (getCurrentSession() !is null) {
                getCurrentSession().toggleTerminalFind();
            }
        });

        //Header Bar
        HeaderBar header = new HeaderBar();
        if (!isCSDDisabled()) {
            header.setCustomTitle(createCustomTitle());
        }
        if (useTabs) {
            header.packStart(btnNew);
        } else {
            header.packStart(bSessionButtons);
        }
        header.packStart(btnAddHorizontal);
        header.packStart(btnAddVertical);
        header.packEnd(mbSessionActions);
        header.packEnd(tbFind);
        return header;
    }

    void onCustomTitleChange(string title) {
            _overrideTitle = title;
            updateTitle;
    }

    void onCustomTitleCancelEdit() {
        if (getCurrentSession() !is null) {
            getCurrentSession().focusRestore();
        }
    }

    void onCustomTitleEdit(CumulativeResult!string result) {
        if (_overrideTitle.length > 0) {
            result.addResult(_overrideTitle);
        } else {
            result.addResult(gsSettings.getString(SETTINGS_APP_TITLE_KEY));
        }
    }

    Widget createCustomTitle() {
        cTitle = new CustomTitle();
        cTitle.onTitleChange.connect(&onCustomTitleChange);
        cTitle.onCancelEdit.connect(&onCustomTitleCancelEdit);
        cTitle.onEdit.connect(&onCustomTitleEdit);
        return cTitle;
    }

    /**
     * Create Window actions
     */
    void createWindowActions(GSettings gsShortcuts) {
        debug(GC) {
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

        registerActionWithSettings(this, "win", ACTION_SESSION_REORDER_PREVIOUS, gsShortcuts, delegate(GVariant, SimpleAction) {
            reorderCurrentSessionRelative(-1);
        });

        registerActionWithSettings(this, "win", ACTION_SESSION_REORDER_NEXT, gsShortcuts, delegate(GVariant, SimpleAction) {
            reorderCurrentSessionRelative(1);
        });

        registerActionWithSettings(this, "win", ACTION_WIN_FULLSCREEN, gsShortcuts, delegate(GVariant value, SimpleAction sa) {
            trace("Setting fullscreen");
            if (getWindow() !is null && ((getWindow().getState() & GdkWindowState.FULLSCREEN) == GdkWindowState.FULLSCREEN)) {
                unfullscreen();
                sa.setState(new GVariant(false));
            } else {
                fullscreen();
                sa.setState(new GVariant(true));
            }
        }, null, new GVariant(false));

        if (!useTabs) {
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
        }
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
            if (session !is null && !session.maximized)
                session.addTerminal(Orientation.HORIZONTAL);
        });
        saSessionAddDown = registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_ADD_DOWN, gsShortcuts, delegate(GVariant, SimpleAction) {
            Session session = getCurrentSession();
            if (session !is null && !session.maximized) 
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
                CumulativeResult!bool results = new CumulativeResult!bool();
                onUserSessionClose(getCurrentSession().uuid, results);
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

            MessageDialog dialog = new MessageDialog(this, DialogFlags.MODAL + DialogFlags.USE_HEADER_BAR, MessageType.QUESTION, ButtonsType.OK_CANCEL, _("Enter a new name for the session"), null);
            scope (exit) {
                dialog.destroy();
            }
            dialog.setTransientFor(this);
            dialog.setTitle( _("Change Session Name"));
            Entry entry = new Entry(session.name);
            entry.setWidthChars(30);
            entry.addOnActivate(delegate(Entry) {
                dialog.response(ResponseType.OK);
            });
            if (isWayland(this) && Version.checkVersion(3, 14, 0).length == 0) {
                dialog.getMessageArea().add(createTitleEditHelper(entry, TitleEditScope.SESSION));
            } else {
                dialog.getMessageArea().add(entry);
            }
            dialog.setDefaultResponse(ResponseType.OK);
            dialog.showAll();
            if (dialog.run() == ResponseType.OK && entry.getText().length > 0) {
                session.name = entry.getText();
                updateTitle();
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
     * https://github.com/gnunn1/tilix/issues/342
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
                        gx.tilix.terminal.terminal.Terminal terminal = cast(gx.tilix.terminal.terminal.Terminal)findWidgetForUUID(terminalUUID);
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

        if (isQuake()) {
            GMenu mPrefSection = new GMenu();
            mPrefSection.appendItem(new GMenuItem(_("Preferences"), getActionDetailedName("app", "preferences")));
            model.appendSection(null, mPrefSection);
        }

        debug(GC) {
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

    void onPageAdded(Widget page, uint index, Notebook) {
        trace("**** Adding page");

        Session session = cast(Session) page;

        session.onClose.connect(&onSessionClose);
        session.onAttach.connect(&onSessionAttach);
        session.onDetach.connect(&onSessionDetach);
        session.onStateChange.connect(&onSessionStateChange);
        session.onIsActionAllowed.connect(&onIsActionAllowed);
        session.onProcessNotification.connect(&onSessionProcessNotification);

        if (useTabs) {
            SessionTabLabel label = cast(SessionTabLabel) nb.getTabLabel(page);
            label.onCloseClicked.connect(&closeSession);
            nb.setTabReorderable(session, true);
            nb.setTabDetachable(session, true);
        }
    }

    void onPageRemoved(Widget page, uint index, Notebook notebook) {
        trace("**** Removing page");
        Session session = cast(Session) page;

        //remove event handlers
        session.onClose.disconnect(&onSessionClose);
        session.onAttach.disconnect(&onSessionAttach);
        session.onDetach.disconnect(&onSessionDetach);
        session.onStateChange.disconnect(&onSessionStateChange);
        session.onIsActionAllowed.disconnect(&onIsActionAllowed);
        session.onProcessNotification.disconnect(&onSessionProcessNotification);
    }

    void addSession(Session session) {
        int index;
        if (!useTabs) {
            index = nb.appendPage(session, session.name);
        } else {
            SessionTabLabel label = new SessionTabLabel(session.displayName, session);
            index = nb.appendPage(session, label);
        }
        nb.showAll();
        nb.setCurrentPage(index);
        updateUIState();
    }

    void removeSession(Session session) {
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
    void onUserSessionClose(string sessionUUID, CumulativeResult!bool result) {
        if (_noPrompt) {
            result.addResult(false);
            return;
        }
        trace("Sidebar requested to close session " ~ sessionUUID);
        if (sessionUUID.length > 0) {
            Session session = getSession(sessionUUID);
            if (session !is null) {
                ProcessInformation pi = session.getProcessInformation();
                if (pi.children.length > 0) {
                    bool canClose = promptCanCloseProcesses(gsSettings, this, pi);
                    if (!canClose) {
                        result.addResult(false);
                        return;
                    }
                }
                closeSession(session);
                result.addResult(true);
                return;
            }
        }
        result.addResult(false);
        return;
    }

    void closeSession(Session session) {
        //remove session reference from label
        if (useTabs) {
            SessionTabLabel label = cast(SessionTabLabel) nb.getTabLabel(session);
            if (label !is null) {
                label.onCloseClicked.disconnect(&closeSession);
                label.clear();
            }
        }
        bool isCurrentSession = (session == getCurrentSession());
        removeSession(session);
        // Don't destroy session artificially due to GtkD issues
        //session.destroy();
        if (!isCurrentSession) {
            updateTitle();
            updateUIState();
        }
        trace("Session closed");
    }

    void onSessionClose(Session session) {
        closeSession(session);
    }

    void onFileSelected(string file) {
        if (file) {
            try {
                loadSession(file);
            }
            catch (SessionCreationException e) {
                removeRecentSessionFile(file);

                showErrorDialog(this, e.msg);
            }
        }
    }

    void onFileRemoved(string file) {
        removeRecentSessionFile(file);
    }

    void onOpenSelected(string uuid) {
        if (uuid) {
            activateSession(uuid);
        }
    }

    void reorderCurrentSessionRelative(int offset) {
        int page = nb.getCurrentPage();
        Session session = getCurrentSession();
        nb.reorderChild(session, page + offset);
    }

    void onSessionReorder(string sourceUUID, string targetUUID, bool after, CumulativeResult!bool result) {
        Session sourceSession = getSession(sourceUUID);
        Session targetSession = getSession(targetUUID);
        if (sourceSession is null || targetSession is null) {
            errorf("Unexpected error for DND, source or target page is null %s, %s", sourceUUID, targetUUID);
            result.addResult(false);
            return;
        }
        int index;
        if (!after) {
            index = nb.pageNum(targetSession);
        } else {
            index = nb.pageNum(targetSession);
            if (index == nb.getNPages() - 1) index = -1;
        }
        nb.reorderChild(sourceSession, index);
        result.addResult(true);
        updateUIState();
    }

    /**
     * Invoked by sidebar when user selects a session.
     */
    void onSessionSelected(string sessionUUID) {
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
    }

    /**
     * Invoked by DND a session on a terminal
     */
    void onSessionAttach(string sessionUUID) {

        AppWindow getWindow(Session session) {

            Widget widget = session.getParent();
            while (widget !is null) {
                AppWindow result = cast(AppWindow) widget;
                if (result !is null)
                    return result;
                widget = widget.getParent();
            }
            return null;
        }

        Session session = getSession(sessionUUID);
        // If session isn't null it already belongs to this window, ignore
        if (session !is null) return;

        session = cast(Session) tilix.findWidgetForUUID(sessionUUID);
        if (session is null) {
            errorf("The session %s could not be located", sessionUUID);
            return;
        }

        AppWindow sourceWindow = getWindow(session);
        if (sourceWindow is null) {
            errorf("The AppWindow for session %s could not be located", sessionUUID);
            return;
        }

        sourceWindow.removeSession(session);
        addSession(session);
    }

    AppWindow cloneWindow() {
        AppWindow result = new AppWindow(tilix, true);
        tilix.addAppWindow(result);
        result.setDefaultSize(getAllocatedWidth(), getAllocatedHeight());
        if (isMaximized) result.maximize();
        return result;        
    }

    Notebook onCreateWindow(Widget page, int x, int y, Notebook) {
        SessionTabLabel label = cast(SessionTabLabel) nb.getTabLabel(page);
        if (label !is null) {
            label.onCloseClicked.disconnect(&closeSession);
        }
        AppWindow window = cloneWindow();
        window.move(x, y);
        window.showAll();
        return window.nb;
    }

    void onSessionDetach(string sessionUUID, int x, int y) {
        Session session = getSession(sessionUUID);
        if (session !is null) {
            onSessionDetach(session, x, y, false);
        } else {
            errorf("Could not locate session for %s", sessionUUID);
        }
    }

    void onSessionDetach(Session session, int x, int y, bool isNewSession) {
        trace("Detaching session");
        //Detach an existing session, let's close it
        if (!isNewSession) {
            removeSession(session);
        }
        AppWindow window = new AppWindow(tilix);
        tilix.addAppWindow(window);
        window.initialize(session);
        window.move(x, y);
        window.showAll();
    }

    void onSessionStateChange(Session session, SessionStateChange stateChange) {
        trace("State change received");
        if (getCurrentSession() == session) {
            updateUIState();
            updateTitle();
            if (stateChange == SessionStateChange.TERMINAL_FOCUSED) {
                Signals.handlerBlock(tbFind, _tbFindToggledId);
                tbFind.setActive(getActiveTerminal().isFindToggled());
                Signals.handlerUnblock(tbFind, _tbFindToggledId);
            }
        }
        if (useTabs && ((stateChange == SessionStateChange.TERMINAL_TITLE) || (stateChange == SessionStateChange.SESSION_TITLE)) || (stateChange == SessionStateChange.TERMINAL_FOCUSED)) {
            SessionTabLabel label = cast(SessionTabLabel) nb.getTabLabel(session);
            if (label !is null) label.text=session.displayName;
        }
    }

    void updateUIState() {
        if (!useTabs) {
            tbSideBar.queueDraw();
        }
        saCloseSession.setEnabled(nb.getNPages > 1);
        Session session = getCurrentSession();
        if (session !is null) {
            saSessionAddRight.setEnabled(!session.maximized);
            saSessionAddDown.setEnabled(!session.maximized);
        }
        if (useTabs) {
            nb.setShowTabs(nb.getNPages() > 1);
            for (int i = 0; i < nb.getNPages(); i++) {
                Session s = getSession(i);
                SessionTabLabel label = cast(SessionTabLabel) nb.getTabLabel(s);
                if (label is null) continue;
                if (s.uuid in sessionNotifications) {
                    label.updateNotifications(sessionNotifications[s.uuid].messages);
                } else {
                    label.clearNotifications();
                }
            }
        } else {
            lblSideBar.setLabel(format("%d / %d", nb.getCurrentPage() + 1, nb.getNPages()));
        }
    }

    void updateTitle() {
        string title = getDisplayTitle();
        if (!isCSDDisabled()) {
            if (cTitle !is null) {
                cTitle.title = title;
            } else {
                hb.setTitle(title);
            }
        }
        setTitle(title);
    }

    string getDisplayTitle() {
        string title = _overrideTitle.length == 0?gsSettings.getString(SETTINGS_APP_TITLE_KEY):_overrideTitle;
        title = title.replace(VARIABLE_APP_NAME, _(APPLICATION_NAME));
        Session session = getCurrentSession();
        if (session) {
            title = session.getDisplayText(title);
            title = title.replace(VARIABLE_SESSION_NUMBER, to!string(nb.getCurrentPage()+1));
            title = title.replace(VARIABLE_SESSION_COUNT, to!string(nb.getNPages()));
            title = title.replace(VARIABLE_SESSION_NAME, session.displayName);
        } else {
            title = title.replace(VARIABLE_SESSION_NUMBER, to!string(nb.getCurrentPage()+1));
            title = title.replace(VARIABLE_SESSION_COUNT, to!string(nb.getNPages()));
            title = title.replace(VARIABLE_SESSION_NAME, _("Default"));
        }
        return title;
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

    void onIsActionAllowed(ActionType actionType, CumulativeResult!bool result) {
        final switch (actionType) {
            case ActionType.DETACH_TERMINAL:
                // Only allow if there is more then one session, note that session
                // checks if there is more then one terminal and allows in either case
                result.addResult( nb.getNPages() > 1);
                break;
            case ActionType.DETACH_SESSION:
                // Only allow if there is more then one session
                result.addResult( nb.getNPages() > 1);
                break;
        }
        return;
    }

    void onSessionProcessNotification(string summary, string _body, string terminalUUID, string sessionUUID) {
        tracef("Notification Received\n\tSummary=%s\n\tBody=%s", summary, _body);
        // If window not active, send notification to shell
        if (!isActive() && !_destroyed && gsSettings.getBoolean(SETTINGS_NOTIFY_ON_PROCESS_COMPLETE_KEY)) {
            Notification n = new Notification(_(summary));
            n.setBody(_body);
            n.setDefaultAction("app.activate-session::" ~ sessionUUID);
            tracef("Sending notification %s", uuid);
            getApplication().sendNotification(uuid, n);
            //if session not visible send to local handler
        }
        // If session not active, keep copy locally
        if (sessionUUID != getCurrentSession().uuid) {
            tracef("SessionUUID: %s versusterminal. Notification UUID: %s", sessionUUID, getCurrentSession().uuid);
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
        if (_noPrompt) return false;
        ProcessInformation pi = getProcessInformation();
        if (pi.children.length > 0) {
            return !promptCanCloseProcesses(gsSettings, this, pi);
        } else if (nb.getNPages() > 1) {
            return !showConfirmDialog(this, _("There are multiple sessions open, close anyway?"), gsSettings, SETTINGS_PROMPT_ON_CLOSE_KEY);
        }
        return false;
    }

    void onWindowDestroyed(Widget) {
        tracef("AppWindow %s destroyed", uuid);
        _destroyed = true;
        tilix.withdrawNotification(uuid);
        tilix.removeAppWindow(this);
        sessionActions.destroy();
        sessionActions = null;
        saSyncInput  = null;
        saCloseSession = null;
        saViewSideBar = null;
        saSessionAddRight = null;
        saSessionAddDown = null;
    }

    void onWindowShow(Widget) {
        if (tilix.getGlobalOverrides().maximize) {
            maximize();
        } else if (tilix.getGlobalOverrides().minimize) {
            iconify();
        } else if (tilix.getGlobalOverrides().fullscreen) {
            changeActionState(ACTION_WIN_FULLSCREEN, new GVariant(true));
            fullscreen();
        } else if (isQuake()) {
            moveAndSizeQuake();
            setKeepAbove(true);
            trace("Focus terminal");
            activateFocus();
            if (getActiveTerminal() !is null) {
                getActiveTerminal().focusTerminal();
            } else if (getCurrentSession() !is null) {
                getCurrentSession().focusTerminal(1);
            }
        } else if (tilix.getGlobalOverrides().geometry.flag == GeometryFlag.NONE && !isWayland(this) && gsSettings.getBoolean(SETTINGS_WINDOW_SAVE_STATE_KEY)) {
            GdkWindowState state = cast(GdkWindowState)gsSettings.getInt(SETTINGS_WINDOW_STATE_KEY);
            if (state & GdkWindowState.MAXIMIZED) {
                maximize();
            } else if (state & GdkWindowState.ICONIFIED) {
                iconify();
            } else if (state & GdkWindowState.FULLSCREEN) {
                fullscreen();
            }
            if (state & GdkWindowState.STICKY) {
                stick();
            }
        }
    }

    void onWindowRealized(Widget) {
        if (isQuake()) {
            applyPreference(SETTINGS_QUAKE_HEIGHT_PERCENT_KEY);
        } else {
            handleGeometry();
        }
    }

    bool handleGeometry() {
        if (!isQuake() && tilix.getGlobalOverrides().geometry.flag == GeometryFlag.FULL && !isWayland(this)) {
            int x, y;
            Geometry geometry = tilix.getGlobalOverrides().geometry;
            Gravity gravity = Gravity.NORTH_WEST;
            int width = nb.getAllocatedWidth();
            int height = nb.getAllocatedHeight();
            if (!geometry.xNegative)
                x = geometry.x;
            else {
                x = getScreen().getWidth() - width + geometry.x;
                gravity = Gravity.NORTH_EAST;
            }

            if (!geometry.yNegative)
                y = geometry.y;
            else {
                y = getScreen().getHeight() - height + geometry.y;
                gravity = (geometry.xNegative) ? Gravity.SOUTH_EAST : Gravity.SOUTH_WEST;
            }
            setGravity(gravity);
            move(x, y);
            return true;
        }
        return false;
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
            case SETTINGS_QUAKE_TAB_POSITION_KEY:
                if (isQuake && useTabs) {
                    nb.setTabPos(cast(GtkPositionType) gsSettings.getEnum(SETTINGS_QUAKE_TAB_POSITION_KEY));
                }
                break;
            case SETTINGS_TAB_POSITION_KEY:
                if (useTabs && !isQuake) {
                    nb.setTabPos(cast(GtkPositionType) gsSettings.getEnum(SETTINGS_TAB_POSITION_KEY));
                }
                break;
            /*
            case SETTINGS_QUAKE_DISABLE_ANIMATION_KEY:
                if (isQuake) {
                    if (gsSettings.getBoolean(SETTINGS_QUAKE_DISABLE_ANIMATION_KEY)) {
                        setTypeHint(GdkWindowTypeHint.UTILITY);
                    } else {
                        setTypeHint(GdkWindowTypeHint.NORMAL);
                    }
                }
                break;
            */
            case SETTINGS_QUAKE_HIDE_HEADERBAR_KEY:
                if (isQuake) {
                    bool hide = gsSettings.getBoolean(SETTINGS_QUAKE_HIDE_HEADERBAR_KEY);
                    hb.setNoShowAll(hide);
                    if (hide) hb.hide();
                    else hb.show();
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
        if (getWindow() is null) return;
        GdkRectangle rect;
        getQuakePosition(rect);
        trace("Actually move/resize quake window");
        if (getWindow() !is null) {
            getWindow().moveResize(rect.x, rect.y, rect.width, rect.height);
        } else {
            move(rect.x, rect.y);
            resize(rect.width, rect.height);
        }
    }

    void getQuakePosition(out GdkRectangle rect) {
        bool wayland = isWayland(this);
        Screen screen = getScreen();

        int monitor = screen.getPrimaryMonitor();
        if (!wayland) {
            if (gsSettings.getBoolean(SETTINGS_QUAKE_ACTIVE_MONITOR_KEY)) {
                int x, y = 0;
                GdkModifierType mask;
                Screen tempScreen;
                screen.getDisplay().getPointer(tempScreen, x, y, mask);
                if (tempScreen !is null) {
                    monitor = tempScreen.getMonitorAtPoint(x, y);
                } else if (screen.getActiveWindow() !is null) {
                    monitor = screen.getMonitorAtWindow(screen.getActiveWindow());
                }
            } else {
                int altMonitor = gsSettings.getInt(SETTINGS_QUAKE_SPECIFIC_MONITOR_KEY);
                if (altMonitor>=0 && altMonitor < getScreen().getNMonitors()) {
                    monitor = altMonitor;
                }
            }
        }
        //getScreen().getMonitorGeometry(monitor, rect);
        getScreen().getMonitorWorkarea(monitor, rect);
        tracef("Monitor geometry: monitor=%d, x=%d, y=%d, width=%d, height=%d", monitor, rect.x, rect.y, rect.width, rect.height);

        // Wayland works with screen factor natively whereas X11 does not
        int scaleFactor = screen.getMonitorScaleFactor(monitor);
        if (wayland && scaleFactor > 1) {
            rect.width = rect.width / scaleFactor;
            rect.height = rect.height / scaleFactor;
            tracef("Scaled monitor geometry: monitor=%d, scaleFactor=%d, x=%d, y=%d, width=%d, height=%d", monitor, scaleFactor, rect.x, rect.y, rect.width, rect.height);
        }

        double widthPercent = to!double(gsSettings.getInt(SETTINGS_QUAKE_WIDTH_PERCENT_KEY))/100.0;
        double heightPercent = to!double(gsSettings.getInt(SETTINGS_QUAKE_HEIGHT_PERCENT_KEY))/100.0;
        if (wayland) {
            widthPercent = 1;
        }

        if (widthPercent == 1 && heightPercent == 1) {
            maximize();
            return;
        }

        //Height
        rect.height = to!int(rect.height * heightPercent);

        //Width
        // Window only gets positioned properly in Wayland when width is 100%,
        // not sure if this kludge is really a good idea and will work consistently.
        if (widthPercent < 1) {
            int width = to!int(rect.width * widthPercent);
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
        if (DialogPath.LOAD_SESSION in dialogPaths) {
            fcd.setCurrentFolder(dialogPaths[DialogPath.LOAD_SESSION]);
        }
        addFilters(fcd);
        fcd.setDefaultResponse(ResponseType.OK);
        if (fcd.run() == ResponseType.OK) {
            try {
                loadSession(fcd.getFilename());
                addRecentSessionFile(fcd.getFilename());
                dialogPaths[DialogPath.LOAD_SESSION] = fcd.getCurrentFolder();
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
            if (filename.length > 0) {
                fcd.setCurrentFolder(dirName(filename));
                fcd.setCurrentName(filename.length > 0 ? baseName(filename) : session.displayName ~ ".json");
            } else if (DialogPath.SAVE_SESSION in dialogPaths) {
                fcd.setCurrentFolder(dialogPaths[DialogPath.SAVE_SESSION]);
            }
            if (fcd.run() == ResponseType.OK) {
                filename = fcd.getFilename();
                dialogPaths[DialogPath.SAVE_SESSION] = fcd.getCurrentFolder();
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

    void setWindowStyle() {
        windowStyle = gsSettings.getEnum(SETTINGS_WINDOW_STYLE_KEY);
        if (tilix.getGlobalOverrides().windowStyle.length > 0) {
            foreach(i, style; SETTINGS_WINDOW_STYLE_VALUES) {
                if (style == tilix.getGlobalOverrides().windowStyle) {
                    windowStyle = i;
                    break;
                }
            }
        }
    }

public:

    this(Application application, bool useTabs = false) {
        super(application);
        _windowUUID = randomUUID().toString();
        this.useTabs = useTabs;
        tilix.addAppWindow(this);
        gsSettings = new GSettings(SETTINGS_ID);
        gsSettings.addOnChanged(delegate(string key, GSettings) {
            applyPreference(key);
        });
        setTitle(_("Tilix"));
        setIconName("com.gexperts.Tilix");
        setWindowStyle();
        loadRecentSessionFileList();
        gsSettings.addOnChanged(delegate(string key, GSettings) {
            if (key == SETTINGS_RECENT_SESSION_FILES_KEY) {
                loadRecentSessionFileList();
            } else if (key == SETTINGS_APP_TITLE_KEY) {
                updateTitle();
            }
        });

        if (gsSettings.getBoolean(SETTINGS_ENABLE_TRANSPARENCY_KEY)) {
            updateVisual();
        }
        if (tilix.getGlobalOverrides().quake) {
            _quake = true;
            setDecorated(false);
            // Todo: Should this be NORTH instead?
            setGravity(GdkGravity.STATIC);
            setKeepAbove(true);
            setSkipTaskbarHint(true);
            setSkipPagerHint(true);
            applyPreference(SETTINGS_QUAKE_HEIGHT_PERCENT_KEY);
            applyPreference(SETTINGS_QUAKE_SHOW_ON_ALL_WORKSPACES_KEY);
            // On Ubuntu this causes terminal to use default size, see #602
            //setResizable(false);
            setRole("quake");
        } else {
            if (windowStyle == 3) {
                setDecorated(false);
            }
            forceAppMenu();
        }
        setShowMenubar(false);

        createUI();

        addOnDelete(&onWindowClosed);
        addOnDestroy(&onWindowDestroyed);
        addOnRealize(&onWindowRealized);
        /*
        addOnMap(delegate(Widget) {
            if (isQuake()) {
                applyPreference(SETTINGS_QUAKE_DISABLE_ANIMATION_KEY);
            }
        }, ConnectFlags.AFTER);
        */

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
                Window window = tilix.getActiveWindow();
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
                threadsAddTimeoutDelegate(gsSettings.getInt(SETTINGS_QUAKE_HIDE_LOSE_FOCUS_DELAY_KEY), delegate() {
                    if (isVisible()) {
                        this.hide();
                    }
                    return false;
                });
            }
            return false;
        }, ConnectFlags.AFTER);
        addOnFocusIn(delegate(Event e, Widget widget) {
            tilix.withdrawNotification(uuid);
            return false;
        });
        addOnWindowState(delegate(GdkEventWindowState* state, Widget) {
            trace("Window state changed");
            if ((state.newWindowState & GdkWindowState.FULLSCREEN) == GdkWindowState.FULLSCREEN) {
                trace("Window state is fullscreen");
            }
            if (getWindow() !is null && !isQuake() && gsSettings.getBoolean(SETTINGS_WINDOW_SAVE_STATE_KEY)) {
                gsSettings.setInt(SETTINGS_WINDOW_STATE_KEY, getWindow().getState());
            }
            return false;
        });
        handleGeometry();
    }

    debug(Destructors) {
        ~this() {
            import std.stdio;
            writeln("***** AppWindow destructor is called");
        }
    }

    void initialize() {
        if (tilix.getGlobalOverrides().session.length > 0) {
            foreach (sessionFilename; tilix.getGlobalOverrides().session) {
                try {
                    if (!exists(sessionFilename)) {
                        string filename = buildPath(tilix.getGlobalOverrides().cwd, sessionFilename);
                        tracef("Trying filename %s", filename);
                        if (exists(filename)) {
                            sessionFilename = filename;
                        } else {
                            warningf("Session filename '%s' does not exist, ignoring", filename);
                            continue;
                        }
                    }
                    loadSession(sessionFilename);
                } catch (SessionCreationException e) {
                    errorf("Could not load session from file '%s', error occurred", sessionFilename);
                    error(e.msg);
                }
            }
            if (nb.getNPages() > 0) return;
        }
        //Create an initial session using default session name and profile
        createSession(gsSettings.getString(SETTINGS_SESSION_NAME_KEY), prfMgr.getDefaultProfile());
    }

    void initialize(Session session) {
        addSession(session);
    }

    void closeNoPrompt() {
        _noPrompt = true;
        close();
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
        if (!useTabs && sb.getRevealChild()) {
            saViewSideBar.activate(null);
        }

        string workingDir;
        string profileUUID = prfMgr.getDefaultProfile();

        // Inherit current session directory unless overrides exist, fix #343
        if (tilix.getGlobalOverrides().cwd.length ==0 && tilix.getGlobalOverrides().workingDir.length == 0) {
            ITerminal terminal = getActiveTerminal();
            if (terminal !is null) {
                workingDir = terminal.currentLocalDirectory;
                profileUUID = terminal.defaultProfileUUID;
            }
        }
        if (gsSettings.getBoolean(SETTINGS_PROMPT_ON_NEW_SESSION_KEY)) {
            SessionProperties sp = new SessionProperties(this, gsSettings.getString(SETTINGS_SESSION_NAME_KEY), profileUUID);
            scope (exit) {
                sp.destroy();
            }
            sp.showAll();
            if (sp.run() == ResponseType.OK) {
                createSession(sp.name, sp.profileUUID, workingDir);
            }
        } else {
            createSession(gsSettings.getString(SETTINGS_SESSION_NAME_KEY), profileUUID, workingDir);
        }
    }

    /**
     * Information about any running processes in the window.
     */
    ProcessInformation getProcessInformation() {
        ProcessInformation result = ProcessInformation(ProcessInfoSource.WINDOW, getTitle(), "", []);
        for(int i=0; i<nb.getNPages; i++) {
            Session session = cast(Session) nb.getNthPage(i);
            if (session !is null) {
                ProcessInformation sessionInfo = session.getProcessInformation();
                if (sessionInfo.children.length > 0) {
                    result.children ~= sessionInfo;
                }
            }
        }
        return result;
    }

    /**
     * Unique and immutable session ID
     */
    @property string uuid() {
        return _windowUUID;
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

        ImageSurface surface = tilix.getBackgroundImage();
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
        isBGImage = renderImage(surface, widget.getAllocatedWidth(), widget.getAllocatedHeight(), mode, true, cast(cairo_filter_t) scale);
        return isBGImage;
    }

// Quake methods
private:
    bool wasFullscreen = false;

public:

    /**
     * Returns true if this window is in quake mode.
     */
    bool isQuake() {
        return _quake;
    }

    /**
     * Override hide to handle hiding quake window when full screened
     */
    override void hide() {
        if (isQuake()) {
            if (getWindow() !is null && ((getWindow().getState() & GdkWindowState.FULLSCREEN) == GdkWindowState.FULLSCREEN)) {
                unfullscreen();
                wasFullscreen = true;
            } else {
                wasFullscreen = false;
            }
        }
        super.hide();
    }

    /**
     * If quake window was hidden when fullscreen, restore fullscreen
     */
    override void present() {
        super.present();
        if (isQuake()) {
            if (getWindow() !is null && wasFullscreen) {
                wasFullscreen = false;
                fullscreen();
            }
        }
    }
}

/**
 * Widget used for labels in tabs for sessions.
 */
class SessionTabLabel: Box {

private:
	Button button;
    EventBox evNotifications;
    AspectFrame afNotifications;
	Label lblText;
    Label lblNotifications;
	Session session;

	void closeClicked(Button button) {
		onCloseClicked.emit(session);
	}

public:

	this(string text, Session session) {
		super(Orientation.HORIZONTAL, 5);

		this.session = session;

        lblNotifications = new Label("");
        lblNotifications.setUseMarkup(true);
        lblNotifications.setWidthChars(2);
        setAllMargins(lblNotifications, 4);
        
        evNotifications = new EventBox();
        evNotifications.add(lblNotifications);
        evNotifications.getStyleContext().addClass("tilix-notification-count");

        afNotifications = new AspectFrame(null, 0.5, 0.5, 1.0, false);
        afNotifications.setShadowType(ShadowType.NONE);
        afNotifications.add(evNotifications);

        add(afNotifications);

		lblText = new Label(text);
        lblText.setEllipsize(PangoEllipsizeMode.START);
		lblText.setWidthChars(10);
        lblText.setHexpand(true);
		add(lblText);

		button = new Button("window-close-symbolic", IconSize.MENU);
        button.getStyleContext().addClass("tilix-small-button");
		button.setRelief(ReliefStyle.NONE);
		button.setFocusOnClick(false);
        button.setTooltipText(_("Close session"));

		button.addOnClicked(&closeClicked);

		add(button);

		showAll();
	}

    void clear() {
        session = null;
    }

	@property string text() {
		return lblText.getText();
	}

	@property void text(string value) {
		lblText.setText(value);
	}

    void updateNotifications(ProcessNotificationMessage[] pn) {
        if (pn is null || pn.length == 0) {
            afNotifications.hide();
        } else {
            lblNotifications.setText(to!string(pn.length));
            string tooltip;
            foreach (i, message; pn) {
                if (i > 0) tooltip ~= "\n\n";
                tooltip ~= message._body;
            }
            evNotifications.setTooltipText(tooltip);
            afNotifications.show();
            lblNotifications.show();
        }
    }

    void clearNotifications() {
        afNotifications.hide();
    }

	/**
	 * Event triggered when user clicks the close button
	 */
    GenericEvent!(Session) onCloseClicked;
}