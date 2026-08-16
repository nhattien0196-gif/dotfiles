#!/usr/bin/env bash

ROFI_CONFIG="$HOME/.config/rofi/config-wifi.rasi"

get_networks() {
    nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list |
    while IFS=: read -r active signal security ssid; do
        [ -z "$ssid" ] && continue

        if [ "$active" = "*" ]; then
            marker="●"
            status="Connected"
        else
            marker="○"
            status=""
        fi

        if [ -n "$security" ]; then
            lock="󰌾"
        else
            lock="󰖩"
        fi

        if [ "$signal" -ge 80 ]; then
            bars="󰤨"
        elif [ "$signal" -ge 60 ]; then
            bars="󰤥"
        elif [ "$signal" -ge 40 ]; then
            bars="󰤢"
        else
            bars="󰤟"
        fi

        printf '%s\t%s  %s\t%s\t%s%%\t%s\n' \
            "$ssid" "$marker $ssid" "$status" "$signal" "$bars"
    done
}

choice=$(get_networks | rofi \
    -dmenu \
    -i \
    -p "󰤨  Wi-Fi" \
    -config "$ROFI_CONFIG" \
    -format 's')

[ -z "$choice" ] && exit 0

ssid="$choice"

if nmcli -t -f IN-USE,SSID dev wifi list | grep -Fq "*:$ssid"; then
    action=$(printf 'Disconnect\nConnection Information' | rofi \
        -dmenu \
        -i \
        -p "$ssid" \
        -config "$ROFI_CONFIG")

    case "$action" in
        Disconnect)
            nmcli connection down "$ssid"
            ;;
        "Connection Information")
            nmcli connection show "$ssid" | rofi \
                -dmenu \
                -p "󰋼  $ssid" \
                -config "$ROFI_CONFIG"
            ;;
    esac
else
    nmcli device wifi connect "$ssid"
fi
