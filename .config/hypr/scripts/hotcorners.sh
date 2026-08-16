#!/usr/bin/env bash

WIDTH=1920
HEIGHT=1080
SIZE=20

LAST_CORNER=""
    echo "POS=$POS X=$X Y=$Y" >> /tmp/hotcorners-debug.log

while true; do
    POS=$(hyprctl cursorpos 2>/dev/null)
    X=${POS%,*}
    Y=${POS#*,}

    CORNER=""
    echo "POS=$POS X=$X Y=$Y" >> /tmp/hotcorners-debug.log

    if (( X <= SIZE && Y <= SIZE )); then
        CORNER="top-left"
    elif (( X >= WIDTH-SIZE && Y <= SIZE )); then
        CORNER="top-right"
    elif (( X <= SIZE && Y >= HEIGHT-SIZE )); then
        CORNER="bottom-left"
    elif (( X >= WIDTH-SIZE && Y >= HEIGHT-SIZE )); then
        CORNER="bottom-right"
    fi

if [[ -n "$CORNER" && "$CORNER" != "$LAST_CORNER" ]]; then
    case "$CORNER" in
        top-left)
            qs -p "$HOME/.config/quickshell/overview" ipc call overview toggle
            ;;
        top-right)
            swaync-client -t -sw
            ;;
        bottom-left)
            hyprctl dispatch workspace empty
            ;;
        bottom-right)
            "$HOME/.config/ml4w/scripts/ml4w-power" -l
            ;;
    esac

    LAST_CORNER="$CORNER"
elif [[ -z "$CORNER" ]]; then
    LAST_CORNER=""
    echo "POS=$POS X=$X Y=$Y" >> /tmp/hotcorners-debug.log
fi
    sleep 0.1
done
