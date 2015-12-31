/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.appwindow;

import std.conv;
import std.experimental.logger;
import std.file;
import std.format;
import std.json;

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
import gio.Settings: GSettings = Settings;
import gio.SimpleAction;
import gio.SimpleActionGroup;

import glib.Util;
import glib.Variant: GVariant = Variant;
import glib.VariantType: GVariantType = VariantType;

import gtk.Box;
import gtk.Button;
import gtk.FileChooserDialog;
import gtk.FileFilter;
import gtk.HeaderBar;
import gtk.Image;
import gtk.MenuButton;
import gtk.MessageDialog;
import gtk.Notebook;
import gtk.Popover;
import gtk.Widget;

import vte.Pty;
import vte.Terminal;

import gx.gtk.actions;
import gx.gtk.tablabel;
import gx.gtk.util;
import gx.i18n.l10n;

import gx.terminix.constants;
import gx.terminix.preferences;
import gx.terminix.session;

class AppWindow : ApplicationWindow {

private:

	enum DEFAULT_SESSION_NAME = "Default";

    enum ACTION_PREFIX = "session";
	enum ACTION_SESSION_LIST = "list";
    enum ACTION_SESSION_NAME = "name";
    enum ACTION_SESSION_NEXT_TERMINAL = "switch-to-next-terminal";
    enum ACTION_SESSION_PREV_TERMINAL = "switch-to-previous-terminal";
    enum ACTION_SESSION_TERMINAL_X = "switch-to-terminal-";
    enum ACTION_SESSION_SAVE = "save";
    enum ACTION_SESSION_SAVE_AS = "save-as";
    enum ACTION_SESSION_LOAD = "load";
    enum ACTION_SESSION_SYNC_INPUT = "synchronize-input";

	Notebook nb;
	HeaderBar hb;
    
	GMenu sessionMenu;
    SimpleAction saSessionSelect;
    MenuButton mbSessions;
    
    SimpleActionGroup sessionActions;
    MenuButton mbSessionActions;
    SimpleAction saSyncInput;    

	void createUI() {
        createActions();

		//Header Bar
		hb = new HeaderBar();
		hb.setShowCloseButton(true);
		hb.setTitle(APPLICATION_NAME);
		this.setTitlebar(hb);

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
		mbSessions.addOnButtonPress(delegate(Event e, Widget w) {
            buildSessionMenu();
            return false;
        });
		hb.packStart(mbSessions);

		//New tab button
		Button btnNew = new Button("tab-new-symbolic", IconSize.BUTTON);
		btnNew.setFocusOnClick(false);
		btnNew.setAlwaysShowImage(true);
		btnNew.addOnClicked(delegate(Button button) {
            createSession();
		});
		btnNew.setTooltipText(_("Create a new session"));
		hb.packStart(btnNew);

		//Session Actions
	    mbSessionActions = new MenuButton();
		mbSessionActions.setFocusOnClick(false);
		Image iHamburger = new Image("open-menu-symbolic", IconSize.MENU);
		mbSessionActions.add(iHamburger);
		mbSessionActions.setPopover(createPopover(mbSessionActions));
		hb.packEnd(mbSessionActions);

		//Notebook
		nb = new Notebook();
		nb.setShowTabs(false);
		nb.addOnSwitchPage(delegate(Widget page, uint pageNo, Notebook) {
			Session session = cast(Session) page;
			updateTitle(session);
            updateUIState();
			session.focusRestore();
            saSyncInput.setState(new GVariant(session.synchronizeInput));
		}, ConnectFlags.AFTER);
		this.add(nb);

        //Create an initial session using default session name and profile
        createSession(_(DEFAULT_SESSION_NAME), prfMgr.getDefaultProfile());
	}

    void createActions() {
        GSettings gsShortcuts = new GSettings(SETTINGS_PROFILE_KEY_BINDINGS_ID);
		sessionActions = new SimpleActionGroup();
        
        //Select Session
        GVariant pu = new GVariant(0);
        saSessionSelect = registerAction(sessionActions, ACTION_PREFIX, ACTION_SESSION_LIST, null, delegate(GVariant value, SimpleAction sa) {
            nb.setCurrentPage(value.getInt32());
            saSessionSelect.setState(value);
            mbSessions.setActive(false);
        }, pu.getType(), pu);

        //Create Switch to Terminal (0..9) actions
        for(int i=0; i<=9; i++) {
            registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_TERMINAL_X ~ to!string(i), gsShortcuts, delegate(Variant, SimpleAction sa) { 
                Session session = getCurrentSession();
                if (session !is null) {
                    ulong terminalID = to!ulong(sa.getName()[$-1..$]);
                    session.focusTerminal(terminalID);
                }
            });
        }
        /* TODO - GTK doesn't support settings Tab for accelerators, need to look into this more */
		registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_NEXT_TERMINAL, gsShortcuts, delegate(Variant, SimpleAction) { 
            Session session = getCurrentSession();
            if (session !is null) session.focusNext();
        });
		registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_PREV_TERMINAL, gsShortcuts, delegate(Variant, SimpleAction) { 
            Session session = getCurrentSession();
            if (session !is null) session.focusPrevious();
        });
        
        //Load Session
		registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_LOAD, gsShortcuts, delegate(Variant, SimpleAction) { 
            loadSession();
        });
        
        //Save Session
		registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_SAVE, gsShortcuts, delegate(Variant, SimpleAction) { 
            saveSession(false);
        });

        //Save As Session
		registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_SAVE_AS, gsShortcuts, delegate(Variant, SimpleAction) { 
            saveSession(true);
        });
        
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
        GVariant state = new GVariant(false);
		saSyncInput = registerActionWithSettings(sessionActions, ACTION_PREFIX, ACTION_SESSION_SYNC_INPUT, gsShortcuts, delegate(GVariant value, SimpleAction sa) {
            bool newState = !sa.getState().getBoolean();
            sa.setState(new GVariant(newState));
            getCurrentSession().synchronizeInput = newState;            
            mbSessionActions.setActive(false);
        }, null, state);
        
		insertActionGroup(ACTION_PREFIX, sessionActions);       
    }
    
    Popover createPopover(Widget parent) {
		GMenu model = new GMenu();

        GMenu mFileSection = new GMenu();
        mFileSection.appendItem(new GMenuItem(_("Load..."), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_LOAD)));
        mFileSection.appendItem(new GMenuItem(_("Save"), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_SAVE)));
        mFileSection.appendItem(new GMenuItem(_("Save As..."), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_SAVE_AS)));
        model.appendSection(null, mFileSection);
        
        GMenu mSessionSection = new GMenu();
        mSessionSection.appendItem(new GMenuItem(_("Name..."), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_NAME)));
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

	void createNewSession(string name, string profileUUID) {
        Session session = new Session(name, profileUUID, nb.getNPages() == 0);
        addSession(session);
	}
    
    void addSession(Session session) {
        session.addOnSessionClose(&onSessionClose);
		int index = nb.appendPage(session, session.name);
		nb.showAll();
		nb.setCurrentPage(index);
        updateUIState();
    }

	void updateUIState() {
	}
    
	void updateTitle(Session session) {
		if (session) {
			hb.setTitle(APPLICATION_NAME ~ ": " ~ session.name);
		} else {
			hb.setTitle(APPLICATION_NAME);
		}
	}

	void onSessionClose(Session session) {
		nb.remove(session);
		updateUIState();
		//Close Window if there are no pages
		if (nb.getNPages() == 0) {
			this.close();
		}
	}

	/**
     * Dynamically build actions and menu items to show in session popover
     */
    void buildSessionMenu() {
        sessionMenu.removeAll();
        saSessionSelect.setState(new GVariant(nb.getCurrentPage()));
        for(int i=0; i<nb.getNPages; i++) {
            Session session = cast(Session) nb.getNthPage(i);
            GMenuItem menuItem = new GMenuItem(session.name, getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_LIST));
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

	void onCompositedChanged(Widget widget) {
		trace("Composite changed");
		updateVisual();
	}
    
    Session getCurrentSession() {
        if (nb.getCurrentPage<0) return null;
        else return cast(Session) nb.getNthPage(nb.getCurrentPage);
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
    
    void loadSession() {
        FileChooserDialog fcd = new FileChooserDialog(_("Load Session"), this, FileChooserAction.OPEN);
        scope(exit) {fcd.destroy();}
        addFilters(fcd);
        fcd.setDefaultResponse(ResponseType.OK);
        if (fcd.run() == ResponseType.OK) {
            try {
                string filename = fcd.getFilename();
                string text = readText(filename);
                JSONValue value = parseJSON(text);
                Session session = new Session(value, filename, nb.getAllocatedWidth(), nb.getAllocatedHeight(), nb.getNPages() == 0);
                addSession(session);
            } catch (Exception e) {
                fcd.hide();
                error(e);
                showErrorDialog(this, _("Could not load session due to unexpected error.") ~ "\n" ~ e.msg, _("Error Loading Session"));
            }
        }
    }
    
    void saveSession(bool showSaveAsDialog = true) {
        Session session = getCurrentSession();
        string filename = session.filename;
        if (filename.length <= 0 || showSaveAsDialog) {
            FileChooserDialog fcd = new FileChooserDialog(_("Save Session"), this, FileChooserAction.SAVE);
            scope (exit) fcd.destroy();
            
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

public:

	this(Application application) {
		super(application);
		setTitle(_("Terminix"));
		setIconName("terminal");

		updateVisual();
		createUI();

		addOnDelete(&onWindowClosed);
		addOnCompositedChanged(&onCompositedChanged);
	}

	void createSession() {
        string value;
        SessionProperties sp = new SessionProperties(this, _(DEFAULT_SESSION_NAME), prfMgr.getDefaultProfile());
        scope(exit) {sp.destroy();}
        sp.showAll();
        if (sp.run() == ResponseType.OK) {
            createSession(sp.name, sp.profileUUID);
        }  
	}

	void createSession(string name, string profileUUID) {
		createNewSession(name, profileUUID);
	}
}