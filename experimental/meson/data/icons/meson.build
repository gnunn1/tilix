
icon_sizes = ['16x16', '22x22', '24x24', '32x32', '48x48', '256x256', '512x512']

# install bitmap icons
foreach size : icon_sizes
    install_data('hicolor/' + size + '/apps/com.gexperts.Tilix.png',
                 install_dir: 'share/icons/hicolor/' + size + '/apps/'
    )
endforeach

# install scalable symbolic icon
install_data('hicolor/scalable/apps/com.gexperts.Tilix-symbolic.svg',
             install_dir: 'share/icons/hicolor/scalable/apps/'
)
