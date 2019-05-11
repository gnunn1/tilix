configure_file(
  input: '@0@.service.in'.format(meson.project_name()),
  output: '@0@.service'.format(meson.project_name()),
  configuration: conf,
  install_dir: join_paths(get_option('datadir'), 'dbus-1/services')
)
