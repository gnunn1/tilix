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
* Background images
* Supports notifications when processes are completed out of view. Requires the Fedora notification patches for VTE

The application was written using GTK 3 and an effort was made to conform to Gnome Human Interface Guidelines (HIG). As a result, it does use CSD (i.e. the GTK HeaderBar) though it can be disabled if necessary. Other than Gnome, only Unity has been tested officially though users have had success with other desktop environments.

At this point in time the application has been tested to varying degrees with the following distros:

* Arch Linux (primary test platform, works)
* Ubuntu 16.04 (secondary, works)
* Fedora 23 (primary, works)
* RHEL 7.2 (primary, works)
* Fedora Rawhide (Supported with Gnome 3.20, works)

### Dependencies

Terminix requires the following libraries to be installed in order to run:
* GTK 3.14 or later
* GTK VTE 0.42 or later
* Dconf
* GSettings
* [Nautilus-Python](https://wiki.gnome.org/Projects/NautilusPython) (Required For Nautilus integration)
 
### Localization

Terminix is localized using Weblate, please visit the Weblate hosted [Terminix translations site](https://hosted.weblate.org/projects/terminix/translations) in order to assist with translations, pease do not submit direct pull requests to this repository for translations.

### Building

Terminix is written in D and GTK 3 using the gtkd framework. This project uses dub to manage the build process including fetching the dependencies, thus there is no need to install dependencies manually. The only thing you need to install to build the application is the D tools (DMD and Phobos) along with dub itself. Note that D supports three compilers (DMD, GDC and LDC) and Terminix only supports DMD.

Once you have those installed, compiling the application is a one line command as follows:

```
dub build --build=release
```

The application depends on various resources to function correctly, run sudo ./install.sh to build and copy all of the resources to the correct locations. Note this has only been tested on Arch Linux, use with caution.

Note there is also experimental support for autotools, please see the wiki page on [autotools](https://github.com/gnunn1/terminix/wiki/Building-with-Autotools) for more information.

#### Build Dependencies

Terminix depends on the following libraries as defined in dub.json:
* [gtkd](http://gtkd.org/) >= 3.3.0

### Install Terminix

Terminix is available for the following distributions as a 64 bit application:

| Distribution | Package
|---|---|
|Arch|[AUR Terminix Package](https://aur.archlinux.org/packages/terminix)|
|Fedora|[COPR Repository](https://copr.fedorainfracloud.org/coprs/heikoada/terminix)|
|Cent OS 7.2|[EPEL Package via COPR](https://copr.fedorainfracloud.org/coprs/heikoada/terminix)|
|Ubuntu|[Not yet available](https://github.com/gnunn1/terminix/issues/25)|
|OpenSUSE|[Package Search](https://software.opensuse.org/package/terminix)|

For 64 bit distros where a package is not available, Terminix can be installed manually from the releases section by downloading terminix.zip and following these instructions:

```
sudo unzip terminix.zip -d /
sudo glib-compile-schemas /usr/share/glib-2.0/schemas/
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
