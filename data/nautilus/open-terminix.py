# -*- coding: UTF-8 -*-

# This example is contributed by Martin Enlund
# Example modified for Terminix
# Shortcuts Provider was inspired by captain nemo extension
import gettext
from urllib import unquote

from subprocess import PIPE, call
from urlparse import urlparse
gettext.textdomain("terminix")
_ = gettext.gettext

from gi import require_version

require_version('Gtk', '3.0')
require_version('Nautilus', '3.0')

from gi.repository import GObject, Gdk, Gio, Gtk, Nautilus

TERMINAL = "terminix"
IS_INSTALLED = bool(call(['which', TERMINAL], stdout=PIPE, stderr=PIPE) == 0)


def open_terminl_in_file(filename):
    if filename:
        call('{0} -w "{1}" &'.format(TERMINAL, filename), shell=True)
    else:
        call("{0} &".format(TERMINAL), shell=True)


class OpenTerminixShortcutProvider(GObject.GObject, Nautilus.LocationWidgetProvider):
    def __init__(self):
        self.accel_group = Gtk.AccelGroup()
        if IS_INSTALLED:
            self.accel_group.connect(ord('z'), Gdk.ModifierType.CONTROL_MASK,
                Gtk.AccelFlags.VISIBLE, self._open_terminal)
        self.window = None
        self.uri = None

    def _open_terminal(self, *args):
        filename = unquote(self.uri[7:])
        open_terminl_in_file(filename)

    def get_widget(self, uri, window):
        self.uri = uri
        if self.window:
            self.window.remove_accel_group(self.accel_group)
        window.add_accel_group(self.accel_group)
        self.window = window
        return None

class OpenTerminixExtension(GObject.GObject, Nautilus.MenuProvider):

    def _open_terminal(self, file):
        if file.get_uri_scheme() in ['ftp', 'sftp']:
            result = urlparse(file.get_uri())
            if result.username:
                value = 'ssh -t {0}@{1}'.format(result.username, result.hostname)
            else:
                value = 'ssh -t {0}'.format(result.hostname)
            if result.port:
                value = "{0} -p {1}".format(value, result.port)
            if file.is_directory():
                value = '{0} cd "{1}" ; $SHELL'.format(value, result.path)

            call('{0} -e "{1}" &'.format(TERMINAL, value), shell=True)
        else:
            gfile = Gio.File.new_for_uri(file.get_uri())
            filename = gfile.get_path()
            open_terminl_in_file(filename)

    def menu_activate_cb(self, menu, file):
        self._open_terminal(file)

    def menu_background_activate_cb(self, menu, file):
        self._open_terminal(file)

    def get_file_items(self, window, files):
        if len(files) != 1:
            print("Number of files is %d" % len(files))
            return
        items = []
        file = files[0]
        print("Handling file: ", file.get_uri())
        print("file scheme: ", file.get_uri_scheme())

        if file.is_directory():  # and file.get_uri_scheme() == 'file':

            if file.get_uri_scheme() in ['ftp', 'sftp']:
                item = Nautilus.MenuItem(name='NautilusPython::openterminal_remote_item',
                                         label=_(u'Open Remote Terminix'),
                                         tip=_(u'Open Remote Terminix In %s') % file.get_uri())
                item.connect('activate', self.menu_activate_cb, file)
                items.append(item)

            gfile = Gio.File.new_for_uri(file.get_uri())
            info = gfile.query_info(
                "standard::*", Gio.FileQueryInfoFlags.NONE, None)
            # Get UTF-8 version of basename
            filename = info.get_attribute_as_string("standard::name")

            item = Nautilus.MenuItem(name='NautilusPython::openterminal_file_item',
                                     label=_(u'Open In Terminix'),
                                     tip=_(u'Open Terminix In %s') % filename)
            item.connect('activate', self.menu_activate_cb, file)
            items.append(item)

        if not IS_INSTALLED:
            items = []
        return items

    def get_background_items(self, window, file):
        items = []
        if file.get_uri_scheme() in ['ftp', 'sftp']:
            item = Nautilus.MenuItem(name='NautilusPython::openterminal_bg_remote_item',
                                     label=_(u'Open Remote Terminix Here'),
                                     tip=_(u'Open Remote Terminix In This Directory'))
            item.connect('activate', self.menu_activate_cb, file)
            items.append(item)

        item = Nautilus.MenuItem(name='NautilusPython::openterminal_bg_file_item',
                                 label=_(u'Open Terminix Here'),
                                 tip=_(u'Open Terminix In This Directory'))
        item.connect('activate', self.menu_background_activate_cb, file)
        items.append(item)

        if not IS_INSTALLED:
            items = []
        return items
