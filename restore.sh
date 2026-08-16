#!/usr/bin/env bash

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "       ML4W Dotfiles Restore"
echo "========================================"
echo

mkdir -p "$HOME/.config"
mkdir -p "$HOME/.local/bin"

link_config() {
    local source="$1"
    local target="$2"

    if [ -L "$target" ]; then
        echo "Already linked: $target"
        return
    fi

    if [ -e "$target" ]; then
        echo "Existing config found:"
        echo "  $target"
        echo "Skipping to prevent overwrite."
        return
    fi

    ln -s "$source" "$target"
    echo "Restored: $target"
}

link_config "$REPO_DIR/.config/hypr" "$HOME/.config/hypr"
link_config "$REPO_DIR/.config/quickshell" "$HOME/.config/quickshell"
link_config "$REPO_DIR/.config/waybar" "$HOME/.config/waybar"
link_config "$REPO_DIR/.config/ml4w" "$HOME/.config/ml4w"

for file in .bashrc .zshrc .Xresources .gtkrc-2.0; do
    if [ -f "$REPO_DIR/$file" ]; then
        link_config "$REPO_DIR/$file" "$HOME/$file"
    fi
done

echo
echo "Restore completed."
