project(
    'Tilix', 'd',
    version: '1.9.7',
    license: 'MPL-2.0',
    meson_version: '>= 0.56'
)

compiler = meson.get_compiler('d')
if compiler.get_id() == 'llvm'
  d_extra_args = ['-vcolumns']
  d_link_args = []
elif compiler.get_id() == 'dmd'
  # Workaround for https://issues.dlang.org/show_bug.cgi?id=20668
  d_extra_args = ['-allinst']
  d_link_args = []
elif compiler.get_id() == 'gcc'
  # Workaround for https://issues.dlang.org/show_bug.cgi?id=20668
  d_extra_args = ['-fall-instantiations']
  d_link_args = []
endif

project_id = 'com.gexperts.Tilix'
project_name = meson.project_name()

gnome = import('gnome')
i18n = import('i18n')

prefix = get_option('prefix')
bindir = prefix / get_option('bindir')
datadir = prefix / get_option('datadir')
pkgdatadir = datadir / project_name.to_lower()
schemadir = datadir / 'glib-2.0' / 'schemas'
iconsdir = datadir / 'icons' / 'hicolor'
appdir = datadir / 'applications'

tilix_sources = [
    'source/gx/gtk/actions.d',
    'source/gx/gtk/cairo.d',
    'source/gx/gtk/clipboard.d',
    'source/gx/gtk/color.d',
    'source/gx/gtk/dialog.d',
    'source/gx/gtk/resource.d',
    'source/gx/gtk/settings.d',
    'source/gx/gtk/threads.d',
    'source/gx/gtk/util.d',
    'source/gx/gtk/vte.d',
    'source/gx/gtk/x11.d',
    'source/gx/i18n/l10n.d',
    'source/gx/tilix/bookmark/bmchooser.d',
    'source/gx/tilix/bookmark/bmeditor.d',
    'source/gx/tilix/bookmark/bmtreeview.d',
    'source/gx/tilix/bookmark/manager.d',
    'source/gx/tilix/prefeditor/advdialog.d',
    'source/gx/tilix/prefeditor/bookmarkeditor.d',
    'source/gx/tilix/prefeditor/common.d',
    'source/gx/tilix/prefeditor/prefdialog.d',
    'source/gx/tilix/prefeditor/profileeditor.d',
    'source/gx/tilix/prefeditor/titleeditor.d',
    'source/gx/tilix/terminal/actions.d',
    'source/gx/tilix/terminal/activeprocess.d',
    'source/gx/tilix/terminal/advpaste.d',
    'source/gx/tilix/terminal/exvte.d',
    'source/gx/tilix/terminal/layout.d',
    'source/gx/tilix/terminal/monitor.d',
    'source/gx/tilix/terminal/password.d',
    'source/gx/tilix/terminal/regex.d',
    'source/gx/tilix/terminal/search.d',
    'source/gx/tilix/terminal/terminal.d',
    'source/gx/tilix/terminal/util.d',
    'source/gx/tilix/application.d',
    'source/gx/tilix/appwindow.d',
    'source/gx/tilix/closedialog.d',
    'source/gx/tilix/cmdparams.d',
    'source/gx/tilix/colorschemes.d',
    'source/gx/tilix/common.d',
    'source/gx/tilix/constants.d',
    'source/gx/tilix/customtitle.d',
    'source/gx/tilix/encoding.d',
    'source/gx/tilix/preferences.d',
    'source/gx/tilix/session.d',
    'source/gx/tilix/shortcuts.d',
    'source/gx/tilix/sidebar.d',
    'source/gx/util/array.d',
    'source/gx/util/path.d',
    'source/gx/util/string.d',
    'source/secret/Collection.d',
    'source/secret/Item.d',
    'source/secret/Prompt.d',
    'source/secret/Schema.d',
    'source/secret/SchemaAttribute.d',
    'source/secret/Secret.d',
    'source/secret/Service.d',
    'source/secret/Value.d',
    'source/secretc/secret.d',
    'source/secretc/secrettypes.d',
    'source/x11/X.d',
    'source/x11/Xlib.d',
    'source/app.d'
]

sources_dir = include_directories('source/')

# Dependencies
gtkd_dep = dependency('gtkd-3', version: '>=3.8.5')
vted_dep = dependency('vted-3', version: '>=3.8.5')
xlib_dep = dependency('x11')
libunwind_dep = dependency('libunwind')
libsecret_dep = dependency('libsecret-1', required: false)

subdir('po')
subdir('data')

# Build & Test
executable('tilix',
    [tilix_sources, gresource],
    include_directories : sources_dir,
    dependencies : [gtkd_dep,
                    vted_dep,
                    xlib_dep,
                    libunwind_dep,
                    libsecret_dep],
    d_args: d_extra_args,
    d_module_versions: ['StdLoggerDisableTrace'],
    link_args: d_link_args,
    install : true
)

tilix_test_exe = executable('tilix_test',
    [tilix_sources],
    include_directories : [sources_dir],
    dependencies : [gtkd_dep,
                    vted_dep,
                    xlib_dep],
    d_args: d_extra_args,
    link_args: d_link_args,
    d_unittest: true
)
test('tilix_test', tilix_test_exe)

meson.add_install_script('meson_post_install.py')
