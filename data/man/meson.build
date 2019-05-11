r = run_command(meson.source_root() + '/../../install-man-pages.sh')
if r.returncode() != 0
  error('install-man-pages.sh failed with return code ', r.returncode(), ':\nstdout: ', r.stdout().strip(), '\nstderr: ', r.stderr().strip())
endif
