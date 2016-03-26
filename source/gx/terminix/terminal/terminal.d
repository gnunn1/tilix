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
import std.string;
import std.uuid;

import cairo.Context;

import gdk.Atom;
import gdk.DragContext;
import gdk.Event;
import gdk.RGBA;
import gdk.Screen;

import gdkpixbuf.Pixbuf;

import gio.ActionMapIF;
import gio.File : GFile = File;
import gio.FileIF : GFileIF = FileIF;
import gio.Menu : GMenu = Menu;
import gio.MenuItem : GMenuItem = MenuItem;
import gio.Settings : GSettings = Settings;
import gio.SimpleAction;
import gio.SimpleActionGroup;
import gio.ThemedIcon;

import glib.GException;
import glib.Regex;
import glib.ShellUtils;
import glib.SimpleXML;
import glib.Str;
import glib.URI;
import glib.Variant : GVariant = Variant;
import glib.VariantType : GVariantType = VariantType;

import gtk.Box;
import gtk.Button;
import gtk.Clipboard;
import gtk.Dialog;
import gtk.DragAndDrop;
import gtk.EventBox;
import gtk.FileChooserDialog;
import gtk.FileFilter;
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

static if (USE_SCROLLED_WINDOW) {
    import gtk.ScrolledWindow;
} else {
    import gtk.Scrollbar;
}
import gtk.SelectionData;
import gtk.Separator;
import gtk.SeparatorMenuItem;
import gtk.TargetEntry;
import gtk.ToggleButton;
import gtk.Widget;
import gtk.Window;

import pango.PgFontDescription;

import vte.Terminal : VTE = Terminal;
import vtec.vtetypes;

import gx.gtk.actions;
import gx.gtk.cairo;
import gx.gtk.util;
import gx.i18n.l10n;
import gx.util.array;

import gx.terminix.application;
import gx.terminix.cmdparams;
import gx.terminix.common;
import gx.terminix.constants;
import gx.terminix.encoding;
import gx.terminix.preferences;
import gx.terminix.terminal.actions;
import gx.terminix.terminal.layout;
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
 * The window state of the terminal
 */
enum TerminalState {
    NORMAL,
    MAXIMIZED
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

enum SyncInputEventType {
    KEY_PRESS,
    PASTE
};

struct SyncInputEvent {
    SyncInputEventType eventType;
    Event event;
}

/**
 * Triggered on a terminal key press, used by the session to synchronize input
 * when this option is selected.
 */
alias OnTerminalSyncInput = void delegate(Terminal terminal, SyncInputEvent event);

/**
 * Triggered when the terminal needs to change state. Delegate returns whether
 * state change was successful.
 */
alias OnTerminalRequestStateChange = bool delegate(Terminal terminal, TerminalState state);

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
class Terminal : EventBox {

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
    OnTerminalSyncInput[] terminalSyncInputDelegates;
    OnTerminalRequestStateChange[] terminalRequestStateChangeDelegates;

    TerminalState terminalState = TerminalState.NORMAL;
    Button btnMaximize;

    SearchRevealer rFind;

    VTENotification vte;
    Overlay terminalOverlay;
    static if (!USE_SCROLLED_WINDOW) {
        Scrollbar sb;
    }

    GPid gpid = 0;
    bool _terminalInitialized = false;

    Box bTitle;
    MenuButton mbTitle;
    Label lblTitle;
    ToggleButton tbSyncInput;

    string _profileUUID;
    //Sequential identifier, used to enable user to select terminal by number. Can change, not constant
    ulong _terminalID;
    //Unique identifier for this terminal, never shown to user, never changes
    immutable string _terminalUUID;
    //overrides profile title
    string _overrideTitle;
    //overrides command when load from session JSON
    string _overrideCommand;
    //Whether synchronized input is turned on in the session
    bool _synchronizeInput;
    //If synchronized is on, determines if there is a local override turning it off for this terminal only
    bool _synchronizeInputOverride = true;

    //Whether to ignore unsafe paste, basically when 
    //option is turned on but user opts to ignore it for this terminal
    bool unsafePasteIgnored;

    string initialWorkingDir;

    SimpleActionGroup sagTerminalActions;

    SimpleAction saProfileSelect;
    GMenu profileMenu;

    SimpleAction saEncodingSelect;
    GMenu encodingMenu;

    SimpleAction saCopy;
    SimpleAction saPaste;
    static if (POPOVER_CONTEXT_MENU) {
        Popover pmContext;
    } else {
        Menu mContext;
        MenuItem miCopy;
        MenuItem miPaste;
    }
    GSettings gsProfile;
    GSettings gsShortcuts;
    GSettings gsDesktop;
    GSettings gsSettings;

    // Track Regex Tag we get back from VTE in order
    // to track which regex generated the match
    TerminalRegex[int] regexTag;

    //Track match detection
    TerminalURLMatch match;

    /**
     * Create the user interface of the TerminalPane
     */
    void createUI() {
        sagTerminalActions = new SimpleActionGroup();
        createActions(sagTerminalActions);

        Box box = new Box(Orientation.VERTICAL, 0);
        add(box);
        // Create the title bar of the pane
        Widget titlePane = createTitlePane();
        box.add(titlePane);

        //Create the actual terminal for the pane
        box.add(createVTE());

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
        
        bTitle = new Box(Orientation.HORIZONTAL, 0);
        bTitle.setVexpand(false);
        bTitle.getStyleContext().addClass("notebook");
        bTitle.getStyleContext().addClass("header");

        lblTitle = new Label(_("Terminal"));
        lblTitle.setEllipsize(PangoEllipsizeMode.START);
        lblTitle.setUseMarkup(true);

        //Profile Menu
        profileMenu = new GMenu();

        //Encoding Menu
        encodingMenu = new GMenu();

        Box bTitleLabel = new Box(Orientation.HORIZONTAL, 6);
        bTitleLabel.add(lblTitle);
        bTitleLabel.add(new Image("pan-down-symbolic", IconSize.MENU));

        mbTitle = new MenuButton();
        mbTitle.setRelief(ReliefStyle.NONE);
        mbTitle.setFocusOnClick(false);
        mbTitle.setPopover(createPopover(mbTitle));
        mbTitle.addOnButtonPress(delegate(Event e, Widget w) { buildProfileMenu(); buildEncodingMenu(); return false; });
        mbTitle.add(bTitleLabel);

        bTitle.packStart(mbTitle, false, false, 4);
        setVerticalMargins(mbTitle);

        //Close Button
        Button btnClose = new Button("window-close-symbolic", IconSize.MENU);
        btnClose.setTooltipText(_("Close"));
        btnClose.setRelief(ReliefStyle.NONE);
        btnClose.setFocusOnClick(false);
        btnClose.setActionName(getActionDetailedName(ACTION_PREFIX, ACTION_CLOSE));
        setVerticalMargins(btnClose);
        bTitle.packEnd(btnClose, false, false, 4);

        //Maximize Button
        btnMaximize = new Button("window-maximize-symbolic", IconSize.MENU);
        btnMaximize.setTooltipText(_("Maximize"));
        btnMaximize.setRelief(ReliefStyle.NONE);
        btnMaximize.setFocusOnClick(false);
        btnMaximize.setActionName(getActionDetailedName(ACTION_PREFIX, ACTION_MAXIMIZE));
        setVerticalMargins(btnMaximize);
        bTitle.packEnd(btnMaximize, false, false, 0);

        //Synchronize Input Button
        tbSyncInput = new ToggleButton();
        tbSyncInput.setNoShowAll(true);
        tbSyncInput.setImage(new Image("input-keyboard-symbolic", IconSize.MENU));
        tbSyncInput.setTooltipText(_("Disable input synchronization for this terminal"));
        tbSyncInput.setRelief(ReliefStyle.NONE);
        tbSyncInput.setFocusOnClick(false);
        setVerticalMargins(tbSyncInput);
        tbSyncInput.setActive(_synchronizeInputOverride);
        tbSyncInput.addOnToggled(delegate(ToggleButton btn) { _synchronizeInputOverride = btn.getActive(); }, ConnectFlags.AFTER);
        bTitle.packEnd(tbSyncInput, false, false, 0);

        EventBox evtTitle = new EventBox();
        evtTitle.add(bTitle);
        //Handle double click for window state change
        evtTitle.addOnButtonPress(delegate(Event event, Widget) {
            if (event.getEventType() == EventType.DOUBLE_BUTTON_PRESS && event.button.button == MouseButton.PRIMARY) {
                    maximize();
            } else if (event.getEventType() == EventType.BUTTON_PRESS) {
                    vte.grabFocus();
            }
            return false;
        });
        return evtTitle;
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
        GMenu menuSection = new GMenu();
        menuSection.append(_("Edit Profile"), getActionDetailedName(ACTION_PREFIX, ACTION_PROFILE_PREFERENCE));
        profileMenu.appendSection(null, menuSection);
    }

    //Dynamically build the menus for selecting an encoding
    void buildEncodingMenu() {
        encodingMenu.removeAll();
        saEncodingSelect.setState(new GVariant(vte.getEncoding()));
        string[] encodings = gsSettings.getStrv(SETTINGS_ENCODINGS_KEY);
        foreach (encoding; encodings) {
            if (encoding in lookupEncoding) {
                string name = lookupEncoding[encoding];
                GMenuItem menuItem = new GMenuItem(encoding ~ " " ~ _(name), getActionDetailedName(ACTION_PREFIX, ACTION_ENCODING_SELECT));
                menuItem.setActionAndTargetValue(getActionDetailedName(ACTION_PREFIX, ACTION_ENCODING_SELECT), new GVariant(encoding));
                encodingMenu.appendItem(menuItem);
            }
        }
    }

    /**
     * Creates the common actions used by the terminal pane
     */
    void createActions(SimpleActionGroup group) {
        //Terminal Split actions
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_SPLIT_H, gsShortcuts, delegate(GVariant, SimpleAction) {
            notifyTerminalRequestSplit(Orientation.HORIZONTAL);
        });
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_SPLIT_V, gsShortcuts, delegate(GVariant, SimpleAction) {
            notifyTerminalRequestSplit(Orientation.VERTICAL);
        });

        //Find actions
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_FIND, gsShortcuts, delegate(GVariant, SimpleAction) {
            if (!rFind.getRevealChild()) {
                rFind.setRevealChild(true);
                rFind.focusSearchEntry();
            } else {
                rFind.setRevealChild(false);
                vte.grabFocus();
            }
        });
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_FIND_PREVIOUS, gsShortcuts, delegate(GVariant, SimpleAction) { 
            if (!vte.searchFindPrevious() && !vte.searchGetWrapAround) {
                vte.searchFindNext();    
            }
        });
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_FIND_NEXT, gsShortcuts, delegate(GVariant, SimpleAction) {
            if (!vte.searchFindNext() && !vte.searchGetWrapAround) {
                vte.searchFindPrevious();    
            }
        });

        //Clipboard actions
        saCopy = registerActionWithSettings(group, ACTION_PREFIX, ACTION_COPY, gsShortcuts, delegate(GVariant, SimpleAction) {
            if (vte.getHasSelection()) {
                vte.copyClipboard();
            }
        });
        saPaste = registerActionWithSettings(group, ACTION_PREFIX, ACTION_PASTE, gsShortcuts, delegate(GVariant, SimpleAction) {
            if (Clipboard.get(null).waitIsTextAvailable()) {
                pasteClipboard();
            }
        });
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_SELECT_ALL, gsShortcuts, delegate(GVariant, SimpleAction) { vte.selectAll(); });

        //Link Actions, no shortcuts, context menu only
        registerAction(group, ACTION_PREFIX, ACTION_COPY_LINK, null, delegate(GVariant, SimpleAction) {
            if (match.match) {
                Clipboard.get(null).setText(match.match, to!int(match.match.length));
            }
        });
        registerAction(group, ACTION_PREFIX, ACTION_OPEN_LINK, null, delegate(GVariant, SimpleAction) {
            if (match.match) {
                openURI(match.match, match.flavor);
            }
        });

        //Zoom actions
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_ZOOM_IN, gsShortcuts, delegate(GVariant, SimpleAction) {
            if (vte.getFontScale() < 5) {
                trace("Zoom In");
                vte.setFontScale(vte.getFontScale() + 0.1);
            }
        });
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_ZOOM_OUT, gsShortcuts, delegate(GVariant, SimpleAction) {
            if (vte.getFontScale() > 0.1) {
                trace("Zoom Out");
                vte.setFontScale(vte.getFontScale() - 0.1);
            }
        });
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_ZOOM_NORMAL, gsShortcuts, delegate(GVariant, SimpleAction) {
            trace("Zoom Normal");
            vte.setFontScale(1.0);
        });

        //Override terminal title
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_LAYOUT, gsShortcuts, delegate(GVariant, SimpleAction) {
            string terminalTitle = _overrideTitle.length == 0 ? gsProfile.getString(SETTINGS_PROFILE_TITLE_KEY) : _overrideTitle;
            LayoutDialog dialog = new LayoutDialog(cast(Window) getToplevel());
            scope (exit) {
                dialog.destroy();
            }
            dialog.title = terminalTitle;
            dialog.command = _overrideCommand;
            dialog.showAll();
            if (dialog.run() == ResponseType.OK) {
                _overrideTitle = dialog.title;
                _overrideCommand = dialog.command;
                updateTitle();
            }
            /*            
            if (showInputDialog(null, terminalTitle, terminalTitle, _("Enter Custom Title"),
                _("Enter a new title to override the one specified by the profile. To reset it to the profile setting, leave it blank."))) {
                _overrideTitle = terminalTitle;
                if (_overrideTitle.length == 0)
                    _overrideTitle.length = 0;
                updateTitle();
            }
            */
        });

        //Maximize Terminal
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_MAXIMIZE, gsShortcuts, delegate(GVariant, SimpleAction) { maximize(); });

        //Close Terminal Action
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_CLOSE, gsShortcuts, delegate(GVariant, SimpleAction) {
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

        //Read Only
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_READ_ONLY, gsShortcuts, delegate(GVariant state, SimpleAction sa) {
            bool newState = !sa.getState().getBoolean();
            sa.setState(new GVariant(newState));
            vte.setInputEnabled(!newState);
        }, null, new GVariant(false));

        //SaveAs
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_SAVE, gsShortcuts, delegate(GVariant state, SimpleAction sa) { saveTerminalOutput(); }, null, null);

        //Edit Profile Preference
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_PROFILE_PREFERENCE, gsShortcuts, delegate(GVariant, SimpleAction) {
            terminix.presentProfilePreferences(prfMgr.getProfile(_profileUUID));
        }, null, null);

        //Select Profile
        GVariant pu = new GVariant(profileUUID);
        saProfileSelect = registerAction(group, ACTION_PREFIX, ACTION_PROFILE_SELECT, null, delegate(GVariant value, SimpleAction sa) {
            ulong l;
            string uuid = value.getString(l);
            profileUUID = uuid;
            saProfileSelect.setState(value);
        }, pu.getType(), pu);

        // Select Encoding
        // 
        GVariant encoding = new GVariant(gsProfile.getString(SETTINGS_PROFILE_ENCODING_KEY));
        saEncodingSelect = registerAction(group, ACTION_PREFIX, ACTION_ENCODING_SELECT, null, delegate(GVariant value, SimpleAction sa) {
            ulong l;
            sa.setState(value);
            vte.setEncoding(value.getString(l));
        }, encoding.getType(), encoding);

        //Insert Terminal Actions
        insertActionGroup(ACTION_PREFIX, sagTerminalActions);
    }

    /**
     * Creates the terminal pane popover
     */
    Popover createPopover(Widget parent) {
        GMenu model = new GMenu();

        GMenuItem buttons = createSplitButtons();
        model.appendItem(buttons);

        GMenu menuSection = new GMenu();
        menuSection.append(_("Save…"), ACTION_SAVE);
        menuSection.append(_("Find…"), ACTION_FIND);
        menuSection.append(_("Layout Options…"), ACTION_LAYOUT);
        model.appendSection(null, menuSection);

        menuSection = new GMenu();
        menuSection.append(_("Read-Only"), ACTION_READ_ONLY);
        model.appendSection(null, menuSection);

        menuSection = new GMenu();
        menuSection.appendSubmenu(_("Profiles"), profileMenu);
        menuSection.appendSubmenu(_("Encoding"), encodingMenu);
        model.appendSection(null, menuSection);

        Popover pm = new Popover(parent);
        pm.bindModel(model, ACTION_PREFIX);
        return pm;
    }

    /**
     * Creates the horizontal/vertical split buttons
     */
    GMenuItem createSplitButtons() {
        GMenuItem splitH = new GMenuItem(null, ACTION_SPLIT_H);
        splitH.setAttributeValue("verb-icon", new GVariant("terminix-split-tab-right-symbolic"));
        splitH.setAttributeValue("label", new GVariant(_("Split Right")));

        GMenuItem splitV = new GMenuItem(null, ACTION_SPLIT_V);
        splitV.setAttributeValue("verb-icon", new GVariant("terminix-split-tab-down-symbolic"));
        splitV.setAttributeValue("label", new GVariant(_("Split Down")));

        GMenu splitSection = new GMenu();
        splitSection.appendItem(splitH);
        splitSection.appendItem(splitV);

        GMenuItem splits = new GMenuItem(null, null);
        splits.setSection(splitSection);
        splits.setAttributeValue("display-hint", new GVariant("horizontal-buttons"));

        return splits;
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
        foreach (i, regex; compiledRegex) {
            int id = vte.matchAddGregex(cast(Regex) regex, cast(GRegexMatchFlags) 0);
            regexTag[id] = URL_REGEX_PATTERNS[i];
            vte.matchSetCursorType(id, CursorType.HAND2);
        }

        //Event handlers
        vte.addOnChildExited(&onTerminalChildExited);
        vte.addOnWindowTitleChanged(delegate(VTE terminal) {
            trace(format("Window title changed, pid=%d '%s'", gpid, vte.getWindowTitle()));
            terminalInitialized = true;
            updateTitle();
        });
        vte.addOnIconTitleChanged(delegate(VTE terminal) { trace(format("Icon title changed, pid=%d '%s'", gpid, vte.getIconTitle())); updateTitle(); });
        vte.addOnCurrentDirectoryUriChanged(delegate(VTE terminal) {
            trace(format("Current directory changed, pid=%d '%s'", gpid, currentDirectory));
            terminalInitialized = true;
            updateTitle();
        });
        vte.addOnCurrentFileUriChanged(delegate(VTE terminal) { trace("Current file is " ~ vte.getCurrentFileUri); });
        vte.addOnFocusIn(&onTerminalWidgetFocusIn);
        vte.addOnFocusOut(&onTerminalWidgetFocusOut);
        vte.addOnNotificationReceived(delegate(string summary, string _body, VTE terminal) {
            if (terminalInitialized && !terminal.hasFocus()) {
                notifyProcessNotification(summary, _body, terminalUUID);
            }
        });
        vte.addOnContentsChanged(delegate(VTE) {
            // VTE configuration problem, Issue #34
            if (terminalInitialized && terminix.testVTEConfig() && currentDirectory.length == 0) {
                terminix.warnVTEConfigIssue();
            }
        });
        vte.addOnEnterNotify(delegate(Event event, Widget) {
            if (gsSettings.getBoolean(SETTINGS_TERMINAL_FOCUS_FOLLOWS_MOUSE_KEY)) {
                vte.grabFocus();
            }
            return false;
        }, GConnectFlags.AFTER);

        vte.addOnButtonPress(&onTerminalButtonPress);
        vte.addOnKeyPress(delegate(Event event, Widget widget) {
            if (isSynchronizedInput() && event.key.sendEvent == 0) {
                SyncInputEvent se = SyncInputEvent(SyncInputEventType.KEY_PRESS, event);
                foreach (dlg; terminalSyncInputDelegates)
                    dlg(this, se);
            }
            return false;
        });

        // Create basic context menu, items get added dynamically
        static if (POPOVER_CONTEXT_MENU) {
            pmContext = new Popover(vte);
            pmContext.setModal(true);
            pmContext.setPosition(PositionType.BOTTOM);
        } else {
            mContext = new Menu();
        }
        terminalOverlay = new Overlay();
        static if (USE_SCROLLED_WINDOW) {
            ScrolledWindow sw = new ScrolledWindow(vte);
            terminalOverlay.add(sw);
        } else {
            terminalOverlay.add(vte);
        }

        Box terminalBox = new Box(Orientation.HORIZONTAL, 0);
        terminalBox.add(terminalOverlay);

        // See https://bugzilla.gnome.org/show_bug.cgi?id=760718 for why we use
        // a Scrollbar instead of a ScrolledWindow. It's pity considering the
        // overlay scrollbars look awesome with VTE
        static if (!USE_SCROLLED_WINDOW) {
            sb = new Scrollbar(Orientation.VERTICAL, vte.getVadjustment());
            terminalBox.add(sb);
        }

        Box box = new Box(Orientation.VERTICAL, 0);
        rFind = new SearchRevealer(vte, sagTerminalActions);
        rFind.addOnSearchEntryFocusIn(&onTerminalWidgetFocusIn);
        rFind.addOnSearchEntryFocusOut(&onTerminalWidgetFocusOut);

        box.add(rFind);
        box.add(terminalBox);

        return box;
    }

    bool isSynchronizedInput() {
        return _synchronizeInput && _synchronizeInputOverride;
    }

    /**
     * Updates the terminal title in response to UI changes
     */
    void updateTitle() {
        string title = _overrideTitle.length == 0 ? gsProfile.getString(SETTINGS_PROFILE_TITLE_KEY) : _overrideTitle;
        string windowTitle = vte.getWindowTitle();
        if (windowTitle.length == 0)
            windowTitle = _("Terminal");
        title = title.replace(TERMINAL_TITLE, windowTitle);
        title = title.replace(TERMINAL_ICON_TITLE, vte.getIconTitle());
        title = title.replace(TERMINAL_ID, to!string(terminalID));
        string path;
        if (terminalInitialized) {
            path = currentDirectory;
            trace("Current directory is " ~ path);
        } else {
            trace("Terminal not initialized yet, no path available");
            path = "";
        }
        title = title.replace(TERMINAL_DIR, path);
        lblTitle.setMarkup(title);
    }

    /**
     * Enables/Disables actions depending on UI state
     */
    void updateActions() {
        SimpleAction sa = cast(SimpleAction) sagTerminalActions.lookup(ACTION_SPLIT_H);
        sa.setEnabled(terminalState == TerminalState.NORMAL);
        sa = cast(SimpleAction) sagTerminalActions.lookup(ACTION_SPLIT_V);
        sa.setEnabled(terminalState == TerminalState.NORMAL);
        //Update button image
        string icon;
        if (terminalState == TerminalState.MAXIMIZED) {
            icon = "window-restore-symbolic";
            btnMaximize.setTooltipText(_("Restore"));
        } else {
            icon = "window-maximize-symbolic";
            btnMaximize.setTooltipText(_("Maximize"));
        }
        btnMaximize.setImage(new Image(icon, IconSize.BUTTON));
    }

    void pasteClipboard(bool inputSync = false) {
        string pasteText = Clipboard.get(null).waitForText();
        // Don't check for unsafe paste if doing sync input, original paste checked it
        if (!inputSync && (pasteText.indexOf("sudo") > -1) && (pasteText.indexOf("\n") != 0)) {
            if (!unsafePasteIgnored && gsSettings.getBoolean(SETTINGS_UNSAFE_PASTE_ALERT_KEY)) {
                UnsafePasteDialog dialog = new UnsafePasteDialog(cast(Window) getToplevel(), chomp(pasteText));
                scope (exit) {
                    dialog.destroy();
                }
                if (dialog.run() == 1)
                    return;
                else
                    unsafePasteIgnored = true;
            }
        }
        scope (exit) {
            // Only call handler if synchronized input is active and we are
            // not doing this paste as a result of a synchronized input
            if (!inputSync && isSynchronizedInput()) {
                SyncInputEvent se = SyncInputEvent(SyncInputEventType.PASTE, null);
                foreach (dlg; terminalSyncInputDelegates)
                    dlg(this, se);
            }
        }
        if (gsSettings.getBoolean(SETTINGS_STRIP_FIRST_COMMENT_CHAR_ON_PASTE_KEY)) {
            if (pasteText.length > 0 && (pasteText[0] == '#' || pasteText[0] == '$')) {
                vte.feedChild(pasteText[1 .. $], pasteText.length - 1);
                return;
            }
        }
        vte.pasteClipboard();
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
        gpid = -1;
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

    void buildContextMenu() {
        static if (POPOVER_CONTEXT_MENU) {
            GMenu mmContext = new GMenu();
            if (match.match) {
                GMenu linkSection = new GMenu();
                linkSection.append(_("Open Link"), ACTION_OPEN_LINK);
                linkSection.append(_("Copy Link Address"), ACTION_COPY_LINK);
                mmContext.appendSection(null, linkSection);
            }
            GMenu clipSection = new GMenu();
            clipSection.append(_("Copy"), ACTION_COPY);
            clipSection.append(_("Paste"), ACTION_PASTE);
            clipSection.append(_("Select All"), ACTION_SELECT_ALL);
            mmContext.appendSection(null, clipSection);

            GMenuItem buttons = createSplitButtons();
            mmContext.appendItem(buttons);

            pmContext.bindModel(mmContext, ACTION_PREFIX);
        } else {
            //Can't get GIO Actions to work with GTKMenu, they are always disabled even though they
            //work fine in a popover. Could switch this to a popover but popover positioning could use some
            //work, as well popover clips in small windows.
            //
            // Note doesn't have new copy/open link actions, will be removing context menu support in near
            // future since popover seems to be working well
            mContext.removeAll();
            miCopy = new MenuItem(delegate(MenuItem) { vte.copyClipboard(); }, _("Copy"), null);
            mContext.add(miCopy);
            miPaste = new MenuItem(delegate(MenuItem) { pasteClipboard(); }, _("Paste"), null);
            mContext.add(miPaste);
            MenuItem miSelectAll = new MenuItem(delegate(MenuItem) { vte.selectAll(); }, _("Select All"), null);
            mContext.add(new SeparatorMenuItem());
            mContext.add(miSelectAll);
        }
    }

    /**
     * Signal received when mouse button is pressed in terminal
     */
    bool onTerminalButtonPress(Event event, Widget widget) {

        void updateMatch(Event event) {
            match.clear;
            int tag;
            match.match = vte.matchCheckEvent(event, tag);
            if (match.match) {
                if (tag in regexTag) {
                    TerminalRegex regex = regexTag[tag];
                    match.flavor = regex.flavor;
                }
            }
        }

        if (event.type == EventType.BUTTON_PRESS) {
            GdkEventButton* buttonEvent = event.button;
            updateMatch(event);
            switch (buttonEvent.button) {
            case MouseButton.PRIMARY:
                if (match.match) {
                    openURI(match.match, match.flavor);
                    return true;
                } else {
                    return false;
                }
            case MouseButton.SECONDARY:
                trace("Enabling actions");
                if (!(event.button.state & (GdkModifierType.SHIFT_MASK | GdkModifierType.CONTROL_MASK | GdkModifierType.MOD1_MASK)) && vte.onButtonPressEvent(event.button))
                    return true;

                buildContextMenu();
                static if (POPOVER_CONTEXT_MENU) {
                    saCopy.setEnabled(vte.getHasSelection());
                    saPaste.setEnabled(Clipboard.get(null).waitIsTextAvailable());
                    GdkRectangle rect = GdkRectangle(to!int(buttonEvent.x), to!int(buttonEvent.y), 1, 1);
                    pmContext.setPointingTo(&rect);
                    pmContext.showAll();
                } else {
                    miCopy.setSensitive(vte.getHasSelection());
                    miPaste.setSensitive(Clipboard.get(null).waitIsTextAvailable());
                    mContext.showAll();
                    mContext.popup(buttonEvent.button, buttonEvent.time);
                }
                return true;
            default:
                return false;
            }
        }
        return false;
    }

    void openURI(string uri, TerminalURLFlavor flavor) {
        switch (flavor) {
        case TerminalURLFlavor.DEFAULT_TO_HTTP:
            uri = "http://" ~ uri;
            break;
        case TerminalURLFlavor.EMAIL:
            if (!uri.startsWith("mailto:")) {
                uri = "mailto:" ~ uri;
            }
            break;
        default:
            break;
        }
        MountOperation.showUri(null, uri, Main.getCurrentEventTime());
    }

    /**
     * returns true if any widget in the "terminal" has focus,
     * this includes both the vte and the search entry. This is
     * used to determine if the title should be dislayed normally
     * or grayed out.
     */
    bool isTerminalWidgetFocused() {
        return vte.hasFocus || rFind.hasSearchEntryFocus();
    }

    /**
     * Tracks focus of widgets (vte and rFind) in this terminal pane
     */
    bool onTerminalWidgetFocusIn(Event event, Widget widget) {
        trace("Terminal gained focus " ~ terminalUUID);
        lblTitle.setSensitive(true);
        //Fire focus events so session can track which terminal last had focus
        foreach (dlg; terminalInFocusDelegates) {
            dlg(this);
        }
        static if (DIM_TERMINAL_NO_FOCUS) {
            //Add dim effect
            vte.queueDraw();
        }
        return false;
    }

    /**
     * Tracks focus of widgets (vte and rFind) in this terminal pane
     */
    bool onTerminalWidgetFocusOut(Event event, Widget widget) {
        trace("Terminal lost focus" ~ terminalUUID);
        lblTitle.setSensitive(isTerminalWidgetFocused());
        static if (DIM_TERMINAL_NO_FOCUS) {
            //Add dim effect
            vte.queueDraw();
        }
        return false;
    }

    // Preferences go here
private:
    RGBA vteFG;
    RGBA vteBG;
    RGBA[16] vtePalette;

    void initColors() {
        vteFG = new RGBA();
        vteBG = new RGBA();
        vtePalette = new RGBA[16];
        for (int i = 0; i < 16; i++) {
            vtePalette[i] = new RGBA();
        }
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
        case SETTINGS_PROFILE_FG_COLOR_KEY, SETTINGS_PROFILE_BG_COLOR_KEY, SETTINGS_PROFILE_PALETTE_COLOR_KEY, SETTINGS_PROFILE_USE_THEME_COLORS_KEY,
        SETTINGS_PROFILE_BG_TRANSPARENCY_KEY:
                if (gsProfile.getBoolean(SETTINGS_PROFILE_USE_THEME_COLORS_KEY)) {
                    getStyleColor(vte.getStyleContext(), StateFlags.ACTIVE, vteFG);
                    getStyleBackgroundColor(vte.getStyleContext(), StateFlags.ACTIVE, vteBG);
                } else {
                if (!vteFG.parse(gsProfile.getString(SETTINGS_PROFILE_FG_COLOR_KEY)))
                    trace("Parsing foreground color failed");
                if (!vteBG.parse(gsProfile.getString(SETTINGS_PROFILE_BG_COLOR_KEY)))
                    trace("Parsing background color failed");
            }
            vteBG.alpha = to!double(100 - gsProfile.getInt(SETTINGS_PROFILE_BG_TRANSPARENCY_KEY)) / 100.0;
            string[] colors = gsProfile.getStrv(SETTINGS_PROFILE_PALETTE_COLOR_KEY);
            foreach (i, color; colors) {
                if (!vtePalette[i].parse(color))
                    trace("Parsing color failed " ~ colors[i]);
            }
            vte.setColors(vteFG, vteBG, vtePalette);
            break;
        case SETTINGS_PROFILE_SHOW_SCROLLBAR_KEY:
            static if (!USE_SCROLLED_WINDOW) {
                sb.setNoShowAll(!gsProfile.getBoolean(SETTINGS_PROFILE_SHOW_SCROLLBAR_KEY));
                sb.setVisible(gsProfile.getBoolean(SETTINGS_PROFILE_SHOW_SCROLLBAR_KEY));
            }
            break;
        case SETTINGS_PROFILE_SCROLL_ON_OUTPUT_KEY:
            vte.setScrollOnOutput(gsProfile.getBoolean(SETTINGS_PROFILE_SCROLL_ON_OUTPUT_KEY));
            break;
        case SETTINGS_PROFILE_SCROLL_ON_INPUT_KEY:
            vte.setScrollOnKeystroke(gsProfile.getBoolean(SETTINGS_PROFILE_SCROLL_ON_INPUT_KEY));
            break;
        case SETTINGS_PROFILE_UNLIMITED_SCROLL_KEY, SETTINGS_PROFILE_SCROLLBACK_LINES_KEY:
            long scrollLines = gsProfile.getBoolean(SETTINGS_PROFILE_UNLIMITED_SCROLL_KEY) ? -1 : gsProfile.getInt(SETTINGS_PROFILE_SCROLLBACK_LINES_KEY);
            vte.setScrollbackLines(scrollLines);
            break;
        case SETTINGS_PROFILE_BACKSPACE_BINDING_KEY:
            vte.setBackspaceBinding(getEraseBinding(gsProfile.getString(SETTINGS_PROFILE_BACKSPACE_BINDING_KEY)));
            break;
        case SETTINGS_PROFILE_DELETE_BINDING_KEY:
            vte.setDeleteBinding(getEraseBinding(gsProfile.getString(SETTINGS_PROFILE_DELETE_BINDING_KEY)));
            break;
        case SETTINGS_PROFILE_ENCODING_KEY:
            vte.setEncoding(gsProfile.getString(SETTINGS_PROFILE_ENCODING_KEY));
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
        case SETTINGS_PROFILE_USE_SYSTEM_FONT_KEY, SETTINGS_PROFILE_FONT_KEY:
            PgFontDescription desc;
            if (gsProfile.getBoolean(SETTINGS_PROFILE_USE_SYSTEM_FONT_KEY)) {
                desc = PgFontDescription.fromString(gsDesktop.getString(SETTINGS_MONOSPACE_FONT_KEY));
            } else {
                desc = PgFontDescription.fromString(gsProfile.getString(SETTINGS_PROFILE_FONT_KEY));
            }
            if (desc.getSize() == 0)
                desc.setSize(10);
            vte.setFont(desc);
            break;
        case SETTINGS_AUTO_HIDE_MOUSE_KEY:
            vte.setMouseAutohide(gsSettings.getBoolean(SETTINGS_AUTO_HIDE_MOUSE_KEY));
            break;
        case SETTINGS_ENABLE_SMALL_TITLE_KEY:
            if (gsSettings.getBoolean(SETTINGS_ENABLE_SMALL_TITLE_KEY)) {
                bTitle.getStyleContext().addClass("compact");
            } else {
                bTitle.getStyleContext().removeClass("compact");
            }
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
            SETTINGS_PROFILE_AUDIBLE_BELL_KEY, SETTINGS_PROFILE_ALLOW_BOLD_KEY,
            SETTINGS_PROFILE_REWRAP_KEY,
            SETTINGS_PROFILE_CURSOR_SHAPE_KEY, // Only pass one color key, all colors will be applied
            SETTINGS_PROFILE_FG_COLOR_KEY, SETTINGS_PROFILE_SHOW_SCROLLBAR_KEY, SETTINGS_PROFILE_SCROLL_ON_OUTPUT_KEY,
            SETTINGS_PROFILE_SCROLL_ON_INPUT_KEY,
            SETTINGS_PROFILE_UNLIMITED_SCROLL_KEY,
            SETTINGS_PROFILE_BACKSPACE_BINDING_KEY,
            SETTINGS_PROFILE_DELETE_BINDING_KEY,
            SETTINGS_PROFILE_CJK_WIDTH_KEY, SETTINGS_PROFILE_ENCODING_KEY, SETTINGS_PROFILE_CURSOR_BLINK_MODE_KEY, //Only pass the one font key, will handle both cases
            SETTINGS_PROFILE_FONT_KEY,
            SETTINGS_ENABLE_SMALL_TITLE_KEY, SETTINGS_AUTO_HIDE_MOUSE_KEY
        ];

        foreach (key; keys) {
            applyPreference(key);
        }
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

private:

    void showInfoBarMessage(string message) {
        TerminalInfoBar ibRelaunch = new TerminalInfoBar();
        ibRelaunch.addOnResponse(delegate(int response, InfoBar ib) {
            if (response == ResponseType.OK) {
                ibRelaunch.destroy();
                spawnTerminalProcess(initialWorkingDir);
            }
        });
        ibRelaunch.setMessage(message);
        terminalOverlay.addOverlay(ibRelaunch);
        ibRelaunch.showAll();
    }

    /**
     * Spawns the child process in the Terminal depending on the Profile
     * command options.
     *
     * Note that command must be passed in rather then using overrideCommand
     * directly in case we re-spawn it later.
     */
    void spawnTerminalProcess(string workingDir, string command = null) {
        CommandParameters overrides = terminix.getGlobalOverrides();
        if (overrides.workingDir.length > 0) {
            workingDir = overrides.workingDir;
            trace("Working directory overriden to " ~ workingDir);
        }

        GSpawnFlags flags = GSpawnFlags.SEARCH_PATH_FROM_ENVP;
        string shell = vte.getUserShell();
        string[] args;
        // Passed command takes precedence over global override which comes from -x flag
        if (command.length == 0 && overrides.execute.length > 0) {
            command = overrides.execute;
        }
        if (command.length > 0) {
            trace("Overriding the command from command prompt: " ~ overrides.execute);
            ShellUtils.shellParseArgv(command, args);
            flags = flags | GSpawnFlags.SEARCH_PATH;
        } else if (gsProfile.getBoolean(SETTINGS_PROFILE_USE_CUSTOM_COMMAND_KEY)) {
            ShellUtils.shellParseArgv(gsProfile.getString(SETTINGS_PROFILE_CUSTOM_COMMAND_KEY), args);
            flags = flags | GSpawnFlags.SEARCH_PATH;
        } else {
            args ~= shell;
            if (gsProfile.getBoolean(SETTINGS_PROFILE_LOGIN_SHELL_KEY)) {
                args ~= format("-%s", shell);
                flags = flags | GSpawnFlags.FILE_AND_ARGV_ZERO;
            }
        }
        string[] envv = ["TERMINIX_ID=" ~ terminalUUID];
        foreach (arg; args)
            trace("Argument: " ~ arg);
        try {
            //Set PWD so that shell sets correct directory for symlinks, see #164
            if (workingDir.length > 0) {
                envv ~= ["PWD=" ~ workingDir];
            }
            bool result = vte.spawnSync(VtePtyFlags.DEFAULT, workingDir, args, envv, flags, null, null, gpid, null);
            if (!result) {
                string msg = _("Unexpected error occurred, no additional information available");
                error(msg);
                showInfoBarMessage(msg);
            }
        }
        catch (GException ge) {
            string msg = format(_("Unexpected error occurred: %s"), ge.msg);
            error(msg);
            showInfoBarMessage(msg);
        }
        vte.grabFocus();
    }

    // Code to move terminals through Drag And Drop (DND) is in this private block
    // Keep all DND code here and do not intermix with other blocks
    //
    // This code also handles other DND for text, URI, etc in VTE but the vast bulk deals
    // with terminal DND   
private:

    DragInfo dragInfo = DragInfo(false, DragQuadrant.LEFT);
    static if (USE_PIXBUF_DND) {
        Pixbuf dragImage;
    } else {
        Window dragImage;
    }

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
        dragSourceSet(ModifierType.BUTTON1_MASK, [vteEntry], DragAction.MOVE);
        //vte.dragSourceSet(ModifierType.BUTTON1_MASK, [vteEntry], DragAction.MOVE);

        //Title bar events
        addOnDragBegin(&onTitleDragBegin);
        addOnDragDataGet(&onTitleDragDataGet);
        addOnDragFailed(&onTitleDragFailed, ConnectFlags.AFTER);
        addOnDragEnd(&onTitleDragEnd, ConnectFlags.AFTER);

        //VTE Drop events
        vte.addOnDragDataReceived(&onVTEDragDataReceived);
        vte.addOnDragMotion(&onVTEDragMotion);
        vte.addOnDragLeave(&onVTEDragLeave);
        vte.addOnDraw(&onVTEDraw, ConnectFlags.AFTER);

        trace("Drag and drop completed");
    }

    /**
     * Called to set the selection data, which is later returned in the drag received
     * so it knows which terminal was dropped, in this case the terminal UUID
     */
    void onTitleDragDataGet(DragContext dc, SelectionData data, uint info, uint time, Widget widget) {
        char[] buffer = (terminalUUID ~ '\0').dup;
        data.set(intern(VTE_DND, false), 8, buffer);
    }

    /**
     * Begin the drag operation from the use dragging the title bar, renders the 
     * terminal image into a scaled Pixbuf to use as the drag icon.
     *
     * Cribbed idea from Terminator, my original implementation worked
     * but had an issue in Fedora 23 potentially due to a Cario bug,
     * see Issue #19
     *
     * TODO - Add some transparency
     */
    void onTitleDragBegin(DragContext dc, Widget widget) {
        trace("Title Drag begin");
        static if (USE_PIXBUF_DND) {
            dragImage = getWidgetImage(this, 0.20);
            DragAndDrop.dragSetIconPixbuf(dc, dragImage, 0, 0);
        } else {
            Image image = new Image(getWidgetImage(this, 0.20));
            image.show();
            dragImage = new Window(GtkWindowType.POPUP);
            dragImage.add(image);
            DragAndDrop.dragSetIconWidget(dc, dragImage, 0, 0);
        }
    }

    void onTitleDragEnd(DragContext dc, Widget widget) {
        trace("Title drag end");
        dragImage.destroy();
        dragImage = null;
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
                terminalState = TerminalState.NORMAL;
                updateActions();
            } else {
                error("Failed to get terminal therefore detach request failed");
            }
            return true;
        }
        return false;
    }

    Terminal getDragTerminal(DragContext dc) {
        Terminal terminal = cast(Terminal) DragAndDrop.dragGetSourceWidget(dc);
        if (terminal is null) {
            error("Oops, something went wrong not a terminal drag");
            return null;
        }
        return terminal;
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
        //Don't allow drop on the same terminal or if it is maximized
        if (isSourceAndDestEqual(dc, this) || terminalState == TerminalState.MAXIMIZED) {
            //trace("Invalid drop");
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

        error("Error with drag quandrant calculation, no quandrant calculated");
        return DragQuadrant.LEFT;
    }

    /**
     * Called when the drag operation ends and a drop occurred
     */
    void onVTEDragDataReceived(DragContext dc, int x, int y, SelectionData data, uint info, uint time, Widget widget) {
        trace("Drag data recieved for " ~ to!string(info));
        final switch (info) {
        case DropTargets.URILIST:
            string[] uris = data.getUris();
            if (uris) {
                foreach (uri; uris) {
                    trace("Dropped filename " ~ uri);
                    GFileIF file = GFile.parseName(uri);
                    string filename;
                    if (file !is null) {
                        filename = file.getPath();
                        trace("Converted filename " ~ filename);
                    } else {
                        string hostname;
                        filename = URI.filenameFromUri(uri, hostname);
                    }
                    string quoted = ShellUtils.shellQuote(filename) ~ " ";
                    vte.feedChild(quoted, quoted.length);
                }
            }
            break;
        case DropTargets.STRING, DropTargets.TEXT:
            string text = data.getText();
            if (text.length > 0) {
                vte.feedChild(text, text.length);
            }
            break;
        case DropTargets.VTE:
            //Don't allow drop on the same terminal
            if (isSourceAndDestEqual(dc, this) || terminalState == TerminalState.MAXIMIZED)
                return;
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

        static if (DIM_TERMINAL_NO_FOCUS && POPOVER_CONTEXT_MENU) {
            if (!vte.isFocus() && !rFind.isSearchEntryFocus() && !pmContext.isVisible() && !mbTitle.getPopover().isVisible()) {
                RGBA bg;
                getStyleBackgroundColor(vte.getStyleContext(), StateFlags.SELECTED, bg);
                cr.setSourceRgba(bg.red, bg.green, bg.blue, 0.1);
                cr.rectangle(0, 0, widget.getAllocatedWidth(), widget.getAllocatedHeight());
                cr.fill();
            }
        }
        //Dragging happening?
        if (!dragInfo.isDragActive)
            return false;
        RGBA color;
        getStyleColor(vte.getStyleContext(), StateFlags.ACTIVE, color);
        /*
        if (!vte.getStyleContext().lookupColor("theme_selected_bg_color", bg)) {
            getStyleBackgroundColor(vte.getStyleContext(), StateFlags.SELECTED, bg);
        }
        */
        cr.setSourceRgba(color.red, color.green, color.blue, 0.3);
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

    //Save terminal output functionality
private:
    string outputFilename;

    /**
     * Saves terminal output to a file
     *
     * Params:
     *  showSaveAsDialog = Determines if save as dialog is shown. Note dialog may be shown even if false is passed if the session filename is not set
     */
    void saveTerminalOutput(bool showSaveAsDialog = true) {
        if (outputFilename.length == 0 || showSaveAsDialog) {
            Window window = cast(Window) getToplevel();
            FileChooserDialog fcd = new FileChooserDialog(_("Save Terminal Output"), window, FileChooserAction.SAVE);
            scope (exit)
                fcd.destroy();

            FileFilter ff = new FileFilter();
            ff.addPattern("*.txt");
            ff.setName(_("All Text Files"));
            fcd.addFilter(ff);
            ff = new FileFilter();
            ff.addPattern("*");
            ff.setName(_("All Files"));
            fcd.addFilter(ff);

            fcd.setDoOverwriteConfirmation(true);
            fcd.setDefaultResponse(ResponseType.OK);
            if (outputFilename.length == 0) {
            } else {
                fcd.setCurrentName("output.txt");
            }

            if (fcd.run() == ResponseType.OK) {
                outputFilename = fcd.getFilename();
            } else {
                return;
            }
        }
        //Do work here
        gio.FileIF.FileIF file = gio.File.File.parseName(outputFilename);
        gio.OutputStream.OutputStream stream = file.create(GFileCreateFlags.NONE, null);
        scope (exit) {
            stream.close(null);
        }
        vte.writeContentsSync(stream, VteWriteFlags.DEFAULT, null);
    }

public:

    /**
     * Creates the TerminalPane using the specified profile
     */
    this(string profileUUID) {
        super();
        addOnDestroy(delegate(Widget) { trace("Terminal destroy"); stopProcess(); });
        initColors();
        _terminalUUID = randomUUID().toString();
        _profileUUID = profileUUID;
        // Check if profile is overriden globally
        if (terminix.getGlobalOverrides().profileName.length > 0) {
            string newProfileUUID = prfMgr.getProfileUUIDFromName(terminix.getGlobalOverrides().profileName);
            if (newProfileUUID.length > 0) {
                _profileUUID = newProfileUUID;
                trace("Overriding profile with global: " ~ _profileUUID);
            }
        }
        gsSettings = new GSettings(SETTINGS_ID);
        gsSettings.addOnChanged(delegate(string key, GSettings) { applyPreference(key); });
        gsProfile = prfMgr.getProfileSettings(_profileUUID);
        gsShortcuts = new GSettings(SETTINGS_PROFILE_KEY_BINDINGS_ID);
        gsDesktop = new GSettings(SETTINGS_DESKTOP_ID);
        gsDesktop.addOnChanged(delegate(string key, GSettings) {
            if (key == SETTINGS_MONOSPACE_FONT_KEY) {
                applyPreference(SETTINGS_PROFILE_FONT_KEY);
            }
        });
        createUI();
        trace("Apply preferences");
        applyPreferences();
        trace("Profile Event Handler");
        gsProfile.addOnChanged(delegate(string key, Settings) { applyPreference(key); });
        trace("Finished creation");
    }

    /**
     * initializes the terminal, i.e spawns the child process.
     *
     * Params:
     *  initialPath = The initial working directory for the terminal
     *  firstRun    = Whether this is the first run of the application, used to determine whether to apply profile geometry
     */
    void initTerminal(string initialPath, bool firstRun) {
        trace("Initializing Terminal with directory " ~ initialPath);
        initialWorkingDir = initialPath;
        spawnTerminalProcess(initialPath, overrideCommand);
        if (firstRun) {
            trace("Set VTE Size for rows " ~ to!string(gsProfile.getInt(SETTINGS_PROFILE_SIZE_ROWS_KEY)));
            trace("Set VTE Size for columns " ~ to!string(gsProfile.getInt(SETTINGS_PROFILE_SIZE_COLUMNS_KEY)));
            vte.setSize(gsProfile.getInt(SETTINGS_PROFILE_SIZE_COLUMNS_KEY), gsProfile.getInt(SETTINGS_PROFILE_SIZE_ROWS_KEY));
        }
        trace("Terminal initialized");
        updateTitle();
    }

    /**
     * Maximizes or restores terminal by requesting
     * state change from container.
     */
    void maximize() {
        TerminalState newState = (terminalState == TerminalState.NORMAL) ? TerminalState.MAXIMIZED : TerminalState.NORMAL;
        bool result = true;
        foreach (dlg; terminalRequestStateChangeDelegates) {
            if (!dlg(this, newState)) {
                result = false;
            }
        }
        if (result) {
            terminalState = newState;
            updateActions();
        }
    }

    /**
     * Issues a SIGHUP to pid to get it close. This is used
     * when the terminal is destroyed.
     */
    void stopProcess() {
        if (gpid > 0) {
            try {
                kill(gpid, SIGHUP);
            }
            catch (ProcessException pe) {
                error("Error when stoping terminal child process:\n\t" ~ pe.msg);
            }
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
        if (vte.getPty() is null) return false;
        int fd = vte.getPty().getFd();
        pid_t fg = tcgetpgrp(fd);
        trace(format("fg=%d gpid=%d", fg, gpid));
        return (fg != -1 && fg != gpid);
    }

    /**
     * Called by the session to synchronize input
     */
    void handleSyncInput(SyncInputEvent sie) {
        if (!isSynchronizedInput())
            return;

        final switch (sie.eventType) {
        case SyncInputEventType.KEY_PRESS:
            Event newEvent = sie.event.copy();
            newEvent.key.sendEvent = 1;
            newEvent.key.window = vte.getWindow().getWindowStruct();
            vte.event(newEvent);
            break;
        case SyncInputEventType.PASTE:
            pasteClipboard(true);
            break;
        }
    }

    @property string currentDirectory() {
        if (gpid == 0)
            return null;
        string hostname;
        string cwd = vte.getCurrentDirectoryUri();
        if (cwd.length == 0) {
            return null;
        }
        string result = URI.filenameFromUri(cwd, hostname);
        return result;
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
        if (_synchronizeInput != value) {
            _synchronizeInput = value;
            if (_synchronizeInput)
                tbSyncInput.show();
            else
                tbSyncInput.hide();
        }
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

    @property bool terminalInitialized() {
        return _terminalInitialized;
    }

    @property void terminalInitialized(bool value) {
        if (value != _terminalInitialized) {
            _terminalInitialized = value;
        }
    }

    @property string overrideCommand() {
        return _overrideCommand;
    }

    @property void overrideCommand(string value) {
        _overrideCommand = value;
    }

    @property string overrideTitle() {
        return _overrideTitle;
    }

    @property void overrideTitle(string value) {
        _overrideTitle = value;
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

    void addOnTerminalSyncInput(OnTerminalSyncInput dlg) {
        terminalSyncInputDelegates ~= dlg;
    }

    void removeOnTerminalSyncInput(OnTerminalSyncInput dlg) {
        gx.util.array.remove(terminalSyncInputDelegates, dlg);
    }

    void addOnTerminalRequestStateChange(OnTerminalRequestStateChange dlg) {
        terminalRequestStateChangeDelegates ~= dlg;
    }

    void removeOnTerminalRequestStateChange(OnTerminalRequestStateChange dlg) {
        gx.util.array.remove(terminalRequestStateChangeDelegates, dlg);
    }

}

/**
 * Terminal Exited Info Bar, used when Hold option for exiting terminal is selected
 */
package class TerminalInfoBar : InfoBar {

private:
    enum STATUS_NORMAL = N_("The child process exited normally with status %d");
    enum STATUS_ABORT_STATUS = N_("The child process was aborted by signal %d.");
    enum STATUS_ABORT = N_("The child process was aborted.");

    Label lblPrompt;

public:
    this() {
        super([_("Relaunch")], [ResponseType.OK]);
        setDefaultResponse(ResponseType.OK);
        setMessageType(MessageType.QUESTION);
        lblPrompt = new Label("");
        lblPrompt.setHalign(Align.START);
        getContentArea().packStart(lblPrompt, true, true, 0);
        setHalign(Align.FILL);
        setValign(Align.START);
    }
    
    void setMessage(string message) {
        lblPrompt.setText(message);
    }

    void setStatus(int value) {
        if (WEXITSTATUS(value)) {
            lblPrompt.setText(format(_(STATUS_NORMAL), WEXITSTATUS(value)));
        } else if (WIFSIGNALED(value)) {
            lblPrompt.setText(format(_(STATUS_ABORT_STATUS), WTERMSIG(value)));
        } else {
            lblPrompt.setText(_(STATUS_ABORT));
        }
    }
}

/**
 * This feature has been copied from Pantheon Terminal and
 * translated from Vala to D. Thanks to Pantheon for this.
 *
 * http://bazaar.launchpad.net/~elementary-apps/pantheon-terminal/trunk/view/head:/src/UnsafePasteDialog.vala
 */
package class UnsafePasteDialog : MessageDialog {

public:

    this(Window parent, string cmd) {
        super(parent, DialogFlags.MODAL, MessageType.WARNING, ButtonsType.NONE, null, null);
        setTransientFor(parent);
        getMessageArea().setMarginLeft(0);
        getMessageArea().setMarginRight(0);
        setMarkup("<span weight='bold' size='larger'>" ~ _("This command is asking for Administrative access to your computer") ~ "</span>\n\n" ~ _(
                "Copying commands from the internet can be dangerous. ") ~ "\n" ~ _(
                "Be sure you understand what each part of this command does.") ~ "\n\n" ~ "<tt><b>" ~ SimpleXML.markupEscapeText(cmd, cmd.length) ~ "</b></tt>");
        setImage(new Image("dialog-warning", IconSize.DIALOG));
        Button btnCancel = new Button(_("Don't Paste"));
        Button btnIgnore = new Button(_("Paste Anyway"));
        btnIgnore.getStyleContext().addClass("destructive-action");
        addActionWidget(btnCancel, 1);
        addActionWidget(btnIgnore, 0);
        showAll();
    }
}

//Block for defining various DND structs and constants
private:
/**
 * Constant used to identify terminal drag and drop
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

/**
 * Struct used to track matches in terminal for cases like context menu
 * where we need to preserve state between finding match and performing action
 */
struct TerminalURLMatch {
    TerminalURLFlavor flavor;
    string match;

    void clear() {
        flavor = TerminalURLFlavor.AS_IS;
        match.length = 0;
    }
}

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
    AS_IS,
    DEFAULT_TO_HTTP,
    VOIP_CALL,
    EMAIL,
    NUMBER,
};

struct TerminalRegex {
    string pattern;
    TerminalURLFlavor flavor;
    bool caseless;
}

immutable TerminalRegex[] URL_REGEX_PATTERNS = [
    TerminalRegex(SCHEME ~ "//(?:" ~ USERPASS ~ "\\@)?" ~ HOST ~ PORT ~ URLPATH, TerminalURLFlavor.AS_IS, true),
    TerminalRegex("(?:www|ftp)" ~ HOSTCHARS_CLASS ~ "*\\." ~ HOST ~ PORT ~ URLPATH,
        TerminalURLFlavor.DEFAULT_TO_HTTP, true), TerminalRegex("(?:callto:|h323:|sip:)" ~ USERCHARS_CLASS ~ "[" ~ USERCHARS ~ ".]*(?:" ~ PORT ~ "/[a-z0-9]+)?\\@" ~ HOST,
        TerminalURLFlavor.VOIP_CALL, true), TerminalRegex("(?:mailto:)?" ~ USERCHARS_CLASS ~ "[" ~ USERCHARS ~ ".]*\\@" ~ HOSTCHARS_CLASS ~ "+\\." ~ HOST,
        TerminalURLFlavor.EMAIL, true), TerminalRegex("(?:news:|man:|info:)[-[:alnum:]\\Q^_{|}~!\"#$%&'()*+,./;:=?`\\E]+", TerminalURLFlavor.AS_IS, true)
];

immutable Regex[URL_REGEX_PATTERNS.length] compiledRegex;

static this() {
    import std.exception : assumeUnique;
    import vte.Version : Version;

    uint majorVersion = Version.getMajorVersion();
    uint minorVersion = Version.getMinorVersion();
    trace(format("VTE Version is %d.%d", majorVersion, minorVersion));

    Regex[URL_REGEX_PATTERNS.length] tempRegex;
    foreach (i, regex; URL_REGEX_PATTERNS) {
        GRegexCompileFlags flags = GRegexCompileFlags.OPTIMIZE | regex.caseless ? GRegexCompileFlags.CASELESS : cast(GRegexCompileFlags) 0;
        if (minorVersion >= 44) {
            flags = flags | GRegexCompileFlags.MULTILINE;
        }
        tempRegex[i] = new Regex(regex.pattern, flags, cast(GRegexMatchFlags) 0);
    }
    compiledRegex = assumeUnique(tempRegex);
}
