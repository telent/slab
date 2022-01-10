# Slab

A NixOS module (collection of packages and configuration)1 that can be
installed on a phone to provide a responsive and usable experience

That's the plan.

Right now it might be responsive but it's not very usable



## TODO/BUGS

* swaylock doesn't open onscreen keyboard, so no unlock possible

* keyboard
 - doesn't open on demand, must be toggled manually
 - missing icon for backspace key
 - arrow keys are half-size
 - ctrl key is sticky

* add pane-aware gestures so apps can be dismissed/hidden by dragging them
offsscreen

* switch termite for something still maintained (alacritty?)

* improve networkmanager ui to work with touch input

* missings apps
 - dialler
 - messaging (SMS etc)
 - waydroid?
 - totp
 
* (hardware/pinephone) find out why it doesn't charge on usb2

* firefox
 - automate layers.acceleration.force setting
 