# Maintainer: Gerald Nunn <gerald dot b dot nunn at gmail dot com>

pkgname=terminix
pkgver=0.20
pkgrel=1
pkgdesc="A tiling terminal emulator based on GTK+ 3"
arch=('x86_64')
url="http://github.com/gnunn1/terminix"
license=('MPL')
depends=('gtk3' 'dconf' 'gsettings-desktop-schemas' 'vte3')
install=terminix.install
source_x86_64=(https://github.com/gnunn1/terminix/releases/download/$pkgver/terminix.zip)
md5sums_x86_64=('a0abba232236efe570d50e6221a695a0')

package() {
  mkdir -p "$pkgdir/usr/bin"
  mkdir -p "$pkgdir/usr/share/applications"
  mkdir -p "$pkgdir/usr/share/terminix/schemes"
  mkdir -p "$pkgdir/usr/share/terminix/resources"

  install -Dm755 usr/bin/terminix "$pkgdir/usr/bin/terminix"
  install -Dm755 usr/share/applications/terminix.desktop "$pkgdir/usr/share/applications/terminix.desktop"
  install -Dm755 usr/share/terminix/schemes/* "$pkgdir/usr/share/terminix/schemes/"
  install -Dm755 usr/share/terminix/resources/* "$pkgdir/usr/share/terminix/resources/"
  install -Dm755 usr/share/glib-2.0/schemas/com.gexperts.Terminix.gschema.xml "$pkgdir/usr/share/glib-2.0/schemas/com.gexperts.Terminix.gschema.xml"
}
