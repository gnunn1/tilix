# Terminix
A tiling terminal emulator for Linux using GTK+ 3

###### Screenshot
![Screenshot](http://www.gexperts.com/img/terminix/terminix2.png)

### About

Terminix is a tiling terminal emulator which uses the VTE GTK+ 3 widget with the following features:

* Layout terminals in any fashion by splitting them horizontally or vertically
* Terminals can be re-arranged using drag and drop both within and between windows
* Terminals can be detached into a new window via drag and drop
* Input can be synchronized between terminals so commands typed in one terminal are replicated to the others
* The grouping of terminals can be saved and loaded from disk
* Terminals support custom titles
* Color schemes are stored in files and custom color schemes can be created by simply creating a new file
* Transparent background
* Supports notifications when processes are completed out of view. Requires the Fedora notification patches for VTE

The application was written using GTK 3 and an effort was made to conform to Gnome Human Interface Guidelines (HIG). As a result, it does use CSD (i.e. the GTK HeaderBar) and no allowance has been made for other Desktop Environments (xfce, unity, kde, etc) at this time so your mileage may vary. Consideration for other environments may be given if demand warrants it.

At this point in time the application should be considered early alpha and has been tested to varying degrees with the following distros:

* Arch Linux (primary test platform, works)
* Ubuntu 16.04 (secondary, works)
* Fedora 23 (primary, works, bug #19)
* RHEL 7.2 (primary, works)
* Fedora Rawhide (not supported, semi-works, UI broken, bug #16)

### Dependencies

Terminix requires the following libraries to be installed in order to run:
* GTK 3.14 or later
* GTK VTE Widget 0.42 or later
* Dconf
* GSettings

### Todo Items

Since this is an early alpha release, there are a number of features which have not yet been developed including:

* Add an option to support a "compact" view which would have smaller terminal title bars and move commands to popup menus
* Add support for localization

Additional feature requests are gladly accepted

### Building

Terminix is written in D and GTK 3 using the gtkd framework. This project uses dub to manage the build process including fetching the dependencies, thus there is no need to install dependencies manually. The only thing you need to install to build the application is the D tools (DMD and Phobos) along with dub itself.

Once you have those installed, building the application is a one line command as follows:

```
dub build --build=release
```

The application depends on various resources to function directly, run sudo ./install.sh to compile and copy all of the necessary files to the correct locations. Note this has only been tested on Arch Linux, use with caution.

#### Build Dependencies

Terminix depends on the following libraries as defined in dub.json:
* [gtkd](http://gtkd.org/) >= 3.2.1

### Installation

Terminix is available in Arch Linux as the AUR package [terminix](https://aur.archlinux.org/packages/terminix), for other distros releases can be installed manually from the releases section by downloading terminix.zip and following these instructions:

```
sudo unzip terminix.zip -d /
glib-compile-schemas /usr/share/glib-2.0/schemas/
```
