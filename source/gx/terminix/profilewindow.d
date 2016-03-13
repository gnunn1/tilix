/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.profilewindow;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.format;

import gdk.RGBA;

import gio.Settings : GSettings = Settings;

import glib.Util;

import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Box;
import gtk.Button;
import gtk.CellRendererText;
import gtk.CheckButton;
import gtk.ColorButton;
import gtk.ComboBox;
import gtk.ComboBoxText;
import gtk.Entry;
import gtk.FontButton;
import gtk.Grid;
import gtk.HeaderBar;
import gtk.Label;
import gtk.ListStore;
import gtk.Notebook;
import gtk.Scale;
import gtk.SpinButton;
import gtk.Switch;
import gtk.Widget;

import gx.gtk.util;

import gx.i18n.l10n;

import gx.terminix.application;
import gx.terminix.colorschemes;
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

        nb = new Notebook();
        nb.setHexpand(true);
        nb.setVexpand(true);

        nb.appendPage(new GeneralPage(profile, gsProfile), _("General"));
        nb.appendPage(new CommandPage(profile, gsProfile), _("Command"));
        nb.appendPage(new ColorPage(profile, gsProfile), _("Color"));
        nb.appendPage(new ScrollPage(profile, gsProfile), _("Scrolling"));
        nb.appendPage(new CompatibilityPage(profile, gsProfile), _("Compatibility"));

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
        Label lblName = new Label(_("Profile Name"));
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
        Label lblSize = new Label(_("Terminal Size"));
        lblSize.setHalign(Align.END);
        grid.attach(lblSize, 0, row, 1, 1);
        SpinButton sbColumn = new SpinButton(16, 256, 1);
        gsProfile.bind(SETTINGS_PROFILE_SIZE_COLUMNS_KEY, sbColumn, "value", GSettingsBindFlags.DEFAULT);
        SpinButton sbRow = new SpinButton(4, 256, 1);
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
        Label lblBlinkMode = new Label(_("Blink Mode"));
        lblBlinkMode.setHalign(Align.END);
        grid.attach(lblBlinkMode, 0, row, 1, 1);
        ComboBox cbBlinkMode = createNameValueCombo([_("System"), _("On"), _("Off")], SETTINGS_PROFILE_CURSOR_BLINK_MODE_VALUES);
        gsProfile.bind(SETTINGS_PROFILE_CURSOR_BLINK_MODE_KEY, cbBlinkMode, "active-id", GSettingsBindFlags.DEFAULT);
        grid.attach(cbBlinkMode, 1, row, 1, 1);
        row++;

        //Terminal Bell
        Label lblBell = new Label(_("Terminal Bell"));
        lblBell.setHalign(Align.END);
        grid.attach(lblBell, 0, row, 1, 1);
        Switch sBell = new Switch();
        sBell.setHalign(Align.START);
        gsProfile.bind(SETTINGS_PROFILE_AUDIBLE_BELL_KEY, sBell, "active", GSettingsBindFlags.DEFAULT);
        grid.attach(sBell, 1, row, 1, 1);
        row++;

        //Terminal Title
        Label lblTerminalTitle = new Label(_("Terminal Title"));
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
        CheckButton cbCustomFont = new CheckButton(_("Custom Font"));
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

        Box bOptions = new Box(Orientation.VERTICAL, 3);

        cbUseThemeColors = new CheckButton(_("Use theme colors for foreground/background"));
        cbUseThemeColors.addOnToggled(delegate(ToggleButton) { setCustomScheme(); });
        gsProfile.bind(SETTINGS_PROFILE_USE_THEME_COLORS_KEY, cbUseThemeColors, "active", GSettingsBindFlags.DEFAULT);

        bOptions.add(cbUseThemeColors);
        GSettings gsSettings = new GSettings(SETTINGS_ID);
        if (gsSettings.getBoolean(SETTINGS_ENABLE_TRANSPARENCY_KEY)) {
            Box bTransparent = new Box(Orientation.HORIZONTAL, 6);
            bTransparent.setHexpand(true);

            Label lblTransparent = new Label(_("Transparency"));
            bTransparent.add(lblTransparent);

            Scale sTransparent = new Scale(Orientation.HORIZONTAL, 0, 100, 10);
            sTransparent.setDrawValue(false);
            sTransparent.setHexpand(true);
            gsProfile.bind(SETTINGS_PROFILE_BG_TRANSPARENCY_KEY, sTransparent.getAdjustment(), "value", GSettingsBindFlags.DEFAULT);
            bTransparent.add(sTransparent);

            bOptions.add(bTransparent);
        }
        grid.attach(bOptions, 1, row, 1, 1);
        row++;

        add(grid);
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

    void initColorSchemeCombo() {
        //Initialize ColorScheme combobox
        RGBA[16] colors;
        foreach (i, cb; cbPalette) {
            cb.getRgba(colors[i]);
        }
        RGBA fg;
        RGBA bg;
        cbFG.getRgba(fg);
        cbBG.getRgba(bg);
        int index = findSchemeByColors(schemes, cbUseThemeColors.getActive(), fg, bg, colors);
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
            cbFG.setRgba(scheme.foreground);
            cbBG.setRgba(scheme.background);
            gsProfile.setString(SETTINGS_PROFILE_FG_COLOR_KEY, rgbaTo8bitHex(scheme.foreground, false, true));
            gsProfile.setString(SETTINGS_PROFILE_BG_COLOR_KEY, rgbaTo8bitHex(scheme.background, false, true));
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
