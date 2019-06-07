# install the icons
install_data(
    'icons/hicolor/scalable/apps/@0@.svg'.format(meson.project_name()),
    install_dir: iconsdir / 'scalable' / 'apps'
)
install_data(
    'icons/hicolor/scalable/apps/@0@-symbolic.svg'.format(meson.project_name()),
    install_dir: iconsdir / 'symbolic' / 'apps'
)

# Install the desktop file
desktop_file = i18n.merge_file(
    '@0@.desktop'.format(meson.project_name()),
    output: '@BASENAME@',
    input: 'pkg/desktop/@0@.desktop.in'.format(meson.project_name()),
    po_dir: meson.source_root() / 'po',
    type: 'desktop',
    install: true,
    install_dir: appdir
)

# Validate desktop file
desktop_file_validate = find_program('desktop-file-validate', required:false)
if desktop_file_validate.found()
  test (
    'Validate desktop file',
    desktop_file_validate,
    args: desktop_file.full_path()
  )
endif

# Install the AppData file
appdata_file = i18n.merge_file(
    '@0@.appdata.xml'.format(meson.project_name()),
    output: '@BASENAME@',
    input: 'appdata/@0@.appdata.xml.in'.format(meson.project_name()),
    po_dir: meson.source_root() / 'po',
    install: true,
    install_dir: datadir / 'metainfo'
)

# Validate AppData file
appstream_util = find_program('appstream-util', required:false)
if appstream_util.found()
  test (
    'Validate appdata file',
    appstream_util,
    args: ['validate-relax', '--nonet', appdata_file.full_path()]
  )
endif

# Build resources
gresource = gnome.compile_resources(
    'tilix',
    'resources/tilix.gresource.xml',
    gresource_bundle: true,
    install: true,
    source_dir: 'resources/',
    install_dir: pkgdatadir / 'resources'
)

# Install GSchemas
install_data(
  'gsettings/@0@.gschema.xml'.format(meson.project_name()),
  install_dir: schemadir
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
    install_dir: pkgdatadir / 'schemes'
)

# Scripts
install_data(
    'scripts/tilix_int.sh',
    install_dir: pkgdatadir / 'scripts'
)

# Copying Nautilus extension
install_data(
    'nautilus/open-tilix.py',
    install_dir: datadir / 'nautilus-python' / 'extensions'
)

# Copy D-Bus service descriptor
conf = configuration_data()
conf.set('bindir', bindir)

configure_file(
  input: 'dbus/@0@.service.in'.format(meson.project_name()),
  output: '@BASENAME@',
  configuration: conf,
  install_dir: datadir / 'dbus-1' / 'services'
)
