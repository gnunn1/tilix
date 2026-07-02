project(
    'Tilix', 'd',
    version: '1.9.7',
    license: 'MPL-2.0',
    meson_version: '>= 0.56'
)

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

# Dependencies (for pkg-config checks only, actual linking done by dub)
xlib_dep = dependency('x11')
libsecret_dep = dependency('libsecret-1', required: false)

subdir('po')
subdir('data')

# Build using dub with GDC compiler
# We use a custom_target because gid bindings are D source packages
# that need to be compiled by dub, not meson's D support

tilix_dub = custom_target('tilix',
    output: 'tilix',
    command: [
        'sh', '-c',
        'cd @0@ && dub build --compiler=gdc --build=debug && cp tilix @1@/'.format(
            meson.current_source_dir(),
            meson.current_build_dir()
        )
    ],
    build_by_default: true,
    console: true,
    install: true,
    install_dir: bindir
)

meson.add_install_script('meson_post_install.py')
