#!/bin/bash

compton -b &
feh --bg-fill  ~/.local/share/wallpapers/bz.jpg
optimus-manager-qt &
dunst &
nm-applet &
xinput set-prop --type=int --format=8 "SynPS/2 Synaptics TouchPad" "libinput Tapping Enabled" 1 &
xinput set-prop --type=int --format=8 "SynPS/2 Synaptics TouchPad" 308 1 &
libinput-gestures-setup start &
~/.scripts/autostart-wait.sh &
~/.scripts/dwm-status.sh &
