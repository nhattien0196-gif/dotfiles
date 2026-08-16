hl.on("hyprland.start", function ()
    hl.exec_cmd("sleep 2 && hyprpm reload")
    
    local HOME = os.getenv("HOME")

    -- Read wallpaper app setting
    local wallpaper_app = "quickshell"
    local f = io.open(HOME .. "/.config/ml4w/settings/wallpaper-app", "r")
    if f then
        wallpaper_app = f:read("*l"):match("^%s*(.-)%s*$")
        f:close()
    end

    -- Export variables to systemd
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    -- Restart portals so they catch the environment
    hl.exec_cmd("systemctl --user stop xdg-desktop-portal xdg-desktop-portal-hyprland")
    hl.exec_cmd("systemctl --user start xdg-desktop-portal-hyprland xdg-desktop-portal")

    -- awww daemon
    hl.exec_cmd("awww-daemon")

    -- Load cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")

    -- Start listeners
    hl.exec_cmd("~/.config/ml4w/listeners.sh --startall")
    hl.exec_cmd("sleep 2 && fcitx5")
    hl.exec_cmd("sleep 3 && /opt/abdownloadmanager/bin/ABDownloadManager --background")
    -- Start waybar
    hl.exec_cmd(HOME .. "/.config/waybar/launch.sh")

    -- Start polkit daemon
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- Restore wallpaper (skip for quickshell — handled inside ml4w-autostart)
    if wallpaper_app ~= "quickshell" then
        hl.exec_cmd("~/.config/ml4w/scripts/ml4w-wallpaper-app --restore")
    end

    -- Autostart scripts
-- Autostart scripts
hl.exec_cmd("~/.config/ml4w/scripts/ml4w-autostart > ~/.mydotfiles/ml4w-autostart.log 2>&1")

-- Random wallpaper on login
hl.exec_cmd("sleep 2 && ~/.local/bin/random-wallpaper")

-- Load GTK settings
hl.exec_cmd("~/.config/hypr/scripts/gtk.sh")
    -- Load GTK settings
    hl.exec_cmd("~/.config/hypr/scripts/gtk.sh")

    -- Start swaync
    hl.exec_cmd("swaync")

    -- Start hypridle
    hl.exec_cmd("hypridle")
    hl.exec_cmd("kdeconnectd")
    -- Load cliphist history
    hl.exec_cmd("wl-paste --watch cliphist store")

    -- Start autostart cleanup
    hl.exec_cmd("~/.config/hypr/scripts/cleanup.sh")
-- Hot corners disabled
-- hl.exec_cmd("nohup ~/.config/hypr/scripts/hotcorners.sh >/dev/null 2>&1 &")
end)
