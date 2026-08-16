#!/usr/bin/env bash

# -----------------------------------------------------
# Load Launcher
# -----------------------------------------------------
launcher=$(cat $HOME/.config/ml4w/settings/launcher)

# Use Walker
_launch_rofi() {
    pkill rofi
    fish "$HOME/.config/rofi/scripts/random-wallpaper.fish"
    rofi -show drun -replace -i
}
# Use Rofi

if [ "$launcher" == "walker" ]; then
    _launch_walker
else
    _launch_rofi
fi
