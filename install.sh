#!/usr/bin/env bash

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "   ML4W / Hyprland Dotfiles Installer"
echo "========================================"
echo

if ! command -v pacman >/dev/null 2>&1; then
    echo "ERROR: pacman not found."
    echo "This installer is intended for Arch/CachyOS."
    exit 1
fi

echo "[1/4] Installing packages..."

sudo pacman -Syu --needed - < "$REPO_DIR/packages.txt"

echo
echo "[2/4] Creating config directories..."

mkdir -p "$HOME/.config"
mkdir -p "$HOME/.local/bin"

echo
echo "[3/4] Creating dotfile symlinks..."

link_path() {
    local source="$1"
    local target="$2"

    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
            echo "OK: $target"
            return
        fi

        echo "Skipping existing: $target"
        return
    fi

    ln -s "$source" "$target"
    echo "Linked: $target"
}

link_path "$REPO_DIR/.config/hypr" "$HOME/.config/hypr"
link_path "$REPO_DIR/.config/quickshell" "$HOME/.config/quickshell"
link_path "$REPO_DIR/.config/waybar" "$HOME/.config/waybar"
link_path "$REPO_DIR/.config/ml4w" "$HOME/.config/ml4w"

echo
echo "[4/4] Installing shell configuration..."

for file in .bashrc .zshrc .Xresources .gtkrc-2.0; do
    if [ -f "$REPO_DIR/$file" ] && [ ! -e "$HOME/$file" ]; then
        ln -s "$REPO_DIR/$file" "$HOME/$file"
        echo "Linked: $HOME/$file"
    else
        echo "Skipping existing: $HOME/$file"
    fi
done

echo
echo "========================================"
echo "Installation completed."
echo "========================================"
echo
echo "You may need to log out and log back in."
