/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.terminal.terminal;

import core.sys.posix.stdio;
import core.sys.posix.sys.wait;
import core.sys.posix.unistd;

import std.algorithm;
import std.array;
import std.conv;
import std.concurrency;
import std.experimental.logger;
import std.format;
import std.process;
import std.stdio;
import std.uuid;

import cairo.Context;

import gdk.Atom;
import gdk.DragContext;
import gdk.Event;
import gdk.RGBA;
import gdk.Screen;

import gdkpixbuf.Pixbuf;

import gio.ActionMapIF;
import gio.Menu : GMenu = Menu;
import gio.MenuItem : GMenuItem = MenuItem;
import gio.Settings : GSettings = Settings;
import gio.SimpleAction;
import gio.SimpleActionGroup;
import gio.ThemedIcon;

import glib.Regex;
import glib.ShellUtils;
import glib.Str;
import glib.URI;
import glib.Variant : GVariant = Variant;
import glib.VariantType : GVariantType = VariantType;

import gtk.Box;
import gtk.Button;
import gtk.Clipboard;
import gtk.DragAndDrop;
import gtk.EventBox;
import gtk.Frame;
import gtk.Image;
import gtk.InfoBar;
import gtk.Label;
import gtk.Main;
import gtk.Menu;
import gtk.MenuButton;
import gtk.MenuItem;
import gtk.MessageDialog;
import gtk.MountOperation;
import gtk.Overlay;
import gtk.Popover;
import gtk.Revealer;
import gtk.Scrollbar;
import gtk.SelectionData;
import gtk.Separator;
import gtk.TargetEntry;
import gtk.Widget;
import gtk.Window;

import vte.Terminal : VTE = Terminal;
import vtec.vtetypes;

import gx.gtk.actions;
import gx.gtk.util;
import gx.i18n.l10n;
import gx.util.array;

import gx.terminix.common;
import gx.terminix.constants;
import gx.terminix.preferences;
import gx.terminix.terminal.actions;
import gx.terminix.terminal.search;
import gx.terminix.terminal.vtenotification;

/**
* When dragging over VTE, specifies which quandrant new terminal
* should snap to
*/
enum DragQuadrant {
    LEFT,
    TOP,
    RIGHT,
    BOTTOM
}

/**
 * An event that is fired whenever the terminal gets focused. Used by
 * the Session to track focus.
 */
alias OnTerminalInFocus = void delegate(Terminal terminal);

/**
 * An event that is fired when the terminal has been requested to close,
 * either explicitly by the user clicking the close button or the terminal
 * process exiting/aborting.
 */
alias OnTerminalClose = void delegate(Terminal terminal);

/**
 * An event that is triggered when the terminal requests to be split into two,
 * either vertrically or horizontally. The session is reponsible for actually
 * making the split happen.
 */
alias OnTerminalRequestSplit = void delegate(Terminal terminal, Orientation orientation);

/**
 * An event that is triggered when a terminal requests to moved from it's
 * original location (src) and split with another terminal (dest).
 *
 * This typically happens after a drag and drop of a terminal
 */
alias OnTerminalRequestMove = void delegate(string srcUUID, Terminal dest, DragQuadrant dq);

/**
 * Invoked when a terminal requests that it be detached into it's own window
 */
alias OnTerminalRequestDetach = void delegate(Terminal terminal, int x, int y);

/**
 * Triggered on a terminal key press, used by the session to synchronize input
 * when this option is selected.
 */
alias OnTerminalKeyPress = void delegate(Terminal terminal, Event event);

/**
 * Constants used for the various variables permitted when defining
 * the terminal title.
 */
enum TERMINAL_TITLE = "${title}";
enum TERMINAL_ICON_TITLE = "${iconTitle}";
enum TERMINAL_ID = "${id}";
enum TERMINAL_DIR = "${directory}";

/**
 * This class is a composite widget that consists of the VTE Terminal
 * widget and the title bar. From the perspective of a session this is
 * treated as the Terminal, the Session class has no direct access to the
 * actual VTE widget and this abstraction should be maintained to
 * separate concerns.
 *
 * Communication between the Session and the actual VTE widget is achieved through
 * various event handlers defined in this Terminal widget. Note these event handlers
 * do not correspond to GTK signals, they are pure D code.
 */
class Terminal : Box {

private:

    // mixin for managing is action allowed event delegates
    mixin IsActionAllowedHandler;
    
    // mixin for managing process notification event delegates     
    mixin ProcessNotificationHandler;

    OnTerminalInFocus[] terminalInFocusDelegates;
    OnTerminalClose[] terminalCloseDelegates;
    OnTerminalRequestSplit[] terminalRequestSplitDelegates;
    OnTerminalRequestMove[] terminalRequestMoveDelegates;
    OnTerminalRequestDetach[] terminalRequestDetachDelegates;
    OnTerminalKeyPress[] terminalKeyPressDelegates;

    SearchRevealer rFind;

    VTENotification vte;
    Overlay terminalOverlay;
    Scrollbar sb;

    GPid gpid = 0;
    bool titleInitialized = false;

    Label lblTitle;

    string _profileUUID;
    ulong _terminalID;
    string _terminalUUID;
    string overrideTitle;
    bool _synchronizeInput;

    string initialWorkingDir;

    SimpleActionGroup sagTerminalActions;

    SimpleAction saProfileSelect;
    GMenu profileMenu;

    Menu mContext;
    MenuItem miCopy;
    MenuItem miPaste;

    GSettings gsProfile;
    GSettings gsShortcuts;

    /**
     * Create the user interface of the TerminalPane
     */
    void createUI() {
        sagTerminalActions = new SimpleActionGroup();
        createActions(sagTerminalActions);
        insertActionGroup(ACTION_PREFIX, sagTerminalActions);

        // Create the title bar of the pane
        Widget titlePane = createTitlePane();
        add(titlePane);

        //Create the actual terminal for the pane
        add(createVTE());

        //Enable Drag and Drop
        setupDragAndDrop(titlePane);
    }

    /**
     * Creates the top bar of the terminal pane
     */
    Widget createTitlePane() {

        void setVerticalMargins(Widget widget) {
            widget.setMarginTop(1);
            widget.setMarginBottom(2);
        }

        Box bTitle = new Box(Orientation.HORIZONTAL, 0);
        bTitle.setVexpand(false);
        bTitle.getStyleContext().addClass("notebook");
        bTitle.getStyleContext().addClass("header");

        lblTitle = new Label(_("Terminal"));
        lblTitle.setEllipsize(PangoEllipsizeMode.START);
        lblTitle.setUseMarkup(true);

        //Profile Menu
        profileMenu = new GMenu();

        Box bTitleLabel = new Box(Orientation.HORIZONTAL, 6);
        bTitleLabel.add(lblTitle);
        bTitleLabel.add(new Image("pan-down-symbolic", IconSize.MENU));

        MenuButton mbTitle = new MenuButton();
        mbTitle.setRelief(ReliefStyle.NONE);
        mbTitle.setFocusOnClick(false);
        mbTitle.setPopover(createPopover(mbTitle));
        mbTitle.addOnButtonPress(delegate(Event e, Widget w) { buildProfileMenu(); return false; });
        mbTitle.add(bTitleLabel);

        bTitle.packStart(mbTitle, false, false, 4);
        setVerticalMargins(mbTitle);

        //Close Button
        Button btnClose = new Button("window-close-symbolic", IconSize.MENU);
        btnClose.setRelief(ReliefStyle.NONE);
        btnClose.setFocusOnClick(false);
        btnClose.setActionName(getActionDetailedName(ACTION_PREFIX, ACTION_CLOSE));
        setVerticalMargins(btnClose);
        bTitle.packEnd(btnClose, false, false, 4);

        //Need EventBox to support drag and drop
        EventBox ev = new EventBox();
        ev.add(bTitle);

        return ev;
    }

    //Dynamically build the menus for selecting a profile
    void buildProfileMenu() {
        profileMenu.removeAll();
        saProfileSelect.setState(new GVariant(profileUUID));
        ProfileInfo[] profiles = prfMgr.getProfiles();
        foreach (profile; profiles) {
            GMenuItem menuItem = new GMenuItem(profile.name, getActionDetailedName(ACTION_PREFIX, ACTION_PROFILE_SELECT));
            menuItem.setActionAndTargetValue(getActionDetailedName(ACTION_PREFIX, ACTION_PROFILE_SELECT), new GVariant(profile.uuid));
            profileMenu.appendItem(menuItem);
        }
    }

    /**
     * Creates the common actions used by the terminal pane
     */
    void createActions(SimpleActionGroup group) {
        //Terminal Split actions
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_SPLIT_H, gsShortcuts, delegate(Variant, SimpleAction) {
            notifyTerminalRequestSplit(Orientation.HORIZONTAL);
        });
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_SPLIT_V, gsShortcuts, delegate(Variant, SimpleAction) {
            notifyTerminalRequestSplit(Orientation.VERTICAL);
        });

        //Find actions
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_FIND, gsShortcuts, delegate(Variant, SimpleAction) {
            if (!rFind.getRevealChild()) {
                rFind.setRevealChild(true);
                rFind.focusSearchEntry();
            } else {
                rFind.setRevealChild(false);
                vte.grabFocus();
            }
        });
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_FIND_PREVIOUS, gsShortcuts, delegate(Variant, SimpleAction) { vte.searchFindPrevious(); });
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_FIND_NEXT, gsShortcuts, delegate(Variant, SimpleAction) { vte.searchFindNext(); });

        //Override terminal title
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_TITLE, gsShortcuts, delegate(Variant, SimpleAction) {
            string terminalTitle = overrideTitle is null ? gsProfile.getString(SETTINGS_PROFILE_TITLE_KEY) : overrideTitle;
            if (showInputDialog(null, terminalTitle, terminalTitle, _("Enter Custom Title"),
                    _("Enter a new title to override the one specified by the profile. To reset it to the profile setting, leave it blank"))) {
                overrideTitle = terminalTitle;
                if (overrideTitle.length == 0)
                    overrideTitle = null;
                updateTitle();
            }
        });

        //Close Terminal Action
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_CLOSE, gsShortcuts, delegate(Variant, SimpleAction) {
            bool closeTerminal = true;
            if (isProcessRunning()) {
                MessageDialog dialog = new MessageDialog(cast(Window) this.getToplevel(), DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.OK_CANCEL,
                    _("There are processes that are still running, close anyway?"), null);
                scope (exit) {
                    dialog.destroy();
                }
                dialog.setDefaultResponse(ResponseType.CANCEL);
                if (dialog.run() == ResponseType.CANCEL)
                    closeTerminal = false;
            }
            if (closeTerminal)
                notifyTerminalClose();
        });

        //Select Profile
        GVariant pu = new GVariant(profileUUID);
        saProfileSelect = registerAction(sagTerminalActions, ACTION_PREFIX, ACTION_PROFILE_SELECT, null, delegate(GVariant value, SimpleAction sa) {
            ulong l;
            string uuid = value.getString(l);
            profileUUID = uuid;
            saProfileSelect.setState(value);
        }, pu.getType(), pu);
    }

    /**
     * Creates the terminal pane popover
     */
    Popover createPopover(Widget parent) {
        GMenu model = new GMenu();

        GMenuItem splitH = new GMenuItem(null, ACTION_PREFIX ~ "." ~ ACTION_SPLIT_H);
        splitH.setAttributeValue("verb-icon", new GVariant("terminix-split-tab-right-symbolic"));
        splitH.setAttributeValue("label", new GVariant(_("Split Right")));

        GMenuItem splitV = new GMenuItem(null, ACTION_PREFIX ~ "." ~ ACTION_SPLIT_V);
        splitV.setAttributeValue("verb-icon", new GVariant("terminix-split-tab-down-symbolic"));
        splitV.setAttributeValue("label", new GVariant(_("Split Down")));

        GMenu splitSection = new GMenu();
        splitSection.appendItem(splitH);
        splitSection.appendItem(splitV);

        GMenuItem splits = new GMenuItem(null, null);
        splits.setSection(splitSection);
        //splits.setLabel("Split");
        splits.setAttributeValue("display-hint", new GVariant("horizontal-buttons"));
        model.appendItem(splits);

        GMenu menuSection = new GMenu();
        menuSection.appendItem(new GMenuItem(_("Find..."), ACTION_PREFIX ~ "." ~ ACTION_FIND));
        menuSection.appendItem(new GMenuItem(_("Title..."), ACTION_PREFIX ~ "." ~ ACTION_TITLE));
        model.appendSection(null, menuSection);

        model.appendSubmenu(_("Profiles"), profileMenu);

        Popover pm = new Popover(parent, model);
        return pm;
    }

    /**
     * Creates the actual VTE terminal inside an Overlay along with some support
     * widgets such as the Find revealer.
     */
    Widget createVTE() {
        vte = new VTENotification();
        // Basic widget properties
        vte.setHexpand(true);
        vte.setVexpand(true);
        //URL Regex Experessions
        foreach (regex; compiledRegex) {
            int id = vte.matchAddGregex(cast(Regex) regex, cast(GRegexMatchFlags) 0);
            vte.matchSetCursorType(id, CursorType.HAND2);
        }

        //Event handlers
        vte.addOnChildExited(&onTerminalChildExited);
        vte.addOnWindowTitleChanged(delegate(VTE terminal) { updateTitle(); });
        vte.addOnIconTitleChanged(delegate(VTE terminal) { updateTitle(); });
        vte.addOnCurrentDirectoryUriChanged(delegate(VTE terminal) { titleInitialized = true; updateTitle(); });
        vte.addOnCurrentFileUriChanged(delegate(VTE terminal) { trace("Current file is " ~ vte.getCurrentFileUri); });
        vte.addOnFocusIn(&onTerminalFocusIn);
        vte.addOnFocusOut(&onTerminalFocusOut);
        vte.addOnNotificationReceived(delegate(string summary, string _body, VTE terminal) {
            if (titleInitialized && !terminal.hasFocus()) {
                notifyProcessNotification(summary, _body, terminalUUID);
            }
        });

        vte.addOnButtonPress(&onTerminalButtonPress);
        vte.addOnKeyPress(delegate(Event event, Widget widget) {
            if (_synchronizeInput && event.key.sendEvent == 0) {
                trace("forward event key press");
                foreach (dlg; terminalKeyPressDelegates)
                    dlg(this, event);
            } else {
                //trace("Synchronized Input = " ~ to!string(_synchronizeInput) ~ ", sendEvent=" ~ to!string(event.key.sendEvent));
            }
            return false;
        });

        mContext = new Menu();
        miCopy = new MenuItem(delegate(MenuItem item) { vte.copyClipboard(); }, _("Copy"), null);
        mContext.add(miCopy);
        miPaste = new MenuItem(delegate(MenuItem item) { vte.pasteClipboard(); }, _("Paste"), null);
        mContext.add(miPaste);

        terminalOverlay = new Overlay();
        terminalOverlay.add(vte);
        rFind = new SearchRevealer(vte);
        terminalOverlay.addOverlay(rFind);

        Box box = new Box(Orientation.HORIZONTAL, 0);
        box.add(terminalOverlay);

        sb = new Scrollbar(Orientation.VERTICAL, vte.getVadjustment());
        box.add(sb);
        return box;
    }

    /**
     * Updates the terminal title in response to UI changes
     */
    void updateTitle() {
        string title = overrideTitle is null ? gsProfile.getString(SETTINGS_PROFILE_TITLE_KEY) : overrideTitle;
        title = title.replace(TERMINAL_TITLE, vte.getWindowTitle());
        title = title.replace(TERMINAL_ICON_TITLE, vte.getIconTitle());
        title = title.replace(TERMINAL_ID, to!string(terminalID));
        string path;
        if (titleInitialized) {
            path = currentDirectory;
        } else {
            path = "";
        }
        title = title.replace(TERMINAL_DIR, path);
        if (title.length == 0)
            title = _("Terminal");
        lblTitle.setMarkup(title);
    }

    void notifyTerminalRequestSplit(Orientation orientation) {
        foreach (OnTerminalRequestSplit dlg; terminalRequestSplitDelegates) {
            dlg(this, orientation);
        }
    }

    void notifyTerminalRequestMove(string srcUUID, Terminal dest, DragQuadrant dq) {
        foreach (OnTerminalRequestMove dlg; terminalRequestMoveDelegates) {
            dlg(srcUUID, dest, dq);
        }
    }

    void notifyTerminalRequestDetach(Terminal terminal, int x, int y) {
        foreach (OnTerminalRequestDetach dlg; terminalRequestDetachDelegates) {
            dlg(terminal, x, y);
        }
    }

    void notifyTerminalClose() {
        foreach (OnTerminalClose dlg; terminalCloseDelegates) {
            dlg(this);
        }
    }

    /**
     * Triggered when the terminal signals the child process has exited
     */
    void onTerminalChildExited(int status, VTE terminal) {
        trace("Exit code received is " ~ to!string(status));
        switch (gsProfile.getString(SETTINGS_PROFILE_EXIT_ACTION_KEY)) {
        case SETTINGS_PROFILE_EXIT_ACTION_RESTART_VALUE:
            spawnTerminalProcess(initialWorkingDir);
            return;
        case SETTINGS_PROFILE_EXIT_ACTION_CLOSE_VALUE:
            notifyTerminalClose();
            return;
        case SETTINGS_PROFILE_EXIT_ACTION_HOLD_VALUE:
            TerminalInfoBar ibRelaunch = new TerminalInfoBar();
            ibRelaunch.addOnResponse(delegate(int response, InfoBar ib) {
                if (response == ResponseType.OK) {
                    ibRelaunch.destroy();
                    spawnTerminalProcess(initialWorkingDir);
                }
            });
            ibRelaunch.setStatus(status);
            terminalOverlay.addOverlay(ibRelaunch);
            ibRelaunch.showAll();
            return;
        default:
            return;
        }
    }

    /**
     * Signal received when mouse button is pressed in terminal
     */
    bool onTerminalButtonPress(Event event, Widget widget) {
        if (event.type == EventType.BUTTON_PRESS) {
            GdkEventButton* buttonEvent = event.button;
            switch (buttonEvent.button) {
            case MouseButton.PRIMARY:
                long col = to!long(buttonEvent.x) / vte.getCharWidth();
                long row = to!long(buttonEvent.y) / vte.getCharHeight();
                int tag;
                string match = vte.matchCheck(col, row, tag);
                if (match) {
                    MountOperation.showUri(null, match, Main.getCurrentEventTime());
                    return true;
                } else {
                    return false;
                }
            case MouseButton.SECONDARY:
                miCopy.setSensitive(vte.getHasSelection());
                miPaste.setSensitive(Clipboard.get(null).waitIsTextAvailable());
                mContext.showAll();
                mContext.popup(buttonEvent.button, buttonEvent.time);
                return true;
            default:
                return false;
            }
        }
        return false;
    }

    bool onTerminalFocusIn(Event event, Widget widget) {
        lblTitle.setSensitive(true);
        //Fire focus events so session can track which terminal last had focus
        foreach (dlg; terminalInFocusDelegates) {
            dlg(this);
        }
        return false;
    }

    bool onTerminalFocusOut(Event event, Widget widget) {
        lblTitle.setSensitive(false);
        return false;
    }

    /**
     * Updates a setting based on the passed key. Note that using gio.Settings.bind
     * would have been very viable here to handle configuration changes but the VTE widget
     * has so few binable properties it's just easier to handle everything consistently.
     */
    void applyPreference(string key) {
        switch (key) {
        case SETTINGS_PROFILE_AUDIBLE_BELL_KEY:
            vte.setAudibleBell(gsProfile.getBoolean(SETTINGS_PROFILE_AUDIBLE_BELL_KEY));
            break;
        case SETTINGS_PROFILE_ALLOW_BOLD_KEY:
            vte.setAllowBold(gsProfile.getBoolean(SETTINGS_PROFILE_ALLOW_BOLD_KEY));
            break;
        case SETTINGS_PROFILE_REWRAP_KEY:
            vte.setRewrapOnResize(gsProfile.getBoolean(SETTINGS_PROFILE_REWRAP_KEY));
            break;
        case SETTINGS_PROFILE_CURSOR_SHAPE_KEY:
            vte.setCursorShape(getCursorShape(gsProfile.getString(SETTINGS_PROFILE_CURSOR_SHAPE_KEY)));
            break;
        case SETTINGS_PROFILE_FG_COLOR_KEY, SETTINGS_PROFILE_BG_COLOR_KEY, SETTINGS_PROFILE_PALETTE_COLOR_KEY, SETTINGS_PROFILE_BG_TRANSPARENCY_KEY,
        SETTINGS_PROFILE_USE_THEME_COLORS_KEY:
                RGBA fg;
            RGBA bg;
            if (gsProfile.getBoolean(SETTINGS_PROFILE_USE_THEME_COLORS_KEY)) {
                vte.getStyleContext().getColor(StateFlags.ACTIVE, fg);
                vte.getStyleContext().getBackgroundColor(StateFlags.ACTIVE, bg);
            } else {
                fg = new RGBA();
                bg = new RGBA();
                fg.parse(gsProfile.getString(SETTINGS_PROFILE_FG_COLOR_KEY));
                bg.parse(gsProfile.getString(SETTINGS_PROFILE_BG_COLOR_KEY));
            }
            double alpha = to!double(100 - gsProfile.getInt(SETTINGS_PROFILE_BG_TRANSPARENCY_KEY)) / 100.0;
            bg.alpha = alpha;
            string[] colors = gsProfile.getStrv(SETTINGS_PROFILE_PALETTE_COLOR_KEY);
            RGBA[] palette = new RGBA[colors.length];
            foreach (i, color; colors) {
                palette[i] = new RGBA();
                palette[i].parse(colors[i]);
            }
            vte.setColors(fg, bg, palette);
            break;
        case SETTINGS_PROFILE_SHOW_SCROLLBAR_KEY:
            sb.setVisible(gsProfile.getBoolean(SETTINGS_PROFILE_SHOW_SCROLLBAR_KEY));
            break;
        case SETTINGS_PROFILE_SCROLL_ON_OUTPUT_KEY:
            vte.setScrollOnOutput(gsProfile.getBoolean(SETTINGS_PROFILE_SCROLL_ON_OUTPUT_KEY));
            break;
        case SETTINGS_PROFILE_SCROLL_ON_INPUT_KEY:
            vte.setScrollOnOutput(gsProfile.getBoolean(SETTINGS_PROFILE_SCROLL_ON_INPUT_KEY));
            break;
        case SETTINGS_PROFILE_UNLIMITED_SCROLL_KEY,
        SETTINGS_PROFILE_SCROLLBACK_LINES_KEY:
                long scrollLines = gsProfile.getBoolean(SETTINGS_PROFILE_UNLIMITED_SCROLL_KEY) ? -1 : gsProfile.getValue(SETTINGS_PROFILE_SCROLLBACK_LINES_KEY).getInt64();
            vte.setScrollbackLines(scrollLines);
            break;
        case SETTINGS_PROFILE_BACKSPACE_BINDING_KEY:
            vte.setBackspaceBinding(getEraseBinding(gsProfile.getString(SETTINGS_PROFILE_BACKSPACE_BINDING_KEY)));
            break;
        case SETTINGS_PROFILE_DELETE_BINDING_KEY:
            vte.setDeleteBinding(getEraseBinding(gsProfile.getString(SETTINGS_PROFILE_DELETE_BINDING_KEY)));
            break;
        case SETTINGS_PROFILE_CJK_WIDTH_KEY:
            vte.setCjkAmbiguousWidth(to!int(countUntil(SETTINGS_PROFILE_CJK_WIDTH_VALUES, gsProfile.getString(SETTINGS_PROFILE_CJK_WIDTH_KEY))) + 1);
            break;
        case SETTINGS_PROFILE_CURSOR_BLINK_MODE_KEY:
            vte.setCursorBlinkMode(getBlinkMode(gsProfile.getString(SETTINGS_PROFILE_CURSOR_BLINK_MODE_KEY)));
            break;
        case SETTINGS_PROFILE_TITLE_KEY:
            updateTitle();
            break;
        default:
            break;
        }
    }

    /**
     * Applies all preferences, used when terminal widget is first started to configure it
     */
    void applyPreferences() {
        string[] keys = [
            SETTINGS_PROFILE_AUDIBLE_BELL_KEY, SETTINGS_PROFILE_ALLOW_BOLD_KEY, SETTINGS_PROFILE_REWRAP_KEY, SETTINGS_PROFILE_CURSOR_SHAPE_KEY,
            // Only pass one color key, all colors will be applied
            SETTINGS_PROFILE_FG_COLOR_KEY, SETTINGS_PROFILE_SHOW_SCROLLBAR_KEY, SETTINGS_PROFILE_SCROLL_ON_OUTPUT_KEY, SETTINGS_PROFILE_SCROLL_ON_INPUT_KEY,
            SETTINGS_PROFILE_UNLIMITED_SCROLL_KEY, SETTINGS_PROFILE_BACKSPACE_BINDING_KEY, SETTINGS_PROFILE_DELETE_BINDING_KEY, SETTINGS_PROFILE_CJK_WIDTH_KEY,
            SETTINGS_PROFILE_CURSOR_BLINK_MODE_KEY
        ];

        foreach (key; keys)
            applyPreference(key);
    }

    VteCursorBlinkMode getBlinkMode(string mode) {
        long i = countUntil(SETTINGS_PROFILE_CURSOR_BLINK_MODE_VALUES, mode);
        return cast(VteCursorBlinkMode) i;
    }

    VteEraseBinding getEraseBinding(string binding) {
        long i = countUntil(SETTINGS_PROFILE_ERASE_BINDING_VALUES, binding);
        return cast(VteEraseBinding) i;
    }

    VteCursorShape getCursorShape(string shape) {
        final switch (shape) {
        case SETTINGS_PROFILE_CURSOR_SHAPE_BLOCK_VALUE:
            return VteCursorShape.BLOCK;
        case SETTINGS_PROFILE_CURSOR_SHAPE_IBEAM_VALUE:
            return VteCursorShape.IBEAM;
        case SETTINGS_PROFILE_CURSOR_SHAPE_UNDERLINE_VALUE:
            return VteCursorShape.UNDERLINE;
        }
    }

    /**
     * Spawns the child process in the Terminal depending on the Profile
     * command options.
     */
    void spawnTerminalProcess(string initialPath) {
        GSpawnFlags flags;
        string shell = vte.getUserShell();
        string[] args = [shell];
        if (gsProfile.getBoolean(SETTINGS_PROFILE_USE_CUSTOM_COMMAND_KEY)) {
            args ~= "-c";
            args ~= gsProfile.getString(SETTINGS_PROFILE_CUSTOM_COMMAND_KEY);
            flags = GSpawnFlags.SEARCH_PATH;
        } else {
            if (gsProfile.getBoolean(SETTINGS_PROFILE_LOGIN_SHELL_KEY)) {
                args ~= "-" ~ shell;
            }
            flags = GSpawnFlags.FILE_AND_ARGV_ZERO;
        }
        string[] envv = [""];
        vte.spawnSync(VtePtyFlags.DEFAULT, initialPath, args, envv, flags, null, null, gpid, null);
        vte.grabFocus();
    }

    // Code to move terminals through Drag And Drop (DND) is in this private block
    // Keep all DND code here and do not intermix with other blocks
    //
    // This code also handles other DND for text, URI, etc in VTE but the vast bulk deals
    // with terminal DND   
private:

    DragInfo dragInfo = DragInfo(false, DragQuadrant.LEFT);

    /**
     * Sets up the DND by registering the TargetEntry objects as source and destinations
     * as well as attaching the various event handlers
     *
     * Called at the end of createUI when all UI elements are in place
     */
    void setupDragAndDrop(Widget title) {
        trace("Setting up drag and drop");
        //DND
        TargetEntry uriEntry = new TargetEntry("text/uri-list", TargetFlags.OTHER_APP, DropTargets.URILIST);
        TargetEntry stringEntry = new TargetEntry("STRING", TargetFlags.OTHER_APP, DropTargets.STRING);
        TargetEntry textEntry = new TargetEntry("text/plain", TargetFlags.OTHER_APP, DropTargets.TEXT);
        TargetEntry vteEntry = new TargetEntry(VTE_DND, TargetFlags.SAME_APP, DropTargets.VTE);
        TargetEntry[] targets = [uriEntry, stringEntry, textEntry, vteEntry];
        vte.dragDestSet(DestDefaults.ALL, targets, DragAction.COPY | DragAction.MOVE);
        title.dragSourceSet(ModifierType.BUTTON1_MASK, [vteEntry], DragAction.MOVE);
        //vte.dragSourceSet(ModifierType.BUTTON1_MASK, [vteEntry], DragAction.MOVE);

        //Title bar events
        title.addOnDragBegin(&onTitleDragBegin);
        title.addOnDragDataGet(&onTitleDragDataGet);
        title.addOnDragFailed(&onTitleDragFailed, ConnectFlags.AFTER);

        //VTE Drop events
        vte.addOnDragDataReceived(&onVTEDragDataReceived);
        vte.addOnDragMotion(&onVTEDragMotion);
        vte.addOnDragLeave(&onVTEDragLeave);
        vte.addOnDraw(&onVTEDraw, ConnectFlags.AFTER);
    }

    /**
     * Called to set the selection data, which is later returned in the drag received
     * so it knows which terminal was dropped, in this case the terminal UUID
     */
    void onTitleDragDataGet(DragContext dc, SelectionData data, uint info, uint time, Widget widget) {
        char[] buffer = (terminalUUID ~ '\0').dup;
        data.set(intern(VTE_DND, false), info, buffer);
    }

    /**
     * Begin the drag operation from the use dragging the title bar, renders the 
     * terminal image into a scaled Pixbuf to use as the drag icon.
     *
     * TODO - Add some transparency
     */
    void onTitleDragBegin(DragContext dc, Widget widget) {
        const int MAX_SIZE = 300;

        double w = this.getAllocatedWidth();
        double h = this.getAllocatedHeight();
        trace(format("Original: %f, %f", w, h));
        Pixbuf pb = gdk.Pixbuf.getFromWindow(getWindow(), 0, 0, to!int(w), to!int(h));
        //Only scale if we need too
        if (w > MAX_SIZE || h > MAX_SIZE) {
            if (w > h) {
                h = 256 * h / w;
                w = 256;
            } else if (h > w) {
                w = 256 * w / h;
                h = 256;
            } else {
                w, h = 256;
            }
        }
        trace(format("New: %f, %f", w, h));
        pb = pb.scaleSimple(to!int(w), to!int(h), GdkInterpType.BILINEAR);

        DragAndDrop.dragSetIconPixbuf(dc, pb, 0, 0);
    }

    /**
     * Called when drag failed, used this to detach a terminal into a new window
     */
    bool onTitleDragFailed(DragContext dc, GtkDragResult dr, Widget widget) {
        trace("Drag Failed with ", dr);
        if (dr == GtkDragResult.NO_TARGET) {
            //Only allow detach if whole heirarchy agrees (application, window, session)
            if (!notifyIsActionAllowed(ActionType.DETACH))
                return false;
            trace("Detaching terminal");
            Screen screen;
            int x, y;
            dc.getDevice().getPosition(screen, x, y);
            //Detach here
            Terminal terminal = getDragTerminal(dc);
            if (terminal !is null) {
                trace("Detaching terminal ", dr);
                notifyTerminalRequestDetach(terminal, x, y);
            } else {
                error("Failed to get terminal therefore detach request failed");
            }
            return true;
        }
        return false;
    }

    Terminal getDragTerminal(DragContext dc) {
        EventBox title = cast(EventBox) DragAndDrop.dragGetSourceWidget(dc);
        if (title is null) {
            trace("Oops, something went wrong not a terminal drag");
            return null;
        }
        return cast(Terminal) title.getParent();
    }

    bool isSourceAndDestEqual(DragContext dc, Terminal dest) {
        Terminal dragTerminal = getDragTerminal(dc);
        return (dragTerminal.terminalUUID == _terminalUUID);
    }

    /**
     * Keeps track of where the cursor is and sets dragInfo so the correct
     * quandrant can be highlighted.
     */
    bool onVTEDragMotion(DragContext dc, int x, int y, uint time, Widget widget) {
        //Is this a terminal drag or something else?
        if (!dc.listTargets().find(intern(VTE_DND, false)))
            return true;
        //Don't allow drop on the same terminal
        if (isSourceAndDestEqual(dc, this)) {
            trace("Invalid drop");
            return false;
        }
        DragQuadrant dq = getDragQuadrant(x, y, vte);

        dragInfo = DragInfo(true, dq);
        vte.queueDraw();
        //Uncomment this if debugging motion otherwise generates annoying amount of trace noise
        //trace(format("Drag motion: %s %d, %d, %d", _terminalUUID, x, y, dq));

        return true;
    }

    void onVTEDragLeave(DragContext, uint, Widget) {
        trace("Drag Leave " ~ _terminalUUID);
        dragInfo = DragInfo(false, DragQuadrant.LEFT);
        vte.queueDraw();
    }

    /**
     * Given a point x,y which quandrant (left, top, right, bottom) should
     * the drag snap too.
     */
    DragQuadrant getDragQuadrant(int x, int y, Widget widget) {

        /**
         * Cribbed from Stackoverflow (http://stackoverflow.com/questions/2049582/how-to-determine-a-point-in-a-2d-triangle)
         * since implementing my own version of barycentric method will turn my brain to mush
         */
        bool pointInTriangle(GdkPoint p, GdkPoint p0, GdkPoint p1, GdkPoint p2) {
            int s = p0.y * p2.x - p0.x * p2.y + (p2.y - p0.y) * p.x + (p0.x - p2.x) * p.y;
            int t = p0.x * p1.y - p0.y * p1.x + (p0.y - p1.y) * p.x + (p1.x - p0.x) * p.y;

            if ((s < 0) != (t < 0))
                return false;

            int a = -p1.y * p2.x + p0.y * (p2.x - p1.x) + p0.x * (p1.y - p2.y) + p1.x * p2.y;
            if (a < 0.0) {
                s = -s;
                t = -t;
                a = -a;
            }
            return s > 0 && t > 0 && (s + t) <= a;
        }

        GdkPoint cursor = GdkPoint(x, y);
        GdkPoint topLeft = GdkPoint(0, 0);
        GdkPoint topRight = GdkPoint(widget.getAllocatedWidth(), 0);
        GdkPoint bottomRight = GdkPoint(widget.getAllocatedWidth(), widget.getAllocatedHeight());
        GdkPoint bottomLeft = GdkPoint(0, widget.getAllocatedHeight());
        GdkPoint center = GdkPoint(widget.getAllocatedWidth() / 2, widget.getAllocatedHeight() / 2);

        //LEFT
        if (pointInTriangle(cursor, topLeft, bottomLeft, center))
            return DragQuadrant.LEFT;
        //TOP
        if (pointInTriangle(cursor, topLeft, topRight, center))
            return DragQuadrant.TOP;
        //RIGHT
        if (pointInTriangle(cursor, topRight, bottomRight, center))
            return DragQuadrant.RIGHT;
        //BOTTOM
        if (pointInTriangle(cursor, bottomLeft, bottomRight, center))
            return DragQuadrant.BOTTOM;

        trace("Whoops, something wrong with calculation");
        return DragQuadrant.LEFT;
    }

    /**
     * Called when the drag operation ends and a drop occurred
     */
    void onVTEDragDataReceived(DragContext dc, int x, int y, SelectionData data, uint info, uint time, Widget widget) {
        trace("Drag data recieved for " ~ to!string(info));
        //Don't allow drop on the same terminal
        if (isSourceAndDestEqual(dc, this))
            return;

        final switch (info) {
        case DropTargets.URILIST:
            string[] uris = data.getUris();
            if (uris) {
                foreach (uri; uris) {
                    string hostname;
                    string quoted = ShellUtils.shellQuote(URI.filenameFromUri(uri, hostname)) ~ " ";
                    vte.feedChild(quoted, quoted.length);
                }
            }
            break;
        case DropTargets.STRING, DropTargets.TEXT:
            string text = data.getText();
            if (!text)
                vte.feedChild(text, text.length);
            break;
        case DropTargets.VTE:
            string uuid = to!string(data.getDataWithLength()[0 .. $ - 1]);
            DragQuadrant dq = getDragQuadrant(x, y, vte);
            trace(format("Receiving Terminal %s, Dropped terminal %s, x=%d, y=%d, dq=%d", _terminalUUID, uuid, x, y, dq));
            notifyTerminalRequestMove(uuid, this, dq);
            dragInfo = DragInfo(false, dq);
            break;
        }
    }

    //Draw the drag hint if dragging is occurring
    bool onVTEDraw(Scoped!Context cr, Widget widget) {
        //Dragging happening?
        if (!dragInfo.isDragActive)
            return false;
        RGBA bg;
        vte.getStyleContext().getBackgroundColor(StateFlags.SELECTED, bg);
        cr.setSourceRgba(bg.red, bg.green, bg.blue, 0.1);
        cr.setLineWidth(1);
        int w = widget.getAllocatedWidth();
        int h = widget.getAllocatedHeight();
        final switch (dragInfo.dq) {
        case DragQuadrant.LEFT:
            cr.rectangle(0, 0, w / 2, h);
            break;
        case DragQuadrant.TOP:
            cr.rectangle(0, 0, w, h / 2);
            break;
        case DragQuadrant.BOTTOM:
            cr.rectangle(0, h / 2, w, h);
            break;
        case DragQuadrant.RIGHT:
            cr.rectangle(w / 2, 0, w, h);
            break;
        }
        cr.strokePreserve();
        cr.fill();
        return false;
    }

public:

    /**
     * Creates the TerminalPane using the specified profile
     */
    this(string profileUUID) {
        super(Orientation.VERTICAL, 0);
        _terminalUUID = randomUUID().toString();
        _profileUUID = profileUUID;
        gsProfile = prfMgr.getProfileSettings(profileUUID);
        gsShortcuts = new GSettings(SETTINGS_PROFILE_KEY_BINDINGS_ID);
        createUI();
        applyPreferences();
        gsProfile.addOnChanged(delegate(string key, Settings) { applyPreference(key); });
    }

    /**
     * initializes the terminal, i.w spawns the child process.
     *
     * Params:
     *  initialPath = The initial working directory for the terminal
     *  firstRun    = Whether this is the first run of the application, used to determine whether to apply profile geometry
     */
    void initTerminal(string initialPath, bool firstRun) {
        initialWorkingDir = initialPath;
        spawnTerminalProcess(initialPath);
        if (firstRun) {
            vte.setSize(gsProfile.getInt(SETTINGS_PROFILE_SIZE_COLUMNS_KEY), gsProfile.getInt(SETTINGS_PROFILE_SIZE_ROWS_KEY));
        }
    }

    /**
     * Requests the terminal be focused
     */
    void focusTerminal() {
        vte.grabFocus();
    }

    /**
     * Determines if a child process is running in the terminal
     */
    bool isProcessRunning() {
        int fd = vte.getPty().getFd();
        pid_t fg = tcgetpgrp(fd);
        trace(format("fg=%d gpid=%d", fg, gpid));
        return (fg != -1 && fg != gpid);
    }

    /**
     * Called by the session to synchronize input
     */
    void echoKeyPressEvent(Event event) {
        //TODO - Look at this some more, feedChild seems to work fine but would really preferences
        //to simply fire the key event against the terminal. The problem is that while te event is set to 
        //the right terminal window, the key always gets handled by the terminal with focus
        // 
        //event.key.window = terminal.getWindow().getWindowStruct();
        //trace(format("Getting GDKWindow Pointer %s for terminal %d", to!string(event.getWindow().getWindowStruct()), terminalID));
        //Main.doEvent(event);
        string data = Str.toString(event.key.str, event.key.length);
        vte.feedChild(data, data.length);
    }

    @property string currentDirectory() {
        if (gpid == 0)
            return null;
        string hostname;
        return URI.filenameFromUri(vte.getCurrentDirectoryUri(), hostname);
    }

    @property string profileUUID() {
        return _profileUUID;
    }

    @property void profileUUID(string uuid) {
        if (_profileUUID != uuid) {
            _profileUUID = uuid;
            gsProfile = prfMgr.getProfileSettings(profileUUID);
            applyPreferences();
        }
    }

    @property bool synchronizeInput() {
        return _synchronizeInput;
    }

    @property void synchronizeInput(bool value) {
        _synchronizeInput = value;
    }

    /**
     * A numeric ID managed by the session, this ID can and does change
     */
    @property ulong terminalID() {
        return _terminalID;
    }

    @property void terminalID(ulong ID) {
        if (this._terminalID != ID) {
            this._terminalID = ID;
            updateTitle();
        }
    }

    /**
     * A unique ID for the terminal, it is constant for the lifespan
     * of the terminal
     */
    @property string terminalUUID() {
        return _terminalUUID;
    }

    void addOnTerminalRequestSplit(OnTerminalRequestSplit dlg) {
        terminalRequestSplitDelegates ~= dlg;
    }

    void removeOnTerminalRequestSplit(OnTerminalRequestSplit dlg) {
        gx.util.array.remove(terminalRequestSplitDelegates, dlg);
    }

    void addOnTerminalRequestMove(OnTerminalRequestMove dlg) {
        terminalRequestMoveDelegates ~= dlg;
    }

    void removeOnTerminalRequestMove(OnTerminalRequestMove dlg) {
        gx.util.array.remove(terminalRequestMoveDelegates, dlg);
    }

    void addOnTerminalRequestDetach(OnTerminalRequestDetach dlg) {
        terminalRequestDetachDelegates ~= dlg;
    }

    void removeOnTerminalRequestDetach(OnTerminalRequestDetach dlg) {
        gx.util.array.remove(terminalRequestDetachDelegates, dlg);
    }

    void addOnTerminalClose(OnTerminalClose dlg) {
        terminalCloseDelegates ~= dlg;
    }

    void removeOnTerminalClose(OnTerminalClose dlg) {
        gx.util.array.remove(terminalCloseDelegates, dlg);
    }

    void addOnTerminalInFocus(OnTerminalInFocus dlg) {
        terminalInFocusDelegates ~= dlg;
    }

    void removeOnTerminalInFocus(OnTerminalInFocus dlg) {
        gx.util.array.remove(terminalInFocusDelegates, dlg);
    }

    void addOnTerminalKeyPress(OnTerminalKeyPress dlg) {
        terminalKeyPressDelegates ~= dlg;
    }

    void removeOnTerminalKeyPress(OnTerminalKeyPress dlg) {
        gx.util.array.remove(terminalKeyPressDelegates, dlg);
    }
}

/**
 * Terminal Exited Info Bar, used when Hold option for exiting terminal is selected
 */
package class TerminalInfoBar : InfoBar {

private:
    enum STATUS_NORMAL = "The child process exited normally with status %d";
    enum STATUS_ABORT_STATUS = "The child process was aborted by signal %d.";
    enum STATUS_ABORT = "The child process was aborted.";

    Label lblPrompt;

public:
    this() {
        super([_("Relaunch")], [ResponseType.OK]);
        setDefaultResponse(ResponseType.OK);
        setMessageType(MessageType.QUESTION);
        lblPrompt = new Label(_(""));
        lblPrompt.setHalign(Align.START);
        getContentArea().packStart(lblPrompt, true, true, 0);
        setHalign(Align.FILL);
        setValign(Align.START);
    }

    void setStatus(int value) {
        if (WEXITSTATUS(value)) {
            lblPrompt.setText(format(STATUS_NORMAL, WEXITSTATUS(value)));
        } else if (WIFSIGNALED(value)) {
            lblPrompt.setText(format(STATUS_ABORT_STATUS, WTERMSIG(value)));
        } else {
            lblPrompt.setText(STATUS_ABORT);
        }
    }
}

//Block for defining various DND structs and constants
private:
/**
     * Constant used to identift terminal drand and drop
     */
enum VTE_DND = "vte";

/**
    * List of available Drop Targets for VTE
    */
enum DropTargets {
    URILIST,
    STRING,
    TEXT,
    /**
        * Used when one VTE is dropped on another
        */
        VTE
};

struct DragInfo {
    bool isDragActive;
    DragQuadrant dq;
}

//Block for handling default regex in vte
private:

//REGEX, cribbed from Gnome Terminal
enum USERCHARS = "-[:alnum:]";
enum USERCHARS_CLASS = "[" ~ USERCHARS ~ "]";
enum PASSCHARS_CLASS = "[-[:alnum:]\\Q,?;.:/!%$^*&~\"#'\\E]";
enum HOSTCHARS_CLASS = "[-[:alnum:]]";
enum HOST = HOSTCHARS_CLASS ~ "+(\\." ~ HOSTCHARS_CLASS ~ "+)*";
enum PORT = "(?:\\:[[:digit:]]{1,5})?";
enum PATHCHARS_CLASS = "[-[:alnum:]\\Q_$.+!*,:;@&=?/~#%\\E]";
enum PATHTERM_CLASS = "[^\\Q]'.:}>) \t\r\n,\"\\E]";
enum SCHEME = "(?:news:|telnet:|nntp:|file:\\/|https?:|ftps?:|sftp:|webcal:)";
enum USERPASS = USERCHARS_CLASS ~ "+(?:" ~ PASSCHARS_CLASS ~ "+)?";
enum URLPATH = "(?:(/" ~ PATHCHARS_CLASS ~ "+(?:[(]" ~ PATHCHARS_CLASS ~ "*[)])*" ~ PATHCHARS_CLASS ~ "*)*" ~ PATHTERM_CLASS ~ ")?";

enum TerminalURLFlavor {
    FLAVOR_AS_IS,
    FLAVOR_DEFAULT_TO_HTTP,
    FLAVOR_VOIP_CALL,
    FLAVOR_EMAIL,
    FLAVOR_NUMBER,
};

struct TerminalRegex {
    string pattern;
    TerminalURLFlavor flavor;
    bool caseless;
}

immutable TerminalRegex[] URL_REGEX_PATTERNS = [
    TerminalRegex(SCHEME ~ "//(?:" ~ USERPASS ~ "\\@)?" ~ HOST ~ PORT ~ URLPATH, TerminalURLFlavor.FLAVOR_AS_IS, true),
    TerminalRegex("(?:www|ftp)" ~ HOSTCHARS_CLASS ~ "*\\." ~ HOST ~ PORT ~ URLPATH, TerminalURLFlavor.FLAVOR_DEFAULT_TO_HTTP, true),
    TerminalRegex("(?:callto:|h323:|sip:)" ~ USERCHARS_CLASS ~ "[" ~ USERCHARS ~ ".]*(?:" ~ PORT ~ "/[a-z0-9]+)?\\@" ~ HOST, TerminalURLFlavor.FLAVOR_VOIP_CALL, true),
    TerminalRegex("(?:mailto:)?" ~ USERCHARS_CLASS ~ "[" ~ USERCHARS ~ ".]*\\@" ~ HOSTCHARS_CLASS ~ "+\\." ~ HOST, TerminalURLFlavor.FLAVOR_EMAIL, true),
    TerminalRegex("(?:news:|man:|info:)[-[:alnum:]\\Q^_{|}~!\"#$%&'()*+,./;:=?`\\E]+", TerminalURLFlavor.FLAVOR_AS_IS, true)
];

immutable Regex[URL_REGEX_PATTERNS.length] compiledRegex;

static this() {
    import std.exception : assumeUnique;

    Regex[URL_REGEX_PATTERNS.length] tempRegex;
    foreach (i, regex; URL_REGEX_PATTERNS) {
        tempRegex[i] = new Regex(regex.pattern, GRegexCompileFlags.OPTIMIZE | regex.caseless ? GRegexCompileFlags.CASELESS : cast(GRegexCompileFlags) 0, cast(GRegexMatchFlags) 0);
    }
    compiledRegex = assumeUnique(tempRegex);
}
