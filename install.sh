#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "   CachyOS Dotfiles Installer"
echo "========================================"
echo

# ------------------------------------------------------------
# 1. Basic checks
# ------------------------------------------------------------

if ! command -v pacman >/dev/null 2>&1; then
    echo "ERROR: pacman not found."
    echo "This installer is intended for Arch/CachyOS."
    exit 1
fi

if [[ "${EUID}" -eq 0 ]]; then
    echo "ERROR: Do not run this script as root."
    echo "Run it as your normal user; sudo will be requested when needed."
    exit 1
fi

if [[ ! -f "$REPO_DIR/packages.txt" ]]; then
    echo "ERROR: packages.txt not found:"
    echo "  $REPO_DIR/packages.txt"
    exit 1
fi

# ------------------------------------------------------------
# 2. Install basic tools required by the setup
# ------------------------------------------------------------

echo "[1/4] Installing required bootstrap packages..."

sudo pacman -Syu --needed git base-devel

# ------------------------------------------------------------
# 3. Make sure yay is available
# ------------------------------------------------------------

echo
echo "[2/4] Checking yay..."

if command -v yay >/dev/null 2>&1; then
    echo "OK: yay is already installed."
else
    echo "yay not found. Installing yay-bin..."

    if pacman -Si yay-bin >/dev/null 2>&1; then
        sudo pacman -S --needed yay-bin
    else
        echo "yay-bin is not available in the configured repositories."
        echo "Bootstrapping yay from AUR..."

        TMP_DIR="$(mktemp -d)"
        trap 'rm -rf "$TMP_DIR"' EXIT

        git clone https://aur.archlinux.org/yay-bin.git "$TMP_DIR/yay-bin"
        (
            cd "$TMP_DIR/yay-bin"
            makepkg -si --noconfirm
        )
    fi
fi

if ! command -v yay >/dev/null 2>&1; then
    echo "ERROR: yay installation failed."
    exit 1
fi

# ------------------------------------------------------------
# 4. Install all packages
# ------------------------------------------------------------

echo
echo "[3/4] Installing packages from packages.txt..."
echo

yay -Syu --needed - < "$REPO_DIR/packages.txt"

# ------------------------------------------------------------
# 5. Restore dotfiles
# ------------------------------------------------------------

echo
echo "[4/4] Restoring dotfiles..."

if [[ ! -x "$REPO_DIR/restore.sh" ]]; then
    chmod +x "$REPO_DIR/restore.sh"
fi

"$REPO_DIR/restore.sh"

echo
echo "========================================"
echo "Installation completed successfully."
echo "========================================"
echo
echo "Recommended:"
echo "  1. Log out and log back in."
echo "  2. If SDDM/Hyprland was installed for the first time, reboot."
echo
echo "Repository:"
echo "  $REPO_DIR"
