## Introduction

This folder contains patches to the GTK 3 VTE widget to support additional functionality in Terminix. The VTE widget provides the actual underlying terminal emulation and is used by many terminal emulators including gnome-terminal, terminator, xfce4-terminal, etc.

Since the VTE is the component providing the terminal emulation, there is a limit to what Terminix can do in terms of supporting features. The VTE widget quite rightly abstracts a lot of this and provides higher level functionality to the enclosing application. Anything that involves interacting with the other underlying terminal emulation such as handling OSC codes, understanding the alternate screem, etc may require changes in the VTE to support.

In an ideal world the patches available here would be upstreamed or equivalent functionality provided by upstream. Upstream typically prefers higher level patches that fully encompass the functionality to benefit all of the terminal emulators that depend on VTE, and this is the right approach in my opinion. However time is not infinite and my skills with C are limited so it's not always possible to make this happen. As well, sometimes I want to POC some piece of functionality before making a full commitment to implement it in VTE and a tactical approach is used in these cases.

Generally the patches contained here should be considered experimental and applied cautiously. If you are not comfortable with development you are probably better off avoiding them. 

Finally note that applying these patches can break other terminal emulators depending on VTE, I make no guarentee of fitness or suitability.

## Patches

The following patches are available:

| Patch | Compatible | Description |
|---|---|---|
| alternate-screen.patch| Yes | This patch adds a new event to the VTE that signals when the terminal switches between normal and alternate screens. This patch is required to support triggers which are deactivated in Terminix unless this new event is detected as being available. Note that if this patch is applied with the fedora-notifications patch, the padding field in /src/vte/vteterminal.h must be decremented from 15 to 14 since that patch also adds a new event. Failure to do so will break gnome-terminal.
|disable-bg-draw| Yes| This patch adds a new property to the VTE that disables the background draw and allows the application to assume responsibility for it. In Terminix this is used to support badges, however if it gets accepted by upstream some of the other features like background image will leverage it in teh future. |
