# Slab

A NixOS module (collection of packages and configuration) that can be
installed on a phone to provide a responsive and usable experience

That's the plan.

Right now - it might be responsive, but it's not very usable


> A drug used by Trolls, consisting of ammonium chloride cut with
> radium. [...] The actual effects of Slab are similar to LSD, with
> the troll in question seeing things for a prolonged period, not
> causing any trouble, and just wandering off to look at the pretty
> pictures. While the troll will usually go find somewhere quiet to
> enjoy the show, it has nasty side effects up to and including
> melting a troll's brain.

- https://wiki.lspace.org/Slab


## TODO/BUGS

"everything"

* swaylock doesn't open onscreen keyboard, so no unlock possible

* keyboard
  - arrow keys are half-size
  - ctrl key is sticky (https://github.com/valderman/squeekboard-sway/commit/0ae1313659d4d7569169c75c5363a18580497e17 is a clue)
  - layout files must be hand-copied into ~/.local/share/

* add pane-aware gestures so apps can be dismissed/hidden by dragging
them offscreen. This could be a chunk of work: libinput doesn't and
won't support touchscreen gestures, lisgd sees the same events as the
compositor (doesn't consume them when it recognises a gesture)

* switch termite for something still maintained (alacritty?)

* don't let sway suspend the device without warning when ssh sessions active

* improve networkmanager ui to work with touch input

* missings apps
  - dialler
  - messaging (SMS etc)
  - waydroid?
  - totp

* (hardware/pinephone) find out why it doesn't charge on usb2

* firefox
  - automate layers.acceleration.force setting

