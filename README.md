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

The application was written using GTK 3 and an effort was made to conform to Gnome Human Interface Guidelines (HIG). As a result, it does use CSD (i.e. the GTK HeaderBar) though it can be disabled if necessary. Other then Gnome, only Unity and has been tested officially though users have had success with other desktop environments.

At this point in time the application should be considered mid alpha and has been tested to varying degrees with the following distros:

* Arch Linux (primary test platform, works)
* Ubuntu 16.04 (secondary, works)
* Fedora 23 (primary, works)
* RHEL 7.2 (primary, works)
* Fedora Rawhide (Supported with Gnome 3.20, works)

### Dependencies

Terminix requires the following libraries to be installed in order to run:
* GTK 3.14 or later
* GTK VTE Widget 0.42
* Dconf
* GSettings

### Building

Terminix is written in D and GTK 3 using the gtkd framework. This project uses dub to manage the build process including fetching the dependencies, thus there is no need to install dependencies manually. The only thing you need to install to build the application is the D tools (DMD and Phobos) along with dub itself.

Once you have those installed, building the application is a one line command as follows:

```
dub build --build=release
```

The application depends on various resources to function correctly, run sudo ./install.sh to compile and copy all of the resources to the correct locations. Note this has only been tested on Arch Linux, use with caution.

#### Build Dependencies

Terminix depends on the following libraries as defined in dub.json:
* [gtkd](http://gtkd.org/) >= 3.2.2

### Install Terminix

Terminix is available in Arch Linux as the AUR package [terminix](https://aur.archlinux.org/packages/terminix), RPMs for Fedora 23 and CentOS 7 are available via the [OpenSUSE Build Service](https://software.opensuse.org/download.html?project=home%3Agnunn&package=terminix).

For other 64 bit distros releases can be installed manually from the releases section by downloading terminix.zip and following these instructions:

```
sudo unzip terminix.zip -d /
glib-compile-schemas /usr/share/glib-2.0/schemas/
```

Note the project is actively looking for package maintainers, if you are interested in assuming this role for one or more distros please see [Issue #25](https://github.com/gnunn1/terminix/issues/25).

At this time no 32 bit version of Terminix is available and there are no plans to create a 32 bit version at this time. While in theory it would be possible to compile a 32 bit version from source code, no testing of this has been done.


#### Uninstall Terminix

This method only applies if you installed Terminix manually using the install instructions. If you installed Terminix from a distribution package then use your package manager to remove terminix, do not use these instructions.

Download the uninstall.sh script from this repository and then open a terminal (not Terminix!) in the directory where you saved it. First set the executable flag on the script:

```
chmod +x uninstall.sh
```

and then execute it:

```
sudo sh uninstall.sh
```