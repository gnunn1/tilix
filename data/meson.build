
icon_sizes = ['16x16', '22x22', '24x24', '32x32', '48x48', '256x256', '512x512']

# install bitmap icons
foreach size : icon_sizes
    install_data(
        'icons/hicolor/' + size + '/apps/' + meson.project_name() + '.png',
        install_dir: 'share/icons/hicolor/' + size + '/apps/'
    )
endforeach

# install scalable symbolic icon
install_data(
    'icons/hicolor/scalable/apps/com.gexperts.Tilix-symbolic.svg',
    install_dir: 'share/icons/hicolor/scalable/apps/'
)


# Validate desktop file
desktop_file_validate = find_program('desktop-file-validate', required:false)

if desktop_file_validate.found()
  test (
    'Validate desktop file',
    desktop_file_validate,
    args: join_paths(meson.current_build_dir (), meson.project_name() + '.desktop')
  )
endif

# Install the desktop file
i18n.merge_file(
    output:  meson.project_name() + '.desktop',
    input: 'pkg/desktop/' + meson.project_name() + '.desktop.in',
    po_dir: join_paths(meson.source_root(), 'po'),
    type: 'desktop',
    install: true,
    install_dir: 'share/applications'
)

# Validate AppData file
appstreamcli = find_program('appstream-util', required:false)
if appstreamcli.found()
  test (
    'Validate appdata file',
    appstreamcli,
    args: ['validate', join_paths(meson.current_build_dir (), meson.project_name() + '.appdata.xml')]
  )
endif

# Install the AppData file
i18n.merge_file(
    output: meson.project_name() + '.appdata.xml',
    input: 'appdata/' + meson.project_name() + '.appdata.xml.in',
    po_dir: join_paths(meson.source_root(), 'po'),
    install: true,
    install_dir: 'share/metainfo'
)

# Build resources
gresource = gnome.compile_resources(
    'tilix',
    'resources/tilix.gresource.xml',
    gresource_bundle: true,
    install: true,
    source_dir: 'resources/',
    install_dir: 'share/tilix/resources'
)

# Install GSchemas
install_data(
  'gsettings/' + meson.project_name() + '.gschema.xml',
  install_dir : 'share/glib-2.0/schemas'
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
    install_dir: 'share/tilix/schemes'
)

# Scripts
install_data(
    'scripts/tilix_int.sh',
    install_dir: 'share/tilix/scripts'
)

# Copying Nautilus extension
install_data(
    'nautilus/open-tilix.py',
    install_dir: 'share/nautilus-python/extensions/'
)

# Copy D-Bus service descriptor
install_data(
    'dbus/' + meson.project_name() + '.service',
    install_dir: 'share/dbus-1/services/'
)

