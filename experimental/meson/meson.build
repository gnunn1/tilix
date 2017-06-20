project('Tilix', 'd')

compiler = meson.get_compiler('d')

if compiler.get_id() == 'gcc'
    error('Tilix can not be compiled with GDC at time, since the standard library version of all GDC versions is currently (2016) too old. Sorry.')
endif

glib = import('gnome')
i18n = import('i18n')

tilix_sources = [
    'source/gx/util/array.d',
    'source/gx/util/path.d',
    'source/gx/util/string.d',
    'source/gx/i18n/l10n.d',
    'source/gx/tilix/encoding.d',
    'source/gx/tilix/appwindow.d',
    'source/gx/tilix/cmdparams.d',
    'source/gx/tilix/session.d',
    'source/gx/tilix/sidebar.d',
    'source/gx/tilix/preferences.d',
    'source/gx/tilix/colorschemes.d',
    'source/gx/tilix/terminal/search.d',
    'source/gx/tilix/terminal/exvte.d',
    'source/gx/tilix/terminal/terminal.d',
    'source/gx/tilix/terminal/regex.d',
    'source/gx/tilix/terminal/password.d',
    'source/gx/tilix/terminal/layout.d',
    'source/gx/tilix/terminal/advpaste.d',
    'source/gx/tilix/terminal/util.d',
    'source/gx/tilix/terminal/actions.d',
    'source/gx/tilix/constants.d',
    'source/gx/tilix/bookmark/bmtreeview.d',
    'source/gx/tilix/bookmark/bmeditor.d',
    'source/gx/tilix/bookmark/manager.d',
    'source/gx/tilix/bookmark/bmchooser.d',
    'source/gx/tilix/shortcuts.d',
    'source/gx/tilix/sessionswitcher.d',
    'source/gx/tilix/application.d',
    'source/gx/tilix/closedialog.d',
    'source/gx/tilix/customtitle.d',
    'source/gx/tilix/common.d',
    'source/gx/tilix/prefeditor/advdialog.d',
    'source/gx/tilix/prefeditor/common.d',
    'source/gx/tilix/prefeditor/prefdialog.d',
    'source/gx/tilix/prefeditor/titleeditor.d',
    'source/gx/tilix/prefeditor/bookmarkeditor.d',
    'source/gx/tilix/prefeditor/profileeditor.d',
    'source/gx/gtk/resource.d',
    'source/gx/gtk/actions.d',
    'source/gx/gtk/cairo.d',
    'source/gx/gtk/clipboard.d',
    'source/gx/gtk/color.d',
    'source/gx/gtk/dialog.d',
    'source/gx/gtk/settings.d',
    'source/gx/gtk/threads.d',
    'source/gx/gtk/util.d',
    'source/gx/gtk/vte.d',
    'source/gx/gtk/x11.d',
    'source/secret/Service.d',
    'source/secret/Item.d',
    'source/secret/Secret.d',
    'source/secret/Prompt.d',
    'source/secret/Collection.d',
    'source/secret/SchemaAttribute.d',
    'source/secret/Schema.d',
    'source/secret/Value.d',
    'source/x11/X.d',
    'source/x11/Xlib.d',
    'source/secretc/secret.d',
    'source/secretc/secrettypes.d',
    'source/app.d'
]

source_root = meson.source_root()
sources_dir = include_directories('source/')

#
# Dependencies
#
gtkd_dep = dependency('gtkd-3', version: '>=3.5.0')
vted_dep = dependency('vted-3', version: '>=3.5.0')
xlib_dep = dependency('x11')
gcr = find_program('glib-compile-resources')
msgfmt = find_program('msgfmt')

# install target for arch-indep data
tilix_share = 'share/tilix'

#
# Build resources and metadata files
#
gresource = custom_target('glib-resource',
    input: 'data/resources/tilix.gresource.xml',
    output: 'tilix.gresource',
    command: [gcr, '@INPUT@',
        '--sourcedir', source_root + '/data/resources',
        '--target', '@OUTPUT@'],
    install: true,
    install_dir: tilix_share + '/resources'
)

desktop_target = custom_target('desktop-file',
    input: 'data/pkg/desktop/com.gexperts.Tilix.desktop.in',
    output: 'com.gexperts.Tilix.desktop',
    command: [msgfmt, '--desktop',
        '-d', source_root + '/po',
        '--template', '@INPUT@',
        '-o', '@OUTPUT@'],
    install: true,
    install_dir: 'share/applications'
)

metainfo_target = custom_target('metainfo',
    input: 'data/appdata/com.gexperts.Tilix.appdata.xml.in',
    output: 'com.gexperts.Tilix.appdata.xml',
    command: [msgfmt, '--xml',
        '-d', source_root + '/po',
        '--template', '@INPUT@',
        '-o', '@OUTPUT@'],
    install: true,
    install_dir: 'share/metainfo'
)

#
# Build & Test
#
tilix_exe = executable('tilix',
    [tilix_sources],
    include_directories : [sources_dir],
    dependencies : [gtkd_dep,
                    vted_dep,
                    xlib_dep],
    install : true
)

# FIXME: Unittests are currently broken
#tilix_test_exe = executable('tilix_test',
#    [tilix_sources],
#    include_directories : [sources_dir],
#    dependencies : [gtkd_dep,
#                    vted_dep,
#                    xlib_dep],
#    d_args: compiler.unittest_args()
#)
#test('tilix_test', tilix_test_exe)

# Validate things
desktop_file_validate = find_program('desktop-file-validate', required: false)
appstreamcli = find_program('appstreamcli', required: false)

if desktop_file_validate.found()
    test('desktopfile_test',
         desktop_file_validate,
         args: [desktop_target.full_path()]
    )
endif
if appstreamcli.found()
    test('appstream_test',
         appstreamcli,
         args: ['--no-color',
             'validate', metainfo_target.full_path()],
         should_fail: true # FIXME: the <kudos/> tag isn't in the spec and therefore this validation fails
    )
endif

#
# Install
#

color_schemes = [
    'data/schemes/base16-twilight-dark.json',
    'data/schemes/linux.json',
    'data/schemes/material.json',
    'data/schemes/monokai.json',
    'data/schemes/orchis.json',
    'data/schemes/solarized-dark.json',
    'data/schemes/solarized-light.json',
    'data/schemes/tango.json',
]

# GSettings schema
install_data('data/gsettings/com.gexperts.Tilix.gschema.xml', install_dir: 'share/glib-2.0/schemas')

# Color schemes
install_data(color_schemes, install_dir: tilix_share + '/schemes')

# Scripts
install_data('data/scripts/tilix_int.sh', install_dir: tilix_share + '/scripts')

# Copying Nautilus extension
install_data('data/nautilus/open-tilix.py', install_dir: 'share/nautilus-python/extensions/')

# Copy D-Bus service descriptor
install_data('data/dbus/com.gexperts.Tilix.service', install_dir: 'share/dbus-1/services/')

#
# Subdirectories
#
subdir('po')
subdir('data/icons')
