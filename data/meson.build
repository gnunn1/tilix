
# install the icons
install_data(
    'icons/hicolor/scalable/apps/@0@.svg'.format(meson.project_name()),
    install_dir: join_paths(get_option('datadir'), 'icons/hicolor/scalable/apps')
)
install_data(
    'icons/hicolor/scalable/apps/@0@-symbolic.svg'.format(meson.project_name()),
    install_dir: join_paths(get_option('datadir'), 'icons/hicolor/scalable/apps')
)


# Validate desktop file
desktop_file_validate = find_program('desktop-file-validate', required:false)
if desktop_file_validate.found()
  test (
    'Validate desktop file',
    desktop_file_validate,
    args: join_paths(meson.current_build_dir (), '@0@.desktop'.format(meson.project_name()))
  )
endif

# Install the desktop file
i18n.merge_file(
    output: '@0@.desktop'.format(meson.project_name()),
    input: 'pkg/desktop/@0@.desktop.in'.format(meson.project_name()),
    po_dir: join_paths(meson.source_root(), 'po'),
    type: 'desktop',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'applications')
)

# Validate AppData file
appstream_util = find_program('appstream-util', required:false)
if appstream_util.found()
  test (
    'Validate appdata file',
    appstream_util,
    args: ['validate-relax', '--nonet', join_paths(meson.current_build_dir (), '@0@.appdata.xml'.format(meson.project_name()))]
  )
endif

# Install the AppData file
i18n.merge_file(
    output: '@0@.appdata.xml'.format(meson.project_name()),
    input: 'appdata/@0@.appdata.xml.in'.format(meson.project_name()),
    po_dir: join_paths(meson.source_root(), 'po'),
    install: true,
    install_dir: join_paths(get_option('datadir'), 'metainfo')
)

# Build resources
gresource = gnome.compile_resources(
    'tilix',
    'resources/tilix.gresource.xml',
    gresource_bundle: true,
    install: true,
    source_dir: 'resources/',
    install_dir: join_paths(get_option('datadir'), 'tilix/resources')
)

# Install GSchemas
install_data(
  'gsettings/@0@.gschema.xml'.format(meson.project_name()),
  install_dir: join_paths(get_option('datadir'), 'glib-2.0/schemas')
)

# Color schemes
install_data(
    [
        'schemes/base16-twilight-dark.json',
        'schemes/linux.json',
        'schemes/material.json',
        'schemes/monokai.json',
        'schemes/orchis.json',
        'schemes/solarized-dark.json',
        'schemes/solarized-light.json',
        'schemes/tango.json',
    ],
    install_dir: join_paths(get_option('datadir'), 'tilix/schemes')
)

# Scripts
install_data(
    'scripts/tilix_int.sh',
    install_dir: join_paths(get_option('datadir'), 'tilix/scripts')
)

# Copying Nautilus extension
install_data(
    'nautilus/open-tilix.py',
    install_dir: join_paths(get_option('datadir'), 'nautilus-python/extensions')
)

# Copy D-Bus service descriptor
conf = configuration_data()
conf.set('bindir', join_paths(get_option('prefix'), get_option('bindir')))

configure_file(
  input: 'dbus/@0@.service.in'.format(meson.project_name()),
  output: 'dbus/@0@.service'.format(meson.project_name()),
  configuration: conf,
  install_dir: join_paths(get_option('datadir'), 'dbus-1/services')
)
