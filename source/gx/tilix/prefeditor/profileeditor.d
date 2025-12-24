/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.prefeditor.profileeditor;

import std.algorithm;
import std.array;
import std.conv;
import std.experimental.logger;
import std.file;
import std.format;
import std.path;
import std.string;
import std.typecons : Yes, No;

import gdk.event;
import gdk.types;
import gdk.rgba;
import gdk.types;

import gio.settings : Settings = Settings;

import glib.uri;
import glib.global;

import gobject.types;
import gobject.value;

import gtk.application;
import gtk.types;
import gtk.application_window;
import gtk.types;
import gtk.box;
import gtk.types;
import gtk.button;
import gtk.types;
import gtk.cell_renderer_text;
import gtk.types;
import gtk.check_button;
import gtk.types;
import gtk.color_button;
import gtk.types;
import gtk.combo_box;
import gtk.types;
import gtk.combo_box_text;
import gtk.types;
import gtk.dialog;
import gtk.types;
import gtk.editable;
import gtk.types;
import gtk.entry;
import gtk.types;
import gtk.file_chooser_dialog;
import gtk.types;
import gtk.file_filter;
import gtk.types;
import gtk.font_button;
import gtk.types;
import gtk.grid;
import gtk.types;
import gtk.header_bar;
import gtk.types;
import gtk.image;
import gtk.types;
import gtk.label;
import gtk.types;
import gtk.list_store;
import gtk.types;
import gtk.menu_button;
import gtk.types;
import gtk.notebook;
import gtk.types;
import gtk.popover;
import gtk.types;
import gtk.scale;
import gtk.types;
import gtk.scrolled_window;
import gtk.types;
import gtk.size_group;
import gtk.types;
import gtk.spin_button;
import gtk.types;
import gtk.switch_;
import gtk.types;
import gtk.tree_iter;
import gtk.types;
import gtk.tree_model;
import gtk.tree_path;
import gtk.types;
import gtk.tree_view;
import gtk.types;
import gtk.tree_view_column;
import gtk.types;

import gtk.widget;
import gtk.types;
import gtk.window;
import gtk.types;
import gtk.toggle_button;

import gx.gtk.color;
import gx.gtk.dialog;
import gx.gtk.settings;
import gx.gtk.keys;
import gx.gtk.types;
import gx.gtk.util;
import gx.gtk.vte;

import gx.i18n.l10n;

import gx.util.array;

import gx.tilix.application;
import gx.tilix.colorschemes;
import gx.tilix.common;
import gx.tilix.constants;
import gx.tilix.encoding;
import gx.tilix.preferences;

import gx.tilix.prefeditor.advdialog;
import gx.tilix.prefeditor.common;
import gx.tilix.prefeditor.titleeditor;

/**
 * UI used for managing preferences for a specific profile
 */
class ProfileEditor : Box {

private:

    Settings gsProfile;
    ProfileInfo profile;
    Notebook nb;

    void createUI() {
        nb = new Notebook();
        nb.setHexpand(true);
        nb.setVexpand(true);
        nb.setShowBorder(false);
        nb.appendPage(new GeneralPage(this), new Label(_("General")));
        nb.appendPage(new CommandPage(), new Label(_("Command")));
        nb.appendPage(new ColorPage(), new Label(_("Color")));
        nb.appendPage(new ScrollPage(), new Label(_("Scrolling")));
        nb.appendPage(new CompatibilityPage(), new Label(_("Compatibility")));
        if (isVTEBackgroundDrawEnabled()) {
            nb.appendPage(new BadgePage(), new Label(_("Badge")));
        }
        nb.appendPage(new AdvancedPage(), new Label(_("Advanced")));
        add(nb);
    }

    ProfilePage getPage(int index) {
        return cast(ProfilePage) nb.getNthPage(index);
    }

package:
    void triggerNameChanged(string newName) {
        onProfileNameChanged.emit(newName);
    }

public:

    this() {
        super(gtk.types.Orientation.Vertical, 0);
        createUI();
        connectDestroy(delegate() {
            //trace("ProfileEditor destroyed");
            unbind();
        });
    }

    debug(Destructors) {
        ~this() {
            import std.stdio: writeln;
            writeln("********** ProfileEditor destructor");
        }
    }

    void bind(ProfileInfo profile) {
        if (gsProfile !is null) {
            unbind();
        }
        this.profile = profile;
        gsProfile = prfMgr.getProfileSettings(profile.uuid);
        for(int i=0; i<nb.getNPages(); i++) {
            getPage(i).bind(profile, gsProfile);
        }
    }

    void unbind() {
        for(int i=0; i<nb.getNPages(); i++) {
            getPage(i).unbind();
        }
        gsProfile.destroy();
        gsProfile = null;
        profile = ProfileInfo(false, null, null);
    }

    @property string uuid() {
        return profile.uuid;
    }

    /**
    * Event triggered when profile name changes
    */
    GenericEvent!(string) onProfileNameChanged;
}

/**
 * Base class for profile pages, takes care of binding/unbinding settings
 * in a consistent way as the user moves from profile to profile in the
 * preferences dialog.
 *
 * Relies extensively on the BindingHelper class to track bindings.
 */
class ProfilePage: Box {

private:
    ProfileInfo profile;
    Settings gsProfile;
    BindingHelper bh;

public:
    this() {
        super(gtk.types.Orientation.Vertical, 6);
        setAllMargins(this, 18);
        bh = new BindingHelper();
    }

    void bind(ProfileInfo profile, Settings gsProfile) {
        this.profile = profile;
        this.gsProfile = gsProfile;
        bh.settings = gsProfile;
    }

    void unbind() {
        bh.settings = null;
        profile = ProfileInfo(false, null, null);
    }
}

/**
 * Page that handles the general settings for the profile
 */
class GeneralPage : ProfilePage {

private:

    Label lblId;
    ProfileEditor pe;

protected:
    void createUI() {
        int row = 0;
        Grid grid = new Grid();
        grid.setColumnSpacing(12);
        grid.setRowSpacing(6);

        //Profile Name
        Label lblName = new Label(_("Profile name"));
        lblName.setHalign(Align.End);
        grid.attach(lblName, 0, row, 1, 1);
        Entry eName = new Entry();
        // Catch and pass name changes up to preferences dialog
        // Generally it would be better to simply use the Settings onChanged
        // trigger however these are being used transiently here and since gtk.types.DialogFlags
        // doesn't provide a way to remove event handlers we will do it this instead.
        eName.connectChanged(delegate(Editable editable) {
            Entry entry = cast(Entry)editable;
            pe.triggerNameChanged(entry.getText());
        }, Yes.After);
        eName.setHexpand(true);
        bh.bind(SETTINGS_PROFILE_VISIBLE_NAME_KEY, eName, "text", SettingsBindFlags.Default);
        grid.attach(eName, 1, row, 1, 1);
        row++;
        //Profile ID
        lblId = new Label("");
        // lblId.setHalign(Align.Start);
        // lblId.setSensitive(false);
        // grid.attach(lblId, 1, row, 1, 1);
        // row++;

        //Terminal Title
        Label lblTerminalTitle = new Label(_("Terminal title"));
        lblTerminalTitle.setHalign(Align.End);
        grid.attach(lblTerminalTitle, 0, row, 1, 1);
        Entry eTerminalTitle = new Entry();
        eTerminalTitle.setHexpand(true);
        bh.bind(SETTINGS_PROFILE_TITLE_KEY, eTerminalTitle, "text", SettingsBindFlags.Default);
        if (checkVersion(3, 16, 0).length == 0) {
            grid.attach(createTitleEditHelper(eTerminalTitle, TitleEditScope.TERMINAL), 1, row, 1, 1);
        } else {
            grid.attach(eTerminalTitle, 1, row, 1, 1);
        }
        row++;

        Label lblTextTitle = new Label(format("<b>%s</b>", _("Text Appearance")));
        lblTextTitle.setUseMarkup(true);
        lblTextTitle.setHalign(Align.Start);
        lblTextTitle.setMarginTop(6);
        grid.attach(lblTextTitle, 0, row, 2, 1);
        row++;

        //Terminal Size
        Label lblSize = new Label(_("Terminal size"));
        lblSize.setHalign(Align.End);
        grid.attach(lblSize, 0, row, 1, 1);
        SpinButton sbColumn = SpinButton.newWithRange(16, 511, 1);
        bh.bind(SETTINGS_PROFILE_SIZE_COLUMNS_KEY, sbColumn, "value", SettingsBindFlags.Default);
        SpinButton sbRow = SpinButton.newWithRange(4, 511, 1);
        bh.bind(SETTINGS_PROFILE_SIZE_ROWS_KEY, sbRow, "value", SettingsBindFlags.Default);

        Box box = new Box(gtk.types.Orientation.Horizontal, 5);
        box.add(sbColumn);
        Label lblColumns = new Label(_("columns"));
        if (checkVersion(3, 16, 0).length == 0) {
            lblColumns.setXalign(0.0);
        }
        lblColumns.setMarginRight(6);
        lblColumns.setSensitive(false);
        box.add(lblColumns);

        box.add(sbRow);
        Label lblRows = new Label(_("rows"));
        if (checkVersion(3, 16, 0).length == 0) {
            lblRows.setXalign(0.0);
        }
        lblRows.setMarginRight(6);
        lblRows.setSensitive(false);
        box.add(lblRows);

        Button btnReset = Button.newWithLabel(_("Reset"));
        btnReset.connectClicked(delegate(Button b) {
           gsProfile.reset(SETTINGS_PROFILE_SIZE_COLUMNS_KEY);
           gsProfile.reset(SETTINGS_PROFILE_SIZE_ROWS_KEY);

        });
        box.add(btnReset);
        grid.attach(box, 1, row, 1, 1);
        row++;

        //Terminal Spacing
        if (checkVTEVersion(VTE_VERSION_CELL_SCALE)) {
            Label lblSpacing = new Label(_("Cell spacing"));
            lblSpacing.setHalign(Align.End);
            grid.attach(lblSpacing, 0, row, 1, 1);
            SpinButton sbWidthSpacing = SpinButton.newWithRange(1.0, 2.0, 0.1);
            bh.bind(SETTINGS_PROFILE_CELL_WIDTH_SCALE_KEY, sbWidthSpacing, "value", SettingsBindFlags.Default);
            SpinButton sbHeightSpacing = SpinButton.newWithRange(1.0, 2.0, 0.1);
            bh.bind(SETTINGS_PROFILE_CELL_HEIGHT_SCALE_KEY, sbHeightSpacing, "value", SettingsBindFlags.Default);

            Box bSpacing = new Box(gtk.types.Orientation.Horizontal, 5);
            bSpacing.add(sbWidthSpacing);
            Label lblWidthSpacing = new Label(_("width"));
            if (checkVersion(3, 16, 0).length == 0) {
                lblWidthSpacing.setXalign(0.0);
            }
            lblWidthSpacing.setMarginRight(6);
            lblWidthSpacing.setSensitive(false);
            bSpacing.add(lblWidthSpacing);

            bSpacing.add(sbHeightSpacing);
            Label lblHeightSpacing = new Label(_("height"));
            if (checkVersion(3, 16, 0).length == 0) {
                lblHeightSpacing.setXalign(0.0);
            }
            lblHeightSpacing.setMarginRight(6);
            lblHeightSpacing.setSensitive(false);
            bSpacing.add(lblHeightSpacing);

            Button btnSpacingReset = Button.newWithLabel(_("Reset"));
            btnSpacingReset.connectClicked(delegate(Button b) {
                gsProfile.reset(SETTINGS_PROFILE_CELL_WIDTH_SCALE_KEY);
                gsProfile.reset(SETTINGS_PROFILE_CELL_HEIGHT_SCALE_KEY);
            });
            bSpacing.add(btnSpacingReset);
            grid.attach(bSpacing, 1, row, 1, 1);
            row++;

            SizeGroup sgWidth = new SizeGroup(SizeGroupMode.Horizontal);
            sgWidth.addWidget(lblColumns);
            sgWidth.addWidget(lblWidthSpacing);

            SizeGroup sgHeight = new SizeGroup(SizeGroupMode.Horizontal);
            sgHeight.addWidget(lblRows);
            sgHeight.addWidget(lblHeightSpacing);
        }

        if (isVTEBackgroundDrawEnabled()) {
            Label lblMargin = new Label(_("Margin"));
            lblMargin.setHalign(Align.End);
            grid.attach(lblMargin, 0, row, 1, 1);
            SpinButton sbMargin = SpinButton.newWithRange(0.0, 256.0, 4);
            bh.bind(SETTINGS_PROFILE_MARGIN_KEY, sbMargin, "value", SettingsBindFlags.Default);
            grid.attach(sbMargin, 1, row, 1, 1);
            row++;
        }

        if (checkVTEVersion(VTE_VERSION_TEXT_BLINK_MODE)) {
            //Text Blink Mode
            Label lblTextBlinkMode = new Label(_("Text blink mode"));
            lblTextBlinkMode.setHalign(Align.End);
            grid.attach(lblTextBlinkMode, 0, row, 1, 1);
            ComboBox cbTextBlinkMode = createNameValueCombo([_("Never"), _("Focused"), _("Unfocused"), _("Always")], SETTINGS_PROFILE_TEXT_BLINK_MODE_VALUES);
            bh.bind(SETTINGS_PROFILE_TEXT_BLINK_MODE_KEY, cbTextBlinkMode, "active-id", SettingsBindFlags.Default);
            grid.attach(cbTextBlinkMode, 1, row, 1, 1);
            row++;
        }

        //Allow Bold
        // if (!checkVTEVersion(VTE_VERSION_BOLD_IS_BRIGHT)) {
        //     CheckButton cbBold = CheckButton.newWithLabel(_("Allow bold text"));
        //     bh.bind(SETTINGS_PROFILE_ALLOW_BOLD_KEY, cbBold, "active", SettingsBindFlags.Default);
        //     grid.attach(cbBold, 1, row, 1, 1);
        // }

        //Rewrap on resize
        // CheckButton cbRewrap = CheckButton.newWithLabel(_("Rewrap on resize"));
        // bh.bind(SETTINGS_PROFILE_REWRAP_KEY, cbRewrap, "active", SettingsBindFlags.Default);
        // b.add(cbRewrap);

        //Custom Font
        Label lblCustomFont = new Label(_("Custom font"));
        lblCustomFont.setHalign(Align.End);
        grid.attach(lblCustomFont, 0, row, 1, 1);


        Box bFont = new Box(gtk.types.Orientation.Horizontal, 12);
        CheckButton cbCustomFont = new CheckButton();
        bh.bind(SETTINGS_PROFILE_USE_SYSTEM_FONT_KEY, cbCustomFont, "active", SettingsBindFlags.Default | SettingsBindFlags.InvertBoolean);
        bFont.add(cbCustomFont);

        //Font Selector
        FontButton fbFont = new FontButton();
        fbFont.setTitle(_("Choose A Terminal Font"));
        bh.bind(SETTINGS_PROFILE_FONT_KEY, fbFont, "font-name", SettingsBindFlags.Default);
        bh.bind(SETTINGS_PROFILE_USE_SYSTEM_FONT_KEY, fbFont, "sensitive", SettingsBindFlags.Get | SettingsBindFlags.NoSensitivity | SettingsBindFlags
                .InvertBoolean);
        bFont.add(fbFont);
        grid.attach(bFont, 1, row, 1, 1);
        row++;

        //Select-by-word-chars
        Label lblSelectByWordChars = new Label(_("Word-wise select chars"));
        lblSelectByWordChars.setHalign(Align.End);
        grid.attach(lblSelectByWordChars, 0, row, 1, 1);
        Entry eSelectByWordChars = new Entry();
        bh.bind(SETTINGS_PROFILE_WORD_WISE_SELECT_CHARS_KEY, eSelectByWordChars, "text", SettingsBindFlags.Default);
        grid.attach(eSelectByWordChars, 1, row, 1, 1);
        row++;

        Label lblCursorTitle = new Label(format("<b>%s</b>", _("Cursor")));
        lblCursorTitle.setUseMarkup(true);
        lblCursorTitle.setHalign(Align.Start);
        lblCursorTitle.setMarginTop(6);
        grid.attach(lblCursorTitle, 0, row, 2, 1);
        row++;

        //Cursor Shape
        Label lblCursorShape = new Label(_("Cursor"));
        lblCursorShape.setHalign(Align.End);
        grid.attach(lblCursorShape, 0, row, 1, 1);
        ComboBox cbCursorShape = createNameValueCombo([_("Block"), _("IBeam"), _("Underline")], [SETTINGS_PROFILE_CURSOR_SHAPE_BLOCK_VALUE,
                SETTINGS_PROFILE_CURSOR_SHAPE_IBEAM_VALUE, SETTINGS_PROFILE_CURSOR_SHAPE_UNDERLINE_VALUE]);
        bh.bind(SETTINGS_PROFILE_CURSOR_SHAPE_KEY, cbCursorShape, "active-id", SettingsBindFlags.Default);

        grid.attach(cbCursorShape, 1, row, 1, 1);
        row++;

        //Cursor Blink Mode
        Label lblCursorBlinkMode = new Label(_("Cursor blink mode"));
        lblCursorBlinkMode.setHalign(Align.End);
        grid.attach(lblCursorBlinkMode, 0, row, 1, 1);
        ComboBox cbCursorBlinkMode = createNameValueCombo([_("System"), _("On"), _("Off")], SETTINGS_PROFILE_CURSOR_BLINK_MODE_VALUES);
        bh.bind(SETTINGS_PROFILE_CURSOR_BLINK_MODE_KEY, cbCursorBlinkMode, "active-id", SettingsBindFlags.Default);
        grid.attach(cbCursorBlinkMode, 1, row, 1, 1);
        row++;

        Label lblNotifyTitle = new Label(format("<b>%s</b>", _("Notification")));
        lblNotifyTitle.setMarginTop(6);
        lblNotifyTitle.setUseMarkup(true);
        lblNotifyTitle.setHalign(Align.Start);
        grid.attach(lblNotifyTitle, 0, row, 2, 1);
        row++;

        //Terminal Bell
        Label lblBell = new Label(_("Terminal bell"));
        lblBell.setHalign(Align.End);
        grid.attach(lblBell, 0, row, 1, 1);
        ComboBox cbBell = createNameValueCombo([_("None"), _("Sound"), _("Icon"), _("Icon and sound")], SETTINGS_PROFILE_TERMINAL_BELL_VALUES);
        bh.bind(SETTINGS_PROFILE_TERMINAL_BELL_KEY, cbBell, "active-id", SettingsBindFlags.Default);
        grid.attach(cbBell, 1, row, 1, 1);
        row++;

        add(grid);
    }

public:

    this(ProfileEditor pe) {
        super();
        this.pe = pe;
        createUI();
    }

    override void bind(ProfileInfo profile, Settings gsProfile) {
        super.bind(profile, gsProfile);
        lblId.setText(format(_("ID: %s"), profile.uuid));
    }

    override void unbind() {
        super.unbind();
        lblId.setText("");
    }
}

/**
 * The profile page to manage color preferences
 */
class ColorPage : ProfilePage {

private:
    immutable string PALETTE_COLOR_INDEX_KEY = "index";

    ColorScheme[] schemes;
    bool schemeChangingLock = false;
    // Stop event handlers from updating settings when re-binding
    bool blockColorUpdates = false;

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
    CheckButton cbUseBadgeColor;
    ColorButton cbBadgeFG;
    CheckButton cbUseBoldColor;
    ColorButton cbBoldFG;
    ColorButton[16] cbPalette;

    ulong schemeOnChangedHandle;

    Button btnExport;

    void createUI() {
        Grid grid = new Grid();
        grid.setColumnSpacing(12);
        grid.setRowSpacing(18);

        int row = 0;
        Label lblScheme = new Label(format("<b>%s</b>", _("Color scheme")));
        lblScheme.setUseMarkup(true);
        lblScheme.setHalign(Align.End);
        grid.attach(lblScheme, 0, row, 1, 1);

        cbScheme = new ComboBoxText();
        cbScheme.setFocusOnClick(false);
        foreach (scheme; schemes) {
            cbScheme.append(scheme.id, scheme.name);
        }
        cbScheme.append("custom", _("Custom"));
        cbScheme.setHalign(Align.Fill);
        cbScheme.setHexpand(true);
        schemeOnChangedHandle = cbScheme.connectChanged(delegate(ComboBoxText cb) {
            if (cb.getActive >= 0) {
                if (cb.getActive() < schemes.length) {
                    ColorScheme scheme = schemes[cb.getActive];
                    setColorScheme(scheme);
                }
            }
            btnExport.setSensitive(cb.getActive() == schemes.length);
        });

        btnExport = Button.newWithLabel(_("Export"));
        btnExport.connectClicked(&exportColorScheme);

        Box bScheme = new Box(gtk.types.Orientation.Horizontal, 6);
        bScheme.setHalign(Align.Fill);
        bScheme.setHexpand(true);
        bScheme.add(cbScheme);
        bScheme.add(btnExport);

        grid.attach(bScheme, 1, row, 1, 1);
        row++;

        Label lblPalette = new Label(format("<b>%s</b>", _("Color palette")));
        lblPalette.setUseMarkup(true);
        lblPalette.setHalign(Align.End);
        lblPalette.setValign(Align.Start);
        grid.attach(lblPalette, 0, row, 1, 1);
        grid.attach(createColorGrid(row), 1, row, 1, 1);
        row++;

        Label lblOptions = new Label(format("<b>%s</b>", _("Options")));
        lblOptions.setUseMarkup(true);
        lblOptions.setValign(Align.Start);
        lblOptions.setHalign(Align.End);
        grid.attach(lblOptions, 0, row, 1, 1);
        grid.attach(createOptions(), 1, row, 1, 1);
        row++;

        add(grid);
    }

    Widget createOptions() {
        Box box = new Box(gtk.types.Orientation.Vertical, 6);

        cbUseThemeColors = CheckButton.newWithLabel(_("Use theme colors for foreground/background"));
        cbUseThemeColors.connectToggled(delegate() { setCustomScheme(); });
        bh.bind(SETTINGS_PROFILE_USE_THEME_COLORS_KEY, cbUseThemeColors, "active", SettingsBindFlags.Default);

        MenuButton mbAdvanced = new MenuButton();
        mbAdvanced.add(createBox(gtk.types.Orientation.Horizontal, 6, [cast(Widget)new Label(_("Advanced")), cast(Widget)Image.newFromIconName("pan-down-symbolic", IconSize.Menu)]));
        mbAdvanced.setPopover(createPopover(mbAdvanced));
        box.add(createBox(gtk.types.Orientation.Horizontal, 6, [cast(Widget)cbUseThemeColors, cast(Widget)mbAdvanced]));

        if (checkVTEVersion(VTE_VERSION_BOLD_IS_BRIGHT)) {
            CheckButton cbBoldIsBright = CheckButton.newWithLabel(_("Show bold text in bright colors"));
            bh.bind(SETTINGS_PROFILE_BOLD_IS_BRIGHT_KEY, cbBoldIsBright, "active", SettingsBindFlags.Default);
            box.add(cbBoldIsBright);
        }

        Grid gSliders = new Grid();
        gSliders.setColumnSpacing(6);
        gSliders.setRowSpacing(6);
        int row = 0;

        Settings gsSettings = new Settings(SETTINGS_ID);
        if (gsSettings.getBoolean(SETTINGS_ENABLE_TRANSPARENCY_KEY)) {
            Label lblTransparent = new Label(_("Transparency"));
            lblTransparent.setHalign(Align.End);
            lblTransparent.setHexpand(false);
            gSliders.attach(lblTransparent, 0, row, 1, 1);

            Scale sTransparent = Scale.newWithRange(gtk.types.Orientation.Horizontal, 0, 100, 10);
            sTransparent.setDrawValue(false);
            sTransparent.setHexpand(true);
            sTransparent.setHalign(Align.Fill);
            bh.bind(SETTINGS_PROFILE_BG_TRANSPARENCY_KEY, sTransparent.getAdjustment(), "value", SettingsBindFlags.Default);
            gSliders.attach(sTransparent, 1, row, 1, 1);
            row++;
        }

        Label lblDim = new Label(_("Unfocused dim"));
        lblDim.setHalign(Align.End);
        lblDim.setHexpand(false);
        gSliders.attach(lblDim, 0, row, 1, 1);

        Scale sDim = Scale.newWithRange(gtk.types.Orientation.Horizontal, 0, 100, 10);
        sDim.setDrawValue(false);
        sDim.setHexpand(true);
        sDim.setHalign(Align.Fill);
        bh.bind(SETTINGS_PROFILE_DIM_TRANSPARENCY_KEY, sDim.getAdjustment(), "value", SettingsBindFlags.Default);
        gSliders.attach(sDim, 1, row, 1, 1);

        box.add(gSliders);
        return box;
    }

    /**
     * Creates the advanced popover with additional colors for the user
     * to set such as cursor, highlight, dim and badge colors.
     */
    Popover createPopover(Widget widget) {

        ColorButton createColorButton(string settingKey, string title, string sensitiveKey) {
            ColorButton result = new ColorButton();
            if (sensitiveKey.length > 0) {
                bh.bind(sensitiveKey, result, "sensitive", SettingsBindFlags.Get | SettingsBindFlags.NoSensitivity);
            }
            result.setTitle(title);
            result.setHalign(Align.Start);
            result.connectColorSet(delegate(ColorButton cb) {
                if (!blockColorUpdates) {
                    setCustomScheme();
                    RGBA color;
                    cb.getRgba(color);
                    gsProfile.setString(settingKey, rgbaTo16bitHex(color, false, true));
                }
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
        cbUseCursorColor = CheckButton.newWithLabel(_("Cursor"));
        cbUseCursorColor.connectToggled(delegate() { setCustomScheme(); });
        bh.bind(SETTINGS_PROFILE_USE_CURSOR_COLOR_KEY, cbUseCursorColor, "active", SettingsBindFlags.Default);
        gColors.attach(cbUseCursorColor, 0, row, 1, 1);

        cbCursorFG = createColorButton(SETTINGS_PROFILE_CURSOR_FG_COLOR_KEY, _("Select Cursor Foreground Color"), SETTINGS_PROFILE_USE_CURSOR_COLOR_KEY);
        gColors.attach(cbCursorFG, 1, row, 1, 1);
        cbCursorBG = createColorButton(SETTINGS_PROFILE_CURSOR_BG_COLOR_KEY, _("Select Cursor Background Color"), SETTINGS_PROFILE_USE_CURSOR_COLOR_KEY);
        gColors.attach(cbCursorBG, 2, row, 1, 1);
        row++;

        //Highlight
        cbUseHighlightColor = CheckButton.newWithLabel(_("Highlight"));
        cbUseHighlightColor.connectToggled(delegate() { setCustomScheme(); });
        bh.bind(SETTINGS_PROFILE_USE_HIGHLIGHT_COLOR_KEY, cbUseHighlightColor, "active", SettingsBindFlags.Default);
        gColors.attach(cbUseHighlightColor, 0, row, 1, 1);

        cbHighlightFG = createColorButton(SETTINGS_PROFILE_HIGHLIGHT_FG_COLOR_KEY, _("Select Highlight Foreground Color"), SETTINGS_PROFILE_USE_HIGHLIGHT_COLOR_KEY);
        gColors.attach(cbHighlightFG, 1, row, 1, 1);
        cbHighlightBG = createColorButton(SETTINGS_PROFILE_HIGHLIGHT_BG_COLOR_KEY, _("Select Highlight Background Color"), SETTINGS_PROFILE_USE_HIGHLIGHT_COLOR_KEY);
        gColors.attach(cbHighlightBG, 2, row, 1, 1);
        row++;

        //Bold
        cbUseBoldColor = CheckButton.newWithLabel(_("Bold"));
        cbUseBoldColor.connectToggled(delegate() { setCustomScheme(); });
        bh.bind(SETTINGS_PROFILE_USE_BOLD_COLOR_KEY, cbUseBoldColor, "active", SettingsBindFlags.Default);
        gColors.attach(cbUseBoldColor, 0, row, 1, 1);

        cbBoldFG = createColorButton(SETTINGS_PROFILE_BOLD_COLOR_KEY, _("Select Bold Color"), SETTINGS_PROFILE_USE_BOLD_COLOR_KEY);
        gColors.attach(cbBoldFG, 1, row, 1, 1);
        row++;

        //Badge
        cbUseBadgeColor = CheckButton.newWithLabel(_("Badge"));
        cbUseBadgeColor.connectToggled(delegate() { setCustomScheme(); });
        bh.bind(SETTINGS_PROFILE_USE_BADGE_COLOR_KEY, cbUseBadgeColor, "active", SettingsBindFlags.Default);

        cbBadgeFG = createColorButton(SETTINGS_PROFILE_BADGE_COLOR_KEY, _("Select Badge Color"), SETTINGS_PROFILE_USE_BADGE_COLOR_KEY);
        // Only attach badge components if badge feature is available
        // Need to still create them to support color scheme matching
        if (isVTEBackgroundDrawEnabled()) {
            gColors.attach(cbUseBadgeColor, 0, row, 1, 1);
            gColors.attach(cbBadgeFG, 1, row, 1, 1);
        }

        gColors.showAll();
        popAdvanced.add(gColors);
        return popAdvanced;
    }

    /**
     * Manually updates color buttons when new settings is binded Since
     * you can't bind rgba to settings directly
     */
    void bindColorButtons() {
        // FG and BG color buttons
        cbFG.setRgba(parseColor(gsProfile.getString(SETTINGS_PROFILE_FG_COLOR_KEY)));
        cbBG.setRgba(parseColor(gsProfile.getString(SETTINGS_PROFILE_BG_COLOR_KEY)));
        // Update Color Palette buttons
        string[] colorValues = gsProfile.getStrv(SETTINGS_PROFILE_PALETTE_COLOR_KEY);
        for (int i = 0; i < colorValues.length; i++) {
            cbPalette[i].setRgba(parseColor(colorValues[i]));
        }
        //Cursor Colors
        cbCursorFG.setRgba(parseColor(gsProfile.getString(SETTINGS_PROFILE_CURSOR_FG_COLOR_KEY)));
        cbCursorBG.setRgba(parseColor(gsProfile.getString(SETTINGS_PROFILE_CURSOR_BG_COLOR_KEY)));
        //Highlight Colors
        cbHighlightFG.setRgba(parseColor(gsProfile.getString(SETTINGS_PROFILE_HIGHLIGHT_FG_COLOR_KEY)));
        cbHighlightBG.setRgba(parseColor(gsProfile.getString(SETTINGS_PROFILE_HIGHLIGHT_BG_COLOR_KEY)));

        cbBoldFG.setRgba(parseColor(gsProfile.getString(SETTINGS_PROFILE_BOLD_COLOR_KEY)));

        cbBadgeFG.setRgba(parseColor(gsProfile.getString(SETTINGS_PROFILE_BADGE_COLOR_KEY)));
    }

    /**
     * Creates the color grid of foreground, background and palette colors
     */
    Grid createColorGrid(int row) {
        Grid gColors = new Grid();
        gColors.setColumnSpacing(6);
        gColors.setRowSpacing(6);
        cbBG = new ColorButton();

        bh.bind(SETTINGS_PROFILE_USE_THEME_COLORS_KEY, cbBG, "sensitive", SettingsBindFlags.Get | SettingsBindFlags.NoSensitivity | SettingsBindFlags
                .InvertBoolean);
        cbBG.setTitle(_("Select Background Color"));
        cbBG.connectColorSet(delegate(ColorButton cb) {
            if (!blockColorUpdates) {
                trace("Updating background color");
                setCustomScheme();
                RGBA color;
                cb.getRgba(color);
                gsProfile.setString(SETTINGS_PROFILE_BG_COLOR_KEY, rgbaTo16bitHex(color, false, true));
            }
        });
        gColors.attach(cbBG, 0, row, 1, 1);
        gColors.attach(new Label(_("Background")), 1, row, 2, 1);

        cbFG = new ColorButton();
        bh.bind(SETTINGS_PROFILE_USE_THEME_COLORS_KEY, cbFG, "sensitive", SettingsBindFlags.Get | SettingsBindFlags.NoSensitivity | SettingsBindFlags
                .InvertBoolean);
        cbFG.setTitle(_("Select Foreground Color"));
        cbFG.connectColorSet(delegate(ColorButton cb) {
            if (!blockColorUpdates) {
                setCustomScheme();
                RGBA color;
                cb.getRgba(color);
                gsProfile.setString(SETTINGS_PROFILE_FG_COLOR_KEY, rgbaTo16bitHex(color, false, true));
            }
        });

        Label lblSpacer = new Label(" ");
        lblSpacer.setHexpand(true);
        gColors.attach(lblSpacer, 3, row, 1, 1);

        gColors.attach(cbFG, 4, row, 1, 1);
        gColors.attach(new Label(_("Foreground")), 5, row, 2, 1);
        cbBG.setTitle(_("Select Foreground Color"));
        row++;

        immutable string[8] colors = [_("Black"), _("Red"), _("Green"), _("Orange"), _("Blue"), _("Purple"), _("Turquoise"), _("Grey")];
        int col = 0;
        for (int i = 0; i < colors.length; i++) {
            ColorButton cbNormal = new ColorButton();
            cbNormal.connectColorSet(&onPaletteColorSet);
            cbNormal.setData(PALETTE_COLOR_INDEX_KEY, cast(void*) i);
            cbNormal.setTitle(format(_("Select %s Color"), colors[i]));
            gColors.attach(cbNormal, col, row, 1, 1);
            cbPalette[i] = cbNormal;

            ColorButton cbLight = new ColorButton();
            cbLight.connectColorSet(&onPaletteColorSet);
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
        if (!blockColorUpdates) {
            setCustomScheme();
            RGBA color;
            cb.getRgba(color);
            string[] colorValues = gsProfile.getStrv(SETTINGS_PROFILE_PALETTE_COLOR_KEY);
            colorValues[cast(int) cb.getData(PALETTE_COLOR_INDEX_KEY)] = rgbaTo16bitHex(color, false, true);
            gsProfile.setStrv(SETTINGS_PROFILE_PALETTE_COLOR_KEY, colorValues);
        }
    }

    RGBA parseColor(string color) {
        RGBA result = new RGBA();
        result.parse(color);
        return result;
    }

    /**
     * Creates a color scheme from the UI
     */
    ColorScheme getColorSchemeFromUI() {
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

        scheme.useBoldColor = cbUseBoldColor.getActive();
        cbBoldFG.getRgba(scheme.boldColor);

        scheme.useBadgeColor = cbUseBadgeColor.getActive();
        cbBadgeFG.getRgba(scheme.badgeColor);

        return scheme;
    }

    /**
     * This method checks to see if a color scheme matches
     * the current color settings and then set the scheme combobox
     * to that scheme. This provides the user some feedback that
     * they have selected a matching color scheme.
     *
     * Since we don't store the scheme in Settings this is
     * really useful when re-loading the app to show the same
     * scheme they selected previously instead of custom
     */
    void initColorSchemeCombo() {
        //Initialize ColorScheme
        ColorScheme scheme = getColorSchemeFromUI();
        trace("Initialized color scheme");
        trace(scheme);

        int index = findSchemeByColors(schemes, scheme);
        import gobject.global;
import gobject.types;
        gobject.global.signalHandlerBlock(cbScheme, schemeOnChangedHandle);
        try {
            if (index < 0)
                cbScheme.setActive(to!int(schemes.length));
            else
                cbScheme.setActive(index);
        } finally {
            gobject.global.signalHandlerUnblock(cbScheme, schemeOnChangedHandle);
        }
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
            //Bold colors
            gsProfile.setBoolean(SETTINGS_PROFILE_USE_BOLD_COLOR_KEY, scheme.useBoldColor);
            if (scheme.useBoldColor) {
                gsProfile.setString(SETTINGS_PROFILE_BOLD_COLOR_KEY, rgbaTo8bitHex(scheme.boldColor, false, true));
                cbBoldFG.setRgba(scheme.boldColor);
            }
            //Badge colors
            gsProfile.setBoolean(SETTINGS_PROFILE_USE_BADGE_COLOR_KEY, scheme.useBadgeColor);
            if (scheme.useBadgeColor) {
                gsProfile.setString(SETTINGS_PROFILE_BADGE_COLOR_KEY, rgbaTo8bitHex(scheme.badgeColor, false, true));
                cbBadgeFG.setRgba(scheme.badgeColor);
            }
            //Highlight colors
            gsProfile.setBoolean(SETTINGS_PROFILE_USE_HIGHLIGHT_COLOR_KEY, scheme.useHighlightColor);
            if (scheme.useHighlightColor) {
                gsProfile.setString(SETTINGS_PROFILE_HIGHLIGHT_FG_COLOR_KEY, rgbaTo8bitHex(scheme.highlightFG, false, true));
                gsProfile.setString(SETTINGS_PROFILE_HIGHLIGHT_BG_COLOR_KEY, rgbaTo8bitHex(scheme.highlightBG, false, true));
                cbHighlightFG.setRgba(scheme.highlightFG);
                cbHighlightBG.setRgba(scheme.highlightBG);
            }
            //Cursor Colors
            gsProfile.setBoolean(SETTINGS_PROFILE_USE_CURSOR_COLOR_KEY, scheme.useCursorColor);
            if (scheme.useCursorColor) {
                gsProfile.setString(SETTINGS_PROFILE_CURSOR_FG_COLOR_KEY, rgbaTo8bitHex(scheme.cursorFG, false, true));
                gsProfile.setString(SETTINGS_PROFILE_CURSOR_BG_COLOR_KEY, rgbaTo8bitHex(scheme.cursorBG, false, true));
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

    void exportColorScheme(Button button) {
        import gtk.c.functions: gtk_file_chooser_dialog_new;
        import gtk.c.types: GtkWindow;
        import gobject.object : ObjectWrap;
        import std.string: toStringz;

        auto _cretval = gtk_file_chooser_dialog_new(
          toStringz(_("Export Color Scheme")),
          cast(GtkWindow*)getToplevel()._cPtr(No.Dup),
          FileChooserAction.Save,
          toStringz(_("Save")), ResponseType.Ok,
          toStringz(_("Cancel")), ResponseType.Cancel,
          null);
        FileChooserDialog fcd = ObjectWrap._getDObject!(FileChooserDialog)(_cretval, Yes.Take);

        scope (exit)
            fcd.destroy();

        if (fcd.run() != ResponseType.Ok) return;

        string path = buildPath(getUserConfigDir(), APPLICATION_CONFIG_FOLDER, SCHEMES_FOLDER);
        if (!exists(path)) {
            mkdirRecurse(path);
        }

        fcd.setCurrentFolder(path);

        FileFilter ff = new FileFilter();
        ff.addPattern("*.json");
        ff.setName(_("All JSON Files"));
        fcd.addFilter(ff);
        ff = new FileFilter();
        ff.addPattern("*");
        ff.setName(_("All Files"));
        fcd.addFilter(ff);

        fcd.setDoOverwriteConfirmation(true);
        fcd.setDefaultResponse(gtk.types.ResponseType.Ok);
        fcd.setCurrentName("Custom.json");

        if (fcd.run() == gtk.types.ResponseType.Ok) {
            string filename = fcd.getFilename();
            ColorScheme scheme = getColorSchemeFromUI();
            scheme.save(filename);
            reload();
        } else {
            return;
        }
    }

    void reload() {
        schemes = loadColorSchemes();
        cbScheme.removeAll();
        foreach (scheme; schemes) {
            cbScheme.append(scheme.id, scheme.name);
        }
        cbScheme.append("custom", _("Custom"));
        import gtk.global;
import gtk.types;
        mainIterationDo(false);
        initColorSchemeCombo();
    }

public:

    this() {
        super();
        createUI();
        reload();
    }

    override void bind(ProfileInfo profile, Settings gsProfile) {
        blockColorUpdates = true;
        scope(exit) {blockColorUpdates = false;}

        super.bind(profile, gsProfile);
        if (gsProfile !is null) {
            bindColorButtons();
            initColorSchemeCombo();
        }
    }
}

/**
 * The page to manage scrolling options
 */
class ScrollPage : ProfilePage {

private:

    void createUI() {
        CheckButton cbShowScrollbar = CheckButton.newWithLabel(_("Show scrollbar"));
        bh.bind(SETTINGS_PROFILE_SHOW_SCROLLBAR_KEY, cbShowScrollbar, "active", SettingsBindFlags.Default);
        add(cbShowScrollbar);

        CheckButton cbScrollOnOutput = CheckButton.newWithLabel(_("Scroll on output"));
        bh.bind(SETTINGS_PROFILE_SCROLL_ON_OUTPUT_KEY, cbScrollOnOutput, "active", SettingsBindFlags.Default);
        add(cbScrollOnOutput);

        CheckButton cbScrollOnKeystroke = CheckButton.newWithLabel(_("Scroll on keystroke"));
        bh.bind(SETTINGS_PROFILE_SCROLL_ON_INPUT_KEY, cbScrollOnKeystroke, "active", SettingsBindFlags.Default);
        add(cbScrollOnKeystroke);

        CheckButton cbLimitScroll = CheckButton.newWithLabel(_("Limit scrollback to:"));
        bh.bind(SETTINGS_PROFILE_UNLIMITED_SCROLL_KEY, cbLimitScroll, "active", SettingsBindFlags.Default | SettingsBindFlags.InvertBoolean);
        SpinButton sbScrollbackSize = SpinButton.newWithRange(256.0, to!double(int.max), 256.0);
        bh.bind(SETTINGS_PROFILE_SCROLLBACK_LINES_KEY, sbScrollbackSize, "value", SettingsBindFlags.Default);
        bh.bind(SETTINGS_PROFILE_UNLIMITED_SCROLL_KEY, sbScrollbackSize, "sensitive",
                SettingsBindFlags.Get | SettingsBindFlags.NoSensitivity | SettingsBindFlags.InvertBoolean);

        Box b = new Box(gtk.types.Orientation.Horizontal, 12);
        b.add(cbLimitScroll);
        b.add(sbScrollbackSize);
        add(b);
    }

public:

    this() {
        super();
        createUI();
    }
}

/**
 * The profile page that manages compatibility options
 */
class CompatibilityPage : ProfilePage {

private:

    void createUI() {
        Grid grid = new Grid();

        grid.setColumnSpacing(12);
        grid.setRowSpacing(6);

        int row = 0;
        Label lblBackspace = new Label(_("Backspace key generates"));
        lblBackspace.setHalign(Align.End);
        grid.attach(lblBackspace, 0, row, 1, 1);
        ComboBox cbBackspace = createNameValueCombo([_("Automatic"), _("Control-H"), _("ASCII DEL"), _("Escape sequence"), _("TTY")], SETTINGS_PROFILE_ERASE_BINDING_VALUES);
        bh.bind(SETTINGS_PROFILE_BACKSPACE_BINDING_KEY, cbBackspace, "active-id", SettingsBindFlags.Default);

        grid.attach(cbBackspace, 1, row, 1, 1);
        row++;

        Label lblDelete = new Label(_("Delete key generates"));
        lblDelete.setHalign(Align.End);
        grid.attach(lblDelete, 0, row, 1, 1);
        ComboBox cbDelete = createNameValueCombo([_("Automatic"), _("Control-H"), _("ASCII DEL"), _("Escape sequence"), _("TTY")], SETTINGS_PROFILE_ERASE_BINDING_VALUES);
        bh.bind(SETTINGS_PROFILE_DELETE_BINDING_KEY, cbDelete, "active-id", SettingsBindFlags.Default);

        grid.attach(cbDelete, 1, row, 1, 1);
        row++;

        Label lblEncoding = new Label(_("Encoding"));
        lblEncoding.setHalign(Align.End);
        grid.attach(lblEncoding, 0, row, 1, 1);
        string[] key, value;
        key.length = encodings.length;
        value.length = encodings.length;
        foreach (i, encoding; encodings) {
            key[i] = encoding[0];
            value[i] = encoding[0] ~ " " ~ _(encoding[1]);
        }
        ComboBox cbEncoding = createNameValueCombo(value, key);
        bh.bind(SETTINGS_PROFILE_ENCODING_KEY, cbEncoding, "active-id", SettingsBindFlags.Default);
        grid.attach(cbEncoding, 1, row, 1, 1);
        row++;

        Label lblCJK = new Label(_("Ambiguous-width characters"));
        lblCJK.setHalign(Align.End);
        grid.attach(lblCJK, 0, row, 1, 1);
        ComboBox cbCJK = createNameValueCombo([_("Narrow"), _("Wide")], SETTINGS_PROFILE_CJK_WIDTH_VALUES);
        bh.bind(SETTINGS_PROFILE_CJK_WIDTH_KEY, cbCJK, "active-id", SettingsBindFlags.Default);
        grid.attach(cbCJK, 1, row, 1, 1);
        row++;

        add(grid);
    }

public:

    this() {
        super();
        createUI();
    }
}

class CommandPage : ProfilePage {

private:

    void createUI() {
        CheckButton cbLoginShell = CheckButton.newWithLabel(_("Run command as a login shell"));
        bh.bind(SETTINGS_PROFILE_LOGIN_SHELL_KEY, cbLoginShell, "active", SettingsBindFlags.Default);
        add(cbLoginShell);

        CheckButton cbCustomCommand = CheckButton.newWithLabel(_("Run a custom command instead of my shell"));
        bh.bind(SETTINGS_PROFILE_USE_CUSTOM_COMMAND_KEY, cbCustomCommand, "active", SettingsBindFlags.Default);
        add(cbCustomCommand);

        Box bCommand = new Box(gtk.types.Orientation.Horizontal, 12);
        bCommand.setMarginLeft(12);
        Label lblCommand = new Label(_("Command"));
        bh.bind(SETTINGS_PROFILE_USE_CUSTOM_COMMAND_KEY, lblCommand, "sensitive", SettingsBindFlags.Get | SettingsBindFlags.NoSensitivity);
        bCommand.add(lblCommand);
        Entry eCommand = new Entry();
        eCommand.setHexpand(true);
        bh.bind(SETTINGS_PROFILE_CUSTOM_COMMAND_KEY, eCommand, "text", SettingsBindFlags.Default);
        bh.bind(SETTINGS_PROFILE_USE_CUSTOM_COMMAND_KEY, eCommand, "sensitive", SettingsBindFlags.Get | SettingsBindFlags.NoSensitivity);
        bCommand.add(eCommand);
        add(bCommand);

        Box bWhenExits = new Box(gtk.types.Orientation.Horizontal, 12);
        Label lblWhenExists = new Label(_("When command exits"));
        bWhenExits.add(lblWhenExists);
        ComboBox cbWhenExists = createNameValueCombo([_("Exit the terminal"), _("Restart the command"), _("Hold the terminal open")], SETTINGS_PROFILE_EXIT_ACTION_VALUES);
        bh.bind(SETTINGS_PROFILE_EXIT_ACTION_KEY, cbWhenExists, "active-id", SettingsBindFlags.Default);
        bWhenExits.add(cbWhenExists);

        add(bWhenExits);
    }

public:
    this() {
        super();
        createUI();
    }
}

/**
 * Page that manages options for Badges
 */
class BadgePage: ProfilePage {

    void createUI() {
        int row = 0;
        Grid grid = new Grid();
        grid.setColumnSpacing(12);
        grid.setRowSpacing(6);

        //Badge text
        Label lblBadge = new Label(_("Badge"));
        lblBadge.setHalign(Align.End);
        grid.attach(lblBadge, 0, row, 1, 1);
        Entry eBadge = new Entry();
        eBadge.setHexpand(true);
        bh.bind(SETTINGS_PROFILE_BADGE_TEXT_KEY, eBadge, "text", SettingsBindFlags.Default);
        if (checkVersion(3, 16, 0).length == 0) {
            grid.attach(createTitleEditHelper(eBadge, TitleEditScope.TERMINAL), 1, row, 1, 1);
        } else {
            grid.attach(eBadge, 1, row, 1, 1);
        }
        row++;

        //Badge Position
        Label lblBadgePosition = new Label(_("Badge position"));
        lblBadgePosition.setHalign(Align.End);
        grid.attach(lblBadgePosition, 0, row, 1, 1);

        ComboBox cbBadgePosition = createNameValueCombo([_("Northwest"), _("Northeast"), _("Southwest"), _("Southeast")], SETTINGS_QUADRANT_VALUES);
        bh.bind(SETTINGS_PROFILE_BADGE_POSITION_KEY, cbBadgePosition, "active-id", SettingsBindFlags.Default);
        grid.attach(cbBadgePosition, 1, row, 1, 1);
        row++;

        //Custom Font
        Label lblCustomFont = new Label(_("Custom font"));
        lblCustomFont.setHalign(Align.End);
        grid.attach(lblCustomFont, 0, row, 1, 1);


        Box bFont = new Box(gtk.types.Orientation.Horizontal, 12);
        CheckButton cbCustomFont = new CheckButton();
        bh.bind(SETTINGS_PROFILE_BADGE_USE_SYSTEM_FONT_KEY, cbCustomFont, "active", SettingsBindFlags.Default | SettingsBindFlags.InvertBoolean);
        bFont.add(cbCustomFont);

        //Font Selector
        FontButton fbFont = new FontButton();
        fbFont.setTitle(_("Choose A Badge Font"));
        bh.bind(SETTINGS_PROFILE_BADGE_FONT_KEY, fbFont, "font-name", SettingsBindFlags.Default);
        bh.bind(SETTINGS_PROFILE_BADGE_USE_SYSTEM_FONT_KEY, fbFont, "sensitive", SettingsBindFlags.Get | SettingsBindFlags.NoSensitivity | SettingsBindFlags
                .InvertBoolean);
        bFont.add(fbFont);
        grid.attach(bFont, 1, row, 1, 1);
        row++;

        add(grid);
    }

public:
    this() {
        super();
        createUI();
    }
}

/**
 * Page for advanced profile options such as custom hyperlinks and profile switching
 */
class AdvancedPage: ProfilePage {
private:
    TreeView tvValues;
    ListStore lsValues;

    Button btnAdd;
    Button btnEdit;
    Button btnDelete;

     void createUI() {
        Grid grid = new Grid();
        grid.setColumnSpacing(12);
        grid.setRowSpacing(6);

        uint row = 0;

        //Notify silence threshold
        Label lblSilenceTitle = new Label(format("<b>%s</b>", _("Notify New Activity")));
        lblSilenceTitle.setUseMarkup(true);
        lblSilenceTitle.setHalign(Align.Start);
        lblSilenceTitle.setMarginTop(12);
        grid.attach(lblSilenceTitle, 0, row, 3, 1);
        row++;

        grid.attach(createDescriptionLabel(_("A notification can be raised when new activity occurs after a specified period of silence.")),0,row,2,1);
        row++;

        Widget silenceUI = createSilenceUI();
        silenceUI.setMarginTop(6);
        silenceUI.setMarginBottom(6);
        grid.attach(silenceUI, 0, row, 2, 1);
        row++;

        // Create shared advance UI Settings
        createAdvancedUI(grid, row, &getSettings);

        // Profile Switching
        Label lblProfileSwitching = new Label(format("<b>%s</b>", _("Automatic Profile Switching")));
        lblProfileSwitching.setUseMarkup(true);
        lblProfileSwitching.setHalign(Align.Start);
        lblProfileSwitching.setMarginTop(12);
        grid.attach(lblProfileSwitching, 0, row, 3, 1);
        row++;

        string profileSwitchingDescription;
        if (checkVTEFeature(TerminalFeature.EVENT_SCREEN_CHANGED)) {
            profileSwitchingDescription = _("Profiles are automatically selected based on the values entered here.\nValues are entered using a <i>username@hostname:directory</i> format. Either the hostname or directory can be omitted but the colon must be present. Entries with neither hostname or directory are not permitted.");
        } else {
            profileSwitchingDescription = _("Profiles are automatically selected based on the values entered here.\nValues are entered using a <i>hostname:directory</i> format. Either the hostname or directory can be omitted but the colon must be present. Entries with neither hostname or directory are not permitted.");
        }
        grid.attach(createDescriptionLabel(profileSwitchingDescription),0,row,2,1);
        row++;

        lsValues = ListStore.new_([cast(GType)GTypeEnum.String]);
        tvValues = new TreeView();
        tvValues.setModel(lsValues);
        tvValues.setActivateOnSingleClick(true);
        tvValues.connectCursorChanged(delegate(TreeView tv) {
            updateUI();
        });

        TreeViewColumn column = new TreeViewColumn();
        column.setTitle(_("Match"));
        CellRendererText crtMatch = new CellRendererText();
        column.packStart(crtMatch, true);
        column.addAttribute(crtMatch, "text", 0);
        tvValues.appendColumn(column);

        ScrolledWindow scValues = new ScrolledWindow();
        scValues.add(tvValues);
        scValues.setShadowType(ShadowType.EtchedIn);
        scValues.setPolicy(PolicyType.Never, PolicyType.Automatic);
        scValues.setHexpand(true);

        Box bButtons = new Box(gtk.types.Orientation.Vertical, 4);
        bButtons.setVexpand(true);

        btnAdd = Button.newWithLabel(_("Add"));
        btnAdd.connectClicked(delegate(Button btn) {
            string label, value;
            if (checkVTEFeature(TerminalFeature.EVENT_SCREEN_CHANGED)) {
                label = _("Enter username@hostname:directory to match");
            } else {
                label = _("Enter hostname:directory to match");
            }
            if (showInputDialog(cast(Window)getToplevel(), value, "", _("Add New Match"), label, &validateInput)) {
                TreeIter iter;
                lsValues.append(iter);
                lsValues.setValue(iter, 0, new Value(value));
                storeValues();
                selectRow(tvValues, lsValues.iterNChildren(null) - 1, null);
            }
        });

        bButtons.add(btnAdd);

        btnEdit = Button.newWithLabel(_("Edit"));
        btnEdit.connectClicked(delegate(Button btn) {
            TreeIter iter;
            TreeModel model;
            if (tvValues.getSelection().getSelected(model, iter)) {
                Value val = new Value();
                model.getValue(iter, 0, val);
                string value = val.getString();
                string label;
                if (checkVTEFeature(TerminalFeature.EVENT_SCREEN_CHANGED)) {
                    label = _("Edit username@hostname:directory to match");
                } else {
                    label = _("Edit hostname:directory to match");
                }
                if (showInputDialog(cast(Window)getToplevel(), value, value, _("Edit Match"), label, &validateInput)) {
                    lsValues.setValue(iter, 0, new Value(value));
                    storeValues();
                }
            }
        });
        bButtons.add(btnEdit);

        btnDelete = Button.newWithLabel(_("Delete"));
        btnDelete.connectClicked(delegate(Button btn) {
            TreeIter iter;
            TreeModel model;
            if (tvValues.getSelection().getSelected(model, iter)) {
                lsValues.remove(iter);
                storeValues();
            }
        });
        bButtons.add(btnDelete);

        grid.attach(scValues, 0, row, 2, 1);
        grid.attach(bButtons, 2, row, 1, 1);

        this.add(grid);
    }

    Widget createSilenceUI() {
        Grid grid = new Grid();
        grid.setColumnSpacing(12);
        grid.setRowSpacing(6);

        uint row = 0;

        Label lblSilence = new Label(_("Enable by default"));
        lblSilence.setHalign(Align.End);
        grid.attach(lblSilence, 0, row, 1, 1);

        CheckButton cbSilence = new CheckButton();
        bh.bind(SETTINGS_PROFILE_NOTIFY_ENABLED_KEY, cbSilence, "active", SettingsBindFlags.Default);
        grid.attach(cbSilence, 1, row, 1, 1);
        row++;

        Label lblSilenceDesc = new Label(_("Threshold for continuous silence"));
        lblSilenceDesc.setHalign(Align.End);
        grid.attach(lblSilenceDesc, 0, row, 1, 1);

        Box bSilence = new Box(gtk.types.Orientation.Horizontal, 4);
        SpinButton sbSilence = SpinButton.newWithRange(0, 3600, 60);
        bh.bind(SETTINGS_PROFILE_NOTIFY_SILENCE_THRESHOLD_KEY, sbSilence, "value", SettingsBindFlags.Default);
        bSilence.add(sbSilence);

        Label lblSilenceTime = new Label(_("(seconds)"));
        lblSilenceTime.setSensitive(false);
        bSilence.add(lblSilenceTime);

        grid.attach(bSilence, 1, row, 1, 1);
        row++;

        return grid;
    }

    void updateUI() {
        TreeIter iter;
        TreeModel model;
        bool selected = tvValues.getSelection().getSelected(model, iter);
        btnDelete.setSensitive(selected);
        btnEdit.setSensitive(selected);
    }

    void updateBindValues() {
        //Automatic switching
        lsValues.clear();
        string[] values = gsProfile.getStrv(SETTINGS_PROFILE_AUTOMATIC_SWITCH_KEY);
        foreach(value; values) {
            TreeIter iter;
            lsValues.append(iter);
            lsValues.setValue(iter, 0, new Value(value));
        }

    }

    // Validate input, just checks something was entered at this point
    // and least one delimiter, either @ or :
    bool validateInput(string match) {
        if (checkVTEFeature(TerminalFeature.EVENT_SCREEN_CHANGED))
            return (match.length > 1 && (match.indexOf('@') >= 0 || match.indexOf(':') >= 0));
        else
            return (match.length > 1 && (match.indexOf('@') == 0 || match.indexOf(':') >= 0));
    }

    // Store the values in the ListStore into settings
    void storeValues() {
        string[] values;
        foreach (TreeIter iter; TreeIterRange(lsValues)) {
            Value val = new Value();
            lsValues.getValue(iter, 0, val);
            values ~= val.getString();
        }
        gsProfile.setStrv(SETTINGS_PROFILE_AUTOMATIC_SWITCH_KEY, values);
    }

    Settings getSettings() {
        return gsProfile;
    }

public:
    this() {
        super();
        createUI();
    }

    override void bind(ProfileInfo profile, Settings gsProfile) {
        super.bind(profile, gsProfile);
        if (gsProfile !is null) {
            updateBindValues();
            updateUI();
        }
    }
}
