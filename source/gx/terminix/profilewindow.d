/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.profilewindow;

import std.algorithm;
import std.array;
import std.conv;
import std.csv;
import std.experimental.logger;
import std.format;
import std.string;
import std.typecons;

import gdk.RGBA;

import gio.Settings : GSettings = Settings;

import glib.GException;
import glib.Regex : GRegex = Regex;
import glib.URI;
import glib.Util;

import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Box;
import gtk.Button;
import gtk.CellRendererCombo;
import gtk.CellRendererText;
import gtk.CellRendererToggle;
import gtk.CheckButton;
import gtk.ColorButton;
import gtk.ComboBox;
import gtk.ComboBoxText;
import gtk.Dialog;
import gtk.Entry;
import gtk.FontButton;
import gtk.Grid;
import gtk.HeaderBar;
import gtk.Image;
import gtk.Label;
import gtk.ListStore;
import gtk.MenuButton;
import gtk.Notebook;
import gtk.Popover;
import gtk.Scale;
import gtk.ScrolledWindow;
import gtk.SpinButton;
import gtk.Switch;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;
import gtk.Window;

import gx.gtk.dialog;
import gx.gtk.util;
import gx.gtk.vte;

import gx.i18n.l10n;

import gx.util.string;

import gx.terminix.application;
import gx.terminix.colorschemes;
import gx.terminix.constants;
import gx.terminix.encoding;
import gx.terminix.preferences;

/**
 * UI used for managing preferences for a specific profile
 */
class ProfileWindow : ApplicationWindow {

private:

    GSettings gsProfile;
    ProfileInfo profile;
    Notebook nb;

    void createUI() {
        HeaderBar hb = new HeaderBar();
        hb.setShowCloseButton(true);
        string name = gsProfile.getString(SETTINGS_PROFILE_VISIBLE_NAME_KEY);
        if (profile.uuid !is null && profile.uuid.length > 0) {
            hb.setTitle(format(_("Editing Profile: %s"), name));
        } else {
            hb.setTitle(format(_("New Profile"), name));
        }
        this.setTitlebar(hb);
        this.setDefaultSize(400, -1);

        nb = new Notebook();
        nb.setHexpand(true);
        nb.setVexpand(true);

        nb.appendPage(new GeneralPage(profile, gsProfile), _("General"));
        nb.appendPage(new CommandPage(profile, gsProfile), _("Command"));
        nb.appendPage(new ColorPage(profile, gsProfile), _("Color"));
        nb.appendPage(new ScrollPage(profile, gsProfile), _("Scrolling"));
        nb.appendPage(new CompatibilityPage(profile, gsProfile), _("Compatibility"));
        nb.appendPage(new AdvancedPage(profile, gsProfile), _("Advanced"));
        
        add(nb);
    }

    void onWindowDestroyed(Widget) {
        trace("Window destroyed");
        terminix.removeProfileWindow(this);
    }

public:

    this(Terminix app, ProfileInfo profile) {
        super(app);
        this.profile = profile;
        gsProfile = prfMgr.getProfileSettings(profile.uuid);
        createUI();
        app.addProfileWindow(this);
        addOnDestroy(&onWindowDestroyed);
    }

    @property string uuid() {
        return profile.uuid;
    }
}

/**
 * Page that handles the general settings for the profile
 */
class GeneralPage : Box {

private:

    ProfileInfo profile;
    GSettings gsProfile;

    void createUI() {

        setMarginLeft(18);
        setMarginRight(18);
        setMarginTop(18);
        setMarginBottom(18);

        int row = 0;
        Grid grid = new Grid();
        grid.setColumnSpacing(12);
        grid.setRowSpacing(6);

        //Profile Name
        Label lblName = new Label(_("Profile name"));
        lblName.setHalign(Align.END);
        grid.attach(lblName, 0, row, 1, 1);
        Entry eName = new Entry();
        gsProfile.bind(SETTINGS_PROFILE_VISIBLE_NAME_KEY, eName, "text", GSettingsBindFlags.DEFAULT);
        grid.attach(eName, 1, row, 1, 1);
        row++;
        //Profile ID
        Label lblId = new Label(format(_("ID: %s"), profile.uuid));
        lblId.setHalign(Align.START);
        lblId.setSensitive(false);
        grid.attach(lblId, 1, row, 1, 1);
        row++;

        //Terminal Size
        Label lblSize = new Label(_("Terminal size"));
        lblSize.setHalign(Align.END);
        grid.attach(lblSize, 0, row, 1, 1);
        SpinButton sbColumn = new SpinButton(16, 511, 1);
        gsProfile.bind(SETTINGS_PROFILE_SIZE_COLUMNS_KEY, sbColumn, "value", GSettingsBindFlags.DEFAULT);
        SpinButton sbRow = new SpinButton(4, 511, 1);
        gsProfile.bind(SETTINGS_PROFILE_SIZE_ROWS_KEY, sbRow, "value", GSettingsBindFlags.DEFAULT);

        Box box = new Box(Orientation.HORIZONTAL, 5);
        box.add(sbColumn);
        Label lblColumns = new Label(_("columns"));
        lblColumns.setMarginRight(6);
        lblColumns.setSensitive(false);
        box.add(lblColumns);

        box.add(sbRow);
        Label lblRows = new Label(_("rows"));
        lblRows.setMarginRight(6);
        lblRows.setSensitive(false);
        box.add(lblRows);

        Button btnReset = new Button(_("Reset"));
        btnReset.addOnClicked(delegate(Button) {
           gsProfile.reset(SETTINGS_PROFILE_SIZE_COLUMNS_KEY);
           gsProfile.reset(SETTINGS_PROFILE_SIZE_ROWS_KEY);
            
        });
        box.add(btnReset);
        grid.attach(box, 1, row, 1, 1);
        row++;

        //Cursor Shape
        Label lblCursorShape = new Label(_("Cursor"));
        lblCursorShape.setHalign(Align.END);
        grid.attach(lblCursorShape, 0, row, 1, 1);
        ComboBox cbCursorShape = createNameValueCombo([_("Block"), _("IBeam"), _("Underline")], [SETTINGS_PROFILE_CURSOR_SHAPE_BLOCK_VALUE,
                SETTINGS_PROFILE_CURSOR_SHAPE_IBEAM_VALUE, SETTINGS_PROFILE_CURSOR_SHAPE_UNDERLINE_VALUE]);
        gsProfile.bind(SETTINGS_PROFILE_CURSOR_SHAPE_KEY, cbCursorShape, "active-id", GSettingsBindFlags.DEFAULT);
        grid.attach(cbCursorShape, 1, row, 1, 1);
        row++;

        //Blink Mode
        Label lblBlinkMode = new Label(_("Blink mode"));
        lblBlinkMode.setHalign(Align.END);
        grid.attach(lblBlinkMode, 0, row, 1, 1);
        ComboBox cbBlinkMode = createNameValueCombo([_("System"), _("On"), _("Off")], SETTINGS_PROFILE_CURSOR_BLINK_MODE_VALUES);
        gsProfile.bind(SETTINGS_PROFILE_CURSOR_BLINK_MODE_KEY, cbBlinkMode, "active-id", GSettingsBindFlags.DEFAULT);
        grid.attach(cbBlinkMode, 1, row, 1, 1);
        row++;

        //Terminal Bell
        Label lblBell = new Label(_("Terminal bell"));
        lblBell.setHalign(Align.END);
        grid.attach(lblBell, 0, row, 1, 1);
        ComboBox cbBell = createNameValueCombo([_("None"), _("Sound"), _("Icon"), _("Icon and Sound")], SETTINGS_PROFILE_TERMINAL_BELL_VALUES);
        gsProfile.bind(SETTINGS_PROFILE_TERMINAL_BELL_KEY, cbBell, "active-id", GSettingsBindFlags.DEFAULT);
        grid.attach(cbBell, 1, row, 1, 1);
        row++;

        //Terminal Title
        Label lblTerminalTitle = new Label(_("Terminal title"));
        lblTerminalTitle.setHalign(Align.END);
        grid.attach(lblTerminalTitle, 0, row, 1, 1);
        Entry eTerminalTitle = new Entry();
        gsProfile.bind(SETTINGS_PROFILE_TITLE_KEY, eTerminalTitle, "text", GSettingsBindFlags.DEFAULT);
        grid.attach(eTerminalTitle, 1, row, 1, 1);
        row++;

        add(grid);

        //Text Appearance
        Box b = new Box(Orientation.VERTICAL, 6);
        b.setMarginTop(18);
        Label lblTitle = new Label(format("<b>%s</b>", _("Text Appearance")));
        lblTitle.setUseMarkup(true);
        lblTitle.setHalign(Align.START);
        b.add(lblTitle);

        //Allow Bold
        CheckButton cbBold = new CheckButton(_("Allow bold text"));
        gsProfile.bind(SETTINGS_PROFILE_ALLOW_BOLD_KEY, cbBold, "active", GSettingsBindFlags.DEFAULT);
        b.add(cbBold);

        //Rewrap on resize
        CheckButton cbRewrap = new CheckButton(_("Rewrap on resize"));
        gsProfile.bind(SETTINGS_PROFILE_REWRAP_KEY, cbRewrap, "active", GSettingsBindFlags.DEFAULT);
        b.add(cbRewrap);

        //Custom Font
        Box bFont = new Box(Orientation.HORIZONTAL, 12);
        CheckButton cbCustomFont = new CheckButton(_("Custom font"));
        gsProfile.bind(SETTINGS_PROFILE_USE_SYSTEM_FONT_KEY, cbCustomFont, "active", GSettingsBindFlags.DEFAULT | GSettingsBindFlags.INVERT_BOOLEAN);
        bFont.add(cbCustomFont);

        //Font Selector
        FontButton fbFont = new FontButton();
        fbFont.setTitle(_("Choose A Terminal Font"));
        gsProfile.bind(SETTINGS_PROFILE_FONT_KEY, fbFont, "font-name", GSettingsBindFlags.DEFAULT);
        gsProfile.bind(SETTINGS_PROFILE_USE_SYSTEM_FONT_KEY, fbFont, "sensitive", GSettingsBindFlags.GET | GSettingsBindFlags.NO_SENSITIVITY | GSettingsBindFlags
                .INVERT_BOOLEAN);
        bFont.add(fbFont);
        b.add(bFont);

        add(b);
    }

public:

    this(ProfileInfo profile, GSettings gsProfile) {
        super(Orientation.VERTICAL, 5);
        this.profile = profile;
        this.gsProfile = gsProfile;
        createUI();
    }

}

/**
 * The profile page to manage color preferences
 */
class ColorPage : Box {

private:
    immutable string PALETTE_COLOR_INDEX_KEY = "index";

    ProfileInfo profile;
    GSettings gsProfile;

    ColorScheme[] schemes;
    bool schemeChangingLock = false;

    CheckButton cbUseThemeColors;
    ComboBoxText cbScheme;
    ColorButton cbFG;
    ColorButton cbBG;
    CheckButton cbUseHighlightColor;
    ColorButton cbHighlightFG;
    ColorButton cbHighlightBG;
    CheckButton cbUseCursorColor;
    ColorButton cbCursorFG;
    ColorButton cbCursorBG;
    CheckButton cbUseDimColor;
    ColorButton cbDimBG;
    ColorButton[16] cbPalette;

    void createUI() {
        setMarginLeft(18);
        setMarginRight(18);
        setMarginTop(18);
        setMarginBottom(18);

        Grid grid = new Grid();
        grid.setColumnSpacing(12);
        grid.setRowSpacing(18);

        int row = 0;
        Label lblScheme = new Label(format("<b>%s</b>", _("Color scheme")));
        lblScheme.setUseMarkup(true);
        lblScheme.setHalign(Align.END);
        grid.attach(lblScheme, 0, row, 1, 1);

        cbScheme = new ComboBoxText(false);
        cbScheme.setFocusOnClick(false);
        foreach (scheme; schemes) {
            cbScheme.append(scheme.id, scheme.name);
        }
        cbScheme.append("custom", _("Custom"));
        cbScheme.setHalign(Align.FILL);
        cbScheme.addOnChanged(delegate(ComboBoxText cb) {
            if (cb.getActive() < schemes.length) {
                ColorScheme scheme = schemes[cb.getActive];
                setColorScheme(scheme);
            }
        });
        grid.attach(cbScheme, 1, row, 1, 1);
        row++;

        Label lblPalette = new Label(format("<b>%s</b>", _("Color palette")));
        lblPalette.setUseMarkup(true);
        lblPalette.setHalign(Align.END);
        lblPalette.setValign(Align.START);
        grid.attach(lblPalette, 0, row, 1, 1);
        grid.attach(createColorGrid(row), 1, row, 1, 1);
        row++;

        Label lblOptions = new Label(format("<b>%s</b>", _("Options")));
        lblOptions.setUseMarkup(true);
        lblOptions.setValign(Align.START);
        lblOptions.setHalign(Align.END);
        grid.attach(lblOptions, 0, row, 1, 1);
        grid.attach(createOptions(), 1, row, 1, 1);
        row++;

        add(grid);
    }
    
    Widget createOptions() {
        Box box = new Box(Orientation.VERTICAL, 6);
        
        cbUseThemeColors = new CheckButton(_("Use theme colors for foreground/background"));
        cbUseThemeColors.addOnToggled(delegate(ToggleButton) { setCustomScheme(); });
        gsProfile.bind(SETTINGS_PROFILE_USE_THEME_COLORS_KEY, cbUseThemeColors, "active", GSettingsBindFlags.DEFAULT);
        
        MenuButton mbAdvanced = new MenuButton();
        mbAdvanced.add(createBox(Orientation.HORIZONTAL, 6, [new Label(_("Advanced")), new Image("pan-down-symbolic", IconSize.MENU)]));
        mbAdvanced.setPopover(createPopover(mbAdvanced));
        gsProfile.bind(SETTINGS_PROFILE_USE_THEME_COLORS_KEY, mbAdvanced, "sensitive", GSettingsBindFlags.GET | GSettingsBindFlags.NO_SENSITIVITY | GSettingsBindFlags
                .INVERT_BOOLEAN);
        box.add(createBox(Orientation.HORIZONTAL, 6, [cbUseThemeColors, mbAdvanced]));
        
        Grid gSliders = new Grid();
        gSliders.setColumnSpacing(6);
        gSliders.setRowSpacing(6);
        int row = 0;
        
        GSettings gsSettings = new GSettings(SETTINGS_ID);
        if (gsSettings.getBoolean(SETTINGS_ENABLE_TRANSPARENCY_KEY)) {
            Label lblTransparent = new Label(_("Transparency"));
            lblTransparent.setHalign(Align.END);
            lblTransparent.setHexpand(false);
            gSliders.attach(lblTransparent, 0, row, 1, 1);

            Scale sTransparent = new Scale(Orientation.HORIZONTAL, 0, 100, 10);
            sTransparent.setDrawValue(false);
            sTransparent.setHexpand(true);
            sTransparent.setHalign(Align.FILL);
            gsProfile.bind(SETTINGS_PROFILE_BG_TRANSPARENCY_KEY, sTransparent.getAdjustment(), "value", GSettingsBindFlags.DEFAULT);
            gSliders.attach(sTransparent, 1, row, 1, 1);
            row++;
        }
        
        Label lblDim = new Label(_("Unfocused dim"));
        lblDim.setHalign(Align.END);
        lblDim.setHexpand(false);
        gSliders.attach(lblDim, 0, row, 1, 1);
        
        Scale sDim = new Scale(Orientation.HORIZONTAL, 0, 100, 10);
        sDim.setDrawValue(false);
        sDim.setHexpand(true);
        sDim.setHalign(Align.FILL);
        gsProfile.bind(SETTINGS_PROFILE_DIM_TRANSPARENCY_KEY, sDim.getAdjustment(), "value", GSettingsBindFlags.DEFAULT);
        gSliders.attach(sDim, 1, row, 1, 1);

        box.add(gSliders);
        return box;        
    }
    
    Popover createPopover(Widget widget) {
        
        ColorButton createColorButton(string settingKey, string title, string sensitiveKey) {
            ColorButton result = new ColorButton(parseColor(gsProfile.getString(settingKey)));
            if (sensitiveKey.length > 0) {
                gsProfile.bind(sensitiveKey, result, "sensitive", GSettingsBindFlags.GET | GSettingsBindFlags.NO_SENSITIVITY);
            }
            result.setTitle(title);
            result.setHalign(Align.START);
            result.addOnColorSet(delegate(ColorButton cb) {
                setCustomScheme();
                RGBA color;
                cb.getRgba(color);
                gsProfile.setString(settingKey, rgbaTo16bitHex(color, false, true));
            });
            return result;
        }
        
        Popover popAdvanced = new Popover(widget);
        
        Grid gColors = new Grid();
        gColors.setColumnSpacing(6);
        gColors.setRowSpacing(6);
        setAllMargins(gColors, 6);

        int row = 0;
        gColors.attach(new Label(_("Text")), 1, row, 1, 1);
        gColors.attach(new Label(_("Background")), 2, row, 1, 1);
        row++;
        
        //Cursor
        cbUseCursorColor = new CheckButton(_("Cursor"));
        cbUseCursorColor.addOnToggled(delegate(ToggleButton) { setCustomScheme(); });
        gsProfile.bind(SETTINGS_PROFILE_USE_CURSOR_COLOR_KEY, cbUseCursorColor, "active", GSettingsBindFlags.DEFAULT);
        if (checkVTEVersionNumber(0, 44)) {
            gColors.attach(cbUseCursorColor, 0, row, 1, 1);
        }
        
        cbCursorFG = createColorButton(SETTINGS_PROFILE_CURSOR_FG_COLOR_KEY, _("Select Cursor Foreground Color"), SETTINGS_PROFILE_USE_CURSOR_COLOR_KEY);
        gColors.attach(cbCursorFG, 1, row, 1, 1);
        cbCursorBG = createColorButton(SETTINGS_PROFILE_CURSOR_BG_COLOR_KEY, _("Select Cursor Background Color"), SETTINGS_PROFILE_USE_CURSOR_COLOR_KEY);
        gColors.attach(cbCursorBG, 2, row, 1, 1);
        row++;

        //Highlight
        cbUseHighlightColor = new CheckButton(_("Highlight"));
        cbUseHighlightColor.addOnToggled(delegate(ToggleButton) { setCustomScheme(); });
        gsProfile.bind(SETTINGS_PROFILE_USE_HIGHLIGHT_COLOR_KEY, cbUseHighlightColor, "active", GSettingsBindFlags.DEFAULT);
        gColors.attach(cbUseHighlightColor, 0, row, 1, 1);
        
        cbHighlightFG = createColorButton(SETTINGS_PROFILE_HIGHLIGHT_FG_COLOR_KEY, _("Select Highlight Foreground Color"), SETTINGS_PROFILE_USE_HIGHLIGHT_COLOR_KEY);
        gColors.attach(cbHighlightFG, 1, row, 1, 1);
        cbHighlightBG = createColorButton(SETTINGS_PROFILE_HIGHLIGHT_BG_COLOR_KEY, _("Select Highlight Background Color"), SETTINGS_PROFILE_USE_HIGHLIGHT_COLOR_KEY);
        gColors.attach(cbHighlightBG, 2, row, 1, 1);
        row++;
        
        //Dim
        cbUseDimColor = new CheckButton(_("Dim"));
        cbUseDimColor.addOnToggled(delegate(ToggleButton) { setCustomScheme(); });
        gsProfile.bind(SETTINGS_PROFILE_USE_DIM_COLOR_KEY, cbUseDimColor, "active", GSettingsBindFlags.DEFAULT);
        gColors.attach(cbUseDimColor, 0, row, 1, 1);
        
        cbDimBG = createColorButton(SETTINGS_PROFILE_DIM_COLOR_KEY, _("Select Dim Color"), SETTINGS_PROFILE_USE_DIM_COLOR_KEY);
        gColors.attach(cbDimBG, 2, row, 1, 1);
        gColors.showAll();
        popAdvanced.add(gColors);
        return popAdvanced;
    }

    Grid createColorGrid(int row) {
        Grid gColors = new Grid();
        gColors.setColumnSpacing(6);
        gColors.setRowSpacing(6);
        cbBG = new ColorButton(parseColor(gsProfile.getString(SETTINGS_PROFILE_BG_COLOR_KEY)));
        gsProfile.bind(SETTINGS_PROFILE_USE_THEME_COLORS_KEY, cbBG, "sensitive", GSettingsBindFlags.GET | GSettingsBindFlags.NO_SENSITIVITY | GSettingsBindFlags
                .INVERT_BOOLEAN);
        cbBG.setTitle(_("Select Background Color"));
        cbBG.addOnColorSet(delegate(ColorButton cb) {
            setCustomScheme();
            RGBA color;
            cb.getRgba(color);
            gsProfile.setString(SETTINGS_PROFILE_BG_COLOR_KEY, rgbaTo16bitHex(color, false, true));
        });
        gColors.attach(cbBG, 0, row, 1, 1);
        gColors.attach(new Label(_("Background")), 1, row, 2, 1);

        cbFG = new ColorButton(parseColor(gsProfile.getString(SETTINGS_PROFILE_FG_COLOR_KEY)));
        gsProfile.bind(SETTINGS_PROFILE_USE_THEME_COLORS_KEY, cbFG, "sensitive", GSettingsBindFlags.GET | GSettingsBindFlags.NO_SENSITIVITY | GSettingsBindFlags
                .INVERT_BOOLEAN);
        cbFG.setTitle(_("Select Foreground Color"));
        cbFG.addOnColorSet(delegate(ColorButton cb) {
            setCustomScheme();
            RGBA color;
            cb.getRgba(color);
            gsProfile.setString(SETTINGS_PROFILE_FG_COLOR_KEY, rgbaTo16bitHex(color, false, true));
        });

        Label lblSpacer = new Label(" ");
        lblSpacer.setHexpand(true);
        gColors.attach(lblSpacer, 3, row, 1, 1);

        gColors.attach(cbFG, 4, row, 1, 1);
        gColors.attach(new Label(_("Foreground")), 5, row, 2, 1);
        cbBG.setTitle(_("Select Foreground Color"));
        row++;

        string[] colorValues = gsProfile.getStrv(SETTINGS_PROFILE_PALETTE_COLOR_KEY);
        immutable string[8] colors = [_("Black"), _("Red"), _("Green"), _("Orange"), _("Blue"), _("Purple"), _("Turquoise"), _("Grey")];
        int col = 0;
        for (int i = 0; i < colors.length; i++) {
            ColorButton cbNormal = new ColorButton(parseColor(colorValues[i]));
            cbNormal.addOnColorSet(&onPaletteColorSet);
            cbNormal.setData(PALETTE_COLOR_INDEX_KEY, cast(void*) i);
            cbNormal.setTitle(format(_("Select %s Color"), colors[i]));
            gColors.attach(cbNormal, col, row, 1, 1);
            cbPalette[i] = cbNormal;

            ColorButton cbLight = new ColorButton(parseColor(colorValues[i + 8]));
            cbLight.addOnColorSet(&onPaletteColorSet);
            cbLight.setData(PALETTE_COLOR_INDEX_KEY, cast(void*) i + 8);
            cbLight.setTitle(format(_("Select %s Light Color"), colors[i]));
            gColors.attach(cbLight, col + 1, row, 1, 1);
            cbPalette[i + 8] = cbLight;

            gColors.attach(new Label(colors[i]), col + 2, row, 1, 1);
            if (i == 3) {
                row = row - 3;
                col = 4;
            } else {
                row++;
            }
        }
        return gColors;
    }

    void onPaletteColorSet(ColorButton cb) {
        setCustomScheme();
        RGBA color;
        cb.getRgba(color);
        string[] colorValues = gsProfile.getStrv(SETTINGS_PROFILE_PALETTE_COLOR_KEY);
        colorValues[cast(int) cb.getData(PALETTE_COLOR_INDEX_KEY)] = rgbaTo16bitHex(color, false, true);
        gsProfile.setStrv(SETTINGS_PROFILE_PALETTE_COLOR_KEY, colorValues);
    }

    RGBA parseColor(string color) {
        RGBA result = new RGBA();
        result.parse(color);
        return result;
    }

    /**
     * This method checks to see if a color scheme matches
     * the current color settings and then set the scheme combobox
     * to that scheme. This provides the user some feedback that
     * they have selected a matching color scheme.
     *
     * Since we don't store the scheme in GSettings this is 
     * really useful when re-loading the app to show the same
     * scheme they selected previously instead of custom
     */
    void initColorSchemeCombo() {
        //Initialize ColorScheme combobox
        ColorScheme scheme = new ColorScheme();
        scheme.useThemeColors = cbUseThemeColors.getActive();
        foreach (i, cb; cbPalette) {
            cb.getRgba(scheme.palette[i]);
        }
        cbFG.getRgba(scheme.foreground);
        cbBG.getRgba(scheme.background);
        scheme.useHighlightColor = cbUseHighlightColor.getActive();
        cbHighlightFG.getRgba(scheme.highlightFG);
        cbHighlightBG.getRgba(scheme.highlightBG);
        scheme.useCursorColor = cbUseCursorColor.getActive();
        cbCursorFG.getRgba(scheme.cursorFG);
        cbCursorBG.getRgba(scheme.cursorBG);
        scheme.useDimColor = cbUseDimColor.getActive();
        cbDimBG.getRgba(scheme.dimColor);         
        
        int index = findSchemeByColors(schemes, scheme);
        if (index < 0)
            cbScheme.setActive(to!int(schemes.length));
        else
            cbScheme.setActive(index);
    }
    
    /**
     * Sets a color scheme and updates profile and controls
     */
    void setColorScheme(ColorScheme scheme) {
        schemeChangingLock = true;
        scope (exit) {
            schemeChangingLock = false;
        }
        gsProfile.setBoolean(SETTINGS_PROFILE_USE_THEME_COLORS_KEY, scheme.useThemeColors);
        if (!scheme.useThemeColors) {
            //System Colors
            cbFG.setRgba(scheme.foreground);
            cbBG.setRgba(scheme.background);
            gsProfile.setString(SETTINGS_PROFILE_FG_COLOR_KEY, rgbaTo8bitHex(scheme.foreground, false, true));
            gsProfile.setString(SETTINGS_PROFILE_BG_COLOR_KEY, rgbaTo8bitHex(scheme.background, false, true));
            //Dim colors
            gsProfile.setBoolean(SETTINGS_PROFILE_USE_DIM_COLOR_KEY, scheme.useDimColor);
            if (scheme.useDimColor) {
                cbDimBG.setRgba(scheme.dimColor);
            }
            //Highlight colors
            gsProfile.setBoolean(SETTINGS_PROFILE_USE_HIGHLIGHT_COLOR_KEY, scheme.useHighlightColor);
            if (scheme.useHighlightColor) {
                cbHighlightFG.setRgba(scheme.highlightFG);
                cbHighlightBG.setRgba(scheme.highlightBG);
            }
            //Cursor Colors          
            gsProfile.setBoolean(SETTINGS_PROFILE_USE_CURSOR_COLOR_KEY, scheme.useCursorColor);
            if (scheme.useCursorColor) {
                cbCursorFG.setRgba(scheme.cursorFG);
                cbCursorBG.setRgba(scheme.cursorBG);
            }
        }
        string[16] palette;
        foreach (i, color; scheme.palette) {
            cbPalette[i].setRgba(color);
            palette[i] = rgbaTo8bitHex(color, false, true);
        }
        gsProfile.setStrv(SETTINGS_PROFILE_PALETTE_COLOR_KEY, palette);
    }

    /**
     * Sets the scheme box to Custom, triggered by changes to color controls
     */
    void setCustomScheme() {
        if (!schemeChangingLock) {
            cbScheme.setActive(to!int(schemes.length));
        }
    }

public:

    this(ProfileInfo profile, GSettings gsProfile) {
        super(Orientation.VERTICAL, 5);
        this.profile = profile;
        this.gsProfile = gsProfile;
        schemes = loadColorSchemes();
        createUI();
        initColorSchemeCombo();
    }
}

/**
 * The page to manage scrolling options
 */
class ScrollPage : Box {

private:
    ProfileInfo profile;
    GSettings gsProfile;

    void createUI() {
        setMarginLeft(18);
        setMarginRight(18);
        setMarginTop(18);
        setMarginBottom(18);

        CheckButton cbShowScrollbar = new CheckButton(_("Show scrollbar"));
        gsProfile.bind(SETTINGS_PROFILE_SHOW_SCROLLBAR_KEY, cbShowScrollbar, "active", GSettingsBindFlags.DEFAULT);
        add(cbShowScrollbar);

        CheckButton cbScrollOnOutput = new CheckButton(_("Scroll on output"));
        gsProfile.bind(SETTINGS_PROFILE_SCROLL_ON_OUTPUT_KEY, cbScrollOnOutput, "active", GSettingsBindFlags.DEFAULT);
        add(cbScrollOnOutput);

        CheckButton cbScrollOnKeystroke = new CheckButton(_("Scroll on keystroke"));
        gsProfile.bind(SETTINGS_PROFILE_SCROLL_ON_INPUT_KEY, cbScrollOnKeystroke, "active", GSettingsBindFlags.DEFAULT);
        add(cbScrollOnKeystroke);

        CheckButton cbLimitScroll = new CheckButton(_("Limit scrollback to:"));
        gsProfile.bind(SETTINGS_PROFILE_UNLIMITED_SCROLL_KEY, cbLimitScroll, "active", GSettingsBindFlags.DEFAULT | GSettingsBindFlags.INVERT_BOOLEAN);
        SpinButton sbScrollbackSize = new SpinButton(256, long.max, 256);
        gsProfile.bind(SETTINGS_PROFILE_SCROLLBACK_LINES_KEY, sbScrollbackSize, "value", GSettingsBindFlags.DEFAULT);
        gsProfile.bind(SETTINGS_PROFILE_UNLIMITED_SCROLL_KEY, sbScrollbackSize, "sensitive",
                GSettingsBindFlags.GET | GSettingsBindFlags.NO_SENSITIVITY | GSettingsBindFlags.INVERT_BOOLEAN);

        Box b = new Box(Orientation.HORIZONTAL, 12);
        b.add(cbLimitScroll);
        b.add(sbScrollbackSize);
        add(b);
    }

public:

    this(ProfileInfo profile, GSettings gsProfile) {
        super(Orientation.VERTICAL, 6);
        this.profile = profile;
        this.gsProfile = gsProfile;
        createUI();
    }
}

/**
 * The profile page that manages compatibility options
 */
class CompatibilityPage : Grid {

private:
    GSettings gsProfile;

    void createUI() {
        setMarginLeft(18);
        setMarginRight(18);
        setMarginTop(18);
        setMarginBottom(18);

        setColumnSpacing(12);
        setRowSpacing(6);

        int row = 0;
        Label lblBackspace = new Label(_("Backspace key generates"));
        lblBackspace.setHalign(Align.END);
        attach(lblBackspace, 0, row, 1, 1);
        ComboBox cbBackspace = createNameValueCombo([_("Automatic"), _("Control-H"), _("ASCII DEL"), _("Escape sequence"), _("TTY")], SETTINGS_PROFILE_ERASE_BINDING_VALUES);
        gsProfile.bind(SETTINGS_PROFILE_BACKSPACE_BINDING_KEY, cbBackspace, "active-id", GSettingsBindFlags.DEFAULT);
        attach(cbBackspace, 1, row, 1, 1);
        row++;

        Label lblDelete = new Label(_("Delete key generates"));
        lblDelete.setHalign(Align.END);
        attach(lblDelete, 0, row, 1, 1);
        ComboBox cbDelete = createNameValueCombo([_("Automatic"), _("Control-H"), _("ASCII DEL"), _("Escape sequence"), _("TTY")], SETTINGS_PROFILE_ERASE_BINDING_VALUES);
        gsProfile.bind(SETTINGS_PROFILE_DELETE_BINDING_KEY, cbDelete, "active-id", GSettingsBindFlags.DEFAULT);
        attach(cbDelete, 1, row, 1, 1);
        row++;

        Label lblEncoding = new Label(_("Encoding"));
        lblEncoding.setHalign(Align.END);
        attach(lblEncoding, 0, row, 1, 1);
        string[] key, value;
        key.length = encodings.length;
        value.length = encodings.length;
        foreach (i, encoding; encodings) {
            key[i] = encoding[0];
            value[i] = encoding[0] ~ " " ~ _(encoding[1]);
        }
        ComboBox cbEncoding = createNameValueCombo(value, key);
        gsProfile.bind(SETTINGS_PROFILE_ENCODING_KEY, cbEncoding, "active-id", GSettingsBindFlags.DEFAULT);
        attach(cbEncoding, 1, row, 1, 1);
        row++;

        Label lblCJK = new Label(_("Ambiguous-width characters"));
        lblCJK.setHalign(Align.END);
        attach(lblCJK, 0, row, 1, 1);
        ComboBox cbCJK = createNameValueCombo([_("Narrow"), _("Wide")], SETTINGS_PROFILE_CJK_WIDTH_VALUES);
        gsProfile.bind(SETTINGS_PROFILE_CJK_WIDTH_KEY, cbCJK, "active-id", GSettingsBindFlags.DEFAULT);
        attach(cbCJK, 1, row, 1, 1);
        row++;
    }

public:

    this(ProfileInfo profile, GSettings gsProfile) {
        super();
        this.gsProfile = gsProfile;
        createUI();
    }
}

class CommandPage : Box {

private:
    GSettings gsProfile;

    void createUI() {
        setMarginLeft(18);
        setMarginRight(18);
        setMarginTop(18);
        setMarginBottom(18);

        CheckButton cbLoginShell = new CheckButton(_("Run command as a login shell"));
        gsProfile.bind(SETTINGS_PROFILE_LOGIN_SHELL_KEY, cbLoginShell, "active", GSettingsBindFlags.DEFAULT);
        add(cbLoginShell);

        CheckButton cbCustomCommand = new CheckButton(_("Run a custom command instead of my shell"));
        gsProfile.bind(SETTINGS_PROFILE_USE_CUSTOM_COMMAND_KEY, cbCustomCommand, "active", GSettingsBindFlags.DEFAULT);
        add(cbCustomCommand);

        Box bCommand = new Box(Orientation.HORIZONTAL, 12);
        bCommand.setMarginLeft(12);
        Label lblCommand = new Label(_("Command"));
        gsProfile.bind(SETTINGS_PROFILE_USE_CUSTOM_COMMAND_KEY, lblCommand, "sensitive", GSettingsBindFlags.GET | GSettingsBindFlags.NO_SENSITIVITY);
        bCommand.add(lblCommand);
        Entry eCommand = new Entry();
        gsProfile.bind(SETTINGS_PROFILE_CUSTOM_COMMAND_KEY, eCommand, "text", GSettingsBindFlags.DEFAULT);
        gsProfile.bind(SETTINGS_PROFILE_USE_CUSTOM_COMMAND_KEY, eCommand, "sensitive", GSettingsBindFlags.GET | GSettingsBindFlags.NO_SENSITIVITY);
        bCommand.add(eCommand);
        add(bCommand);

        Box bWhenExits = new Box(Orientation.HORIZONTAL, 12);
        Label lblWhenExists = new Label(_("When command exits"));
        bWhenExits.add(lblWhenExists);
        ComboBox cbWhenExists = createNameValueCombo([_("Exit the terminal"), _("Restart the command"), _("Hold the terminal open")], SETTINGS_PROFILE_EXIT_ACTION_VALUES);
        gsProfile.bind(SETTINGS_PROFILE_EXIT_ACTION_KEY, cbWhenExists, "active-id", GSettingsBindFlags.DEFAULT);
        bWhenExits.add(cbWhenExists);

        add(bWhenExits);
    }

public:
    this(ProfileInfo profile, GSettings gsProfile) {
        super(Orientation.VERTICAL, 6);
        this.gsProfile = gsProfile;
        createUI();
    }
}

/**
 * Page for advanced profile options such as custom hyperlinks and profile switching
 */
class AdvancedPage: Box {

private:
    GSettings gsProfile;
    TreeView tvValues;
    ListStore lsValues;
    
    Button btnAdd;
    Button btnEdit;
    Button btnDelete;

    Label createDescriptionLabel(string desc) {
        Label lblDescription = new Label(desc);
        lblDescription.setUseMarkup(true);
        lblDescription.setLineWrap(true);
        lblDescription.setSensitive(false);
        lblDescription.setLineWrap(true);
        return lblDescription;
    }
    
    void createUI() {
        setMarginLeft(18);
        setMarginRight(18);
        setMarginTop(18);
        setMarginBottom(18);

        // Custom Links Section
        Label lblCustomLinks = new Label(format("<b>%s</b>", _("Custom Links")));
        lblCustomLinks.setUseMarkup(true);
        lblCustomLinks.setHalign(Align.START);
        add(lblCustomLinks);

        string customLinksDescription = _("A list of user defined links that can be clicked on in the terminal based on regular expression definitions.");
        packStart(createDescriptionLabel(customLinksDescription), false, false, 0);
        
        Button btnEditLink = new Button(_("Edit"));
        btnEditLink.setHexpand(false);
        btnEditLink.setHalign(Align.START);
        btnEditLink.addOnClicked(delegate(Button) {
            string[] links = gsProfile.getStrv(SETTINGS_PROFILE_CUSTOM_HYPERLINK_KEY);
            EditCustomLinksDialog dlg = new EditCustomLinksDialog(cast(Window) getToplevel(), links);
            scope (exit) {
                dlg.destroy();
            }
            dlg.showAll();
            if (dlg.run() != ResponseType.CANCEL) {
                gsProfile.setStrv(SETTINGS_PROFILE_CUSTOM_HYPERLINK_KEY, dlg.getLinks());
            }
        });
        add(btnEditLink);

        if (checkVTEFeature(TerminalFeature.EVENT_SCREEN_CHANGED)) {
            // Triggers Section
            Label lblTriggers = new Label(format("<b>%s</b>", _("Triggers")));
            lblTriggers.setUseMarkup(true);
            lblTriggers.setHalign(Align.START);
            add(lblTriggers);

            string triggersDescription = _("Triggers are regular expressions that are used to check against output text in the terminal. When a match is detected the configured action is executed.");
            packStart(createDescriptionLabel(triggersDescription), false, false, 0);
            
            Button btnEditTriggers = new Button(_("Edit"));
            btnEditTriggers.setHexpand(false);
            btnEditTriggers.setHalign(Align.START);
            btnEditTriggers.addOnClicked(delegate(Button) {
                EditTriggersDialog dlg = new EditTriggersDialog(cast(Window) getToplevel(), gsProfile);
                scope (exit) {
                    dlg.destroy();
                }
                dlg.showAll();
                if (dlg.run() != ResponseType.CANCEL) {
                    gsProfile.setStrv(SETTINGS_PROFILE_TRIGGERS_KEY, dlg.getTriggers());
                }
            });
            add(btnEditTriggers);
        }
        
        //Profile Switching        
        Label lblProfileSwitching = new Label(format("<b>%s</b>", _("Automatic Profile Switching")));
        lblProfileSwitching.setUseMarkup(true);
        lblProfileSwitching.setHalign(Align.START);
        add(lblProfileSwitching);
        
        string profileSwitchingDescription;
        if (checkVTEFeature(TerminalFeature.EVENT_SCREEN_CHANGED)) {
            profileSwitchingDescription = _("Profiles are automatically selected based on the values entered here.\nValues are entered using a <i>username@hostname:directory</i> format. Either the hostname or directory can be omitted but the colon must be present. Entries with neither hostname or directory are not permitted.");
        } else {
            profileSwitchingDescription = _("Profiles are automatically selected based on the values entered here.\nValues are entered using a <i>hostname:directory</i> format. Either the hostname or directory can be omitted but the colon must be present. Entries with neither hostname or directory are not permitted.");
        }
        packStart(createDescriptionLabel(profileSwitchingDescription), false, false, 0);
        
        lsValues = new ListStore([GType.STRING]);
        string[] values = gsProfile.getStrv(SETTINGS_PROFILE_AUTOMATIC_SWITCH_KEY);
        foreach(value; values) {
            TreeIter iter = lsValues.createIter();
            lsValues.setValue(iter, 0, value);
        }
        tvValues = new TreeView(lsValues);
        tvValues.setActivateOnSingleClick(true);
        tvValues.addOnCursorChanged(delegate(TreeView) {
            updateUI(); 
        });
        
        TreeViewColumn column = new TreeViewColumn(_("Match"), new CellRendererText(), "text", 0);
        tvValues.appendColumn(column);
        
        ScrolledWindow scValues = new ScrolledWindow(tvValues);
        scValues.setShadowType(ShadowType.ETCHED_IN);
        scValues.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        scValues.setHexpand(true);

        Box bButtons = new Box(Orientation.VERTICAL, 4);
        bButtons.setVexpand(true);

        btnAdd = new Button(_("Add"));
        btnAdd.addOnClicked(delegate(Button) {
            string label, value;
            if (checkVTEFeature(TerminalFeature.EVENT_SCREEN_CHANGED)) {
                label = _("Enter username@hostname:directory to match");
            } else {
                label = _("Enter hostname:directory to match");
            }
            if (showInputDialog(cast(ProfileWindow)getToplevel(), value, "", _("Add New Match"), label, &validateInput)) {
                TreeIter iter = lsValues.createIter();
                lsValues.setValue(iter, 0, value);
                storeValues();                
                selectRow(tvValues, lsValues.iterNChildren(null) - 1, null);
            }
        });
        
        bButtons.add(btnAdd);

        btnEdit = new Button(_("Edit"));
        btnEdit.addOnClicked(delegate(Button) {
            TreeIter iter = tvValues.getSelectedIter();
            if (iter !is null) {
                string value = lsValues.getValueString(iter, 0);
                string label;
                if (checkVTEFeature(TerminalFeature.EVENT_SCREEN_CHANGED)) {
                    label = _("Edit username@hostname:directory to match");
                } else {
                    label = _("Edit hostname:directory to match");
                }
                if (showInputDialog(cast(ProfileWindow)getToplevel(), value, value, _("Edit Match"), label, &validateInput)) {
                    lsValues.setValue(iter, 0, value);
                    storeValues();
                } 
            }
        });
        bButtons.add(btnEdit);
        
        btnDelete = new Button(_("Delete"));
        btnDelete.addOnClicked(delegate(Button) {
            TreeIter iter = tvValues.getSelectedIter();
            if (iter !is null) {
                lsValues.remove(iter);
                storeValues();                
            }
        });
        bButtons.add(btnDelete);
        
        Box box = new Box(Orientation.HORIZONTAL, 6);
        box.add(scValues);
        box.add(bButtons);
        add(box);
    }
    
    void updateUI() {
        TreeIter selected = tvValues.getSelectedIter();
        btnDelete.setSensitive(selected !is null);
        btnEdit.setSensitive(selected !is null);
    }
    
    // Validate input, just checks something was entered at this point
    // and least one delimiter, either @ or :
    bool validateInput(string match) {
        return (match.length > 1 && (match.indexOf('@') >= 0 || match.indexOf(':') >= 0));
    }
    
    // Store the values in the ListStore into settings
    void storeValues() {
        string[] values;
        foreach (TreeIter iter; TreeIterRange(lsValues)) {
            values ~= lsValues.getValueString(iter, 0);
        }
        gsProfile.setStrv(SETTINGS_PROFILE_AUTOMATIC_SWITCH_KEY, values);
    }

public:
    this(ProfileInfo profile, GSettings gsProfile) {
        super(Orientation.VERTICAL, 6);
        this.gsProfile = gsProfile;
        createUI();
        updateUI();
    }    
}

/**
 * Dialog for editing custom hyperlinks
 */
class EditCustomLinksDialog: Dialog {

private:
    enum COLUMN_REGEX = 0;
    enum COLUMN_CMD = 1;
    enum COLUMN_CASE = 2;

    TreeView tv;
    ListStore ls;
    Button btnDelete;

    void createUI(string[] links) {
        
        Box box = new Box(Orientation.HORIZONTAL, 6);
        with (box) {
            setMarginLeft(18);
            setMarginRight(18);
            setMarginTop(18);
            setMarginBottom(18);
        }

        ls = new ListStore([GType.STRING, GType.STRING, GType.BOOLEAN]);
        foreach(link; links) {
            foreach(value; csvReader!(Tuple!(string, string, string))(link)) {
                TreeIter iter = ls.createIter();
                ls.setValue(iter, COLUMN_REGEX, value[0]);
                ls.setValue(iter, COLUMN_CMD, value[1]);
                try {
                    ls.setValue(iter, COLUMN_CASE, to!bool(value[2]));
                } catch (Exception e) {
                    ls.setValue(iter, COLUMN_CASE, false);
                }
            }
        }

        tv = new TreeView(ls);
        tv.setActivateOnSingleClick(false);
        tv.addOnCursorChanged(delegate(TreeView) { 
            updateUI(); 
        });
        tv.setHeadersVisible(true);

        //Regex column
        CellRendererText crtRegex = new CellRendererText();
        crtRegex.setProperty("editable", 1);
        crtRegex.addOnEdited(delegate(string path, string newText, CellRendererText) {
            TreeIter iter = new TreeIter();
            ls.getIter(iter, new TreePath(path));
            if (newText.length != 0) {
                GRegex check = new GRegex(newText, GRegexCompileFlags.OPTIMIZE, cast(GRegexMatchFlags) 0);
                if (check is null) {
                    showErrorDialog(cast(Window) getToplevel(), format(_("The expression %s is not a valid regex"), newText));    
                }                
            }
            ls.setValue(iter, COLUMN_REGEX, newText);
        });
        TreeViewColumn column = new TreeViewColumn(_("Regex"), crtRegex, "text", COLUMN_REGEX);
        column.setMinWidth(200);
        tv.appendColumn(column);

        //Command column 
        CellRendererText crtCommand = new CellRendererText();
        crtCommand.setProperty("editable", 1);
        crtCommand.addOnEdited(delegate(string path, string newText, CellRendererText) {
            TreeIter iter = new TreeIter();
            ls.getIter(iter, new TreePath(path));
            ls.setValue(iter, COLUMN_CMD, newText);
        });
        column = new TreeViewColumn(_("Command"), crtCommand, "text", COLUMN_CMD);
        column.setMinWidth(200);
        tv.appendColumn(column);

        //Case Insensitive Column
        CellRendererToggle crtCase = new CellRendererToggle();
        crtCase.setActivatable(true);
        crtCase.addOnToggled(delegate(string path, CellRendererToggle crt) {
            TreeIter iter = new TreeIter();
            ls.getIter(iter, new TreePath(path));
            ls.setValue(iter, COLUMN_CASE, !crt.getActive());
        });
        column = new TreeViewColumn(_("Case Insensitive"), crtCase, "active", COLUMN_CASE);
        tv.appendColumn(column);

        ScrolledWindow sc = new ScrolledWindow(tv);
        sc.setShadowType(ShadowType.ETCHED_IN);
        sc.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sc.setHexpand(true);
        sc.setVexpand(true);
        sc.setSizeRequest(-1, 250);

        box.add(sc);

        Box buttons = new Box(Orientation.VERTICAL, 6);
        Button btnAdd = new Button(_("Add"));
        btnAdd.addOnClicked(delegate(Button) {
            ls.createIter();
            selectRow(tv, ls.iterNChildren(null) - 1, null);
        });
        buttons.add(btnAdd);
        btnDelete = new Button(_("Delete"));
        btnDelete.addOnClicked(delegate(Button) {
            TreeIter selected = tv.getSelectedIter();
            if (selected) {
                ls.remove(selected);
            }
        });
        buttons.add(btnDelete);
        
        box.add(buttons);

        getContentArea().add(box);
        updateUI();
    }

    void updateUI() {
        btnDelete.setSensitive(tv.getSelectedIter() !is null);
    }

public:
    this(Window parent, string[] links) {
        super(_("Edit Custom Links"), parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("Apply"), _("Cancel")], [GtkResponseType.APPLY, GtkResponseType.CANCEL]);
        setDefaultResponse(GtkResponseType.APPLY);
        createUI(links);
    }

    string[] getLinks() {
        string[] results;
        foreach (TreeIter iter; TreeIterRange(ls)) {
            string regex = ls.getValueString(iter, COLUMN_REGEX);
            if (regex.length == 0) continue;
            results ~= escapeCSV(regex) ~ ',' ~ 
                       escapeCSV(ls.getValueString(iter, COLUMN_CMD)) ~ ',' ~
                       to!string(ls.getValue(iter, COLUMN_CASE).getBoolean());
        }
        return results;        
    }
}

/**
 * Dialog for editing triggers
 */
class EditTriggersDialog: Dialog {

private:
    enum COLUMN_REGEX = 0;
    enum COLUMN_ACTION = 1;
    enum COLUMN_PARAMETERS = 2;

    TreeView tv;
    ListStore ls;
    ListStore lsActions;
    Button btnDelete;

    string[string] localizedActions;

    void createUI(GSettings gsProfile) {
        
        string[] triggers = gsProfile.getStrv(SETTINGS_PROFILE_TRIGGERS_KEY);

        Box box = new Box(Orientation.HORIZONTAL, 6);
        with (getContentArea()) {
            setMarginLeft(18);
            setMarginRight(18);
            setMarginTop(18);
            setMarginBottom(18);
        }

        ls = new ListStore([GType.STRING, GType.STRING, GType.STRING]);
        foreach(trigger; triggers) {
            foreach(value; csvReader!(Tuple!(string, string, string))(trigger)) {
                TreeIter iter = ls.createIter();
                ls.setValue(iter, COLUMN_REGEX, value[0]);
                ls.setValue(iter, COLUMN_ACTION, value[1]);
                ls.setValue(iter, COLUMN_PARAMETERS, value[2]);
            }
        }

        tv = new TreeView(ls);
        tv.setActivateOnSingleClick(false);
        tv.addOnCursorChanged(delegate(TreeView) { 
            updateUI(); 
        });
        tv.setHeadersVisible(true);

        //Regex column
        CellRendererText crtRegex = new CellRendererText();
        crtRegex.setProperty("editable", 1);
        crtRegex.addOnEdited(delegate(string path, string newText, CellRendererText) {
            TreeIter iter = new TreeIter();
            ls.getIter(iter, new TreePath(path));
            if (newText.length != 0) {
                GRegex check = new GRegex(newText, GRegexCompileFlags.OPTIMIZE, cast(GRegexMatchFlags) 0);
                if (check is null) {
                    showErrorDialog(cast(Window) getToplevel(), format(_("The expression %s is not a valid regex"), newText));    
                }                
            }
            ls.setValue(iter, COLUMN_REGEX, newText);
        });
        TreeViewColumn column = new TreeViewColumn(_("Regex"), crtRegex, "text", COLUMN_REGEX);
        column.setMinWidth(200);
        tv.appendColumn(column);

        //Action Column
        CellRendererCombo crtAction = new CellRendererCombo();
        ListStore lsActions = new ListStore([GType.STRING]);
        foreach(value; SETTINGS_PROFILE_TRIGGER_ACTION_VALUES) {
            TreeIter iter = lsActions.createIter();
            lsActions.setValue(iter, 0, _(value));
            localizedActions[_(value)] = value;
        }
        import gtkc.gobject: g_object_set;
        import glib.Str: Str;
        g_object_set(crtAction.getCellRendererComboStruct, Str.toStringz("model"), lsActions.getListStoreStruct(), null);
        crtAction.setProperty("editable", 1);
        crtAction.setProperty("has-entry", 0);
        crtAction.setProperty("text-column", 0);
        crtAction.addOnChanged(delegate(string path, TreeIter actionIter, CellRendererCombo) {
            TreeIter iter = new TreeIter();
            ls.getIter(iter, new TreePath(path));
            string action = lsActions.getValueString(actionIter, 0);
            if (iter !is null) {
                ls.setValue(iter, COLUMN_ACTION, action);
            }
        });
        column = new TreeViewColumn(_("Action"), crtAction, "text", COLUMN_ACTION);
        column.setMinWidth(150);
        tv.appendColumn(column);

        //Parameter column 
        CellRendererText crtParameter = new CellRendererText();
        crtParameter.setProperty("editable", 1);
        crtParameter.addOnEdited(delegate(string path, string newText, CellRendererText) {
            TreeIter iter = new TreeIter();
            ls.getIter(iter, new TreePath(path));
            ls.setValue(iter, COLUMN_PARAMETERS, newText);
        });
        column = new TreeViewColumn(_("Parameter"), crtParameter, "text", COLUMN_PARAMETERS);
        column.setMinWidth(200);
        tv.appendColumn(column);

        ScrolledWindow sc = new ScrolledWindow(tv);
        sc.setShadowType(ShadowType.ETCHED_IN);
        sc.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        sc.setHexpand(true);
        sc.setVexpand(true);
        sc.setSizeRequest(-1, 250);

        box.add(sc);

        Box buttons = new Box(Orientation.VERTICAL, 6);
        Button btnAdd = new Button(_("Add"));
        btnAdd.addOnClicked(delegate(Button) {
            ls.createIter();
            selectRow(tv, ls.iterNChildren(null) - 1, null);
        });
        buttons.add(btnAdd);
        btnDelete = new Button(_("Delete"));
        btnDelete.addOnClicked(delegate(Button) {
            TreeIter selected = tv.getSelectedIter();
            if (selected) {
                ls.remove(selected);
            }
        });
        buttons.add(btnDelete);
        
        box.add(buttons);

        // Maximum number of lines to check for triggers when content change is
        // received from VTE with a block of text
        Box bLines = new Box(Orientation.HORIZONTAL, 6);
        bLines.setMarginTop(6);

        CheckButton cbTriggerLimit = new CheckButton("Limit number of lines for trigger processing to:");
        gsProfile.bind(SETTINGS_PROFILE_TRIGGERS_UNLIMITED_LINES_KEY, cbTriggerLimit, "active", GSettingsBindFlags.DEFAULT | GSettingsBindFlags.INVERT_BOOLEAN);

        SpinButton sbLines = new SpinButton(256, long.max, 256);
        gsProfile.bind(SETTINGS_PROFILE_TRIGGERS_LINES_KEY, sbLines, "value", GSettingsBindFlags.DEFAULT);
        gsProfile.bind(SETTINGS_PROFILE_TRIGGERS_UNLIMITED_LINES_KEY, sbLines, "sensitive",
                GSettingsBindFlags.GET | GSettingsBindFlags.NO_SENSITIVITY | GSettingsBindFlags.INVERT_BOOLEAN);
        
        bLines.add(cbTriggerLimit);
        bLines.add(sbLines);

        getContentArea().add(box);
        getContentArea().add(bLines);
        updateUI();
    }

    void updateUI() {
        btnDelete.setSensitive(tv.getSelectedIter() !is null);
    }

public:
    this(Window parent, GSettings gsProfile) {
        super(_("Edit Triggers"), parent, GtkDialogFlags.MODAL + GtkDialogFlags.USE_HEADER_BAR, [_("Apply"), _("Cancel")], [GtkResponseType.APPLY, GtkResponseType.CANCEL]);
        setDefaultResponse(GtkResponseType.APPLY);
        createUI(gsProfile);
    }

    string[] getTriggers() {
        string[] results;
        foreach (TreeIter iter; TreeIterRange(ls)) {
            string regex = ls.getValueString(iter, COLUMN_REGEX);
            if (regex.length == 0) continue;
            results ~= escapeCSV(regex) ~ ',' ~ 
                       escapeCSV(localizedActions[ls.getValueString(iter, COLUMN_ACTION)]) ~ ',' ~
                       escapeCSV(ls.getValueString(iter, COLUMN_PARAMETERS));
        }
        return results;        
    }
}