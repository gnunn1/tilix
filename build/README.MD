*** Building Terminix XDG-APP Bundle

This folder contains the scripts required to build Terminix as an XDG-APP bundle. XDG-APP allows desktop applications to be distributed independently of traditional Linux package managers, applications distributed in this way run in a sandboxed environment. Additional information on XDG-APP can be found [here](https://wiki.gnome.org/Projects/SandboxedApps). 

The first step to building the Terminix XDG-APP Bundle is to install the xdg-app framework. This will vary by distribution, on Arch it is easiy installed using the [xdg-app](https://aur.archlinux.org/packages/xdg-app) package from AUR as follows:

```yaourt xdg-app```

Once that is done you will need to install the Gnome and Freedesktop runtimes, this can be done by following the instructions on the [Gnome wiki](https://wiki.gnome.org/Projects/SandboxedApps#Gnome_sdk). The specific steps you need are as follows:
)
```
$ wget https://people.gnome.org/~alexl/keys/gnome-sdk.gpg
$ xdg-app --user remote-add gnome --gpg-key=gnome-sdk.gpg http://sdk.gnome.org/repo/
$ xdg-app --user install gnome org.gnome.Platform 3.20
$ xdg-app install --user gnome org.gnome.Sdk 3.20
$ xdg-app --user install gnome org.freedesktop.Platform 1.4
```
With all the dependencies in place, you can now build the bundle:

```
./build
```

