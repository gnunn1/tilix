# -*- coding: UTF-8 -*-
# This example is contributed by Martin Enlund
# Example modified for Tilix
# Shortcuts Provider was inspired by captain nemo extension

from gettext import gettext as _, textdomain
from subprocess import PIPE, call
try:
    from urllib import unquote
    from urlparse import urlparse
except ImportError:
    from urllib.parse import unquote, urlparse
from os import path

from gi import require_version
require_version('Gtk', '3.0')
require_version('Nautilus', '3.0')
from gi.repository import Gio, GObject, Gtk, Nautilus


TERMINAL = "tilix"
TILIX_KEYBINDINGS = "com.gexperts.Tilix.Keybindings"
GSETTINGS_OPEN_TERMINAL = "nautilus-open"
REMOTE_URI_SCHEME = ['ftp', 'sftp']
textdomain("tilix")


def open_terminal(uri):
    file_obj = urlparse(uri)
    if file_obj.scheme in REMOTE_URI_SCHEME:
        if file_obj.username:
            value = 'ssh -t {0}@{1}'.format(file_obj.username,
                                            file_obj.hostname)
        else:
            value = 'ssh -t {0}'.format(file_obj.hostname)
        if file_obj.port:
            value = "{0} -p {1}".format(value, file_obj.port)
        _dir = path.dirname(unquote(file_obj.path)).replace(" ", "\ ")
        value = '{0} cd "{1}" ; $SHELL'.format(value, _dir)

        call('{0} -e "{1}" &'.format(TERMINAL, value), shell=True)
    elif file_obj.scheme == "file":
        filename = Gio.File.new_for_uri(uri).get_path()
        if filename:
            call('{0} -w "{1}" &'.format(TERMINAL, filename), shell=True)
        else:
            call("{0} &".format(TERMINAL), shell=True)


class OpenTilixShortcutProvider(GObject.GObject,
                                Nautilus.LocationWidgetProvider):

    def __init__(self):
        source = Gio.SettingsSchemaSource.get_default()
        if source.lookup(TILIX_KEYBINDINGS, True):
            self._gsettings = Gio.Settings.new(TILIX_KEYBINDINGS)
            self._gsettings.connect("changed", self._bind_shortcut)
            self._create_accel_group()
        else:
            self._gsettings = None
        self._window = None
        self._uri = None

    def _create_accel_group(self):
        if self._gsettings:
            self._accel_group = Gtk.AccelGroup()
            shortcut = self._gsettings.get_string(GSETTINGS_OPEN_TERMINAL)
            key, mod = Gtk.accelerator_parse(shortcut)
            self._accel_group.connect(key, mod, Gtk.AccelFlags.VISIBLE,
                                        self._open_terminal)

    def _bind_shortcut(self, gsettings, key):
        if key == GSETTINGS_OPEN_TERMINAL:
            self._accel_group.disconnect(self._open_terminal)
            self._create_accel_group()

    def _open_terminal(self, *args):
        open_terminal(self._uri)

    def get_widget(self, uri, window):
        self._uri = uri
        if self._window:
            self._window.remove_accel_group(self._accel_group)
        self._window = window
        if self._gsettings:
            self._window.add_accel_group(self._accel_group)
        return None


class OpenTilixExtension(GObject.GObject, Nautilus.MenuProvider):

    def _menu_activate(self, menu, file_):
        open_terminal(file_.get_uri())

    def get_file_items(self, window, files):
        if len(files) != 1:
            return
        items = []
        file_ = files[0]
        print("Handling file: ", file_.get_uri())
        print("file scheme: ", file_.get_uri_scheme())

        if file_.is_directory():

            if file_.get_uri_scheme() in REMOTE_URI_SCHEME:
                uri = file_.get_uri().decode('utf-8')
                item = Nautilus.MenuItem(name='NautilusPython::open_remote_item',
                                         label=_(u'Open Remote Tilix'),
                                         tip=_(u'Open Remote Tilix In {}').format(uri))
                item.connect('activate', self._menu_activate, file_)
                items.append(item)

            filename = file_.get_name().decode('utf-8')
            item = Nautilus.MenuItem(name='NautilusPython::open_file_item',
                                     label=_(u'Open In Tilix'),
                                     tip=_(u'Open Tilix In {}').format(filename))
            item.connect('activate', self._menu_activate, file_)
            items.append(item)

        return items

    def get_background_items(self, window, file_):
        items = []
        if file_.get_uri_scheme() in REMOTE_URI_SCHEME:
            item = Nautilus.MenuItem(name='NautilusPython::open_bg_remote_item',
                                     label=_(u'Open Remote Tilix Here'),
                                     tip=_(u'Open Remote Tilix In This Directory'))
            item.connect('activate', self._menu_activate, file_)
            items.append(item)

        item = Nautilus.MenuItem(name='NautilusPython::open_bg_file_item',
                                 label=_(u'Open Tilix Here'),
                                 tip=_(u'Open Tilix In This Directory'))
        item.connect('activate', self._menu_activate, file_)
        items.append(item)
        return items
