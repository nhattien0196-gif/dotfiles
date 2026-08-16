#!/usr/bin/env bash

WIFI_QML="$HOME/.config/quickshell/WifiApp/shell.qml"

if pgrep -af "$WIFI_QML" >/dev/null 2>&1; then
    pkill -f "$WIFI_QML"
else
    quickshell -p "$WIFI_QML" >/tmp/quickshell-wifi.log 2>&1 &
fi
