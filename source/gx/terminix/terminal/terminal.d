/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.terminal.terminal;

import core.sys.posix.fcntl;
import core.sys.posix.stdio;
import core.sys.posix.stdlib;
import core.sys.posix.sys.wait;
import core.sys.posix.unistd;

import std.algorithm;
import std.array;
import std.conv;
import std.concurrency;
import std.csv;
import std.datetime;
import std.exception;
import std.experimental.logger;
import std.format;
import std.json;
import std.math;
import std.process;
import std.regex;
import std.stdio;
import std.string;
import std.traits;
import std.typecons;
import std.uuid;

import cairo.Context;

import gdk.Atom;
import gdk.DragContext;
import gdk.Event;
import gdk.RGBA;
import gdk.Screen;
import gdk.Window: GdkWindow = Window;

import gdkpixbuf.Pixbuf;

import gio.ActionMapIF;
import gio.File : GFile = File;
import gio.FileIF : GFileIF = FileIF;
import gio.Menu : GMenu = Menu;
import gio.MenuItem : GMenuItem = MenuItem;
import gio.Notification : GNotification = Notification;
import gio.Settings : GSettings = Settings;
import gio.SimpleAction;
import gio.SimpleActionGroup;
import gio.ThemedIcon;

import glib.ArrayG;
import glib.GException;
import glib.Regex : GRegex = Regex;
import glib.Timeout;
import glib.ShellUtils;
import glib.SimpleXML;
import glib.Str;
import glib.Util;
import glib.URI;
import glib.Variant : GVariant = Variant;
import glib.VariantBuilder : GVariantBuilder = VariantBuilder;
import glib.VariantType : GVariantType = VariantType;

import gtk.Box;
import gtk.Button;
import gtk.Clipboard;
import gtk.CssProvider;
import gtk.Dialog;
import gtk.DragAndDrop;
import gtk.Entry;
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
import gtk.Spinner;
import gtk.StyleContext;
import gtk.TargetEntry;
import gtk.ToggleButton;
import gtk.Widget;
import gtk.Window;

import pango.PgCairo;
import pango.PgContext;
import pango.PgFontDescription;
import pango.PgLayout;

import vte.Pty;
import vte.Terminal : VTE = Terminal;
import vtec.vtetypes;

import gx.gtk.actions;
import gx.gtk.cairo;
import gx.gtk.clipboard;
import gx.gtk.dialog;
import gx.gtk.resource;
import gx.gtk.util;
import gx.gtk.vte;
import gx.i18n.l10n;
import gx.util.array;

import gx.terminix.application;
import gx.terminix.closedialog;
import gx.terminix.cmdparams;
import gx.terminix.common;
import gx.terminix.constants;
import gx.terminix.encoding;
import gx.terminix.preferences;
import gx.terminix.terminal.actions;
import gx.terminix.terminal.layout;
import gx.terminix.terminal.password;
import gx.terminix.terminal.search;
import gx.terminix.terminal.advpaste;
import gx.terminix.terminal.exvte;

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
enum TerminalWindowState {
    NORMAL,
    MAXIMIZED
}

enum SyncInputEventType {
    INSERT_TERMINAL_NUMBER,
    INSERT_TEXT,
    KEY_PRESS
};

struct SyncInputEvent {
    string senderUUID;
    SyncInputEventType eventType;
    Event event;
    string text;
}

/**
 * Constants used for the various variables permitted when defining
 * the terminal title.
 */
enum TERMINAL_TITLE = "${title}";
enum TERMINAL_ICON_TITLE = "${iconTitle}";
enum TERMINAL_ID = "${id}";
enum TERMINAL_DIR = "${directory}";
enum TERMINAL_COLUMNS = "${columns}";
enum TERMINAL_ROWS = "${rows}";
enum TERMINAL_HOSTNAME = "${hostname}";
enum TERMINAL_USERNAME = "${username}";

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
class Terminal : EventBox, ITerminal {

private:

    // mixin for managing is action allowed event delegates
    mixin IsActionAllowedHandler;

    // mixin for managing process notification event delegates
    mixin ProcessNotificationHandler;

    TerminalWindowState terminalWindowState = TerminalWindowState.NORMAL;
    Button btnMaximize;

    SearchRevealer rFind;

    ExtendedVTE vte;
    Overlay terminalOverlay;
    static if (!USE_SCROLLED_WINDOW) {
        Scrollbar sb;
    }

    GPid gpid = 0;

    Box bTitle;
    MenuButton mbTitle;
    Label lblTitle;
    ToggleButton tbSyncInput;
    Spinner spBell;
    Image imgReadOnly;

    SimpleActionGroup sagTerminalActions;

    SimpleAction saProfileSelect;
    GMenu profileMenu;

    SimpleAction saEncodingSelect;
    GMenu encodingMenu;

    SimpleAction saCopy;
    SimpleAction saPaste;
    SimpleAction saAdvancedPaste;
    Popover pmContext;

    SimpleAction saMaximize;

    GSettings gsProfile;
    GSettings gsShortcuts;
    GSettings gsDesktop;
    GSettings gsSettings;

    //The UUID of the profile which is currently active
    string _activeProfileUUID;
    // The UUID of the default profile, this will always be null unless
    // automatic profile switching has occurred then the UUID of the
    // default profile will be stored here.
    string _defaultProfileUUID;
    //Sequential identifier, used to enable user to select terminal by number. Can change, not constant
    size_t _terminalID;
    //Unique identifier for this terminal, never shown to user, never changes
    immutable string _terminalUUID;
    //overrides profile title
    string _overrideTitle;
    //overrides command when load from session JSON
    string _overrideCommand;
    //overrides badge
    string _overrideBadge;
    //Whether synchronized input is turned on in the session
    bool _synchronizeInput;
    //If synchronized is on, determines if there is a local override turning it off for this terminal only
    bool _synchronizeInputOverride = true;
    //When synchronizing ignore the commit event to prevent recursion
    bool _ignoreCommit = false;
    //Determines if this terminal is the only terminal in the session
    bool _isSingleTerminal = true;

    //Cached badged so it is not calculated on each draw
    string _cachedBadge;

    // Keep track of previous title to avoid triggering too many TerminalTitleChange events
    string lastTitle;

    //Whether to ignore unsafe paste, basically when
    //option is turned on but user opts to ignore it for this terminal
    bool unsafePasteIgnored;

    GlobalTerminalState gst;

    // Track Regex Tag we get back from VTE in order
    // to track which regex generated the match
    TerminalRegex[int] regexTag;

    //Track match detection
    TerminalURLMatch match;

    //Track last time bell was shown
    long bellStart = 0;
    bool deferShowBell;
    Timeout timer;

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
        //Showing is controlled by terminal title preference
        bTitle.setNoShowAll(true);
        bTitle.setVexpand(false);

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
        mbTitle.addOnButtonPress(delegate(Event e, Widget w) {
            buildProfileMenu();
            buildEncodingMenu();
            return false;
        });

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
        tbSyncInput.setActionName(getActionDetailedName(ACTION_PREFIX, ACTION_SYNC_INPUT_OVERRIDE));
        bTitle.packEnd(tbSyncInput, false, false, 0);

        //Read Only Image
        imgReadOnly = new Image("changes-prevent-symbolic", IconSize.MENU);
        imgReadOnly.setNoShowAll(true);
        imgReadOnly.setTooltipText(_("Read-Only"));
        setVerticalMargins(imgReadOnly);
        bTitle.packEnd(imgReadOnly, false, false, 0);

        //Terminal Bell Spinner
        spBell = new Spinner();
        spBell.setNoShowAll(true);
        spBell.setTooltipText(_("Terminal bell"));
        spBell.getStyleContext().addClass("terminix-bell");
        setVerticalMargins(spBell);
        bTitle.packEnd(spBell, false, false, 0);

        EventBox evtTitle = new EventBox();
        evtTitle.add(bTitle);
        //Handle double click for window state change
        evtTitle.addOnButtonPress(delegate(Event event, Widget) {
            int childX, childY;
            mbTitle.translateCoordinates(evtTitle, 0, 0, childX, childY);
            //Ignore clicks propagated from Menu Button, see #215
            if (event.button.x >= childX && event.button.x <= childX + mbTitle.getAllocatedWidth() && event.button.y >= childY
                && event.button.y <= childY + mbTitle.getAllocatedHeight()) {
                return false;
            }
            if (event.getEventType() == EventType.DOUBLE_BUTTON_PRESS && event.button.button == MouseButton.PRIMARY) {
                maximize();
            } else if (event.getEventType() == EventType.BUTTON_PRESS) {
                if (event.button.button == MouseButton.MIDDLE && gsSettings.getBoolean(SETTINGS_MIDDLE_CLICK_CLOSE_KEY)) {
                    SimpleAction close = cast(SimpleAction) sagTerminalActions.lookupAction(ACTION_CLOSE);
                    close.activate(null);
                } else {
                    vte.grabFocus();
                }
            }
            return false;
        });
        return evtTitle;
    }

    //Dynamically build the menus for selecting a profile
    void buildProfileMenu() {
        profileMenu.removeAll();
        SimpleAction aProfileSelect = cast(SimpleAction)sagTerminalActions.lookupAction(ACTION_PROFILE_SELECT);
        if (aProfileSelect !is null) {
            aProfileSelect.setEnabled(_defaultProfileUUID.length == 0);
        }
        saProfileSelect.setState(new GVariant(activeProfileUUID));
        ProfileInfo[] profiles = prfMgr.getProfiles();
        foreach (profile; profiles) {
            GMenuItem menuItem = new GMenuItem(replace(profile.name, "_", "__"), getActionDetailedName(ACTION_PREFIX, ACTION_PROFILE_SELECT));
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
        //Find actions
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_FIND, gsShortcuts, delegate(GVariant, SimpleAction) {
            if (!rFind.getRevealChild()) {
                rFind.setRevealChild(true);
            }
            rFind.focusSearchEntry();
        });
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_FIND_PREVIOUS, gsShortcuts, delegate(GVariant, SimpleAction) {
            bool result = vte.searchFindPrevious();
            if (!result && !vte.searchGetWrapAround) {
                vte.searchFindNext();
            }
        });
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_FIND_NEXT, gsShortcuts, delegate(GVariant, SimpleAction) {
            bool result = vte.searchFindNext();
            if (!result && !vte.searchGetWrapAround) {
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
            // Check to see if something other then terminal has focus
            Window window = cast(Window) getToplevel();
            if (window !is null) {
                Entry entry = cast(Entry) window.getFocus();
                if (entry !is null) {
                    entry.pasteClipboard();
                    return;
                }
            }
            if (Clipboard.get(null).waitIsTextAvailable()) {
                if (gsSettings.getBoolean(SETTINGS_PASTE_ADVANCED_DEFAULT_KEY)) {
                    advancedPaste(GDK_SELECTION_CLIPBOARD);
                } else {
                    paste(GDK_SELECTION_CLIPBOARD);
                }
            }
        });
        saAdvancedPaste = registerActionWithSettings(group, ACTION_PREFIX, ACTION_ADVANCED_PASTE, gsShortcuts, delegate(GVariant, SimpleAction) {
            if (Clipboard.get(null).waitIsTextAvailable()) {
                advancedPaste(GDK_SELECTION_CLIPBOARD);
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
                openURI(match);
            }
        });

        //Zoom actions
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_ZOOM_IN, gsShortcuts, delegate(GVariant, SimpleAction) {
            zoomIn();
        });
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_ZOOM_OUT, gsShortcuts, delegate(GVariant, SimpleAction) {
            zoomOut();
        });
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_ZOOM_NORMAL, gsShortcuts, delegate(GVariant, SimpleAction) {
            zoomNormal();
        });

        //Cycle terminal style
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_TITLE_STYLE, gsShortcuts, delegate(GVariant, SimpleAction) {
            string style = gsSettings.getString(SETTINGS_TERMINAL_TITLE_STYLE_KEY);
            size_t index = SETTINGS_TERMINAL_TITLE_STYLE_VALUES.countUntil(style);
            index++;
            if (index > SETTINGS_TERMINAL_TITLE_STYLE_VALUES.length - 1) {
                index = 0;
            }
            gsSettings.setString(SETTINGS_TERMINAL_TITLE_STYLE_KEY, SETTINGS_TERMINAL_TITLE_STYLE_VALUES[index]);
        });

        //Override terminal title
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_LAYOUT, gsShortcuts, delegate(GVariant, SimpleAction) {
            LayoutDialog dialog = new LayoutDialog(cast(Window) getToplevel());
            scope (exit) {
                dialog.destroy();
            }
            dialog.badge = _overrideBadge.length == 0 ? gsProfile.getString(SETTINGS_PROFILE_BADGE_TEXT_KEY) : _overrideBadge;
            dialog.title = _overrideTitle.length == 0 ? gsProfile.getString(SETTINGS_PROFILE_TITLE_KEY) : _overrideTitle;
            dialog.command = _overrideCommand;
            dialog.showAll();
            if (dialog.run() == ResponseType.OK) {
                _overrideTitle = dialog.title;
                _overrideBadge = dialog.badge;
                _overrideCommand = dialog.command;
                updateDisplayText();
            }
        });

        //Maximize Terminal
        saMaximize = registerActionWithSettings(group, ACTION_PREFIX, ACTION_MAXIMIZE, gsShortcuts, delegate(GVariant, SimpleAction) { maximize(); });

        //Close Terminal Action
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_CLOSE, gsShortcuts, delegate(GVariant, SimpleAction) {
            string name;
            if (isProcessRunning(name)) {
                ProcessInformation pi = ProcessInformation(ProcessInfoSource.TERMINAL, (name.length > 0? name: getDisplayText("")), uuid, []);
                if (!promptCanCloseProcesses(cast(Window)getToplevel(), pi)) return;
            }
            notifyTerminalClose();
        });

        //Read Only
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_READ_ONLY, gsShortcuts, delegate(GVariant state, SimpleAction sa) {
            bool newState = !sa.getState().getBoolean();
            sa.setState(new GVariant(newState));
            vte.setInputEnabled(!newState);
            if (newState) imgReadOnly.show();
            else imgReadOnly.hide();
        }, null, new GVariant(false));


        //Clear Terminal && Reset and Clear Terminal
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_RESET, gsShortcuts, delegate(GVariant, SimpleAction) {
            vte.reset(false, false);
        });
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_RESET_AND_CLEAR, gsShortcuts, delegate(GVariant, SimpleAction) {
            vte.reset(true, true);
        });

        //Sync Input Override
        registerAction(group, ACTION_PREFIX, ACTION_SYNC_INPUT_OVERRIDE, null, delegate(GVariant state, SimpleAction sa) {
            bool newState = !sa.getState().getBoolean();
            sa.setState(new GVariant(newState));
            _synchronizeInputOverride = newState;
            if (_synchronizeInputOverride) {
                tbSyncInput.setTooltipText(_("Disable input synchronization for this terminal"));
            } else {
                tbSyncInput.setTooltipText(_("Enable input synchronization for this terminal"));
            }

        }, null, new GVariant(true));

        //Insert Terminal Number
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_INSERT_NUMBER, gsShortcuts, delegate(GVariant state, SimpleAction sa) {
            string text = to!string(terminalID);
            feedChild(text, true);
            if (isSynchronizedInput()) {
                SyncInputEvent se = SyncInputEvent(_terminalUUID, SyncInputEventType.INSERT_TERMINAL_NUMBER, null, null);
                onSyncInput.emit(this, se);
            }
        }, null, null);

        //Insert Password
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_INSERT_PASSWORD, gsShortcuts, delegate(GVariant state, SimpleAction sa) {
            import gtkc.Loader: Linker;
            import secretc.secret: LIBRARY_SECRET;
            if (Linker.isLoaded(LIBRARY_SECRET)) {
                tracef("Library %s was loaded", LIBRARY_SECRET);
                PasswordManagerDialog pdm = new PasswordManagerDialog(cast(Window)this.getToplevel());
                scope(exit) {pdm.destroy();}
                pdm.showAll();
                if (pdm.run() == ResponseType.APPLY) {
                    string password = pdm.password;
                    vte.feedChild(password, password.length);
                }
            } else {
                showErrorDialog(cast(Window)getToplevel(), format(_("The library %s could not be loaded, password functionality is unavailable."), LIBRARY_SECRET), _("Library Not Loaded"));
            }
        }, null, null);


        //SaveAs
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_SAVE, gsShortcuts, delegate(GVariant state, SimpleAction sa) { saveTerminalOutput(); }, null, null);

        //Edit Profile Preference
        registerActionWithSettings(group, ACTION_PREFIX, ACTION_PROFILE_PREFERENCE, gsShortcuts, delegate(GVariant, SimpleAction) {
            terminix.presentProfilePreferences(prfMgr.getProfile(_activeProfileUUID));
        }, null, null);

        //Select Profile
        GVariant pu = new GVariant(activeProfileUUID);
        saProfileSelect = registerAction(group, ACTION_PREFIX, ACTION_PROFILE_SELECT, null, delegate(GVariant value, SimpleAction sa) {
            size_t l;
            string uuid = value.getString(l);
            activeProfileUUID = uuid;
            saProfileSelect.setState(value);
        }, pu.getType(), pu);

        // Select Encoding
        //
        GVariant encoding = new GVariant(gsProfile.getString(SETTINGS_PROFILE_ENCODING_KEY));
        saEncodingSelect = registerAction(group, ACTION_PREFIX, ACTION_ENCODING_SELECT, null, delegate(GVariant value, SimpleAction sa) {
            size_t l;
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

        createPopoverMenuItems(model);

        Popover pm = new Popover(parent);
        // Force VTE to redraw on showing/hiding of popover if dimUnfocused is active
        pm.addOnMap(delegate(Widget) {
           if (dimPercent > 0) vte.queueDraw();
        });
        pm.addOnUnmap(delegate(Widget) {
           if (dimPercent > 0) vte.queueDraw();
        });
        pm.bindModel(model, null);
        return pm;
    }

    /**
     * Creates the popover menu items
     */
    void createPopoverMenuItems(GMenu model) {
        GMenu menuSection = new GMenu();
        menuSection.append(_("Save Output…"), getActionDetailedName(ACTION_PREFIX, ACTION_SAVE));
        menuSection.append(_("Reset"), getActionDetailedName(ACTION_PREFIX, ACTION_RESET));
        menuSection.append(_("Reset and Clear"), getActionDetailedName(ACTION_PREFIX, ACTION_RESET_AND_CLEAR));
        model.appendSection(null, menuSection);

        menuSection = new GMenu();
        menuSection.appendSubmenu(_("Profiles"), profileMenu);
        menuSection.appendSubmenu(_("Encoding"), encodingMenu);
        model.appendSection(null, menuSection);

        menuSection = new GMenu();
        menuSection.append(_("Find…"), getActionDetailedName(ACTION_PREFIX, ACTION_FIND));
        menuSection.append(_("Layout Options…"), getActionDetailedName(ACTION_PREFIX, ACTION_LAYOUT));
        menuSection.append(_("Read-Only"), getActionDetailedName(ACTION_PREFIX, ACTION_READ_ONLY));
        model.appendSection(null, menuSection);
    }

    /**
     * Creates the horizontal/vertical add buttons
     */
    GMenuItem createAddButtons() {
        GMenuItem addH = new GMenuItem(null, "session.add-right");
        addH.setAttributeValue("verb-icon", new GVariant("terminix-add-horizontal-symbolic"));
        addH.setAttributeValue("label", new GVariant(_("Add Right")));

        GMenuItem addV = new GMenuItem(null, "session.add-down");
        addV.setAttributeValue("verb-icon", new GVariant("terminix-add-vertical-symbolic"));
        addV.setAttributeValue("label", new GVariant(_("Add Down")));

        GMenu addSection = new GMenu();
        addSection.appendItem(addH);
        addSection.appendItem(addV);

        GMenuItem add = new GMenuItem(null, null);
        add.setSection(addSection);
        add.setAttributeValue("display-hint", new GVariant("horizontal-buttons"));

        return add;
    }

    /**
     * Creates the actual VTE terminal inside an Overlay along with some support
     * widgets such as the Find revealer.
     */
    Widget createVTE() {
        vte = new ExtendedVTE();
        // Basic widget properties
        vte.setHexpand(true);
        vte.setVexpand(true);
        //Search Properties
        vte.searchSetWrapAround(gsSettings.getValue(SETTINGS_SEARCH_DEFAULT_WRAP_AROUND).getBoolean());
        //URL Regex Experessions
        foreach (i, regex; compiledRegex) {
            int id = vte.matchAddGregex(cast(GRegex) regex, cast(GRegexMatchFlags) 0);
            regexTag[id] = URL_REGEX_PATTERNS[i];
            vte.matchSetCursorType(id, CursorType.HAND2);
        }

        //Event handlers
        vte.addOnChildExited(&onTerminalChildExited);
        vte.addOnBell(delegate(VTE) {
            // Originally planned on not showing bell when window is not active but too many edge cases
            // like window is active in different monitor, window is visible but not active, just a message
            // to deal with IMHO. Notifications right solution for that
            // Window window = cast(Window)getToplevel();
            if (vte.getMapped()) { //&& (window !is null && window.isVisible() && window.isActive())) {
                showBell();
            } else {
                deferShowBell = true;
            }
        });

        vte.addOnWindowTitleChanged(delegate(VTE terminal) {
            trace("Window title changed");
            gst.updateState();
            updateDisplayText();
        });
        vte.addOnIconTitleChanged(delegate(VTE terminal) {
            updateDisplayText();
        });
        vte.addOnCurrentDirectoryUriChanged(delegate(VTE terminal) {
            string hostname, directory;
            getHostnameAndDirectory(hostname, directory);
            if (hostname != gst.currentHostname || directory != gst.currentDirectory) {
                gst.updateState(hostname, directory);
                updateDisplayText();
                checkAutomaticProfileSwitch();
            }
        });
        vte.addOnCurrentFileUriChanged(delegate(VTE terminal) { trace("Current file is " ~ vte.getCurrentFileUri); });
        vte.addOnFocusIn(&onTerminalWidgetFocusIn);
        vte.addOnFocusOut(&onTerminalWidgetFocusOut);
        vte.addOnNotificationReceived(delegate(string summary, string _body, VTE terminal) {
            if (terminalInitialized && !terminal.hasFocus()) {
                notifyProcessNotification(summary, _body, uuid);
            }
        });
        vte.addOnContentsChanged(delegate(VTE) {
            // VTE configuration problem, Issue #34
            // This emits the CTE configuration warning based on whether the currentLocalDirectory is being set.
            // However this is actually a bit tricky because the currentLocalDirectory only gets set on the first prompt
            // so there are a lot of cases where you don't want to show it.
            //
            // First if overrideCommand is set don't show the warning since no shell is running
            // Also check that the terminal has been initialized
            // Finally check that the VTE cursor position is greater then 0,0, this is a fix for #425. Not sure why
            // but passing command paremeters causes contentschanged signal to fire twice even though there is no change in content.
            if (terminalInitialized && terminix.testVTEConfig() && gst.currentLocalDirectory.length == 0 && _overrideCommand.length == 0) {
                glong cursorCol, cursorRow;
                vte.getCursorPosition(cursorCol, cursorRow);
                //tracef("\trow=%d, column=%d",cursorRow,cursorCol);
                if (cursorRow > 0 || cursorCol >0) {
                    trace("Warning VTE Configuration");
                    terminix.warnVTEConfigIssue();
                }
            }
            vte.addOnScroll(&onTerminalScroll);
            // Update initialized state after initial content change to give prompt_command a chance to kick in
            gst.updateState();
        });

        /*
         * Monitor changes in the VTE to test for triggers
         */
        if (checkVTEFeature(TerminalFeature.EVENT_SCREEN_CHANGED)) {
            vte.addOnContentsChanged(&onVTECheckTriggers, GConnectFlags.AFTER);
            vte.addOnTerminalScreenChanged(&onVTEScreenChanged);
        }

        vte.addOnSizeAllocate(delegate(GdkRectangle*, Widget) {
            updateDisplayText();
        }, GConnectFlags.AFTER);
        vte.addOnEnterNotify(delegate(Event event, Widget) {
            if (gsSettings.getBoolean(SETTINGS_TERMINAL_FOCUS_FOLLOWS_MOUSE_KEY)) {
                vte.grabFocus();
            }
            return false;
        }, GConnectFlags.AFTER);

        vte.addOnButtonPress(&onTerminalButtonPress);
        vte.addOnKeyPress(delegate(Event event, Widget widget) {
            if (isSynchronizedInput() && event.key.sendEvent == 0) {
                // Only synchronize hard code VTE keys otherwise let commit event take care of it
                if (isVTEHandledKeystroke(event.key.keyval, event.key.state)) {
                    tracef("Synchronizing key %d", event.key.keyval);
                    SyncInputEvent se = SyncInputEvent(_terminalUUID, SyncInputEventType.KEY_PRESS, event);
                    onSyncInput.emit(this, se);
                }
            }
            return false;
        });        

        vte.addOnSelectionChanged(delegate(VTE) {
            if (vte.getHasSelection() && gsSettings.getBoolean(SETTINGS_COPY_ON_SELECT_KEY)) {
                vte.copyClipboard();
            }
        });

        vte.addOnCommit(delegate(string text, uint length, VTE) {
            if (!_ignoreCommit && isSynchronizedInput()) {
                //tracef("Sync commit: %s", text);
                SyncInputEvent se = SyncInputEvent(_terminalUUID, SyncInputEventType.INSERT_TEXT, null, text);
                onSyncInput.emit(this, se);
            }
        });

        pmContext = new Popover(vte);
        pmContext.setModal(true);
        pmContext.setPosition(PositionType.BOTTOM);
        // Force VTE to redraw on showing/hiding of popover if dimUnfocused is active
        pmContext.addOnMap(delegate(Widget) {
           if (dimPercent > 0) vte.queueDraw();
        });
        pmContext.addOnUnmap(delegate(Widget) {
           if (dimPercent > 0) vte.queueDraw();
        });
        pmContext.addOnClosed(delegate(Popover) {
            // See #305 for more info on why this is here
            saCopy.setEnabled(true);
            saPaste.setEnabled(true);
        });

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
            sb.getStyleContext().addClass("terminix-terminal-scrollbar");
            terminalBox.add(sb);

            //Draw a transparent background to override Window draw
            //to support transparent terminal scrollbars without
            //impacting other chrome. If no scrollbar CSSProvider is loaded
            //then this drawing does not happen
            terminalBox.addOnDraw(delegate(Scoped!Context cr, Widget w) {
                if (sbProvider !is null) {
                    cr.save();
                    // Paint Transparent
                    cr.setSourceRgba(0, 0, 0, 0);
                    cr.setOperator(cairo_operator_t.SOURCE);

                    // Switched to just painting the scrollbar area, that 1 pixel clip that was required was giving
                    // me the twitches
                    int x, y;
                    sb.translateCoordinates(w, 0, 0, x, y);
                    cr.rectangle(to!double(x), to!double(y), to!double(x + sb.getAllocatedWidth()), to!double(y + sb.getAllocatedHeight()));

                    // Original implementation that painted whole box transparent
                    // Fix problem with VTE not painting top line by clipping one pixel lower
                    // otherwise you get a one pixel transparent line :(
                    //cr.rectangle(0.0, 1.0, to!double(w.getAllocatedWidth()), to!double(w.getAllocatedHeight()));

                    cr.clip();
                    cr.paint();
                    cr.restore();
                }
                return false;
            });
        }

        //Disable background draw if available
        if (checkVTEFeature(TerminalFeature.DISABLE_BACKGROUND_DRAW)) {
            vte.setDisableBGDraw(true);
        }

        Box box = new Box(Orientation.VERTICAL, 0);
        rFind = new SearchRevealer(vte, sagTerminalActions);
        rFind.onSearchEntryFocusIn.connect(&terminalWidgetFocusIn);
        rFind.onSearchEntryFocusOut.connect(&terminalWidgetFocusOut);

        box.add(rFind);
        box.add(terminalBox);
        return box;
    }

    bool isSynchronizedInput() {
        return _synchronizeInput && _synchronizeInputOverride;
    }

    void showBell() {
        string value = gsProfile.getString(SETTINGS_PROFILE_TERMINAL_BELL_KEY);
        if (value == SETTINGS_PROFILE_TERMINAL_BELL_ICON_VALUE || value == SETTINGS_PROFILE_TERMINAL_BELL_ICON_SOUND_VALUE) {
            if (!spBell.getVisible()) {
                spBell.show();
                spBell.start();
                if (timer !is null) {
                    timer.stop();
                }
                timer = new Timeout(5000, delegate() {
                    tracef("Current Time=%d, bellstart=%d, expired=%d", Clock.currStdTime(), bellStart, (bellStart + 5 * 1000 * 1000));
                    if (Clock.currStdTime() >= bellStart + (5 * 1000 * 1000)) {
                        trace("Timer expired, hiding Bell");
                        spBell.stop();
                        spBell.hide();
                        return false;
                    }
                    return true;
                });
            }
            bellStart = Clock.currStdTime();
        }
    }

    /**
     * Check automatic profile switch and make switch if necessary
     */
    void checkAutomaticProfileSwitch() {
        string UUID = prfMgr.findProfileForState(gst.currentUsername, gst.currentHostname, gst.currentDirectory);
        if (UUID.length > 0) {
            // If defaultProfileUUID is not alredy set, update it with last profile
            if (_defaultProfileUUID.length == 0) {
                _defaultProfileUUID = _activeProfileUUID;
                activeProfileUUID = UUID;
            }
        } else {
            // Switch back to default profile?
            if (_defaultProfileUUID.length > 0) {
                activeProfileUUID = _defaultProfileUUID;
                _defaultProfileUUID.length = 0;
            }
        }
    }

    /**
     * Updates things that depend on the calculated text
     */
    void updateDisplayText() {
        updateTitle();
        updateBadge();
    }

    /**
     * Updates the cached badge text
     */
    void updateBadge() {
        string badge = _overrideBadge.length == 0 ? gsProfile.getString(SETTINGS_PROFILE_BADGE_TEXT_KEY) : _overrideBadge;
        badge = getDisplayText(badge);
        if (badge != _cachedBadge) {
            _cachedBadge = badge;
            vte.queueDraw();
        } 
    }

    /**
     * Updates the terminal title in response to UI changes
     */
    void updateTitle() {
        string title = _overrideTitle.length == 0 ? gsProfile.getString(SETTINGS_PROFILE_TITLE_KEY) : _overrideTitle;
        title = getDisplayText(title);
        if (title != lastTitle) {
            lblTitle.setMarkup(title);
            lastTitle = title;
            onTitleChange.emit(this);
        }
    }

    void updateTitleBar() {
        bool show = gsSettings.getString(SETTINGS_TERMINAL_TITLE_STYLE_KEY) != SETTINGS_TERMINAL_TITLE_STYLE_VALUE_NONE;
        if (_isSingleTerminal && !gsSettings.getBoolean(SETTINGS_TERMINAL_TITLE_SHOW_WHEN_SINGLE_KEY)) {
            show = false;
        }
        if (show) {
            trace("Showing titlebar");
            bTitle.setNoShowAll(false);
            bTitle.showAll();
        } else {
            trace("Hiding titlebar");
            bTitle.setNoShowAll(true);
            bTitle.hide();
        }
        saMaximize.setEnabled(!_isSingleTerminal);
    }

    /**
     * Enables/Disables actions depending on UI state
     */
    void updateActions() {
        //Update maximize button image
        string icon;
        if (terminalWindowState == TerminalWindowState.MAXIMIZED) {
            icon = "window-restore-symbolic";
            btnMaximize.setTooltipText(_("Restore"));
        } else {
            icon = "window-maximize-symbolic";
            btnMaximize.setTooltipText(_("Maximize"));
        }
        btnMaximize.setImage(new Image(icon, IconSize.BUTTON));
    }

    /**
     * Tests if the paste is unsafe, currently just looks for sudo
     */
    bool isPasteUnsafe(string text) {
        return (text.indexOf("sudo") > -1) && (text.indexOf("\n") != 0);
    }

    void advancedPaste(GdkAtom source) {
        string pasteText = Clipboard.get(source).waitForText();
        if (pasteText.length == 0) return;

        AdvancedPasteDialog dialog = new AdvancedPasteDialog(cast(Window) getToplevel(), pasteText, isPasteUnsafe(pasteText));
        scope(exit) {
            dialog.hide();
            dialog.destroy();
        }
        dialog.showAll();
        if (dialog.run() == ResponseType.APPLY) {
            pasteText = dialog.text;
            vte.feedChild(pasteText[0 .. $], pasteText.length);
        }
        focusTerminal();
    }

    void paste(GdkAtom source) {

        string pasteText = Clipboard.get(source).waitForText();
        if (pasteText.length == 0) return;

        // Don't check for unsafe paste if doing sync input, original paste checked it
        if (isPasteUnsafe(pasteText)) {
            if (!unsafePasteIgnored && gsSettings.getBoolean(SETTINGS_UNSAFE_PASTE_ALERT_KEY)) {
                UnsafePasteDialog dialog = new UnsafePasteDialog(cast(Window) getToplevel(), chomp(pasteText));
                scope (exit) {
                    dialog.destroy();
                }
                if (dialog.run() == 0)
                    unsafePasteIgnored = true;
                else
                    return;
            }
        }
        if (gsSettings.getBoolean(SETTINGS_STRIP_FIRST_COMMENT_CHAR_ON_PASTE_KEY)) {
            if (pasteText.length > 0 && (pasteText[0] == '#' || pasteText[0] == '$')) {
                vte.feedChild(pasteText[1 .. $], pasteText.length - 1);
                return;
            }
        }
        
        if (source == GDK_SELECTION_CLIPBOARD) vte.pasteClipboard();
        else vte.pastePrimary();
    }

    void notifyTerminalRequestMove(string srcUUID, Terminal dest, DragQuadrant dq) {
        onRequestMove.emit(srcUUID, dest, dq);
    }

    void notifyTerminalRequestDetach(Terminal terminal, int x, int y) {
        onRequestDetach.emit(terminal, x, y);
    }

    void notifyTerminalClose() {
        onClose.emit(this);
    }

// Block for processing triggers
private:

    // List of triggers to test for
    TerminalTrigger[] triggers;
    glong triggerLastRowChecked = -1;
    glong triggerLastColChecked = -1;

    TerminalScreen currentScreen = TerminalScreen.NORMAL;

    void onVTEScreenChanged(TerminalScreen screen, VTE) {
        currentScreen = screen;
    }

    /**
     * This method responds to VTE content changes and checks if a trigger has been activated.
     * It would be nice to detect user typing and not run triggers when text changed but
     * not sure if an ideal way to accomplish that without being leading to false detections.
     */
    void onVTECheckTriggers(VTE) {
        //Only process triggers for normal screen
        if (currentScreen != TerminalScreen.NORMAL) return;

        //Only process if we have triggers to match
        if (triggers.length == 0) return;

        glong cursorRow, cursorCol;
        vte.getCursorPosition(cursorCol, cursorRow);
        //tracef("triggerLastRowChecked=%d, cursorRow=%d", triggerLastRowChecked, cursorRow);

        //Check that position has moved to warrant check
        if (cursorRow > triggerLastRowChecked || (cursorRow == triggerLastRowChecked && cursorCol > triggerLastColChecked)) {
            auto maxLines = gsProfile.getInt(SETTINGS_PROFILE_TRIGGERS_LINES_KEY);
            auto startRow = triggerLastRowChecked;
            auto startCol = triggerLastColChecked;
            // Enforce maximum lines to check
            if (!gsProfile.getBoolean(SETTINGS_PROFILE_TRIGGERS_UNLIMITED_LINES_KEY) && (cursorRow - startRow) > maxLines) {
                startRow = cast(glong) cursorRow - maxLines;
                // If we clip lines set column to 0
                startCol = 0;
            }
            //tracef("Testing trigger: (%d, %d) to (%d, %d)", startRow, startCol, cursorRow, cursorCol);
            ArrayG attr = new ArrayG(false, false, 16);
            //tracef("Checking from %d,%d to %d,%d",startRow, startCol, cursorRow, cursorCol);
            string text = vte.getTextRange(startRow, startCol, cursorRow, cursorCol, null, null, attr);
            // Update position early in case we get re-entrant event
            triggerLastRowChecked = cursorRow;
            triggerLastColChecked = cursorCol;
            // Store matches so we can sort them by position in process in order of appearance
            TerminalTriggerMatch[] triggerMatches;
            foreach(trigger; triggers) {
                auto matches = matchAll(text, trigger.compiledRegex);
                //tracef("Matching trigger '%s' against text '%s'", trigger.pattern, text);play
                foreach (m; matches) {
                    string[] groups = [m.hit];
                    foreach (group; m.captures) {
                        groups ~= group;
                    }
                    triggerMatches ~= TerminalTriggerMatch(trigger, groups, m.pre.length);
                }
            }
            //tracef("Found %d trigger matches", triggerMatches.length);
            bool myComp(TerminalTriggerMatch a, TerminalTriggerMatch b) { return a.index < b.index; }
            foreach(triggerMatch; triggerMatches.sort!(myComp)) {
                processTrigger(triggerMatch.trigger, triggerMatch.groups);
            }
        }
    }

    /**
     * Based on the action processes the appropriate trigger. Groups
     * contains a list of regex macthing groups with the first one
     * being the complete match, similar idea to args in command line
     */
    void processTrigger(TerminalTrigger trigger, string[] groups) {

        string[string] getParameters(string triggerParameters) {
            string[string] result;
            foreach (parameter; split(replaceMatchTokens(triggerParameters, groups), ";")) {
                string[] pair = split(parameter, "=");
                if (pair.length == 2) {
                    result[pair[0].strip()] = pair[1].strip();
                }
            }
            return result;
        }

        final switch (trigger.action) {
            case TriggerAction.UPDATE_STATE:
                string[string] parameters = getParameters(trigger.parameters);
                bool update = false;
                foreach (variable; EnumMembers!(GlobalTerminalState.StateVariable)) {
                    if (variable in parameters) {
                        gst.updateState(variable, parameters[variable]);
                        //tracef("Updating state %s=%s", variable, parameters[variable]);
                        update = true;
                    }
                }
                if (update) {
                    updateDisplayText();
                    checkAutomaticProfileSwitch();
                }
                break;
            case TriggerAction.EXECUTE_COMMAND:
                spawnShell(replaceMatchTokens(trigger.parameters, groups));
                break;
            case TriggerAction.SEND_NOTIFICATION:
                string[string] parameters = getParameters(trigger.parameters);
                tracef("Parameters count: %d", parameters.length);
                string title = "Terminix Custom Notification";
                string summary;
                if ("title" in parameters) title = parameters["title"];
                if ("body" in parameters) summary = parameters["body"];
                else summary = replaceMatchTokens(trigger.parameters, groups);
                GNotification n = new GNotification(title);
                n.setBody(summary);
                n.setDefaultAction("app.activate-terminal::" ~ _terminalUUID);
                terminix.sendNotification(null, n);
                break;
            case TriggerAction.UPDATE_BADGE:
                _overrideBadge = replaceMatchTokens(trigger.parameters, groups);
                updateBadge();
                break;
            case TriggerAction.UPDATE_TITLE:
                _overrideTitle = replaceMatchTokens(trigger.parameters, groups);
                updateTitle();
                break;
            case TriggerAction.PLAY_BELL:
                if (vte.getWindow() !is null) {
                    vte.getWindow().beep();
                }
                break;
            case TriggerAction.SEND_TEXT:
                string value = replaceMatchTokens(trigger.parameters, groups);
                vte.feedChild(value, value.length);
                break;
            case TriggerAction.INSERT_PASSWORD:
                trace("Processing insert password trigger");
                SimpleAction sa = cast(SimpleAction)sagTerminalActions.lookupAction(ACTION_INSERT_PASSWORD);
                if (sa !is null) {
                    sa.activate(null);
                }
                break;
        }
    }

private:    

    bool onTerminalScroll(Event event, Widget widget) {
        if (gsSettings.getBoolean(SETTINGS_CONTROL_SCROLL_ZOOM_KEY) && (event.scroll.state & ModifierType.CONTROL_MASK) && !(event.scroll.state & ModifierType.SHIFT_MASK) && !(event.scroll.state & ModifierType.MOD1_MASK)) {
            ScrollDirection zoomDirection = event.scroll.direction;
            if (zoomDirection == ScrollDirection.SMOOTH) {
                zoomDirection = (event.scroll.deltaY <= 0)?ScrollDirection.UP: ScrollDirection.DOWN;
            } 
            if (zoomDirection == ScrollDirection.UP) {
                zoomIn();    
            } else if (zoomDirection == ScrollDirection.DOWN) {
                zoomOut();
            }
            return true;
        }
        return false;
    }

    /**
     * Triggered when the terminal signals the child process has exited
     */
    void onTerminalChildExited(int status, VTE terminal) {
        gpid = -1;
        trace("Exit code received is " ~ to!string(status));
        if (vte is null) return;

        switch (gsProfile.getString(SETTINGS_PROFILE_EXIT_ACTION_KEY)) {
        case SETTINGS_PROFILE_EXIT_ACTION_RESTART_VALUE:
            spawnTerminalProcess(gst.initialCWD);
            return;
        case SETTINGS_PROFILE_EXIT_ACTION_CLOSE_VALUE:
            notifyTerminalClose();
            return;
        case SETTINGS_PROFILE_EXIT_ACTION_HOLD_VALUE:
            TerminalInfoBar ibRelaunch = new TerminalInfoBar();
            ibRelaunch.addOnResponse(delegate(int response, InfoBar ib) {
                if (response == ResponseType.OK) {
                    ibRelaunch.destroy();
                    spawnTerminalProcess(gst.initialCWD);
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
        GMenu mmContext = new GMenu();

        if (match.match) {
            GMenu linkSection = new GMenu();
            linkSection.append(_("Open Link"), getActionDetailedName(ACTION_PREFIX, ACTION_OPEN_LINK));
            linkSection.append(_("Copy Link Address"), getActionDetailedName(ACTION_PREFIX, ACTION_COPY_LINK));
            mmContext.appendSection(null, linkSection);
        }

        //Add split buttons
        GMenuItem buttons = createAddButtons();
        mmContext.appendItem(buttons);

        GMenu clipSection = new GMenu();
        if (!CLIPBOARD_BTN_IN_CONTEXT) {
            clipSection.append(_("Copy"), getActionDetailedName(ACTION_PREFIX, ACTION_COPY));
            clipSection.append(_("Paste"), getActionDetailedName(ACTION_PREFIX, ACTION_PASTE));
            clipSection.append(_("Select All"), getActionDetailedName(ACTION_PREFIX, ACTION_SELECT_ALL));
            mmContext.appendSection(null, clipSection);
        } else {
            GMenuItem copy = new GMenuItem(null, getActionDetailedName(ACTION_PREFIX, ACTION_COPY));
            copy.setAttributeValue("verb-icon", new GVariant("edit-copy-symbolic"));
            copy.setAttributeValue("label", new GVariant(_("Copy")));
            clipSection.appendItem(copy);

            GMenuItem paste = new GMenuItem(null, getActionDetailedName(ACTION_PREFIX, ACTION_PASTE));
            paste.setAttributeValue("verb-icon", new GVariant("edit-paste-symbolic"));
            paste.setAttributeValue("label", new GVariant(_("Paste")));
            clipSection.appendItem(paste);

            GMenuItem selectAll = new GMenuItem(null, getActionDetailedName(ACTION_PREFIX, ACTION_SELECT_ALL));
            selectAll.setAttributeValue("verb-icon", new GVariant("edit-select-all-symbolic"));
            selectAll.setAttributeValue("label", new GVariant(_("Select All")));
            clipSection.appendItem(selectAll);

            GMenuItem clipItem = new GMenuItem(_("Clipboard"), null);
            clipItem.setSection(clipSection);
            clipItem.setAttributeValue("display-hint", new GVariant("horizontal-buttons"));

            mmContext.appendItem(clipItem);
        }
        //Check if titlebar is hidden and add extra items
        if (!bTitle.isVisible()) {
            GMenu windowSection = new GMenu();
            windowSection.append(terminalWindowState == TerminalWindowState.MAXIMIZED ? _("Restore") : _("Maximize"), getActionDetailedName(ACTION_PREFIX, ACTION_MAXIMIZE));
            windowSection.append(_("Close"), getActionDetailedName(ACTION_PREFIX, ACTION_CLOSE));
            mmContext.appendSection(null, windowSection);
            if (_synchronizeInput) {
                GMenu syncInputSection = new GMenu();
                syncInputSection.append(_("Synchronize input"), getActionDetailedName(ACTION_PREFIX, ACTION_SYNC_INPUT_OVERRIDE));
                mmContext.appendSection(null, syncInputSection);
            }

            buildProfileMenu();
            buildEncodingMenu();
            createPopoverMenuItems(mmContext);
        }

        pmContext.bindModel(mmContext, null);
    }

    /**
     * Signal received when mouse button is pressed in terminal
     */
    bool onTerminalButtonPress(Event event, Widget widget) {

        // Find the matching regex that was clicked
        void updateMatch(Event event) {
            match.clear;
            int tag;
            match.match = vte.matchCheckEvent(event, tag);
            if (match.match) {
                tracef("Match checked: %s for tag %d", match.match, tag);
                if (tag in regexTag) {
                    TerminalRegex regex = regexTag[tag];
                    match.flavor = regex.flavor;
                    match.tag = tag;
                    trace("Found matching regex");
                }
            }
        }

        if (event.type == EventType.BUTTON_PRESS) {
            updateMatch(event);
            switch (event.button.button) {
            case MouseButton.PRIMARY:
                if ((event.button.state & GdkModifierType.CONTROL_MASK) && match.match) {
                    trace("Opening match");
                    openURI(match);
                    return true;
                } else {
                    return false;
                }
            case MouseButton.SECONDARY:
                trace("Enabling actions");
                if (!(event.button.state & (GdkModifierType.SHIFT_MASK | GdkModifierType.CONTROL_MASK | GdkModifierType.MOD1_MASK)) && vte.onButtonPressEvent(event.button))
                    return true;

                widget.grabFocus();
                buildContextMenu();
                saCopy.setEnabled(vte.getHasSelection());
                saPaste.setEnabled(Clipboard.get(null).waitIsTextAvailable());
                GdkRectangle rect = GdkRectangle(to!int(event.button.x), to!int(event.button.y), 1, 1);
                pmContext.setPointingTo(&rect);
                pmContext.showAll();
                return true;
            case MouseButton.MIDDLE:
                widget.grabFocus();
                paste(GDK_SELECTION_PRIMARY);
                return true;
            default:
                return false;
            }
        }
        return false;
    }

    void openURI(TerminalURLMatch urlMatch) {
        trace("Match clicked");
        string uri = urlMatch.match;
        switch (urlMatch.flavor) {
        case TerminalURLFlavor.DEFAULT_TO_HTTP:
            uri = "http://" ~ uri;
            break;
        case TerminalURLFlavor.EMAIL:
            if (!uri.startsWith("mailto:")) {
                uri = "mailto:" ~ uri;
            }
            break;
        case TerminalURLFlavor.CUSTOM:
            // TODO - Optimize this by caching compiled regex
            // Also I'm mixing GRegex which is used to detect initial click
            // with D's regex library to parse out groups, might cause some
            // incompatibilities but we'll see

            if (urlMatch.tag in regexTag) {
                TerminalRegex tr = regexTag[urlMatch.tag];
                auto regexMatch = matchAll(urlMatch.match, regex(tr.pattern, tr.caseless?"i":""));
                string[] groups = [urlMatch.match];
                foreach(group; regexMatch.captures) {
                    groups ~= group;
                }
                trace("Command: " ~ tr.command);
                string command = replaceMatchTokens(tr.command, groups);
                trace("Command: " ~ command);
                string[string] env;
                spawnShell(command, env, Config.none, currentLocalDirectory);
            }
            return;
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
        terminalWidgetFocusIn(widget);
        return false;
    }

    void terminalWidgetFocusIn(Widget widget) {
        trace("Terminal gained focus " ~ uuid);
        lblTitle.setSensitive(true);
        //Fire focus events so session can track which terminal last had focus
        onFocusIn.emit(this);
        if (dimPercent > 0) {
            vte.queueDraw();
        }
    }

    /**
     * Tracks focus of widgets (vte and rFind) in this terminal pane
     */
    bool onTerminalWidgetFocusOut(Event event, Widget widget) {
        terminalWidgetFocusOut(widget);        
        return false;
    }

    void terminalWidgetFocusOut(Widget widget) {
        trace("Terminal lost focus" ~ uuid);
        lblTitle.setSensitive(isTerminalWidgetFocused());
        if (dimPercent > 0) {
            vte.queueDraw();
        }
    }

    // Preferences go here
private:
    RGBA vteFG;
    RGBA vteBG;
    RGBA vteHighlightFG;
    RGBA vteHighlightBG;
    RGBA vteCursorFG;
    RGBA vteCursorBG;
    RGBA vteDimBG;
    RGBA[16] vtePalette;
    RGBA vteBadge;
    double dimPercent;

    /**
     * CSSProvider to enhance terminal scrollbar
     */
    CssProvider sbProvider;

    void initColors() {
        vteFG = new RGBA();
        vteBG = new RGBA();
        vteHighlightFG = new RGBA();
        vteHighlightBG = new RGBA();
        vteCursorFG = new RGBA();
        vteCursorBG = new RGBA();
        vteDimBG = new RGBA();
        vteBadge = new RGBA();

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
        case SETTINGS_PROFILE_TERMINAL_BELL_KEY:
            string value = gsProfile.getString(SETTINGS_PROFILE_TERMINAL_BELL_KEY);
            vte.setAudibleBell(value == SETTINGS_PROFILE_TERMINAL_BELL_SOUND_VALUE || value == SETTINGS_PROFILE_TERMINAL_BELL_ICON_SOUND_VALUE);
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

            // Enhance scrollbar for supported themes, requires a theme specific css file in
            // terminix resources
            static if (!USE_SCROLLED_WINDOW) {
                if (sbProvider !is null) {
                    sb.getStyleContext().removeProvider(sbProvider);
                    sbProvider = null;
                }
                string theme = getGtkTheme();
                string[string] variables;
                variables["$TERMINAL_BG"] = rgbaTo8bitHex(vteBG,false,true);
                variables["$TERMINAL_OPACITY"] = to!string(vteBG.alpha);
                sbProvider = createCssProvider(APPLICATION_RESOURCE_ROOT ~ "/css/terminix." ~ theme ~ ".scrollbar.css", variables);
                if (sbProvider !is null) {
                    sb.getStyleContext().addProvider(sbProvider, ProviderPriority.APPLICATION);
                }
            }
            break;
        case SETTINGS_PROFILE_USE_HIGHLIGHT_COLOR_KEY, SETTINGS_PROFILE_HIGHLIGHT_FG_COLOR_KEY, SETTINGS_PROFILE_HIGHLIGHT_BG_COLOR_KEY:
            if (!gsProfile.getBoolean(SETTINGS_PROFILE_USE_THEME_COLORS_KEY) && gsProfile.getBoolean(SETTINGS_PROFILE_USE_HIGHLIGHT_COLOR_KEY)) {
                vteHighlightFG.parse(gsProfile.getString(SETTINGS_PROFILE_HIGHLIGHT_FG_COLOR_KEY));
                vteHighlightBG.parse(gsProfile.getString(SETTINGS_PROFILE_HIGHLIGHT_BG_COLOR_KEY));
                vte.setColorHighlightForeground(vteHighlightFG);
                vte.setColorHighlight(vteHighlightBG);
            } else {
                vte.setColorHighlightForeground(null);
                vte.setColorHighlight(null);applyPreference(SETTINGS_PROFILE_CURSOR_SHAPE_KEY);
            }
            break;
        case SETTINGS_PROFILE_USE_CURSOR_COLOR_KEY, SETTINGS_PROFILE_CURSOR_FG_COLOR_KEY, SETTINGS_PROFILE_CURSOR_BG_COLOR_KEY:
            if (!gsProfile.getBoolean(SETTINGS_PROFILE_USE_THEME_COLORS_KEY) && gsProfile.getBoolean(SETTINGS_PROFILE_USE_CURSOR_COLOR_KEY)) {
                vteCursorFG.parse(gsProfile.getString(SETTINGS_PROFILE_CURSOR_FG_COLOR_KEY));
                vteCursorBG.parse(gsProfile.getString(SETTINGS_PROFILE_CURSOR_BG_COLOR_KEY));
                if (checkVTEVersionNumber(0, 44)) {
                    vte.setColorCursorForeground(vteCursorFG);
                }
                vte.setColorCursor(vteCursorBG);
            } else {
                if (checkVTEVersionNumber(0, 44)) {
                    vte.setColorCursorForeground(null);
                }
                vte.setColorCursor(null);
            }
            break;
        case SETTINGS_PROFILE_USE_DIM_COLOR_KEY, SETTINGS_PROFILE_DIM_COLOR_KEY, SETTINGS_PROFILE_DIM_TRANSPARENCY_KEY:
            if (!gsProfile.getBoolean(SETTINGS_PROFILE_USE_THEME_COLORS_KEY) && gsProfile.getBoolean(SETTINGS_PROFILE_USE_DIM_COLOR_KEY)) {
                vteDimBG.parse(gsProfile.getString(SETTINGS_PROFILE_DIM_COLOR_KEY));
            } else {
                getStyleBackgroundColor(vte.getStyleContext(), StateFlags.INSENSITIVE, vteDimBG);
            }
            dimPercent = to!double(gsProfile.getInt(SETTINGS_PROFILE_DIM_TRANSPARENCY_KEY)) / 100.0;
            vte.queueDraw();
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
            auto scrollLines = gsProfile.getBoolean(SETTINGS_PROFILE_UNLIMITED_SCROLL_KEY) ? -1 : gsProfile.getInt(SETTINGS_PROFILE_SCROLLBACK_LINES_KEY);
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
            updateDisplayText();
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
        case SETTINGS_TERMINAL_TITLE_STYLE_KEY:
            string value = gsSettings.getString(SETTINGS_TERMINAL_TITLE_STYLE_KEY);
            if (value == SETTINGS_TERMINAL_TITLE_STYLE_VALUE_SMALL) {
                bTitle.getStyleContext().addClass("compact");
            } else {
                bTitle.getStyleContext().removeClass("compact");
            }
            updateTitleBar();
            break;
        case SETTINGS_TERMINAL_TITLE_SHOW_WHEN_SINGLE_KEY:
            updateTitleBar();
            break;
        case SETTINGS_PROFILE_CUSTOM_HYPERLINK_KEY:
            loadCustomRegex();
            break;
        case SETTINGS_PROFILE_TRIGGERS_KEY:
            loadTriggers();
            break;
        case SETTINGS_PROFILE_BADGE_TEXT_KEY:
            if (checkVTEFeature(TerminalFeature.DISABLE_BACKGROUND_DRAW)) {
                updateBadge();
            }
            break;
        case SETTINGS_PROFILE_BADGE_COLOR_KEY, SETTINGS_PROFILE_USE_BADGE_COLOR_KEY:
            if (checkVTEFeature(TerminalFeature.DISABLE_BACKGROUND_DRAW)) {
                string badgeColor;
                if (!gsProfile.getBoolean(SETTINGS_PROFILE_USE_THEME_COLORS_KEY) && gsProfile.getBoolean(SETTINGS_PROFILE_USE_BADGE_COLOR_KEY)) {
                    badgeColor = gsProfile.getString(SETTINGS_PROFILE_BADGE_COLOR_KEY);
                } else {
                    badgeColor = gsProfile.getString(SETTINGS_PROFILE_FG_COLOR_KEY);
                }
                if (!vteBadge.parse(badgeColor)) tracef("Failed to parse badge color %s", badgeColor);
                queueDraw();
            }
            break;
        case SETTINGS_PROFILE_BADGE_POSITION_KEY:
            queueDraw();
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
            SETTINGS_PROFILE_TERMINAL_BELL_KEY, SETTINGS_PROFILE_ALLOW_BOLD_KEY,
            SETTINGS_PROFILE_REWRAP_KEY,
            SETTINGS_PROFILE_CURSOR_SHAPE_KEY, // Only pass one color key, all colors will be applied
            SETTINGS_PROFILE_FG_COLOR_KEY, SETTINGS_PROFILE_SHOW_SCROLLBAR_KEY, SETTINGS_PROFILE_SCROLL_ON_OUTPUT_KEY,
            SETTINGS_PROFILE_SCROLL_ON_INPUT_KEY,
            SETTINGS_PROFILE_UNLIMITED_SCROLL_KEY,
            SETTINGS_PROFILE_BACKSPACE_BINDING_KEY,
            SETTINGS_PROFILE_DELETE_BINDING_KEY,
            SETTINGS_PROFILE_CJK_WIDTH_KEY, SETTINGS_PROFILE_ENCODING_KEY, SETTINGS_PROFILE_CURSOR_BLINK_MODE_KEY, //Only pass the one font key, will handle both cases
            SETTINGS_PROFILE_FONT_KEY,
            SETTINGS_TERMINAL_TITLE_STYLE_KEY, SETTINGS_AUTO_HIDE_MOUSE_KEY,
            SETTINGS_PROFILE_USE_DIM_COLOR_KEY,
            SETTINGS_PROFILE_USE_CURSOR_COLOR_KEY,
            SETTINGS_PROFILE_USE_HIGHLIGHT_COLOR_KEY,
            SETTINGS_PROFILE_CUSTOM_HYPERLINK_KEY,
            SETTINGS_PROFILE_TRIGGERS_KEY,
            SETTINGS_PROFILE_BADGE_TEXT_KEY,
            SETTINGS_PROFILE_BADGE_COLOR_KEY,
            SETTINGS_PROFILE_BADGE_POSITION_KEY
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

    void loadTriggers() {
        TerminalTrigger[] tmpTriggers;
        string[] trgDefs = gsProfile.getStrv(SETTINGS_PROFILE_TRIGGERS_KEY);
        foreach (trgDef; trgDefs) {
            foreach(value; csvReader!(Tuple!(string, string, string))(trgDef)) {
                TerminalTrigger trigger = new TerminalTrigger(value[0], value[1], value[2]);
                tmpTriggers ~= trigger;
            }
        }
        triggers = tmpTriggers;
    }

    /**
     * Loads the custom regex defined by the user for custom hyperlinks
     */
    void loadCustomRegex() {
        //Remove all of the custom regex
        foreach (entry; regexTag.byKeyValue()) {
            if (entry.value.flavor == TerminalURLFlavor.CUSTOM) {
                vte.matchRemove(entry.key);
                regexTag.remove(entry.key);
            }
        }

        //Re-load custom regex
        string[] links = gsProfile.getStrv(SETTINGS_PROFILE_CUSTOM_HYPERLINK_KEY);
        foreach(link; links) {
            foreach(value; csvReader!(Tuple!(string, string, string))(link)) {
                bool caseInsensitive = false;
                try {
                    caseInsensitive = to!bool(value[2]);
                } catch (Exception e) {
                    trace("Bool CaseInsensitive invalid string, ignoring");
                }
                TerminalRegex regex = TerminalRegex(value[0], TerminalURLFlavor.CUSTOM, caseInsensitive, value[1]);
                GRegex compiledRegex = compileRegex(regex);
                if (compiledRegex !is null) {
                    int id = vte.matchAddGregex(compiledRegex, cast(GRegexMatchFlags) 0);
                    regexTag[id] = regex;
                    vte.matchSetCursorType(id, CursorType.HAND2);
                    tracef("Added regex: %s with tag %d",value[0], id);
                }
            }
        }
    }

private:

    void feedChild(string text, bool ignoreCommit) {
        _ignoreCommit = ignoreCommit;
        vte.feedChild(text, text.length);
        _ignoreCommit = false;
    }

    void showInfoBarMessage(string message) {
        TerminalInfoBar ibRelaunch = new TerminalInfoBar();
        ibRelaunch.addOnResponse(delegate(int response, InfoBar ib) {
            if (response == ResponseType.OK) {
                ibRelaunch.destroy();
                spawnTerminalProcess(gst.initialCWD);
            }
        });
        ibRelaunch.setMessage(message);
        terminalOverlay.addOverlay(ibRelaunch);
        ibRelaunch.showAll();
    }

    void getHostnameAndDirectory(out string hostname, out string directory) {
        if (gpid == 0)
            return;
        string cwd = vte.getCurrentDirectoryUri();
        if (cwd.length == 0) {
            return;
        }
        trace("Current directory: " ~ cwd);
        directory = URI.filenameFromUri(cwd, hostname);
    }

    /**
     * Spawns the child process in the Terminal depending on the Profile
     * command options.
     *
     * Note that command must be passed in rather then using overrideCommand
     * directly in case we re-spawn it later.
     */
    void spawnTerminalProcess(string workingDir, string command = null) {

        void outputError(string msg, string workingDir, string[] args, string[] envv) {
            error(msg);
            errorf("Working Directory=%s", workingDir);
            error("Arguments used to execute process:");
            foreach (i, arg; args)
                errorf("\targ %d=%s", i, arg);
            error("Environment used to execute process:");
            foreach (i, env; envv)
                errorf("\tenv %d=%s", i, env);
        }

        trace("workingDir parameter=" ~ workingDir);

        CommandParameters overrides = terminix.getGlobalOverrides();
        //If cwd is set in overrides use that if an explicit working dir wasn't passed as a parameter
        if (workingDir.length == 0 && overrides.cwd.length > 0) {
            trace("Using cwd provided");
            workingDir = overrides.cwd;
        }
        if (overrides.workingDir.length > 0) {
            workingDir = overrides.workingDir;
            trace("Working directory overridden to " ~ workingDir);
        }
        if (workingDir.length == 0) {
            string cwd = Util.getCurrentDir();
            trace("No working directory set, using cwd");
            workingDir = cwd;
        }

        trace("Spawn setting workingDir to " ~ workingDir);

        GSpawnFlags flags = GSpawnFlags.SEARCH_PATH_FROM_ENVP;
        string shell = getUserShell(vte.getUserShell());
        string[] args;
        // Passed command takes precedence over global override which comes from -x flag
        if (command.length == 0 && overrides.command.length > 0) {
            command = overrides.command;
        }
        if (command.length > 0) {
            //keep copy of command around
            _overrideCommand = command;
            trace("Overriding the command from command prompt: " ~ overrides.command);
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
        string[] envv = ["TERMINIX_ID=" ~ uuid];
        foreach (arg; args)
            trace("Argument: " ~ arg);
        try {
            //Set PWD so that shell sets correct directory for symlinks, see #164
            if (workingDir.length > 0) {
                envv ~= ["PWD=" ~ workingDir];
            }
            setProxyEnv(envv);

            /*
            // To make this work the terminal has to be added to the widget
            // heirarchy in order to get the XID first. This was done by breaking
            // the session into create and init methods that the application window
            // could call independently. However this also ended up causing issues
            // with the VTE cursor not showing as focused.
            //
            // Frankly I'm not a big fan of this WINDOWID environment variable since
            // it doesn't work in Wayland and it's not worth the grief it is causing.
            // See Issues #540 and #525
            
            // Add Window ID
            Window tw = cast(Window)getToplevel();
            if (tw !is null && !isWayland(tw)) {
                GdkWindow window = tw.getWindow();
                if (window !is null) {
                    import gdk.X11: getXid;
                    uint xid = getXid(window);
                    tracef("WINDOWID=%d",xid);
                    envv ~= ["WINDOWID=" ~ to!string(xid)];
                }
            }
            */

            bool result = spawnSync(workingDir, args, envv, flags, gpid);
            if (!result) {
                string msg = _("Unexpected error occurred, no additional information available");
                outputError(msg, workingDir, args, envv);
                showInfoBarMessage(msg);
            }
        }
        catch (GException ge) {
            string msg = format(_("Unexpected error occurred: %s"), ge.msg);
            outputError(msg, workingDir, args, envv);
            showInfoBarMessage(msg);
        }
        vte.grabFocus();
    }

    /**
     * Needed spawnSync function to handle flatpak where we need to generate out VtePty in order
     * for it to work at the system level outside of flatpak.
     *
     * Christian Herget of Builder fame pointed me to the spots where he needed to do
     * create the VtePty plus send a DBus message to flatpak to get this work.
     *
     * VtePty: https://git.gnome.org/browse/gnome-builder/tree/plugins/terminal/gb-terminal-view.c#n238
     * HostCommand(): https://git.gnome.org/browse/gnome-builder/tree/libide/subprocess/ide-breakout-subprocess.c#n1448 
     */
    bool spawnSync(string workingDir, string[] args, string[] envv, GSpawnFlags flags, out int gpid) {
        static if (FLATPAK) {
            Pty pty = vte.ptyNewSync(VtePtyFlags.DEFAULT, null);
            //sendHostCommand(pty, workingDir, args, envv);

            import glib.Spawn: Spawn;
            import vtec.vte: vte_pty_child_setup;
            import gtkc.Loader: Linker;
            import gtkc.paths: LIBRARY;

            flags |= GSpawnFlags.DO_NOT_REAP_CHILD;

            envv ~= ["TERM=" ~"xterm-256color"];
            string[string] envParent = environment.toAA();
            foreach(key; envParent.byKey()) {
                envv ~= [key ~ "=" ~ envParent[key]];
            }

            // TODO
            // This is a bit hacky in order to cast from 'void function(VtePty* pty)' to 'void function(void* pty)' required by Spawn.async 
            if (c_vte_pty_child_setup_void is null) {
                Linker.link(c_vte_pty_child_setup_void, "vte_pty_child_setup", LIBRARY.VTE);
            }
            bool result = Spawn.async(workingDir, args, envv, flags, c_vte_pty_child_setup_void, pty.getPtyStruct(), gpid);
            // TODO - Need to retry if it fails due to permissions on workingDir, see vte code
            // https://github.com/GNOME/vte/blob/bcc7bdbed0e2897b67333685cdf8771d832e01d1/src/pty.cc#L397

            vte.setPty(pty);
            return result;
        } else {
            return vte.spawnSync(VtePtyFlags.DEFAULT, workingDir, args, envv, flags, null, null, gpid, null);
        }
    }

    /*
    GVariant buildHostCommandVariant(string workingDir, string[] args, string[] envv, int[] fdlist) {
        if (workingDir.length == 0) workingDir = Util.getHomeDir();
        string arg = join(args, " ");
        GVariantBuilder fdBuilder = new GVariantBuilder(new GVariantType("a{uh}"));
        foreach(fd; fdlist) {
            fdBuilder.addValue(new GVariant(fd));
        }
        GVariantBuilder envBuilder = new GVariantBuilder(new GVariantType("a{ss}"));
        foreach(env; envv) {
            string[] envPair = env.split("=");
            if (envPair.length ==2) {
                envBuilder.addValue(new GVariant(new GVariant(envPair[0]), new GVariant(envPair[1])));
            }
        }
        
        tracef("Working dir=%s, args=%s", workingDir, arg);

        import gtkc.glib: g_variant_new;

        gtkc.glibtypes.GVariant* vs = g_variant_new("(^ay^aay@a{uh}@a{ss}u)",
                          toStringz(workingDir),
                          toStringz(arg),
                          fdBuilder.end().getVariantStruct(),
                          envBuilder.end().getVariantStruct(),
                          0);
        return new GVariant(vs, true);
    }

    enum O_CLOEXEC = 0x80000;

    void sendHostCommand(Pty pty, string workingDir, string[] args, string[] envv) {
        import gio.DBusConnection;
        import gio.UnixFDList;

        int[] fdList;

        char* name = ptsname(pty.getFd());
        int ttyFd = open(name, O_RDWR | O_CLOEXEC);
        if (ttyFd >= 0) {
            fdList ~= ttyFd;
        }

        UnixFDList outFdList = new UnixFDList();
        UnixFDList inFdList = new UnixFDList();
        foreach(fd; fdList) {        
            inFdList.append(fd);
        }

        DBusConnection connection = terminix.getDbusConnection();
        GVariant reply = connection.callWithUnixFdListSync(
            "org.freedesktop.Flatpak",
            "/org/freedesktop/Flatpak/Development",
            "org.freedesktop.Flatpak.Development",
            "HostCommand",
            buildHostCommandVariant(workingDir, args, envv, fdList),
            new GVariantType("(u)"),
            GDBusCallFlags.NONE,
            -1,
            inFdList,
            outFdList,
            null
        );

        if (reply is null) {
            warning("No reply from flatpak dbus service");
        }
    }
    */
    
    /**
     * Returns the child pid running in the terminal or -1
     * if no child pid is running. May also return the VTE gpid
     * as well which also indicates no child process.
     */
    pid_t getChildPid() {
        if (vte.getPty() is null)
            return false;
        return tcgetpgrp(vte.getPty().getFd());
    }

    /**
     * Sets the proxy environment variables in the shell if available in gnome-terminal.
     * Note this only works with manual proxy settings.
     */
    void setProxyEnv(ref string[] envv) {
        
        void addProxy(GSettings gsProxy, string scheme, string urlScheme, string varName) {
            GSettings gsProxyScheme = gsProxy.getChild(scheme);

            string host = gsProxyScheme.getString("host");
            int port = gsProxyScheme.getInt("port");
            if (host.length == 0 || port == 0) return;
            
            string value = urlScheme ~ "://";
            if (scheme == "http") {
                if (gsProxyScheme.getBoolean("use-authentication")) {
                    string user = gsProxyScheme.getString("authentication-user");
                    string pw = gsProxyScheme.getString("authentication-password");
                    if (user.length > 0) {
                        value = value ~ "@" ~ user;
                        if (pw.length > 0) {
                            value = value ~ ":" ~ pw;
                        }
                        value = value ~ "@";
                    }
                }
            }

            value = value ~ format("%s:%d/", host, port);
            envv ~= format("%s=%s",varName,value);
        }

        
        if (!gsSettings.getBoolean(SETTINGS_SET_PROXY_ENV_KEY)) return;

        GSettings gsProxy = terminix.getProxySettings();
        if (gsProxy is null) return;
        if (gsProxy.getString("mode") != "manual") return;
        addProxy(gsProxy, "http", "http", "http_proxy");
        addProxy(gsProxy, "https", "http", "https_proxy");
        addProxy(gsProxy, "ftp", "http", "ftp_proxy");
        addProxy(gsProxy, "socks", "socks", "all_proxy");

        string[] ignore = gsProxy.getStrv("ignore-hosts");
        if (ignore.length > 0) {
            envv ~= "no_proxy=" ~ join(ignore, ",");
        }
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
        TargetEntry colorEntry = new TargetEntry("application/x-color", TargetFlags.OTHER_APP, DropTargets.COLOR);
        TargetEntry vteEntry = new TargetEntry(VTE_DND, TargetFlags.SAME_APP, DropTargets.VTE);
        TargetEntry[] targets = [uriEntry, stringEntry, textEntry, colorEntry, vteEntry];
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
        
        //TODO - Figure out why this is causing issues, see #545
        if (checkVTEFeature(TerminalFeature.DISABLE_BACKGROUND_DRAW)) {
            vte.addOnDraw(&onVTEDrawBadge);
        }
        vte.addOnDraw(&onVTEDraw, ConnectFlags.AFTER);

        trace("Drag and drop completed");
    }

    /**
     * Called to set the selection data, which is later returned in the drag received
     * so it knows which terminal was dropped, in this case the terminal UUID
     */
    void onTitleDragDataGet(DragContext dc, SelectionData data, uint info, uint time, Widget widget) {
        char[] buffer = (uuid ~ '\0').dup;
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
                terminalWindowState = TerminalWindowState.NORMAL;
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
        return (dragTerminal.uuid == _terminalUUID);
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
        if (isSourceAndDestEqual(dc, this) || terminalWindowState == TerminalWindowState.MAXIMIZED) {
            //trace("Invalid drop");
            return false;
        }
        DragQuadrant dq = getDragQuadrant(x, y, vte);

        dragInfo = DragInfo(true, dq);
        vte.queueDraw();
        //Uncomment this if debugging motion otherwise generates annoying amount of trace noise
        //tracef("Drag motion: %s %d, %d, %d", _terminalUUID, x, y, dq);

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
        trace("Drag data received for " ~ to!string(info));
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
        case DropTargets.COLOR:
            if (data.getLength() != 8) return;
            char[] colors = data.getDataWithLength();
            string hexColor = format("#%02X%02X%02X", colors[0], colors[1], colors[2]);
            trace("Hex Color " ~ hexColor);
            tracef("Red=%d,Green=%d,Blue=%d,Alpha=%d", colors[0], colors[1], colors[2], colors[3]);
            gsProfile.setString(SETTINGS_PROFILE_BG_COLOR_KEY, hexColor);
            applyPreference(SETTINGS_PROFILE_BG_COLOR_KEY);
            break;
        case DropTargets.VTE:
            //Don't allow drop on the same terminal
            if (isSourceAndDestEqual(dc, this) || terminalWindowState == TerminalWindowState.MAXIMIZED)
                return;
            string uuid = to!string(data.getDataWithLength()[0 .. $ - 1]);
            DragQuadrant dq = getDragQuadrant(x, y, vte);
            tracef("Receiving Terminal %s, Dropped terminal %s, x=%d, y=%d, dq=%d", _terminalUUID, uuid, x, y, dq);
            notifyTerminalRequestMove(uuid, this, dq);
            dragInfo = DragInfo(false, dq);
            break;
        }
    }

    const uint BADGE_MARGIN = 10;

    bool onVTEDrawBadge(Scoped!Context cr, Widget w) {
        cr.save();
        double width = to!double(w.getAllocatedWidth());
        double height = to!double(w.getAllocatedHeight());

        // Only draw background if vte background draw is disabled
        if (vte.getDisableBGDraw()) {
            cr.setSourceRgba(vteBG.red, vteBG.green, vteBG.blue, vteBG.alpha);
            cr.setOperator(cairo_operator_t.SOURCE);
            cr.rectangle(0.0, 0.0, width, height);
            cr.clip();
            cr.paint();
            cr.resetClip();
        }
        //Draw badge if badge text is available
        if (_cachedBadge.length > 0) {
            // Paint badge
            // Use same alpha as background color to match transparency slider
            cr.setSourceRgba(vteBadge.red, vteBadge.green, vteBadge.blue, vteBG.alpha);

            // Create rect for default NW position
            GdkRectangle rect = GdkRectangle(BADGE_MARGIN, BADGE_MARGIN, to!int(width/2) - BADGE_MARGIN, to!int(height/2) - BADGE_MARGIN);
            string position = gsProfile.getString(SETTINGS_PROFILE_BADGE_POSITION_KEY);
            //Adjust coords of rect for other positions
            switch (position) {
                case SETTINGS_QUADRANT_NE_VALUE:
                    rect.x = to!int(width/2) + BADGE_MARGIN;
                    break;
                case SETTINGS_QUADRANT_SW_VALUE:
                    rect.y = to!int(height/2) + BADGE_MARGIN;
                    break;
                case SETTINGS_QUADRANT_SE_VALUE:
                    rect.x = to!int(width/2) + BADGE_MARGIN;
                    rect.y = to!int(height/2) + BADGE_MARGIN;
                    break;
                default:
            }

            PgFontDescription font = vte.getFont().copy();
            font.setSize(font.getSize() * 2);

            PgLayout pgl = PgCairo.createLayout(cr);
            pgl.setFontDescription(font);
            pgl.setText(_cachedBadge);
            pgl.setWidth(rect.width * PANGO_SCALE);
            pgl.setHeight(rect.height * PANGO_SCALE);
            int pw, ph;
            pgl.getPixelSize(pw, ph);
            //Hack, deduct 0.2 from ratio to make sure text will fit when painted
            double fontRatio = min(to!double(rect.width)/to!double(pw) - 0.2, to!double(rect.height)/to!double(ph)); 
            // If a bigger font fits, then increase it
            if (fontRatio > 1) {
                int fontSize = to!int(floor(fontRatio * font.getSize()));
                font.setSize(fontSize);
                pgl.setFontDescription(font);
                //tracef("Width %d, Pixel Width %d, Pixel Height %d, Original Font ratio %f, Font size %d", rect.width, pw, ph, fontRatio, fontSize);
                pgl.getPixelSize(pw, ph);
            } else {
                pgl.setWrap(PangoWrapMode.WORD_CHAR);
            }

            switch (position) {
                case SETTINGS_QUADRANT_NE_VALUE:
                    pgl.setAlignment(PangoAlignment.RIGHT);
                    break;
                case SETTINGS_QUADRANT_SW_VALUE:
                    rect.y = rect.y + rect.height - ph; 
                    break;
                case SETTINGS_QUADRANT_SE_VALUE:
                    rect.y = rect.y + rect.height - ph; 
                    pgl.setAlignment(PangoAlignment.RIGHT);
                    break;
                default:
            }

            cr.rectangle(rect.x, rect.y, rect.width, rect.height);
            cr.clip();
            cr.moveTo(rect.x, rect.y);

            PgCairo.showLayout(cr, pgl);

            cr.resetClip();
        }
        cr.restore();
        return false;
    }


    enum STROKE_WIDTH = 4;

    //Draw the drag hint if dragging is occurring
    bool onVTEDraw(Scoped!Context cr, Widget widget) {

        if (dimPercent > 0) {
            Window window = cast(Window) getToplevel();
            bool windowActive = (window is null)?false:window.isActive();
            if (!windowActive || (!vte.isFocus() && !rFind.isSearchEntryFocus() && !pmContext.isVisible() && !mbTitle.getPopover().isVisible())) {
                cr.setSourceRgba(vteDimBG.red, vteDimBG.green, vteDimBG.blue, dimPercent);
                cr.setOperator(cairo_operator_t.ATOP);
                cr.paint();
            }
        }
        //Dragging happening?
        if (!dragInfo.isDragActive)
            return false;

        RGBA color;

        if (!vte.getStyleContext().lookupColor("theme_selected_bg_color", color)) {
            getStyleBackgroundColor(vte.getStyleContext(), StateFlags.SELECTED, color);
        }
        cr.setSourceRgba(color.red, color.green, color.blue, 1.0);
        cr.setLineWidth(STROKE_WIDTH);
        int w = widget.getAllocatedWidth();
        int h = widget.getAllocatedHeight();
        int offset = STROKE_WIDTH;
        final switch (dragInfo.dq) {
        case DragQuadrant.LEFT:
            cr.rectangle(offset, offset, w / 2, h - (offset * 2));
            break;
        case DragQuadrant.TOP:
            cr.rectangle(offset, offset, w - (offset * 2), h / 2);
            break;
        case DragQuadrant.BOTTOM:
            cr.rectangle(offset, h / 2, w - (offset * 2), h / 2 - offset);
            break;
        case DragQuadrant.RIGHT:
            cr.rectangle(w / 2, offset, w / 2, h - (offset * 2));
            break;
        }
        cr.strokePreserve();
        //cr.fill();
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
            FileChooserDialog fcd = new FileChooserDialog(
              _("Save Terminal Output"),
              window,
              FileChooserAction.SAVE,
              [_("Save"), _("Cancel")]);
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
        GFileIF file = GFile.parseName(outputFilename);
        gio.OutputStream.OutputStream stream = file.replace(null, false, GFileCreateFlags.NONE, null);
        scope (exit) {
            stream.close(null);
        }
        vte.writeContentsSync(stream, VteWriteFlags.DEFAULT, null);
    }

// Theme changed
private:
    void onThemeChanged(string theme) {
        //Get CSS Provider updated via preference
        applyPreference(SETTINGS_PROFILE_BG_COLOR_KEY);
    }

//Zoom
private:
    void zoomIn() {
        if (vte.getFontScale() < 5) {
            vte.setFontScale(vte.getFontScale() + 0.1);
        }
    }

    void zoomOut() {
        if (vte.getFontScale() > 0.1) {
            vte.setFontScale(vte.getFontScale() - 0.1);
        }
    }

    void zoomNormal() {
        vte.setFontScale(1.0);
    }

public:

    /**
     * Creates the TerminalPane using the specified profile
     */
    this(string profileUUID) {
        super();
        addOnDestroy(delegate(Widget) {
            finalizeTerminal();
        });
        gst = new GlobalTerminalState();
        initColors();
        _terminalUUID = randomUUID().toString();
        _activeProfileUUID = profileUUID;
        // Check if profile is overridden globally
        if (terminix.getGlobalOverrides().profileName.length > 0) {
            string newProfileUUID = prfMgr.getProfileUUIDFromName(terminix.getGlobalOverrides().profileName);
            if (newProfileUUID.length > 0) {
                _activeProfileUUID = newProfileUUID;
                trace("Overriding profile with global: " ~ _activeProfileUUID);
            }
        }
        //Check if title is overridden globally
        if (terminix.getGlobalOverrides().title.length > 0) {
            _overrideTitle = terminix.getGlobalOverrides().title;
        }

        gsSettings = new GSettings(SETTINGS_ID);
        gsSettings.addOnChanged(delegate(string key, GSettings) { applyPreference(key); });
        gsProfile = prfMgr.getProfileSettings(_activeProfileUUID);
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
        gsProfile.addOnChanged(delegate(string key, Settings) {
            applyPreference(key);
        });
        //Get when theme changed
        terminix.onThemeChange.connect(&onThemeChanged);
        trace("Finished creation");
    }

    debug(Destructors) {
        ~this() {
            writeln("***** Terminal destructor is called");
        }
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
        gst.initialCWD = initialPath;
        spawnTerminalProcess(initialPath, _overrideCommand);
        if (firstRun) {
            int width = gsProfile.getInt(SETTINGS_PROFILE_SIZE_COLUMNS_KEY);
            int height = gsProfile.getInt(SETTINGS_PROFILE_SIZE_ROWS_KEY);
            if (terminix.getGlobalOverrides().width > 0) width = terminix.getGlobalOverrides().width;
            if (terminix.getGlobalOverrides().height > 0) height = terminix.getGlobalOverrides().height;
            trace("Set VTE Size for rows " ~ to!string(width));
            trace("Set VTE Size for columns " ~ to!string(height));
            vte.setSize(width, height);
        }
        trace("Terminal initialized");
        updateDisplayText();
    }

    /**
     * Finalize the terminal and cleanup any references, this can be
     * called multiple times with no ill effect.
     */
    void finalizeTerminal() {
        stopProcess();
        terminix.onThemeChange.disconnect(&onThemeChanged);
        if (timer !is null) timer.stop();
        if (sagTerminalActions !is null) {
            sagTerminalActions.destroy();
            sagTerminalActions = null;
        }

        if (rFind !is null) {
            rFind.onSearchEntryFocusIn.disconnect(&terminalWidgetFocusIn);
            rFind.onSearchEntryFocusOut.disconnect(&terminalWidgetFocusOut);
            rFind.destroy();
            rFind = null;
        }

        if (vte !is null && !inDestruction()) {
            //Workaround for #589
            import gtk.Bin;
            Bin bin = cast(Bin)vte.getParent();
            if (bin !is null) {
                bin.remove(vte);
            }
        }
        vte = null;
    }

    /**
     * Maximizes or restores terminal by requesting
     * state change from container.
     */
    void maximize() {
        TerminalWindowState newState = (terminalWindowState == TerminalWindowState.NORMAL) ? TerminalWindowState.MAXIMIZED : TerminalWindowState.NORMAL;
        CumulativeResult!bool result = new CumulativeResult!bool();
        onRequestStateChange.emit(this, newState, result);
        if (!result.isAnyResult(false)) {
            terminalWindowState = newState;
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
        trace("Terminal grabbing focus");
        vte.grabFocus();
    }

    /**
     * Called when the session the terminal is associated with
     * becomes active, i.e. is visible to the user
     *
     * Can't rely on events like map or realized because
     * thumbnail drawing triggers them.
     */
    void notifySessionActive() {
        if (deferShowBell) {
            showBell();
        }
    }

    bool isProcessRunning() {
        pid_t childPid = getChildPid();
        return isProcessRunning(childPid);
    }

    /**
     * Determines if a child process is running in the terminal,
     * and returns the pid
     */
    bool isProcessRunning(out pid_t childPid) {
        if (vte.getPty() is null)
            return false;
        int fd = vte.getPty().getFd();
        childPid = getChildPid();
        tracef("childPid=%d gpid=%d", childPid, gpid);
        return (childPid != -1 && childPid != gpid);
    }

    /**
     * Determines if a child process is running in the terminal,
     * returns the name
     */
    bool isProcessRunning(out string name) {
        if (vte.getPty() is null)
            return false;
        pid_t childPid;
        bool result = isProcessRunning(childPid);

        import std.file: read;
        name = to!string(cast(char[])read(format("/proc/%d/cmdline", childPid)));
        name = replace(name, "\0", " ");

        return result;
    }

    /**
     * Called by the session to synchronize input
     */
    void handleSyncInput(SyncInputEvent sie) {
        if (!isSynchronizedInput())
            return;

        final switch (sie.eventType) {
            case SyncInputEventType.INSERT_TERMINAL_NUMBER:
                string text = to!string(terminalID);
                feedChild(text, true);
                break;
            case SyncInputEventType.INSERT_TEXT:
                if (sie.senderUUID != _terminalUUID) {
                    feedChild(sie.text, true);
                }
                break;
            case SyncInputEventType.KEY_PRESS:
                Event newEvent = sie.event.copy();
                newEvent.key.sendEvent = 1;
                newEvent.key.window = vte.getWindow().getWindowStruct();
                vte.event(newEvent);
                break;                
        }
    }

    void triggerAction(string name, GVariant value) {
        SimpleAction action = cast(SimpleAction) sagTerminalActions.lookup(name);
        if (action !is null && action.getEnabled()) {
            action.activate(value);
        }
    }

    void toggleFind() {
        if (!rFind.getRevealChild()) {
            rFind.setRevealChild(true);
            rFind.focusSearchEntry();
        } else {
            rFind.setRevealChild(false);
            focusTerminal();
        }
    }

    JSONValue serialize(JSONValue value) {
        if (_overrideTitle.length > 0) {
            value[NODE_TITLE] = JSONValue(_overrideTitle);
        }
        if (_overrideBadge.length > 0) {
            value[NODE_BADGE] = JSONValue(_overrideBadge);
        }
        if (_overrideCommand.length > 0) {
            value[NODE_OVERRIDE_CMD] = JSONValue(_overrideCommand);
        }
        value[NODE_READONLY] = JSONValue(!vte.getInputEnabled());
        value[NODE_SYNCHRONIZED_INPUT] = JSONValue(_synchronizeInputOverride);
        return value;
    }

    void deserialize(JSONValue value) {
        if (NODE_TITLE in value) {
            _overrideTitle = value[NODE_TITLE].str();
        }
        if (NODE_BADGE in value) {
            _overrideBadge = value[NODE_BADGE].str();
        }
        if (NODE_OVERRIDE_CMD in value) {
            _overrideCommand = value[NODE_OVERRIDE_CMD].str();
        }
        if (NODE_READONLY in value) {
            vte.setInputEnabled(value[NODE_READONLY].type == JSON_TYPE.FALSE);
            SimpleAction action = cast(SimpleAction) sagTerminalActions.lookup(ACTION_READ_ONLY);
            action.setState(new GVariant(!vte.getInputEnabled()));
        }
        if (NODE_SYNCHRONIZED_INPUT in value) {
            _synchronizeInputOverride = (value[NODE_SYNCHRONIZED_INPUT].type == JSON_TYPE.TRUE);
            SimpleAction action = cast(SimpleAction) sagTerminalActions.lookup(ACTION_SYNC_INPUT_OVERRIDE);
            action.setState(new GVariant(_synchronizeInputOverride));
        }
    }

    /**
     * Takes a terminal title string with tokens/variables like ${title} and
     * performs the substitution to get the displayed title.
     *
     * This is public because the session can use it to resolve these variables
     * for the active terminal for it's own name shown in the sidebar.
     */
    string getDisplayText(string text) {
        string windowTitle = vte.getWindowTitle();
        if (windowTitle.length == 0)
            windowTitle = _("Terminal");
        text = text.replace(TERMINAL_TITLE, windowTitle);
        text = text.replace(TERMINAL_ICON_TITLE, vte.getIconTitle());
        text = text.replace(TERMINAL_ID, to!string(terminalID));
        text = text.replace(TERMINAL_COLUMNS, to!string(vte.getColumnCount()));
        text = text.replace(TERMINAL_ROWS, to!string(vte.getRowCount()));
        text = text.replace(TERMINAL_HOSTNAME, gst.currentHostname);
        text = text.replace(TERMINAL_USERNAME, gst.currentUsername);
        string path;
        if (terminalInitialized) {
            path = gst.currentDirectory;
        } else {
            trace("Terminal not initialized yet or VTE not configured, no path available");
            path = "";
        }
        text = text.replace(TERMINAL_DIR, path);
        return text;
    }

    @property string currentLocalDirectory() {
        return gst.getState(TerminalStateType.LOCAL).directory;
    }

    @property string defaultProfileUUID() {
        if (_defaultProfileUUID.length > 0) return _defaultProfileUUID;
        else return _activeProfileUUID;
    }

    @property string activeProfileUUID() {
        return _activeProfileUUID;
    }

    @property void activeProfileUUID(string uuid) {
        if (_activeProfileUUID != uuid) {
            _activeProfileUUID = uuid;
            // Explicitly destroy previous settings so we don't get change events from it
            gsProfile.destroy();
            gsProfile = prfMgr.getProfileSettings(_activeProfileUUID);
            // Hook up change event
            gsProfile.addOnChanged(delegate(string key, Settings) {
                applyPreference(key);
            });
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

    @property bool isSingleTerminal() {
        return _isSingleTerminal;
    }

    @property void isSingleTerminal(bool value) {
        if (_isSingleTerminal != value) {
            _isSingleTerminal = value;
            updateTitleBar();
        }
    }

    /**
     * A numeric ID managed by the session, this ID can and does change
     */
    @property size_t terminalID() {
        return _terminalID;
    }

    @property void terminalID(size_t ID) {
        if (this._terminalID != ID) {
            this._terminalID = ID;
            updateDisplayText();
        }
    }

    @property bool terminalInitialized() {
        return gst.initialized;
    }

    /**
     * A unique ID for the terminal, it is constant for the lifespan
     * of the terminal
     */
    @property string uuid() {
        return _terminalUUID;
    }

// Events
public:
    /**
    * An event that is fired when the terminal has been requested to close,
    * either explicitly by the user clicking the close button or the terminal
    * process exiting/aborting.
    */
    GenericEvent!(Terminal) onClose;

    /**
    * An event that is fired whenever the terminal gets focused. Used by
    * the Session to track focus.
    */
    GenericEvent!(Terminal) onFocusIn;

    /**
    * An event that is triggered when a terminal requests to moved from it's
    * original location (src) and moved into another terminal (dest).
    *
    * This typically happens after a drag and drop of a terminal
    */
    GenericEvent!(string, Terminal, DragQuadrant) onRequestMove;

    /**
    * Invoked when a terminal requests that it be detached into it's own window
    */
    GenericEvent!(Terminal, int, int) onRequestDetach;

    /**
     * Triggered when the terminal title changes.
     */
    GenericEvent!(Terminal) onTitleChange;

    /**
    * Triggered on a terminal key press, used by the session to synchronize input
    * when this option is selected.
    */
    GenericEvent!(Terminal, SyncInputEvent) onSyncInput;

    /**
    * Triggered when the terminal needs to change state. Delegate returns whether
    * state change was successful.

    */
    GenericEvent!(Terminal, TerminalWindowState, CumulativeResult!bool) onRequestStateChange;
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
 * translated from Vala to D. Thanks to Pantheon and Ikey Doherty for this.
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
        string[3] msg = getUnsafePasteMessage();
        setMarkup("<span weight='bold' size='larger'>" ~ msg[0] ~ "</span>\n\n" ~ msg[1] ~ "\n" ~ msg[2] ~ "\n\n" ~ "<tt><b>" ~ SimpleXML.markupEscapeText(cmd, cmd.length) ~ "</b></tt>");
        setImage(new Image("dialog-warning", IconSize.DIALOG));
        Button btnCancel = new Button(_("Don't Paste"));
        Button btnIgnore = new Button(_("Paste Anyway"));
        btnIgnore.getStyleContext().addClass("destructive-action");
        addActionWidget(btnCancel, 1);
        addActionWidget(btnIgnore, 0);
        showAll();
        btnIgnore.grabFocus();
    }
}


/************************************************************************
 * Block for supporting triggers
 ***********************************************************************/
private:

enum TriggerAction {
    UPDATE_STATE,
    EXECUTE_COMMAND,
    SEND_NOTIFICATION,
    UPDATE_TITLE,
    PLAY_BELL,
    SEND_TEXT,
    INSERT_PASSWORD,
    UPDATE_BADGE
}

/**
 * Class that holds definition of trigger including compiled regex
 */
class TerminalTrigger {

public:

    string pattern;
    TriggerAction action;
    string parameters;
    Regex!char compiledRegex;

    this(string pattern, string actionName, string parameters) {
        this.pattern = pattern;
        //this.action = action;
        this.parameters = parameters;
        switch (actionName) {
            case SETTINGS_PROFILE_TRIGGER_UPDATE_STATE_VALUE:
                action = TriggerAction.UPDATE_STATE;
                break;
            case SETTINGS_PROFILE_TRIGGER_EXECUTE_COMMAND_VALUE:
                action = TriggerAction.EXECUTE_COMMAND;
                break;
            case SETTINGS_PROFILE_TRIGGER_SEND_NOTIFICATION_VALUE:
                action = TriggerAction.SEND_NOTIFICATION;
                break;
            case SETTINGS_PROFILE_TRIGGER_UPDATE_BADGE_VALUE:
                action = TriggerAction.UPDATE_BADGE;
                break;
            case SETTINGS_PROFILE_TRIGGER_UPDATE_TITLE_VALUE:
                action = TriggerAction.UPDATE_TITLE;
                break;
            case SETTINGS_PROFILE_TRIGGER_PLAY_BELL_VALUE:
                action = TriggerAction.PLAY_BELL;
                break;
            case SETTINGS_PROFILE_TRIGGER_SEND_TEXT_VALUE:
                action = TriggerAction.SEND_TEXT;
                break;
            case SETTINGS_PROFILE_TRIGGER_INSERT_PASSWORD_VALUE:
                action = TriggerAction.INSERT_PASSWORD;
                break;
            default:
                break;
        }

        //Triggers always use multi-line mode since we are getting a buffer from VTE
        compiledRegex = regex(pattern, "m");
    }
}

struct TerminalTriggerMatch {
    TerminalTrigger trigger;
    string[] groups;
    size_t index;
}

/************************************************************************
 * Block for defining various DND structs and constants
 ***********************************************************************/
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
    COLOR,
    /**
        * Used when one VTE is dropped on another
        */
    VTE
};

struct DragInfo {
    bool isDragActive;
    DragQuadrant dq;
}

/************************************************************************
 * Block for managing terminal state
 ***********************************************************************/
private:

/**
 * Struct for remembering terminal state, used to track
 * local and remote (i.e. SSH) states.
 */
struct TerminalState {
    string hostname;
    string directory;
    string username;

    void clear() {
        hostname.length = 0;
        directory.length = 0;
        username.length = 0;
    }

    bool hasState() {
        return (hostname.length > 0 || directory.length > 0 || username.length > 0);
    }
}

enum TerminalStateType {LOCAL, REMOTE};

class GlobalTerminalState {
private:
    TerminalState local;
    TerminalState remote;
    string localHostname;
    string _initialCWD;
    bool _initialized = false;

    void updateHostname(string hostname) {
        if (hostname.length > 0 && hostname != localHostname) {
            if (remote.hostname != hostname) {
                remote.hostname = hostname;
                remote.username.length = 0;
                remote.directory.length = 0;
            }
        } else {
            local.hostname = hostname;
            remote.clear();
        }
        if (!_initialized) updateState();
    }

    void updateDirectory(string directory) {
        if (remote.hasState()) {
            remote.directory = directory;
        } else {
            local.directory = directory;
        }
        if (directory.length > 0 && !_initialized) updateState();
    }

    void updateUsername(string username) {
        if (remote.hasState()) {
            remote.username = username;
        } else {
            local.username = username;
        }
        if (username.length > 0 && !_initialized) updateState();
    }

public:

    enum StateVariable {
        HOSTNAME = "hostname",
        USERNAME = "username",
        DIRECTORY = "directory"
    }

    this() {
        //Get local hostname to detect difference between remote and local
        char[1024] systemHostname;
        if (gethostname(cast(char*)&systemHostname, 1024) == 0) {
            localHostname = to!string(cast(char*)&systemHostname);
            trace("Local Hostname: " ~ localHostname);
        }
    }

    void clear() {
        local.clear();
        remote.clear();
    }

    TerminalState getState(TerminalStateType type) {
        final switch (type) {
            case TerminalStateType.LOCAL: return local;
            case TerminalStateType.REMOTE: return remote;
        }
    }

    bool hasState(TerminalStateType type) {
        final switch (type) {
            case TerminalStateType.LOCAL: return local.hasState();
            case TerminalStateType.REMOTE: return remote.hasState();
        }
    }

    void updateState() {
        if (!_initialized) {
            _initialized = true;
            trace("Terminal in initialized state");
        }
    }

    void updateState(StateVariable variable, string value) {
        final switch (variable) {
            case StateVariable.HOSTNAME:
                updateHostname(value);
                break;
            case StateVariable.USERNAME:
                updateUsername(value);
                break;
            case StateVariable.DIRECTORY:
                updateDirectory(value);
                break;
        }
    }

    void updateState(string hostname, string directory) {
        //Is this a remote host?
        if (hostname.length > 0 && hostname != localHostname) {
            remote.hostname = hostname;
            remote.directory = directory;
        } else {
            local.hostname = hostname;
            local.directory = directory;
            remote.clear();
        }
        if (directory.length > 0) {
            updateState();
        }
        tracef("Current directory changed, hostname '%s', directory '%s'", currentHostname, currentDirectory);
    }

    /**
     * if Remote is set returns that otherwise returns local
     */
    @property string currentHostname() {
        if (remote.hasState()) return remote.hostname;
        return local.hostname;
    }

    /**
     * if Remote is set returns that otherwise returns local
     */
    @property string currentDirectory() {
        if (remote.hasState()) return remote.directory;
        return local.directory;
    }

    @property string currentUsername() {
        if (remote.hasState()) return remote.username;
        return local.username;
    }

    @property string currentLocalDirectory() {
        return local.directory;
    }

    @property string initialCWD() {
        return _initialCWD;
    }

    @property void initialCWD(string value) {
        _initialCWD = value;
    }

    @property bool initialized() {
        return _initialized;
    }
}

/************************************************************************
 * Block for handling default regex in vte
 ***********************************************************************/
private:

import std.regex.internal.thompson: ThompsonMatcher;

/**
 * This replaces all instances of $x tokens with values
 * from Regex match. The token $0 matches the whole match
 * whereas $1..$x are replaced with appropriate group match
 */
 string replaceMatchTokens(string tokenizedText, string[] matches) {
     string result = tokenizedText;
     foreach(i, match; matches) {
        result = result.replace("$" ~ to!string(i - 1), match);
     }
     return result;
 }

/**
 * Struct used to track matches in terminal for cases like context menu
 * where we need to preserve state between finding match and performing action
 */
struct TerminalURLMatch {
    TerminalURLFlavor flavor;
    string match;
    int tag;

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
    CUSTOM
};

struct TerminalRegex {
    string pattern;
    TerminalURLFlavor flavor;
    bool caseless;
    // Only used for custom regex
    string command;
}

immutable TerminalRegex[] URL_REGEX_PATTERNS = [
    TerminalRegex(SCHEME ~ "//(?:" ~ USERPASS ~ "\\@)?" ~ HOST ~ PORT ~ URLPATH, TerminalURLFlavor.AS_IS, true),
    TerminalRegex("(?:www|ftp)" ~ HOSTCHARS_CLASS ~ "*\\." ~ HOST ~ PORT ~ URLPATH, TerminalURLFlavor.DEFAULT_TO_HTTP, true),
    TerminalRegex("(?:callto:|h323:|sip:)" ~ USERCHARS_CLASS ~ "[" ~ USERCHARS ~ ".]*(?:" ~ PORT ~ "/[a-z0-9]+)?\\@" ~ HOST, TerminalURLFlavor.VOIP_CALL, true),
    TerminalRegex("(?:mailto:)?" ~ USERCHARS_CLASS ~ "[" ~ USERCHARS ~ ".]*\\@" ~ HOSTCHARS_CLASS ~ "+\\." ~ HOST, TerminalURLFlavor.EMAIL, true),
    TerminalRegex("(?:news:|man:|info:)[-[:alnum:]\\Q^_{|}~!\"#$%&'()*+,./;:=?`\\E]+", TerminalURLFlavor.AS_IS, true)
];

immutable GRegex[URL_REGEX_PATTERNS.length] compiledRegex;

GRegex compileRegex(TerminalRegex regex) {
    if (regex.pattern.length == 0) return null;
    GRegexCompileFlags flags = GRegexCompileFlags.OPTIMIZE | regex.caseless ? GRegexCompileFlags.CASELESS : cast(GRegexCompileFlags) 0;
    if (checkVTEVersionNumber(0, 44)) {
        flags = flags | GRegexCompileFlags.MULTILINE;
    }
    return new GRegex(regex.pattern, flags, cast(GRegexMatchFlags) 0);
}

static this() {
    import std.exception : assumeUnique;

    GRegex[URL_REGEX_PATTERNS.length] tempRegex;
    foreach (i, regex; URL_REGEX_PATTERNS) {
        tempRegex[i] = compileRegex(regex);
    }
    compiledRegex = assumeUnique(tempRegex);
}

/************************************************************************
 * Block for determining Shell
 ***********************************************************************/
private:

//Cribbed from Gnome Terminal
immutable string[] shells = [/* Note that on some systems shells can also
        * be installed in /usr/bin */
"/bin/bash", "/usr/bin/bash", "/bin/zsh", "/usr/bin/zsh", "/bin/tcsh", "/usr/bin/tcsh", "/bin/ksh", "/usr/bin/ksh", "/bin/csh", "/bin/sh"];

string getUserShell(string shell) {
    import std.file : exists;
    import core.sys.posix.pwd : getpwuid, passwd;

    if (shell.length > 0 && exists(shell))
        return shell;

    // Try environment variable next
    try {
        shell = environment["SHELL"];
        if (shell.length > 0) {
            tracef("Using shell %s from SHELL environment variable", shell);
            return shell;
        }
    }
    catch (Exception e) {
        trace("No SHELL environment variable found");
    }

    //Try to get shell from getpwuid
    passwd* pw = getpwuid(getuid());
    if (pw && pw.pw_shell) {
        string pw_shell = to!string(pw.pw_shell);
        if (exists(pw_shell)) {
            tracef("Using shell %s from getpwuid",pw_shell);
            return pw_shell;
        }
    }

    //Try known shells
    foreach (s; shells) {
        if (exists(s)) {
            tracef("Found shell %s, using that", s);
            return s;
        }
    }
    error("No shell found, defaulting to /bin/sh");
    return "/bin/sh";
}

/*
 * Terminal serialization constants
 */
private:
    enum NODE_OVERRIDE_CMD = "overrideCommand";
    enum NODE_BADGE = "badge";
    enum NODE_TITLE = "title";
    enum NODE_READONLY = "readOnly";
    enum NODE_SYNCHRONIZED_INPUT = "synchronizedInput";

/**
 * Part of a workaround for passing function pointer to Spawn.async.
 * See spawnSync in class Terminal for more info.
 */
private:

__gshared extern(C)
{
	void function(void* pty) c_vte_pty_child_setup_void;
}
