/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.appwindow;

import core.memory;

import std.algorithm;
import std.array;
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

// GID imports - cairo
import cairo.context : Context;
import cairo.surface : Surface;
import cairo.types : Filter, FontSlant, FontWeight, TextExtents;

// GID imports - gdk
import gdk.event : Event;
import gdk.event_button : EventButton;
import gdk.event_focus : EventFocus;
import gdk.event_key : EventKey;
import gdk.event_scroll : EventScroll;
import gdk.event_window_state : EventWindowState;
import gdk.rectangle : Rectangle;
import gdk.rgba : RGBA;
import gdk.screen : Screen;
import gdk.types : ScrollDirection, EventType, Gravity, WindowState, ModifierType;
import gdk.c.types : GdkRectangle;
import gdk.visual : Visual;

// GID imports - gdkpixbuf
import gdkpixbuf.pixbuf : Pixbuf;

// GID imports - gio
import gio.action : Action;
import gio.action_map : ActionMap;
import gio.application : GioApplication = Application;
import gio.menu : GMenu = Menu;
import gio.menu_item : GMenuItem = MenuItem;
import gio.notification : Notification;
import gio.settings : GSettings = Settings, Settings;
import gio.simple_action : SimpleAction;
import gio.simple_action_group : SimpleActionGroup;
import gio.types : ApplicationFlags;

// GID imports - glib
import glib.error : ErrorWrap;
import glib.global : getHomeDir;
import glib.variant : GVariant = Variant, Variant;
import glib.variant_type : GVariantType = VariantType;

// GID imports - gobject
import gobject.object : ObjectWrap = ObjectWrap;
import gobject.global : signalHandlerBlock, signalHandlerUnblock;
import gobject.value : Value;

// GID imports - gtk
import gtk.application : Application;
import gtk.application_window : ApplicationWindow;
import gtk.aspect_frame : AspectFrame;
import gtk.box : Box;
import gtk.button : Button;
import gtk.check_button : CheckButton;
import gtk.dialog : Dialog;
import gtk.entry : Entry;
import gtk.event_box : EventBox;
import gtk.file_chooser_dialog : FileChooserDialog;
import gtk.file_filter : FileFilter;
import gtk.frame : Frame;
import gtk.global : checkVersion;
import gtk.grid : Grid;
import gtk.header_bar : HeaderBar;
import gtk.image : Image;
import gtk.label : Label;
import gtk.list_box : ListBox;
import gtk.list_box_row : ListBoxRow;
import gtk.menu_button : MenuButton;
import gtk.message_dialog : MessageDialog;
import gtk.notebook : Notebook;
import gtk.overlay : Overlay;
import gtk.popover : Popover;
import gtk.revealer : Revealer;
import gtk.scrolled_window : ScrolledWindow;
import gtk.settings : GtkSettings = Settings;
import gtk.stack : Stack;
import gtk.style_context : StyleContext;
import gtk.toggle_button : ToggleButton;
import gtk.types : Allocation, IconSize, Orientation, PositionType, ShadowType, ReliefStyle, ResponseType, DialogFlags, MessageType, ButtonsType, FileChooserAction;
import pango.types : EllipsizeMode;
import gtk.widget : Widget;
import gtk.window : Window;
import gtk.window_group : WindowGroup;

// GID imports - vte
import vte.pty : Pty;
import vte.terminal : Terminal;

import gid.gid : No, Yes;

// GDK key constants (not provided by GID)
enum GdkKeysyms {
    GDK_Escape = 0xff1b,
    GDK_Return = 0xff0d,
}

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
    enum ACTION_SESSION_ADD_AUTO = "add-auto";

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
    // Put windows in separate groups
    WindowGroup group;

    SimpleActionGroup sessionActions;
    MenuButton mbSessionActions;
    SimpleAction saSyncInput;
    SimpleAction saViewSideBar;
    SimpleAction saSessionAddRight;
    SimpleAction saSessionAddDown;
    SimpleAction saSessionAddAuto;

    Label lblSideBar;

    SessionNotification[string] sessionNotifications;

    GSettings gsSettings;

    // Cached rendered background image
    Surface isBGImage;
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
    ulong _tbFindToggledId;

    // Preference for the Window Style, i.e normal,disable-csd,disable-csd-hide-toolbar,borderless
    size_t windowStyle = 0;

    enum DialogPath {
        SAVE_SESSION,
        LOAD_SESSION
    }

    // Save file dialog paths between invocations
    string[DialogPath] dialogPaths;

    uint timeoutID;

    bool isCSDDisabled() {
        return windowStyle > 0;
    }

    bool hideToolbar() {
        return (isQuake() && gsSettings.getBoolean(SETTINGS_QUAKE_HIDE_HEADERBAR_KEY)) || windowStyle > 1;
    }

    /**
     * Create the Tilix user interface
     */
    void createUI() {
        // Setup notebook for session tabs
        nb = new Notebook();
        nb.setShowBorder(false);
        nb.setScrollable(true);
        nb.setShowTabs(useTabs);
        nb.setGroupName(APPLICATION_NAME);
        nb.connectPageAdded(&onPageAdded);
        nb.connectPageRemoved(&onPageRemoved);
        nb.connectSwitchPage(delegate void(Widget page, uint index) {
            Session session = cast(Session) page;
            if (session !is null) {
                onSessionSelected(session.uuid);
            }
        });
        nb.connectCreateWindow(&onCreateWindow);

        GSettings gsShortcuts = new GSettings(SETTINGS_KEY_BINDINGS_ID);

        createWindowActions(gsShortcuts);
        createSessionActions(gsShortcuts);
        createDelegatedTerminalActions(gsShortcuts);
        insertActionGroup(ACTION_PREFIX, sessionActions);

        hb = createHeaderBar();
        applyPreference(SETTINGS_TAB_POSITION_KEY);

        Overlay overlay;
        if (!useTabs) {
            // Create sidebar
            sb = new SideBar();
            sb.onSelected.connect(&onOpenSelected);
            sb.onFileSelected.connect(&onFileSelected);
            sb.onFileRemoved.connect(&onFileRemoved);
            sb.onOpenSelected.connect(&onOpenSelected);
            sb.onSessionAttach.connect(&onSessionAttach);
            sb.onSessionReorder.connect(&onSessionReorder);
            sb.onSessionDetach.connect(&onSessionDetach);

            // Create overlay
            overlay = new Overlay();
            overlay.add(nb);
            overlay.addOverlay(sb);
        }

        if (isCSDDisabled()) {
            Box box = new Box(Orientation.Vertical, 0);
            box.packStart(hb, false, true, 0);
            if (overlay !is null) box.packStart(overlay, true, true, 0);
            else box.packStart(nb, true, true, 0);
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
            btnNew = Button.newFromIconName("tab-new-symbolic", IconSize.Button);
        } else {
            btnNew = Button.newFromIconName("list-add-symbolic", IconSize.Button);
        }
        btnNew.setFocusOnClick(false);
        btnNew.setAlwaysShowImage(true);
        btnNew.connectClicked(delegate() {
            createSession();
        });
        btnNew.setTooltipText(_("Create a new session"));

        Box bSessionButtons;

        if (!useTabs) {
            //View sessions button
            tbSideBar = new ToggleButton();
            tbSideBar.getStyleContext().addClass("session-sidebar-button");
            Box b = new Box(Orientation.Horizontal, 6);
            lblSideBar = new Label("1 / 1");
            Image img = Image.newFromIconName("pan-down-symbolic", IconSize.Menu);
            b.add(lblSideBar);
            b.add(img);
            tbSideBar.add(b);
            tbSideBar.setTooltipText(_("View session sidebar"));
            tbSideBar.setFocusOnClick(false);
            tbSideBar.setActionName(getActionDetailedName("win", ACTION_WIN_SIDEBAR));
            tbSideBar.connectDraw(&drawSideBarBadge, Yes.After);
            tbSideBar.connectScrollEvent(delegate bool(EventScroll event) {
                ScrollDirection direction = event.direction;
                if (direction == ScrollDirection.Up) {
                    focusPreviousSession();
                } else if (direction == ScrollDirection.Down) {
                    focusNextSession();
                }
                return false;
            });
            tbSideBar.addEvents(EventType.Scroll);

            bSessionButtons = new Box(Orientation.Horizontal, 0);
            bSessionButtons.getStyleContext().addClass("linked");
            btnNew.getStyleContext().addClass("session-new-button");
            bSessionButtons.packStart(tbSideBar, false, false, 0);
            bSessionButtons.packStart(btnNew, false, false, 0);
        }

        //Session Actions
        mbSessionActions = new MenuButton();
        mbSessionActions.setFocusOnClick(false);
        Image iHamburger = Image.newFromIconName("open-menu-symbolic", IconSize.Menu);
        mbSessionActions.add(iHamburger);
        mbSessionActions.setPopover(createPopover(mbSessionActions));

        Button btnAddHorizontal = Button.newFromIconName("tilix-add-horizontal-symbolic", IconSize.Menu);
        btnAddHorizontal.setDetailedActionName(getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_ADD_RIGHT));
        btnAddHorizontal.setFocusOnClick(false);
        btnAddHorizontal.setTooltipText(_("Add terminal right"));

        Button btnAddVertical = Button.newFromIconName("tilix-add-vertical-symbolic", IconSize.Menu);
        btnAddVertical.setDetailedActionName(getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_ADD_DOWN));
        btnAddVertical.setTooltipText(_("Add terminal down"));
        btnAddVertical.setFocusOnClick(false);

        // Add find button
        tbFind = new ToggleButton();
        tbFind.setImage(Image.newFromIconName("edit-find-symbolic", IconSize.Menu));
        tbFind.setTooltipText(_("Find text in terminal"));
        tbFind.setFocusOnClick(false);
        _tbFindToggledId = tbFind.connectToggled(delegate() {
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
        updateTitle();
    }

    void onCustomTitleCancelEdit() {
        if (getCurrentSession() !is null) {
            getCurrentSession().focusRestore();
        }
    }

    void onCustomTitleEdit(CumulativeResult!string result) {
        if (_overrideTitle.length > 0) {
            result.addResult(_overrideTitle);
        } else if (getCurrentSession() !is null) {
            result.addResult(getCurrentSession().displayName());
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
     * Create the window actions
     */
    void createWindowActions(GSettings gsShortcuts) {
        saViewSideBar = registerActionWithSettings(this, "win", ACTION_WIN_SIDEBAR, gsShortcuts, delegate(Variant value, SimpleAction sa) {
            bool newState = !sa.getState().getBoolean();
            sa.setState(new GVariant(newState));
            if (sb !is null) {
                sb.reveal(newState);
            }
        }, null, new GVariant(!useTabs));  // Initial state: false if using tabs

        registerActionWithSettings(this, "win", ACTION_WIN_SESSIONSWITCHER, gsShortcuts, delegate(Variant, SimpleAction) {
            if (sb !is null) {
                sb.showSessionSwitcher();
            }
        });

        registerActionWithSettings(this, "win", ACTION_WIN_NEXT_SESSION, gsShortcuts, delegate(Variant, SimpleAction) {
            focusNextSession();
        });

        registerActionWithSettings(this, "win", ACTION_WIN_PREVIOUS_SESSION, gsShortcuts, delegate(Variant, SimpleAction) {
            focusPreviousSession();
        });

        registerActionWithSettings(this, "win", ACTION_WIN_FULLSCREEN, gsShortcuts, delegate(Variant value, SimpleAction sa) {
            bool newState = !sa.getState().getBoolean();
            sa.setState(new GVariant(newState));
            if (newState) {
                fullscreen();
            } else {
                unfullscreen();
            }
        }, null, new GVariant(false));  // Initial state: not fullscreen

        // Register actions for switching to session (1-10)
        for (int i = 1; i <= 10; i++) {
            immutable int num = i;
            string actionName = ACTION_WIN_SESSION_X ~ to!string(i);
            registerActionWithSettings(this, "win", actionName, gsShortcuts, delegate(Variant, SimpleAction) {
                int sessionNum = (num == 10) ? 0 : num;
                nb.setCurrentPage(sessionNum - (sessionNum == 0 ? 0 : 1));
            });
        }
    }

    /**
     * Create the session actions (used to control the current session)
     */
    void createSessionActions(GSettings gsShortcuts) {
        sessionActions = new SimpleActionGroup();

        saSessionAddRight = registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_ADD_RIGHT, gsShortcuts, delegate(Variant, SimpleAction) {
            if (getCurrentSession() !is null) {
                getCurrentSession().addTerminal(Orientation.Horizontal);
            }
        });
        saSessionAddDown = registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_ADD_DOWN, gsShortcuts, delegate(Variant, SimpleAction) {
            if (getCurrentSession() !is null) {
                getCurrentSession().addTerminal(Orientation.Vertical);
            }
        });
        saSessionAddAuto = registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_ADD_AUTO, gsShortcuts, delegate(Variant, SimpleAction) {
            if (getCurrentSession() !is null) {
                getCurrentSession().addAutoOrientedTerminal();
            }
        });

        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_CLOSE, gsShortcuts, delegate(Variant, SimpleAction) {
            if (getCurrentSession() !is null) {
                closeSession(getCurrentSession());
            }
        });

        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_NAME, gsShortcuts, delegate(Variant, SimpleAction) {
            if (getCurrentSession() !is null) {
                string newName;
                if (showInputDialog(this, newName, getCurrentSession().name, _("Session Name"), _("Enter a name for the current session:"))) {
                    getCurrentSession().name(newName);
                }
            }
        });

        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_NEXT_TERMINAL, gsShortcuts, delegate(Variant, SimpleAction) {
            if (getCurrentSession() !is null) {
                getCurrentSession().focusNext();
            }
        });

        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_PREV_TERMINAL, gsShortcuts, delegate(Variant, SimpleAction) {
            if (getCurrentSession() !is null) {
                getCurrentSession().focusPrevious();
            }
        });

        // Register actions for switching to terminal (1-10)
        for (int i = 1; i <= 10; i++) {
            immutable int num = i;
            string actionName = ACTION_SESSION_TERMINAL_X ~ to!string(i);
            registerActionWithSettings(sessionActions, ACTION_PREFIX, actionName, gsShortcuts, delegate(Variant, SimpleAction) {
                if (getCurrentSession() !is null) {
                    int termNum = (num == 10) ? 0 : num;
                    getCurrentSession().focusTerminal(termNum);
                }
            });
        }

        // Register actions for resizing terminal in direction
        foreach(direction; ["up", "down", "left", "right"]) {
            string actionName = ACTION_RESIZE_TERMINAL_DIRECTION ~ direction;
            registerActionWithSettings(sessionActions, ACTION_PREFIX, actionName, gsShortcuts, delegate(Variant, SimpleAction) {
                if (getCurrentSession() !is null) {
                    getCurrentSession().resizeTerminal(direction);
                }
            });
        }

        saSyncInput = registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_SYNC_INPUT, gsShortcuts, delegate(Variant value, SimpleAction sa) {
            bool newState = !sa.getState().getBoolean();
            sa.setState(new GVariant(newState));
            if (getCurrentSession() !is null) {
                getCurrentSession().synchronizeInput = newState;
            }
        }, null, new GVariant(false));  // Initial state: sync input off

        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_SAVE, gsShortcuts, delegate(Variant, SimpleAction) {
            saveSession(false);
        });

        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_SAVE_AS, gsShortcuts, delegate(Variant, SimpleAction) {
            saveSession(true);
        });

        registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_OPEN, gsShortcuts, delegate(Variant, SimpleAction) {
            loadSession();
        });

        registerActionWithSettings(sessionActions, "win", ACTION_SESSION_REORDER_PREVIOUS, gsShortcuts, delegate(Variant, SimpleAction) {
            reorderCurrentSessionRelative(-1);
        });

        registerActionWithSettings(sessionActions, "win", ACTION_SESSION_REORDER_NEXT, gsShortcuts, delegate(Variant, SimpleAction) {
            reorderCurrentSessionRelative(1);
        });
    }

    /**
     * Create delegated terminal actions.
     *
     * These are actions that are typically associated with a terminal
     * but need to be available at the session level (e.g., for keyboard
     * shortcuts when terminal doesn't have focus).
     */
    void createDelegatedTerminalActions(GSettings gsShortcuts) {
        import gx.tilix.terminal.actions;

        foreach(actionInfo; terminalDelegatedActions) {
            registerActionWithSettings(sessionActions, ACTION_PREFIX_TERMINAL, actionInfo.name, gsShortcuts, delegate(Variant, SimpleAction sa) {
                if (getCurrentSession() !is null) {
                    ITerminal terminal = getCurrentSession().getActiveTerminal();
                    if (terminal !is null) {
                        terminal.executeAction(sa.getName());
                    }
                }
            });
        }
    }

    /**
     * Creates the popover for the session hamburger menu
     */
    Popover createPopover(Widget parent) {
        GMenu menuModel = new GMenu();

        GMenu sectionSave = new GMenu();
        sectionSave.append(_("_Save"), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_SAVE));
        sectionSave.append(_("Save _As..."), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_SAVE_AS));
        sectionSave.append(_("_Open..."), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_OPEN));
        menuModel.appendSection(null, sectionSave);

        GMenu sectionSync = new GMenu();
        sectionSync.append(_("S_ynchronize Input"), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_SYNC_INPUT));
        menuModel.appendSection(null, sectionSync);

        GMenu sectionSession = new GMenu();
        sectionSession.append(_("Session _Name..."), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_NAME));
        sectionSession.append(_("_Close Session"), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_CLOSE));
        menuModel.appendSection(null, sectionSession);

        GMenu sectionApp = new GMenu();
        sectionApp.append(_("_New Window"), getActionDetailedName(ACTION_PREFIX_APP, ACTION_NEW_WINDOW));
        sectionApp.append(_("_Preferences"), getActionDetailedName(ACTION_PREFIX_APP, ACTION_PREFERENCES));
        if (checkVersion(3, 19, 0) is null) {
            sectionApp.append(_("_Keyboard Shortcuts"), getActionDetailedName(ACTION_PREFIX_APP, ACTION_SHORTCUTS));
        }
        sectionApp.append(_("_About"), getActionDetailedName(ACTION_PREFIX_APP, ACTION_ABOUT));
        menuModel.appendSection(null, sectionApp);

        Popover popover = new Popover(parent);
        popover.bindModel(menuModel, null);
        return popover;
    }

    /**
     * Update the visual to support transparency
     */
    void updateVisual() {
        Screen screen = getScreen();
        Visual visual = screen.getRgbaVisual();
        if (visual !is null) {
            setVisual(visual);
        }
    }

    void createNewSession(string name, string profileUUID, string workingDir) {
        Session session = new Session(name, profileUUID, workingDir);
        session.onProcessNotification.connect(&onSessionProcessNotification);
        session.onUserClose.connect(&onUserSessionClose);
        addSession(session);
    }

    void onPageAdded(Widget page, uint index, Notebook) {
        Session session = cast(Session) page;
        if (session !is null) {
            if (!useTabs) {
                sb.addSession(session);
            }
            session.onStateChange.connect(&onSessionStateChange);
            session.onClose.connect(&onSessionClose);
            session.onIsActionAllowed.connect(&onIsActionAllowed);
            updateUIState();

            // Focus terminal after adding the session
            session.focusTerminal(1);
        }
    }

    void onPageRemoved(Widget page, uint index, Notebook notebook) {
        Session session = cast(Session) page;
        if (session !is null) {
            if (!useTabs) {
                sb.removeSession(session.uuid);
            }
            updateUIState();
        }
    }

    void addSession(Session session) {
        if (useTabs) {
            SessionTabLabel label = new SessionTabLabel(PositionType.Top, session.name, session);
            label.onCloseClicked.connect(delegate(Session s) { closeSession(s); });
            nb.appendPage(session, label);
        } else {
            nb.appendPage(session, new Label(session.name));
        }
        nb.setTabReorderable(session, true);
        nb.setTabDetachable(session, true);
        nb.setCurrentPage(cast(int) nb.getNPages() - 1);
    }

    void removeSession(Session session) {
        if (session.uuid in sessionNotifications) {
            sessionNotifications.remove(session.uuid);
        }

        int pageNum = nb.pageNum(session);
        if (pageNum >= 0) {
            nb.removePage(pageNum);
        }
    }

    Session[] getSessions() {
        Session[] sessions;
        for (int i = 0; i < nb.getNPages(); i++) {
            sessions ~= cast(Session) nb.getNthPage(i);
        }
        return sessions;
    }

    Session getSession(int i) {
        return cast(Session) nb.getNthPage(i);
    }

    /**
     * Handle session close request from user
     */
    void onUserSessionClose(Session session) {
        if (session is null) {
            return;
        }
        ProcessInformation pi = session.getProcessInformation();
        if (pi.children.length > 0) {
            if (!promptCanCloseProcesses(gsSettings, this, pi)) {
                return;
            }
        }
        closeSession(session);
    }

    void closeSession(Session session) {
        if (session is null) {
            return;
        }

        // Check for running processes
        ProcessInformation pi = session.getProcessInformation();
        if (pi.children.length > 0 && !_noPrompt) {
            if (!promptCanCloseProcesses(gsSettings, this, pi)) {
                return;
            }
        }

        removeSession(session);
        session.destroy();

        if (nb.getNPages() == 0) {
            this.close();
        }
    }

    void onSessionClose(Session session) {
        closeSession(session);
    }

    void onFileSelected(string file) {
        if (file.length > 0) {
            loadSession(file);
            if (sb !is null) {
                saViewSideBar.activate(null);
            }
        }
    }

    void onFileRemoved(string file) {
        removeRecentSessionFile(file);
    }

    void onOpenSelected(string uuid) {
        if (uuid is null || uuid.length == 0) {
            // null/empty UUID means close the sidebar
            if (sb !is null) {
                sb.reveal(false);
            }
            return;
        }
        // Close sidebar first, then activate
        if (sb !is null) {
            sb.reveal(false);
        }
        activateSession(uuid);
    }

    void reorderCurrentSessionRelative(int offset) {
        Session session = getCurrentSession();
        if (session is null) return;
        int currentPos = nb.pageNum(session);
        nb.reorderChild(session, currentPos + offset);
    }

    void onSessionReorder(string sourceUUID, string targetUUID, bool after, CumulativeResult!bool result) {
        Session source = getSession(sourceUUID);
        Session target = getSession(targetUUID);
        if (source is null || target is null) {
            result.addResult(false);
            return;
        }
        int targetPos = nb.pageNum(target);
        if (after) {
            targetPos++;
        }
        nb.reorderChild(source, targetPos);
        result.addResult(true);
    }

    /**
     * Called when a session is selected in the sidebar
     */
    void onSessionSelected(string sessionUUID) {
        Session session = getSession(sessionUUID);
        if (session is null) {
            return;
        }
        if (!useTabs && sb !is null) {
            sb.selectSession(session.uuid);
        }
        updateTitle();
        updateUIState();
    }

    /**
     * Called when a session is attached from another window
     */
    void onSessionAttach(string sessionUUID) {
        // Helper function to find window containing session
        AppWindow getWindow(Session session) {
            foreach (window; tilix.getAppWindows) {
                foreach (s; window.getSessions()) {
                    if (s is session) {
                        return window;
                    }
                }
            }
            return null;
        }

        foreach (window; tilix.getAppWindows) {
            Session session = window.getSession(sessionUUID);
            if (session !is null && window !is this) {
                window.removeSession(session);
                addSession(session);
                return;
            }
        }
    }

    AppWindow cloneWindow() {
        AppWindow window = new AppWindow(tilix, useTabs);
        window.initialize();
        window.showAll();
        return window;
    }

    /**
     * Called when a tab is dragged to create a new window
     */
    Notebook onCreateWindow(Widget page, int x, int y, Notebook) {
        AppWindow window = cloneWindow();
        if (x >= 0 && y >= 0) {
            window.move(x, y);
        }
        return window.nb;
    }

    void onSessionDetach(string sessionUUID, int x, int y) {
        Session session = getSession(sessionUUID);
        if (session !is null) {
            onSessionDetach(session, x, y, false);
        }
    }

    void onSessionDetach(Session session, int x, int y, bool isNewSession) {
        if (session is null) {
            return;
        }
        removeSession(session);
        AppWindow window = cloneWindow();
        window.addSession(session);
        if (x >= 0 && y >= 0) {
            window.move(x, y);
        }
    }

    void onSessionStateChange(Session session, SessionStateChange stateChange) {
        final switch (stateChange) {
            case SessionStateChange.NAME:
                if (useTabs) {
                    SessionTabLabel label = cast(SessionTabLabel) nb.getTabLabel(session);
                    if (label !is null) {
                        label.text = session.name;
                    }
                }
                updateTitle();
                break;
            case SessionStateChange.TERMINAL_FOCUSED:
                updateTitle();
                break;
            case SessionStateChange.TERMINAL_TITLE:
                updateTitle();
                break;
            case SessionStateChange.FIND:
                if (session is getCurrentSession()) {
                    // Update find button state
                    signalHandlerBlock(tbFind, _tbFindToggledId);
                    tbFind.setActive(session.isSearching());
                    signalHandlerUnblock(tbFind, _tbFindToggledId);
                }
                break;
            case SessionStateChange.TERMINAL_MAXIMIZED:
            case SessionStateChange.TERMINAL_RESTORED:
            case SessionStateChange.TERMINAL_OUTPUT:
            case SessionStateChange.SESSION_TITLE:
                // Handle these state changes as needed
                break;
        }
    }

    void updateUIState() {
        int numSessions = nb.getNPages();
        int currentPage = nb.getCurrentPage();

        // Update sidebar label
        if (lblSideBar !is null) {
            lblSideBar.setText(format("%d / %d", currentPage + 1, numSessions));
        }

        // Update session action sensitivity
        // Use getNPages() > 0 instead of getCurrentSession() because during onPageAdded
        // the page is added but setCurrentPage hasn't been called yet
        bool hasSession = nb.getNPages() > 0;
        if (saSyncInput !is null) {
            saSyncInput.setEnabled(hasSession);
        }
        if (saSessionAddRight !is null) {
            saSessionAddRight.setEnabled(hasSession);
        }
        if (saSessionAddDown !is null) {
            saSessionAddDown.setEnabled(hasSession);
        }
        if (saSessionAddAuto !is null) {
            saSessionAddAuto.setEnabled(hasSession);
        }

        // Update notifications
        if (!useTabs && sb !is null) {
            sb.updateNotifications(sessionNotifications);
        }
    }

    void updateTitle() {
        string title = getDisplayTitle();
        if (cTitle !is null) {
            cTitle.setTitle(title);
        }
        setTitle(title);
    }

    string getDisplayTitle() {
        import std.string : replace;

        string title = _overrideTitle.length == 0 ? gsSettings.getString(SETTINGS_APP_TITLE_KEY) : _overrideTitle;
        title = title.replace(VARIABLE_APP_NAME, _(APPLICATION_NAME));
        Session session = getCurrentSession();
        if (session !is null) {
            title = session.getDisplayText(title);
            title = title.replace(VARIABLE_SESSION_NUMBER, to!string(nb.getCurrentPage() + 1));
            title = title.replace(VARIABLE_SESSION_COUNT, to!string(nb.getNPages()));
            title = title.replace(VARIABLE_SESSION_NAME, session.displayName);
        } else {
            title = title.replace(VARIABLE_SESSION_NUMBER, to!string(nb.getCurrentPage() + 1));
            title = title.replace(VARIABLE_SESSION_COUNT, to!string(nb.getNPages()));
            title = title.replace(VARIABLE_SESSION_NAME, _("Default"));
        }
        return title;
    }

    bool drawSideBarBadge(Context cr, Widget widget) {
        // Nested function for drawing badge
        void drawBadge(double pw, double ph, double ps, RGBA fg, RGBA bg, int value) {
            string text = to!string(value);
            double radius = ps / 2;
            double x = pw - ps;
            double y = 2;

            cr.setSourceRgba(bg.red, bg.green, bg.blue, bg.alpha);
            cr.arc(x + radius, y + radius, radius, 0, 2 * PI);
            cr.fill();

            cr.setSourceRgba(fg.red, fg.green, fg.blue, fg.alpha);
            cr.selectFontFace("Sans", FontSlant.Normal, FontWeight.Bold);
            cr.setFontSize(10);
            TextExtents extents;
            cr.textExtents(text, extents);
            cr.moveTo(x + radius - extents.width / 2, y + radius + extents.height / 2);
            cr.showText(text);
        }

        int totalNotifications = 0;
        foreach (sn; sessionNotifications.byValue()) {
            totalNotifications += cast(int) sn.messages.length;
        }

        if (totalNotifications > 0) {
            RGBA fg, bg;
            fg.parse("#FFFFFF");
            bg.parse("#CC0000");
            drawBadge(widget.getAllocatedWidth(), widget.getAllocatedHeight(), 16, fg, bg, totalNotifications);
        }

        return false;
    }

    void onIsActionAllowed(ActionType actionType, CumulativeResult!bool result) {
        final switch (actionType) {
            case ActionType.DETACH_TERMINAL:
                result.addResult(true);
                break;
            case ActionType.DETACH_SESSION:
                result.addResult(nb.getNPages() > 1);
                break;
            case ActionType.SPLIT_HORIZONTAL:
            case ActionType.SPLIT_VERTICAL:
            case ActionType.SPLIT_AUTO:
                result.addResult(true);
                break;
        }
    }
    void sendNotification(string id, string summary, string _body) {
        Notification notification = new Notification(summary);
        notification.setBody(_body);
        tilix.sendNotification(id, notification);
    }

    void onSessionProcessNotification(string summary, string _body, string terminalUUID, string sessionUUID) {
        tracef("Process notification: %s - %s", summary, _body);
        if (isActive()) {
            // Window is active, don't show notification
            return;
        }

        auto msg = ProcessNotificationMessage(terminalUUID, summary, _body);

        if (sessionUUID in sessionNotifications) {
            sessionNotifications[sessionUUID].messages ~= msg;
        } else {
            auto sn = new SessionNotification(sessionUUID);
            sn.messages ~= msg;
            sessionNotifications[sessionUUID] = sn;
        }

        // Send desktop notification
        Notification notification = new Notification(summary);
        notification.setBody(_body);
        notification.setDefaultAction("app.activate-terminal('" ~ terminalUUID ~ "')");
        tilix.sendNotification(uuid ~ "-" ~ terminalUUID, notification);

        updateUIState();
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
        saSyncInput = null;
        saViewSideBar = null;
        saSessionAddRight = null;
        saSessionAddDown = null;
        group = null;
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
            applyPreference(SETTINGS_QUAKE_KEEP_ON_TOP_KEY);
            trace("Focus terminal");
            activateFocus();
            if (getActiveTerminal() !is null) {
                getActiveTerminal().focusTerminal();
            } else if (getCurrentSession() !is null) {
                getCurrentSession().focusTerminal(1);
            }
        } else if (tilix.getGlobalOverrides().geometry.flag == GeometryFlag.NONE && !isWayland(this) && gsSettings.getBoolean(SETTINGS_WINDOW_SAVE_STATE_KEY)) {
            WindowState state = cast(WindowState)gsSettings.getInt(SETTINGS_WINDOW_STATE_KEY);
            if (state & WindowState.Maximized) {
                maximize();
            } else if (state & WindowState.Iconified) {
                iconify();
            } else if (state & WindowState.Fullscreen) {
                fullscreen();
            }
            if (state & WindowState.Sticky) {
                stick();
            }
        }
    }

    void onWindowRealized(Widget) {
        if (isQuake()) {
            // Handle quake-specific realization
        }
    }

    bool handleGeometry() {
        CommandParameters params = tilix.getGlobalOverrides();
        if (params.geometry.flag != GeometryFlag.NONE) {
            if (params.geometry.flag == GeometryFlag.PARTIAL || params.geometry.flag == GeometryFlag.FULL) {
                // Size is handled by session/terminal
            }
            if (params.geometry.flag == GeometryFlag.FULL) {
                if (!isWayland(this)) {
                    move(params.geometry.x, params.geometry.y);
                }
            }
            return true;
        }

        // Window size restoration not implemented (no gsettings keys defined)
        return false;
    }

    void onCompositedChanged(Widget) {
        if (gsSettings.getBoolean(SETTINGS_ENABLE_TRANSPARENCY_KEY)) {
            updateVisual();
        }
    }

    void updateTabPosition() {
        string position = gsSettings.getString(SETTINGS_TAB_POSITION_KEY);
        PositionType pos;
        switch (position) {
            case "top":
                pos = PositionType.Top;
                break;
            case "bottom":
                pos = PositionType.Bottom;
                break;
            case "left":
                pos = PositionType.Left;
                break;
            case "right":
                pos = PositionType.Right;
                break;
            default:
                pos = PositionType.Top;
        }
        nb.setTabPos(pos);
    }

    void applyPreference(string key) {
        switch (key) {
            case SETTINGS_ENABLE_TRANSPARENCY_KEY:
                updateVisual();
                break;
            case SETTINGS_TAB_POSITION_KEY:
                updateTabPosition();
                break;
            case SETTINGS_QUAKE_HEIGHT_PERCENT_KEY:
            case SETTINGS_QUAKE_WIDTH_PERCENT_KEY:
            case SETTINGS_QUAKE_ACTIVE_MONITOR_KEY:
            case SETTINGS_QUAKE_ALIGNMENT_KEY:
                if (isQuake()) {
                    moveAndSizeQuake();
                }
                break;
            case SETTINGS_QUAKE_HIDE_HEADERBAR_KEY:
                if (hb !is null) {
                    hb.setNoShowAll(hideToolbar());
                    if (hideToolbar()) {
                        hb.hide();
                    } else {
                        hb.show();
                    }
                }
                break;
            case SETTINGS_QUAKE_KEEP_ON_TOP_KEY:
                if (isQuake()) {
                    setKeepAbove(gsSettings.getBoolean(SETTINGS_QUAKE_KEEP_ON_TOP_KEY));
                }
                break;
            case SETTINGS_QUAKE_SHOW_ON_ALL_WORKSPACES_KEY:
                if (isQuake()) {
                    if (gsSettings.getBoolean(SETTINGS_QUAKE_SHOW_ON_ALL_WORKSPACES_KEY)) {
                        stick();
                    } else {
                        unstick();
                    }
                }
                break;
            default:
                break;
        }
    }

    void moveAndSizeQuake() {
        GdkRectangle rect;
        getQuakePosition(rect);
        move(rect.x, rect.y);
        resize(rect.width, rect.height);
    }

    void getQuakePosition(out GdkRectangle rect) {
        Screen screen = getScreen();
        int monitor = gsSettings.getInt(SETTINGS_QUAKE_ACTIVE_MONITOR_KEY);
        if (monitor < 0 || monitor >= screen.getNMonitors()) {
            monitor = screen.getPrimaryMonitor();
        }
        Rectangle monitorRect;
        screen.getMonitorWorkarea(monitor, monitorRect);

        int heightPercent = gsSettings.getInt(SETTINGS_QUAKE_HEIGHT_PERCENT_KEY);
        int widthPercent = gsSettings.getInt(SETTINGS_QUAKE_WIDTH_PERCENT_KEY);
        string alignment = gsSettings.getString(SETTINGS_QUAKE_ALIGNMENT_KEY);

        rect.width = cast(int)(monitorRect.width * widthPercent / 100.0);
        rect.height = cast(int)(monitorRect.height * heightPercent / 100.0);
        rect.y = monitorRect.y;

        switch (alignment) {
            case "left":
                rect.x = monitorRect.x;
                break;
            case "right":
                rect.x = monitorRect.x + monitorRect.width - rect.width;
                break;
            case "center":
            default:
                rect.x = monitorRect.x + (monitorRect.width - rect.width) / 2;
                break;
        }
    }

    Session getCurrentSession() {
        int currentPage = nb.getCurrentPage();
        if (currentPage < 0) {
            return null;
        }
        return cast(Session) nb.getNthPage(currentPage);
    }

    Session getSession(string sessionUUID) {
        for (int i = 0; i < nb.getNPages(); i++) {
            Session session = cast(Session) nb.getNthPage(i);
            if (session !is null && session.uuid == sessionUUID) {
                return session;
            }
        }
        return null;
    }

    void addFilters(FileChooserDialog fcd) {
        FileFilter filterJson = new FileFilter();
        filterJson.setName(_("Tilix session files (*.json)"));
        filterJson.addPattern("*.json");
        fcd.addFilter(filterJson);

        FileFilter filterAll = new FileFilter();
        filterAll.setName(_("All files"));
        filterAll.addPattern("*");
        fcd.addFilter(filterAll);
    }

    /**
     * Load a session from file
     */
    void loadSession(string filename) {
        if (!exists(filename)) {
            showErrorDialog(this, format(_("File not found: %s"), filename));
            return;
        }

        try {
            string content = readText(filename);
            JSONValue json = parseJSON(content);
            int width, height;
            Session.getPersistedSessionSize(json, width, height);
            string sessionName = json["name"].str();
            Session session = new Session(sessionName);
            session.initSession(json, filename, width, height, false);
            session.onProcessNotification.connect(&onSessionProcessNotification);
            session.onUserClose.connect(&onUserSessionClose);
            addSession(session);
            addRecentSessionFile(filename);
        } catch (Exception e) {
            showErrorDialog(this, format(_("Error loading session: %s"), e.msg));
        }
    }

    /**
     * Show file chooser dialog for loading session
     */
    void loadSession() {
        import gtk.c.functions : gtk_file_chooser_dialog_new;
        import gtk.c.types : GtkFileChooserAction, GtkWidget, GtkWindow;
        import std.string : toStringz;

        GtkWidget* widget = gtk_file_chooser_dialog_new(
            toStringz(_("Open Session")),
            cast(GtkWindow*) _cPtr(),
            GtkFileChooserAction.Open,
            toStringz(_("_Cancel")), ResponseType.Cancel,
            toStringz(_("_Open")), ResponseType.Accept,
            null
        );
        FileChooserDialog fcd = new FileChooserDialog(cast(void*) widget, No.Take);
        scope(exit) fcd.destroy();

        addFilters(fcd);

        if (DialogPath.LOAD_SESSION in dialogPaths) {
            fcd.setCurrentFolder(dialogPaths[DialogPath.LOAD_SESSION]);
        } else {
            fcd.setCurrentFolder(getHomeDir());
        }

        if (fcd.run() == ResponseType.Accept) {
            string filename = fcd.getFilename();
            dialogPaths[DialogPath.LOAD_SESSION] = fcd.getCurrentFolder();
            loadSession(filename);
        }
    }

    /**
     * Save the current session to file
     */
    void saveSession(bool showSaveAsDialog = true) {
        Session session = getCurrentSession();
        if (session is null) {
            return;
        }

        string filename;
        if (showSaveAsDialog || session.filename.length == 0) {
            import gtk.c.functions : gtk_file_chooser_dialog_new;
            import gtk.c.types : GtkFileChooserAction, GtkWidget, GtkWindow;
            import std.string : toStringz;

            GtkWidget* widget = gtk_file_chooser_dialog_new(
                toStringz(_("Save Session")),
                cast(GtkWindow*) _cPtr(),
                GtkFileChooserAction.Save,
                toStringz(_("_Cancel")), ResponseType.Cancel,
                toStringz(_("_Save")), ResponseType.Accept,
                null
            );
            FileChooserDialog fcd = new FileChooserDialog(cast(void*) widget, No.Take);
            scope(exit) fcd.destroy();

            fcd.setDoOverwriteConfirmation(true);
            addFilters(fcd);

            if (session.filename.length > 0) {
                fcd.setFilename(session.filename);
            } else {
                if (DialogPath.SAVE_SESSION in dialogPaths) {
                    fcd.setCurrentFolder(dialogPaths[DialogPath.SAVE_SESSION]);
                } else {
                    fcd.setCurrentFolder(getHomeDir());
                }
                fcd.setCurrentName(session.name ~ ".json");
            }

            if (fcd.run() != ResponseType.Accept) {
                return;
            }
            filename = fcd.getFilename();
            dialogPaths[DialogPath.SAVE_SESSION] = fcd.getCurrentFolder();

            if (!filename.endsWith(".json")) {
                filename ~= ".json";
            }
        } else {
            filename = session.filename;
        }

        try {
            JSONValue json = session.serialize();
            std.file.write(filename, json.toPrettyString());
            session.filename = filename;
            addRecentSessionFile(filename);
        } catch (Exception e) {
            showErrorDialog(this, format(_("Error saving session: %s"), e.msg));
        }
    }

    /**
     * Create a new session (public method)
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
     * Add a file to the recent session files list
     */
    void addRecentSessionFile(string path, bool save = true) {
        // Remove if already in list
        recentSessionFiles = recentSessionFiles.filter!(a => a != path).array;
        // Add to front
        recentSessionFiles = path ~ recentSessionFiles;
        // Limit list size
        if (recentSessionFiles.length > 10) {
            recentSessionFiles = recentSessionFiles[0..10];
        }
        if (save) {
            saveRecentSessionFileList();
        }
    }

    /**
     * Remove a file from the recent session files list
     */
    void removeRecentSessionFile(string path, bool save = true) {
        recentSessionFiles = recentSessionFiles.filter!(a => a != path).array;
        if (save) {
            saveRecentSessionFileList();
        }
        if (sb !is null) {
            sb.updateRecentFiles(recentSessionFiles);
        }
    }

    void removeTimeout() {
        if (timeoutID > 0) {
            import glib.source : Source;
            Source.remove(timeoutID);
            timeoutID = 0;
        }
    }

    void setWindowStyle() {
        string style = gsSettings.getString(SETTINGS_WINDOW_STYLE_KEY);
        // Override from command line
        if (tilix.getGlobalOverrides().windowStyle.length > 0) {
            style = tilix.getGlobalOverrides().windowStyle;
        }
        switch (style) {
            case "normal":
                windowStyle = 0;
                break;
            case "disable-csd":
                windowStyle = 1;
                break;
            case "disable-csd-hide-toolbar":
                windowStyle = 2;
                break;
            case "borderless":
                windowStyle = 3;
                break;
            default:
                windowStyle = 0;
        }
    }

public:

    this(Application application, bool useTabs = false) {
        super(application);
        group = new WindowGroup();
        group.addWindow(this);
        _windowUUID = randomUUID().toString();
        this.useTabs = useTabs;
        tilix.addAppWindow(this);
        gsSettings = new GSettings(SETTINGS_ID);
        gsSettings.connectChanged(null, delegate(string key, Settings settings) {
            applyPreference(key);
        });
        setTitle(_("Tilix"));
        setIconName("com.gexperts.Tilix");
        setWindowStyle();
        loadRecentSessionFileList();
        gsSettings.connectChanged(null, delegate(string key, Settings settings) {
            if (key == SETTINGS_RECENT_SESSION_FILES_KEY) {
                loadRecentSessionFileList();
            } else if (key == SETTINGS_APP_TITLE_KEY) {
                updateTitle();
            }
        });

        if (gsSettings.getBoolean(SETTINGS_ENABLE_TRANSPARENCY_KEY)) {
            updateVisual();
        }
        if (tilix.getGlobalOverrides().quake && !isWayland(null)) {
            _quake = true;
            setDecorated(false);
            setGravity(Gravity.Static);
            setSkipTaskbarHint(true);
            setSkipPagerHint(true);
            applyPreference(SETTINGS_QUAKE_HEIGHT_PERCENT_KEY);
            applyPreference(SETTINGS_QUAKE_SHOW_ON_ALL_WORKSPACES_KEY);
            setRole("quake");
        } else {
            if (tilix.getGlobalOverrides.quake) {
                string message = _("Quake mode is not supported under Wayland, running as normal window");
                error(message);
                sendNotification("quake", _("Quake Mode Not Supported"), message);
            }
            if (windowStyle == 3) {
                setDecorated(false);
            }
        }
        setShowMenubar(false);

        createUI();

        connectDeleteEvent(&onWindowClosed);
        connectDestroy(&onWindowDestroyed);
        connectRealize(&onWindowRealized);

        connectShow(&onWindowShow, Yes.After);
        connectSizeAllocate(delegate(Allocation rect, Widget w) {
            if (lastWidth != rect.width || lastHeight != rect.height) {
                //invalidate rendered background
                if (isBGImage !is null) {
                    isBGImage.destroy();
                    isBGImage = null;
                }
                lastWidth = rect.width;
                lastHeight = rect.height;
            }
        }, Yes.After);
        connectCompositedChanged(&onCompositedChanged);
        connectFocusOutEvent(delegate(EventFocus e, Widget widget) {
            if (isQuake && gsSettings.getBoolean(SETTINGS_QUAKE_HIDE_LOSE_FOCUS_KEY)) {
                Window window = tilix.getActiveWindow();
                if (window !is null) {
                    if (window._cPtr() == this._cPtr()) {
                        Widget[] widgets = window.listToplevels();
                        tracef("Top level windows = %d", widgets.length);
                        foreach(Widget child; widgets) {
                            Dialog dialog = cast(Dialog)child;
                            if (dialog !is null && dialog.getTransientFor() !is null && dialog.getTransientFor()._cPtr() == this._cPtr()) return false;
                        }
                    }
                }

                trace("Focus lost, waiting to hide quake window");
                timeoutID = threadsAddTimeoutDelegate(gsSettings.getInt(SETTINGS_QUAKE_HIDE_LOSE_FOCUS_DELAY_KEY), delegate() {
                    trace("Focus lost and timeout reached, hiding quake window");
                    if (isVisible()) {
                        this.hide();
                    }
                    return false;
                });
            }
            return false;
        }, Yes.After);
        connectFocusInEvent(delegate(EventFocus e, Widget widget) {
            removeTimeout();

            tilix.withdrawNotification(uuid);
            if (getCurrentSession() !is null) {
                getCurrentSession().withdrawNotification();
            }
            return false;
        });
        connectWindowStateEvent(delegate(EventWindowState event, Widget w) {
            trace("Window state changed");
            if (event is null) {
                return false;
            }
            WindowState newState = event.newWindowState;
            if ((newState & WindowState.Fullscreen) == WindowState.Fullscreen) {
                trace("Window state is fullscreen");
            }
            if (getWindow() !is null && !isQuake() && gsSettings.getBoolean(SETTINGS_WINDOW_SAVE_STATE_KEY)) {
                gsSettings.setInt(SETTINGS_WINDOW_STATE_KEY, cast(int)getWindow().getState());
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
                        errorf("Session file not found: %s", sessionFilename);
                        continue;
                    }
                    loadSession(sessionFilename);
                } catch (Exception e) {
                    errorf("Error loading session %s: %s", sessionFilename, e.msg);
                }
            }
        }

        // If no sessions were loaded, create a default one
        if (nb.getNPages() == 0) {
            createSession();
        }

        // Ensure UI state is updated after initialization
        updateUIState();
    }

    void initialize(Session session) {
        addSession(session);
    }

    void closeNoPrompt() {
        _noPrompt = true;
        close();
    }

    /**
     * Activate the session with the given UUID
     */
    bool activateSession(string sessionUUID) {
        for (int i = 0; i < nb.getNPages(); i++) {
            Session session = cast(Session) nb.getNthPage(i);
            if (session !is null && session.uuid == sessionUUID) {
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
        int currentPage = nb.getCurrentPage();
        if (currentPage > 0) {
            nb.setCurrentPage(currentPage - 1);
        }
    }

    /**
     * Focus the next session
     */
    void focusNextSession() {
        int currentPage = nb.getCurrentPage();
        if (currentPage < nb.getNPages() - 1) {
            nb.setCurrentPage(currentPage + 1);
        }
    }

    /**
     * Activate a terminal by session and terminal UUID
     */
    bool activateTerminal(string sessionUUID, string terminalUUID) {
        if (activateSession(sessionUUID)) {
            return getCurrentSession().activateTerminal(terminalUUID);
        }
        return false;
    }

    bool activateTerminal(string terminalUUID) {
        for (int i = 0; i < nb.getNPages(); i++) {
            Session session = cast(Session) nb.getNthPage(i);
            if (session !is null && session.activateTerminal(terminalUUID)) {
                nb.setCurrentPage(i);
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
        return terminal !is null ? terminal.uuid : "";
    }

    /**
     * Find a widget (session or terminal) by UUID
     */
    Widget findWidgetForUUID(string uuid) {
        for (int i = 0; i < nb.getNPages(); i++) {
            Session session = cast(Session) nb.getNthPage(i);
            if (session !is null) {
                if (session.uuid == uuid) {
                    return session;
                }
                Widget terminal = session.findWidgetForUUID(uuid);
                if (terminal !is null) {
                    return terminal;
                }
            }
        }
        return null;
    }

    /**
     * Create a new session with default settings
     */
    void createSession() {
        string profileUUID;
        string workingDir;
        CommandParameters params = tilix.getGlobalOverrides();

        // Get profile from command line or default
        if (params.profileName.length > 0) {
            ProfileInfo profile = prfMgr.getProfileByName(params.profileName);
            if (profile.uuid.length > 0) {
                profileUUID = profile.uuid;
            }
        }
        if (profileUUID.length == 0) {
            profileUUID = prfMgr.getDefaultProfile();
        }

        // Get working directory
        if (params.workingDir.length > 0) {
            workingDir = params.workingDir;
        }

        string sessionName = format(_("Session %d"), nb.getNPages() + 1);
        createNewSession(sessionName, profileUUID, workingDir);
    }

    /**
     * Get process information for all sessions
     */
    ProcessInformation getProcessInformation() {
        ProcessInformation result;
        result.source = ProcessInfoSource.WINDOW;
        result.name = getDisplayTitle();
        result.uuid = uuid;

        foreach (session; getSessions()) {
            ProcessInformation pi = session.getProcessInformation();
            if (pi.children.length > 0) {
                result.children ~= pi;
            }
        }
        return result;
    }

    /**
     * Returns the UUID of this window
     */
    @property string uuid() {
        return _windowUUID;
    }

    /**
     * Invalidate the cached background image
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
    Surface getBackgroundImage(Widget widget) {
        if (isBGImage !is null) {
            return isBGImage;
        }

        Surface surface = tilix.getBackgroundImage();
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
        isBGImage = renderImage(surface, widget.getAllocatedWidth(), widget.getAllocatedHeight(), mode, true, cast(Filter) scale);
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
            if (getWindow() !is null && ((getWindow().getState() & WindowState.Fullscreen) == WindowState.Fullscreen)) {
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
    Image imgNewOutput;
    EventBox lblBox;
    Entry lblEditBox;
    Stack stTitle;

    enum PAGE_LABEL = "label";
    enum PAGE_EDIT = "edit";

	void closeClicked(Button button) {
		onCloseClicked.emit(session);
	}

public:

	this(PositionType position, string text, Session session) {
		super((position == PositionType.Left || position == PositionType.Right) ? Orientation.Vertical : Orientation.Horizontal, 5);

		this.session = session;

        lblNotifications = new Label("");
        lblNotifications.setUseMarkup(true);
        lblNotifications.setWidthChars(2);
        setAllMargins(lblNotifications, 4);

        evNotifications = new EventBox();
        evNotifications.add(lblNotifications);
        evNotifications.getStyleContext().addClass("tilix-notification-count");

        afNotifications = new AspectFrame(null, 0.5, 0.5, 1.0, false);
        afNotifications.setShadowType(ShadowType.None);
        afNotifications.add(evNotifications);

        add(afNotifications);

        stTitle = new Stack();

		lblText = new Label(text);
        lblText.setEllipsize(EllipsizeMode.Start);
		lblText.setWidthChars(10);
        updatePositionType(position);

        lblBox = new EventBox();
        lblBox.add(lblText);
        lblBox.connectButtonPressEvent(delegate(EventButton event) {
            if (event.type == EventType._2buttonPress && event.button == 1) {
                lblEditBox.setText(session.name());
                stTitle.setVisibleChildName(PAGE_EDIT);
                lblEditBox.grabFocus();
                return true;
            }
            return false;
        });
        stTitle.addNamed(lblBox, PAGE_LABEL);

        lblEditBox = new Entry();
        lblEditBox.setHexpand(true);
        lblEditBox.connectFocusOutEvent(delegate(EventFocus event, Widget w) {
            string text = lblEditBox.getText().strip();
            if (text.length == 0)
                return false;

            session.name(text);
            stTitle.setVisibleChildName(PAGE_LABEL);
            return false;
        });
        lblEditBox.connectKeyPressEvent(delegate(EventKey event) {
            switch (event.keyval) {
                case GdkKeysyms.GDK_Escape:
                    stTitle.setVisibleChildName(PAGE_LABEL);
                    return true;
                case GdkKeysyms.GDK_Return:
                    session.name(lblEditBox.getText());
                    stTitle.setVisibleChildName(PAGE_LABEL);
                    return true;
                default:
            }
            return false;
        });
        if (checkVersion(3, 16, 0) is null) {
            stTitle.addNamed(createTitleEditHelper(lblEditBox, TitleEditScope.SESSION), PAGE_EDIT);
        } else {
            stTitle.addNamed(lblEditBox, PAGE_EDIT);
        }

        add(stTitle);

        imgNewOutput = Image.newFromIconName("view-list-symbolic", IconSize.Menu);
        imgNewOutput.setNoShowAll(true);
        imgNewOutput.setTooltipText(_("New output displayed"));

        add(imgNewOutput);

		button = Button.newFromIconName("window-close-symbolic", IconSize.Menu);
        button.getStyleContext().addClass("tilix-small-button");
		button.setRelief(ReliefStyle.None);
		button.setFocusOnClick(false);
        button.setTooltipText(_("Close session"));

		button.connectClicked(&closeClicked);

        add(button);

        stTitle.setVisibleChildName(PAGE_LABEL);
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

    @property bool showNewOutput() {
        return imgNewOutput.isVisible();
    }

    @property void showNewOutput(bool value) {
        if (value) imgNewOutput.show();
        else imgNewOutput.hide();
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

    void updatePositionType(PositionType position) {
        if (position == PositionType.Left || position == PositionType.Right) {
            setOrientation(Orientation.Vertical);
            lblText.setAngle(position == PositionType.Left ? 90 : 270);
            lblText.setHexpand(false);
            lblText.setVexpand(true);
        } else {
            setOrientation(Orientation.Horizontal);
            lblText.setAngle(0);
            lblText.setHexpand(true);
            lblText.setVexpand(false);
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