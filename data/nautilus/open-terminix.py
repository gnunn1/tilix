# -*- coding: UTF-8 -*-

# This example is contributed by Martin Enlund
# Example modified for Terminix
import os
import urllib
from urlparse import urlparse

import gettext
gettext.textdomain("terminix")
_ = gettext.gettext

import gi

gi.require_version('Nautilus', '3.0')

from gi.repository import Nautilus, GObject, Gio

class OpenTerminixExtension(GObject.GObject, Nautilus.MenuProvider):

    def __init__(self):
        self.terminal = 'terminix'

    def _open_terminal(self, file):
        gfile = Gio.File.new_for_uri(file.get_uri())
        filename = gfile.get_path();
        
        #print "Opening file:", filename
        os.system('%s -w "%s" &' % (self.terminal, filename))

    def menu_activate_cb(self, menu, file):
        self._open_terminal(file)

    def menu_activate_cb_remote(self, menu, file):
        result = urlparse(file.get_uri())
        if result.username:
            value = 'ssh -t %s@%s' % (result.username, result.hostname)
        else:
            value = 'ssh -t %s' % (result.hostname)
        if result.port:
            value = value + " -p " + result.port

        os.system('%s -e "%s" &' % (self.terminal, value))

    def menu_background_activate_cb(self, menu, file):
        self._open_terminal(file)

    def get_file_items(self, window, files):
        if len(files) != 1:
            return
        items = []
        file = files[0]
        print "Handling file: ", file.get_uri()
        print "file scheme: ", file.get_uri_scheme()

        if file.get_uri_scheme() in ['ftp','sftp']:
            item = Nautilus.MenuItem(name='NautilusPython::openterminal_remote_item',
                                    label=_(u'Open Remote Terminix…'),
                                    tip=_(u'Open Remote Terminix In %s') % file.get_uri())
            item.connect('activate', self.menu_activate_cb_remote, file)
            items.append(item)

        if file.is_directory(): #and file.get_uri_scheme() == 'file':
            gfile = Gio.File.new_for_uri(file.get_uri())
            info = gfile.query_info("standard::*", Gio.FileQueryInfoFlags.NONE, None)
            # Get UTF-8 version of basename
            filename = info.get_attribute_as_string("standard::name")

            item = Nautilus.MenuItem(name='NautilusPython::openterminal_file_item',
                                    label=_(u'Open In Terminix…'),
                                    tip=_(u'Open Terminix In %s') % filename)
            item.connect('activate', self.menu_activate_cb, file)
            items.append(item)

        return items

    def get_background_items(self, window, file):
        item = Nautilus.MenuItem(name='NautilusPython::openterminal_item',
                                 label=_(u'Open Terminix Here…'),
                                 tip=_(u'Open Terminix In This Directory'))
        item.connect('activate', self.menu_background_activate_cb, file)
        return item,
