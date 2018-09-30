### Building Tilix Flatpak Bundle

This folder contains the scripts required to build Tilix as an Flatpak bundle. Flatpak allows desktop applications to be distributed independently of traditional Linux package managers, applications distributed in this way run in a sandboxed environment. Additional information on Flatpak can be found [here](http://flatpak.org/).

The first step to building the Tilix Flatpak Bundle is to install the flatpak framework. This will vary by distribution, see [Getting Flatpak](http://flatpak.org/getting.html).

Once that is done you will need to install the Gnome runtimes, this can be done by following the instructions on the [Flatpak wiki](http://docs.flatpak.org/en/latest/getting-setup.html). The specific steps you need are as follows:
)
```
flatpak install flathub org.gnome.Sdk 3.28
flatpak install flathub org.gnome.Platform 3.28
```
With all the dependencies in place, you can now build the bundle:

```
flatpak-builder --install flatpak-builder com.gexperts.Tilix.yaml
```

And then run the application:

```
flatpak run com.gexperts.Tilix
```