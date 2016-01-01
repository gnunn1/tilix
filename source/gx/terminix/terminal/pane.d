/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.terminal.pane;

import core.sys.posix.sys.wait;
import core.sys.posix.unistd;

import std.algorithm;
import std.array;
import std.conv;
import std.experimental.logger;
import std.format;

import gdk.DragContext;
import gdk.Event;
import gdk.RGBA;

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

import vte.Terminal;

import gx.gtk.actions;
import gx.gtk.util;
import gx.i18n.l10n;
import gx.util.array;

import gx.terminix.constants;
import gx.terminix.preferences;
import gx.terminix.terminal.actions;
import gx.terminix.terminal.search;

alias OnTerminalInFocus = void delegate(TerminalPane pane);
alias OnTerminalClose = void delegate(TerminalPane pane);
alias OnTerminalRequestSplit = void delegate(TerminalPane pane, Orientation orientation);
alias OnTerminalKeyPress = void delegate(Event event, TerminalPane pane);

enum DropTargets {
	URILIST,
	STRING,
	TEXT
};

enum TERMINAL_TITLE = "${title}";
enum TERMINAL_ID = "${id}";
enum TERMINAL_DIR = "${directory}";

class TerminalPane : Box {

private:

	OnTerminalInFocus[] terminalInFocusDelegates;
	OnTerminalClose[] terminalCloseDelegates;
	OnTerminalRequestSplit[] terminalRequestSplitDelegates;
    OnTerminalKeyPress[] terminalKeyPressDelegates;

    SearchRevealer rFind;

	Terminal terminal;
    Overlay terminalOverlay;
	Scrollbar sb;

	GPid gpid = 0;
    bool titleInitialized = false;
    
	Label lblTitle;
    
    string _profileUUID;
    ulong _terminalID;
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

	void createUI() {
		sagTerminalActions = new SimpleActionGroup();
		createActions(sagTerminalActions);
		insertActionGroup(ACTION_PREFIX, sagTerminalActions);
        
		add(createTitlePane());
        add(createTerminal());
	}

    /**
     * Creates the top bar of the terminal pane
     */
	Widget createTitlePane() {

		Box bTitle = new Box(Orientation.HORIZONTAL, 0);
		bTitle.setVexpand(false);
		bTitle.getStyleContext().addClass("notebook");
		bTitle.getStyleContext().addClass("header");

		lblTitle = new Label(_("Terminal"));
		lblTitle.setEllipsize(PangoEllipsizeMode.START);
        lblTitle.setUseMarkup(true);
		bTitle.packStart(lblTitle, false, false, 4);
        
		//Close Button
		Button btnClose = new Button("window-close-symbolic", IconSize.MENU);
		btnClose.setRelief(ReliefStyle.NONE);
		btnClose.setFocusOnClick(false);
        btnClose.setActionName(getActionDetailedName(ACTION_PREFIX, ACTION_CLOSE));
		setVerticalMargins(btnClose);
		bTitle.packEnd(btnClose, false, false, 4);

		Separator sp = new Separator(Orientation.VERTICAL);
		sp.setMarginLeft(3);
		sp.setMarginRight(3);
		bTitle.packEnd(sp, false, false, 0);

        //Profile Menu
       	profileMenu = new GMenu();

        //Menu button that displays popover
		MenuButton mb = new MenuButton();
		mb.setRelief(ReliefStyle.NONE);
		mb.setFocusOnClick(false);
		Image hamburger = new Image("open-menu-symbolic", IconSize.MENU);
		mb.setPopover(createPopover(mb));
        mb.addOnButtonPress(delegate(Event e, Widget w) {
            buildProfileMenu();
            return false;
        });

		mb.add(hamburger);
		setVerticalMargins(mb);

		bTitle.packEnd(mb, false, false, 5);

		return bTitle;
	}
    
    //Dynamically build the menus for selecting a profile
    void buildProfileMenu() {
        profileMenu.removeAll();
        saProfileSelect.setState(new GVariant(profileUUID));
        ProfileInfo[] profiles = prfMgr.getProfiles();
        foreach(profile; profiles) {
            GMenuItem menuItem = new GMenuItem(profile.name, getActionDetailedName(ACTION_PREFIX, ACTION_PROFILE_SELECT));
            menuItem.setActionAndTargetValue(getActionDetailedName(ACTION_PREFIX, ACTION_PROFILE_SELECT), new GVariant(profile.uuid));
            profileMenu.appendItem(menuItem);
        }
    }

    /**
     * Creates the common actions used by the terminal pane
     */
	void createActions(SimpleActionGroup group) {
		registerActionWithSettings(group, ACTION_PREFIX , ACTION_SPLIT_H, gsShortcuts, delegate(Variant, SimpleAction) { notifyTerminalRequestSplit(Orientation.HORIZONTAL); });
		registerActionWithSettings(group, ACTION_PREFIX, ACTION_SPLIT_V, gsShortcuts, delegate(Variant, SimpleAction) { notifyTerminalRequestSplit(Orientation.VERTICAL); });
		registerActionWithSettings(group, ACTION_PREFIX, ACTION_FIND, gsShortcuts, delegate(Variant, SimpleAction) { 
            if (!rFind.getRevealChild()) {
                rFind.setRevealChild(true); 
                rFind.focusSearchEntry();
            } else {
                rFind.setRevealChild(false);
                terminal.grabFocus(); 
            } 
        });
		registerActionWithSettings(group, ACTION_PREFIX, ACTION_FIND_PREVIOUS, gsShortcuts, delegate(Variant, SimpleAction) { terminal.searchFindPrevious(); });
		registerActionWithSettings(group, ACTION_PREFIX, ACTION_FIND_NEXT, gsShortcuts, delegate(Variant, SimpleAction) { terminal.searchFindNext(); });
		registerActionWithSettings(group, ACTION_PREFIX, ACTION_TITLE, gsShortcuts, delegate(Variant, SimpleAction) {  
            string terminalTitle = overrideTitle is null?gsProfile.getString(SETTINGS_PROFILE_TITLE_KEY):overrideTitle; 
            if (showInputDialog(null, terminalTitle, terminalTitle, _("Enter Custom Title"), _("Enter a new title to override the one specified by the profile. To reset it to the profile setting, leave it blank"))) {
                overrideTitle = terminalTitle;
                if (overrideTitle.length == 0) overrideTitle = null;
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
            if (closeTerminal) notifyTerminalClose();
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

		GMenuItem splitH = new GMenuItem(null, ACTION_PREFIX  ~ "." ~  ACTION_SPLIT_H);
		splitH.setAttributeValue("verb-icon", new GVariant("terminix-split-tab-right-symbolic"));

		GMenuItem splitV = new GMenuItem(null, ACTION_PREFIX  ~ "." ~  ACTION_SPLIT_V);
		splitV.setAttributeValue("verb-icon", new GVariant("terminix-split-tab-down-symbolic"));

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
    
	void setVerticalMargins(Widget widget) {
		widget.setMarginTop(4);
		widget.setMarginBottom(4);
	}

	Widget createTerminal() {
		terminal = new Terminal();
		// Basic widget properties
		terminal.setHexpand(true);
		terminal.setVexpand(true);
		//URL Regex Experessions
		foreach (regex; compiledRegex) {
			int id = terminal.matchAddGregex(cast(Regex) regex, cast(GRegexMatchFlags) 0);
			terminal.matchSetCursorType(id, CursorType.HAND2);
		}
		//DND
		TargetEntry uriEntry = new TargetEntry("text/uri-list", TargetFlags.OTHER_APP, DropTargets.URILIST);
		TargetEntry stringEntry = new TargetEntry("STRING", TargetFlags.OTHER_APP, DropTargets.STRING);
		TargetEntry textEntry = new TargetEntry("text/plain", TargetFlags.OTHER_APP, DropTargets.TEXT);
		TargetEntry[] targets = [uriEntry, stringEntry, textEntry];
		terminal.dragDestSet(DestDefaults.ALL, targets, DragAction.COPY);
		terminal.addOnDragDataReceived(&onTerminalDragDataReceived);

		//Event handlers
		terminal.addOnChildExited(&onTerminalChildExited);
		terminal.addOnWindowTitleChanged(delegate(Terminal terminal) { updateTitle(); });
		terminal.addOnCurrentDirectoryUriChanged(delegate(Terminal terminal) { 
            titleInitialized = true;
            updateTitle(); 
        });
		terminal.addOnCurrentFileUriChanged(delegate(Terminal terminal) { trace("Current file is " ~ terminal.getCurrentFileUri); });
		terminal.addOnFocusIn(&onTerminalFocusIn);
		terminal.addOnFocusOut(&onTerminalFocusOut);

		terminal.addOnButtonPress(&onTerminalButtonPress);
        terminal.addOnKeyPress(delegate(Event event, Widget widget) {
            if (_synchronizeInput && event.key.sendEvent == 0) {
                trace("forward event key press");
                foreach(dlg; terminalKeyPressDelegates) dlg(event, this);            
            } else {
                trace("Synchronized Input = " ~ to!string(_synchronizeInput) ~ ", sendEvent=" ~ to!string(event.key.sendEvent));
            }
            return false;
        });

		mContext = new Menu();
		miCopy = new MenuItem(delegate(MenuItem item) { terminal.copyClipboard(); }, _("Copy"), null);
		mContext.add(miCopy);
		miPaste = new MenuItem(delegate(MenuItem item) { terminal.pasteClipboard(); }, _("Paste"), null);
		mContext.add(miPaste);

        terminalOverlay = new Overlay();
        terminalOverlay.add(terminal);
        rFind = new SearchRevealer(terminal);
        terminalOverlay.addOverlay(rFind);

		Box box = new Box(Orientation.HORIZONTAL, 0);
		box.add(terminalOverlay);

		sb = new Scrollbar(Orientation.VERTICAL, terminal.getVadjustment());
		box.add(sb);
		return box;
	}

	void updateTitle() {
		string title = overrideTitle is null?gsProfile.getString(SETTINGS_PROFILE_TITLE_KEY):overrideTitle;
        title = title.replace(TERMINAL_TITLE, terminal.getWindowTitle());
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

	void notifyTerminalClose() {
		foreach (OnTerminalClose dlg; terminalCloseDelegates) {
			dlg(this);
		}
	}

    void onTerminalChildExited(int status, Terminal terminal) {
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

	bool onTerminalButtonPress(Event event, Widget widget) {
		if (event.type == EventType.BUTTON_PRESS) {
			GdkEventButton* buttonEvent = event.button;
			switch (buttonEvent.button) {
			case MouseButton.PRIMARY:
				long col = to!long(buttonEvent.x) / terminal.getCharWidth();
				long row = to!long(buttonEvent.y) / terminal.getCharHeight();
				int tag;
				string match = terminal.matchCheck(col, row, tag);
				if (match) {
					MountOperation.showUri(null, match, Main.getCurrentEventTime());
					return true;
				} else {
					return false;
				}
			case MouseButton.SECONDARY:
				miCopy.setSensitive(terminal.getHasSelection());
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

	void onTerminalDragDataReceived(DragContext context, int x, int y, SelectionData data, uint info, uint time, Widget widget) {
		final switch (info) {
		case DropTargets.URILIST:
			string[] uris = data.getUris();
			if (uris) {
				foreach (uri; uris) {
					string hostname;
					string quoted = ShellUtils.shellQuote(URI.filenameFromUri(uri, hostname)) ~ " ";
					terminal.feedChild(quoted, quoted.length);
				}
			}
			break;
		case DropTargets.STRING, DropTargets.TEXT:
			string text = data.getText();
			if (!text)
				terminal.feedChild(text, text.length);
			break;
		}
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
			terminal.setAudibleBell(gsProfile.getBoolean(SETTINGS_PROFILE_AUDIBLE_BELL_KEY));
			break;
		case SETTINGS_PROFILE_ALLOW_BOLD_KEY:
			terminal.setAllowBold(gsProfile.getBoolean(SETTINGS_PROFILE_ALLOW_BOLD_KEY));
			break;
		case SETTINGS_PROFILE_REWRAP_KEY:
			terminal.setRewrapOnResize(gsProfile.getBoolean(SETTINGS_PROFILE_REWRAP_KEY));
			break;
		case SETTINGS_PROFILE_CURSOR_SHAPE_KEY:
			terminal.setCursorShape(getCursorShape(gsProfile.getString(SETTINGS_PROFILE_CURSOR_SHAPE_KEY)));
			break;
		case SETTINGS_PROFILE_FG_COLOR_KEY, SETTINGS_PROFILE_BG_COLOR_KEY, SETTINGS_PROFILE_PALETTE_COLOR_KEY, SETTINGS_PROFILE_BG_TRANSPARENCY_KEY,
		SETTINGS_PROFILE_USE_THEME_COLORS_KEY:
				RGBA fg;
			RGBA bg;
			if (gsProfile.getBoolean(SETTINGS_PROFILE_USE_THEME_COLORS_KEY)) {
				terminal.getStyleContext().getColor(StateFlags.ACTIVE, fg);
				terminal.getStyleContext().getBackgroundColor(StateFlags.ACTIVE, bg);
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
			terminal.setColors(fg, bg, palette);
			break;
		case SETTINGS_PROFILE_SHOW_SCROLLBAR_KEY:
			sb.setVisible(gsProfile.getBoolean(SETTINGS_PROFILE_SHOW_SCROLLBAR_KEY));
			break;
		case SETTINGS_PROFILE_SCROLL_ON_OUTPUT_KEY:
			terminal.setScrollOnOutput(gsProfile.getBoolean(SETTINGS_PROFILE_SCROLL_ON_OUTPUT_KEY));
			break;
		case SETTINGS_PROFILE_SCROLL_ON_INPUT_KEY:
			terminal.setScrollOnOutput(gsProfile.getBoolean(SETTINGS_PROFILE_SCROLL_ON_INPUT_KEY));
			break;
		case SETTINGS_PROFILE_UNLIMITED_SCROLL_KEY,
		SETTINGS_PROFILE_SCROLLBACK_LINES_KEY:
				long scrollLines = gsProfile.getBoolean(SETTINGS_PROFILE_UNLIMITED_SCROLL_KEY) ? -1 : gsProfile.getValue(SETTINGS_PROFILE_SCROLLBACK_LINES_KEY).getInt64();
			terminal.setScrollbackLines(scrollLines);
			break;
        case SETTINGS_PROFILE_BACKSPACE_BINDING_KEY:
            terminal.setBackspaceBinding(getEraseBinding(gsProfile.getString(SETTINGS_PROFILE_BACKSPACE_BINDING_KEY)));
            break;
        case SETTINGS_PROFILE_DELETE_BINDING_KEY:
            terminal.setDeleteBinding(getEraseBinding(gsProfile.getString(SETTINGS_PROFILE_DELETE_BINDING_KEY)));
            break;
        case SETTINGS_PROFILE_CJK_WIDTH_KEY:
            terminal.setCjkAmbiguousWidth(to!int(countUntil(SETTINGS_PROFILE_CJK_WIDTH_VALUES, gsProfile.getString(SETTINGS_PROFILE_CJK_WIDTH_KEY))) + 1);
            break;
        case SETTINGS_PROFILE_CURSOR_BLINK_MODE_KEY:
            terminal.setCursorBlinkMode(getBlinkMode(gsProfile.getString(SETTINGS_PROFILE_CURSOR_BLINK_MODE_KEY)));
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
			SETTINGS_PROFILE_UNLIMITED_SCROLL_KEY, SETTINGS_PROFILE_BACKSPACE_BINDING_KEY, SETTINGS_PROFILE_DELETE_BINDING_KEY,
            SETTINGS_PROFILE_CJK_WIDTH_KEY, SETTINGS_PROFILE_CURSOR_BLINK_MODE_KEY
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

	void spawnTerminalProcess(string initialPath) {
		GSpawnFlags flags;
        string shell = terminal.getUserShell();
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
		terminal.spawnSync(VtePtyFlags.DEFAULT, initialPath, args, [""], flags, null, null, gpid, null);
		terminal.grabFocus();
	}


public:

	this(string profileUUID) {
		super(Orientation.VERTICAL, 0);
        _profileUUID = profileUUID;
		gsProfile = prfMgr.getProfileSettings(profileUUID);
        gsShortcuts = new GSettings(SETTINGS_PROFILE_KEY_BINDINGS_ID);
		createUI();
		applyPreferences();
		gsProfile.addOnChanged(delegate(string key, Settings) { 
            applyPreference(key); 
        });
	}

	void initTerminal(string initialPath, bool firstRun) {
        initialWorkingDir = initialPath;
        spawnTerminalProcess(initialPath);
		if (firstRun) {
			terminal.setSize(gsProfile.getInt(SETTINGS_PROFILE_SIZE_COLUMNS_KEY), gsProfile.getInt(SETTINGS_PROFILE_SIZE_ROWS_KEY));
		}
	}

	void focusTerminal() {
		terminal.grabFocus();
	}

	bool isProcessRunning() {
		int fd = terminal.getPty().getFd();
		pid_t fg = tcgetpgrp(fd);
		trace(format("fg=%d gpid=%d", fg, gpid));
		return (fg != -1 && fg != gpid);
	}
    
    void echoKeyPressEvent(Event event) {
        //TODO - Look at this some more, feedChild seems to work fine but would really preferences
        //to simply fire the key event against the terminal. The problem is that while te event is set to 
        //the right terminal window, the key always gets handled by the terminal with focus
        // 
        //event.key.window = terminal.getWindow().getWindowStruct();
        //trace(format("Getting GDKWindow Pointer %s for terminal %d", to!string(event.getWindow().getWindowStruct()), terminalID));
        //Main.doEvent(event);
        string data = Str.toString(event.key.str,event.key.length);
        terminal.feedChild(data, data.length);
    }
    
    @property string currentDirectory() {
        if (gpid == 0) return null; 
        string hostname;
        return URI.filenameFromUri(terminal.getCurrentDirectoryUri(), hostname);
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
    
    @property ulong terminalID() {
        return _terminalID;
    }
    
    @property void terminalID(ulong ID) {
        if (this._terminalID != ID) {
            this._terminalID = ID;
            updateTitle();
        }
    }
    
	void addOnTerminalRequestSplit(OnTerminalRequestSplit dlg) {
		terminalRequestSplitDelegates ~= dlg;
	}

	void removeOnTerminalRequestSplit(OnTerminalRequestSplit dlg) {
		gx.util.array.remove(terminalRequestSplitDelegates, dlg);
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

//Terminal Exited Info Bar, used when Hold option for exiting terminal is selected
package class TerminalInfoBar: InfoBar {

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
