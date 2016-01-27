# This example is contributed by Martin Enlund
# Example modified for Terminix
import os
import urllib

import gi

gi.require_version('Nautilus', '3.0')

from gi.repository import Nautilus, GObject

class OpenTerminixExtension(GObject.GObject, Nautilus.MenuProvider):
        
    def _open_terminal(self, file):
        filename = urllib.unquote(file.get_uri()[7:])
        terminal = "terminix"

        os.system('%s -w %s &' % (terminal, filename))
        
    def menu_activate_cb(self, menu, file):
        self._open_terminal(file)
        
    def menu_background_activate_cb(self, menu, file): 
        self._open_terminal(file)
       
    def get_file_items(self, window, files):
        if len(files) != 1:
            return
        
        file = files[0]
        if not file.is_directory() or file.get_uri_scheme() != 'file':
            return
        
        item = Nautilus.MenuItem(name='NautilusPython::openterminal_file_item',
                                 label='Open in Terminix',
                                 tip='Open Terminix In %s' % file.get_name())
        item.connect('activate', self.menu_activate_cb, file)
        return item,

    def get_background_items(self, window, file):
        item = Nautilus.MenuItem(name='NautilusPython::openterminal_item',
                                 label='Open Terminix Here',
                                 tip='Open Terminix In This Directory')
        item.connect('activate', self.menu_background_activate_cb, file)
        return item,
