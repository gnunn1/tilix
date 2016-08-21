project('Terminix', 'd')

if meson.get_compiler('d').get_id() == 'gcc'
    error('Terminix can not be compiled with GDC at time, since the standard library version of all GDC versions is currently (2016) too old. Sorry.')
endif

glib = import('gnome')
i18n = import('i18n')

terminix_sources = ['source/app.d',
    'source/gx/gtk/actions.d',
    'source/gx/gtk/cairo.d',
    'source/gx/gtk/clipboard.d',
    'source/gx/gtk/dialog.d',
    'source/gx/gtk/resource.d',
    'source/gx/gtk/threads.d',
    'source/gx/gtk/util.d',
    'source/gx/gtk/vte.d',
    'source/gx/i18n/l10n.d',
    'source/gx/terminix/application.d',
    'source/gx/terminix/appwindow.d',
    'source/gx/terminix/cmdparams.d',
    'source/gx/terminix/colorschemes.d',
    'source/gx/terminix/common.d',
    'source/gx/terminix/constants.d',
    'source/gx/terminix/encoding.d',
    'source/gx/terminix/preferences.d',
    'source/gx/terminix/prefwindow.d',
    'source/gx/terminix/profilewindow.d',
    'source/gx/terminix/session.d',
    'source/gx/terminix/shortcuts.d',
    'source/gx/terminix/sidebar.d',
    'source/gx/terminix/terminal/actions.d',
    'source/gx/terminix/terminal/layout.d',
    'source/gx/terminix/terminal/search.d',
    'source/gx/terminix/terminal/terminal.d',
    'source/gx/terminix/terminal/vtenotification.d',
    'source/gx/util/array.d',
    'source/gx/util/string.d'
]

source_root = meson.source_root()
sources_dir = include_directories('source/')

#
# Dependencies
#
gtkd_dep = dependency('gtkd-3 >= 3.3.0')
vted_dep = dependency('vted-3 >= 3.3.0')
gcr = find_program('glib-compile-resources')
msgfmt = find_program('msgfmt')

# install target for arch-indep data
terminix_share = 'share/terminix'

#
# Build resources and metadata files
#
gresource = custom_target('glib-resource',
    input: 'data/resources/terminix.gresource.xml',
    output: 'terminix.gresource',
    command: [gcr, '@INPUT@',
        '--sourcedir', source_root + '/data/resources',
        '--target', '@OUTPUT@'],
    install: true,
    install_dir: terminix_share + '/resources'
)

desktop_target = custom_target('desktop-file',
    input: 'data/pkg/desktop/com.gexperts.Terminix.desktop.in',
    output: 'com.gexperts.Terminix.desktop',
    command: [msgfmt, '--desktop',
        '-d', source_root + '/po',
        '--template', '@INPUT@',
        '-o', '@OUTPUT@'],
    install: true,
    install_dir: 'share/applications'
)

metainfo_target = custom_target('metainfo',
    input: 'data/appdata/com.gexperts.Terminix.appdata.xml.in',
    output: 'com.gexperts.Terminix.appdata.xml',
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
terminix_exe = executable('terminix',
    [terminix_sources],
    include_directories : [sources_dir],
    dependencies : [gtkd_dep,
                    vted_dep],
    install : true
)

terminix_test_exe = executable('terminix_test',
    [terminix_sources],
    include_directories : [sources_dir],
    dependencies : [gtkd_dep,
                    vted_dep],
    d_args: [meson.get_compiler('d').get_unittest_flag()]
)
test('terminix_test', terminix_test_exe)

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
install_data('data/gsettings/com.gexperts.Terminix.gschema.xml', install_dir: 'share/glib-2.0/schemas')

# Color schemes
install_data(color_schemes, install_dir: terminix_share + '/schemes')

# Scripts
install_data('data/scripts/terminix_int.sh', install_dir: terminix_share + '/scripts')

# Copying Nautilus extension
install_data('data/nautilus/open-terminix.py', install_dir: 'share/nautilus-python/extensions/')

# Copy D-Bus service descriptor
install_data('data/dbus/com.gexperts.Terminix.service', install_dir: 'share/dbus-1/services/')

#
# Subdirectories
#
subdir('po')
subdir('data/icons')
