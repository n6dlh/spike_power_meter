#!/bin/bash
#
# install.sh - Spike Power Meter setup for Debian/Ubuntu-family distros
#
# Run this from inside the cloned repo root:
#   chmod +x install.sh
#   ./install.sh
#
# What this does:
#   1. Checks/installs system packages (python3, venv, tk, pip)
#   2. Creates a Python virtual environment in ./venv
#   3. Installs Python requirements from requirements.txt
#   4. Converts the .ico to .png (once) for the Linux taskbar icon
#   5. Creates a ~/.local/share/applications/.desktop launcher
#   6. Checks the user is in the 'dialout' group for serial access
#
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$REPO_DIR/src"
APP_NAME="SpikePowerMeter"
DESKTOP_FILE="$HOME/.local/share/applications/spikepowermeter.desktop"
ICON_DEST_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
ICON_NAME="spikepowermeter"

echo "== Spike Power Meter installer =="
echo "Repo dir: $REPO_DIR"

# --- 1. Distro check -------------------------------------------------------
if [ ! -f /etc/os-release ]; then
    echo "Cannot detect distro (no /etc/os-release). This script targets Debian/Ubuntu-family systems."
    exit 1
fi

. /etc/os-release
case "$ID_LIKE $ID" in
    *debian*|*ubuntu*)
        ;;
    *)
        echo "Detected distro: $PRETTY_NAME"
        echo "This script only handles Debian/Ubuntu-family (apt) systems for now."
        echo "You'll need to install python3, python3-venv, python3-tk, and python3-pip manually,"
        echo "then re-run this script - it will skip apt and continue with the rest."
        read -p "Continue anyway? [y/N] " REPLY
        [[ "$REPLY" =~ ^[Yy]$ ]] || exit 1
        SKIP_APT=1
        ;;
esac

# --- 2. System package check/install ---------------------------------------
if [ -z "$SKIP_APT" ]; then
    NEEDED_PKGS=""
    for pkg in python3 python3-venv python3-pip python3-tk; do
        dpkg -s "$pkg" >/dev/null 2>&1 || NEEDED_PKGS="$NEEDED_PKGS $pkg"
    done

    if [ -n "$NEEDED_PKGS" ]; then
        echo "Missing system packages:$NEEDED_PKGS"
        echo "Installing via apt (will prompt for sudo password)..."
        sudo apt-get update
        sudo apt-get install -y $NEEDED_PKGS
    else
        echo "All required system packages already present."
    fi
fi

# --- 3. Python virtual environment ------------------------------------------
if [ ! -d "$REPO_DIR/venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$REPO_DIR/venv"
else
    echo "Virtual environment already exists, reusing it."
fi

echo "Installing Python requirements..."
"$REPO_DIR/venv/bin/pip" install --upgrade pip
"$REPO_DIR/venv/bin/pip" install -r "$REPO_DIR/requirements.txt"

# --- 4. Icon conversion (.ico -> .png), once --------------------------------
ICO_PATH="$SRC_DIR/DellPowerMeter.ico"
PNG_PATH="$SRC_DIR/DellPowerMeter.png"

if [ -f "$ICO_PATH" ] && [ ! -f "$PNG_PATH" ]; then
    if command -v convert >/dev/null 2>&1; then
        echo "Converting icon .ico -> .png..."
        convert "$ICO_PATH" "$PNG_PATH"
        # .ico files often unpack to multiple frames (DellPowerMeter-0.png, -1.png...);
        # if convert produced numbered frames instead of a single file, grab the largest.
        if [ ! -f "$PNG_PATH" ]; then
            LARGEST=$(ls -S "$SRC_DIR"/DellPowerMeter-*.png 2>/dev/null | head -n1)
            [ -n "$LARGEST" ] && cp "$LARGEST" "$PNG_PATH"
        fi
    else
        echo "ImageMagick 'convert' not found - installing..."
        sudo apt-get install -y imagemagick
        convert "$ICO_PATH" "$PNG_PATH"
    fi
elif [ -f "$PNG_PATH" ]; then
    echo "Icon PNG already present, skipping conversion."
else
    echo "Warning: $ICO_PATH not found - desktop icon will be blank until it's added."
fi

# --- 5. Install icon into hicolor theme + create .desktop file -------------
if [ -f "$PNG_PATH" ]; then
    mkdir -p "$ICON_DEST_DIR"
    cp "$PNG_PATH" "$ICON_DEST_DIR/$ICON_NAME.png"
fi

mkdir -p "$(dirname "$DESKTOP_FILE")"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Spike Power Meter
Exec=$REPO_DIR/venv/bin/python3 $SRC_DIR/dpm_ui.py
Icon=$ICON_NAME
Terminal=false
StartupWMClass=$APP_NAME
Categories=Utility;
EOF

chmod 644 "$DESKTOP_FILE"

if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$DESKTOP_FILE" || echo "Warning: desktop-file-validate reported issues above."
fi

update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor/" 2>/dev/null || true

# --- 6. Serial (dialout) group check ----------------------------------------
if ! groups "$USER" | grep -qw dialout; then
    echo
    echo "NOTE: your user is not in the 'dialout' group, which is required for serial"
    echo "(USB) access to the ESP32. Run this, then log out and back in:"
    echo
    echo "    sudo usermod -aG dialout $USER"
    echo
fi

echo
echo "== Install complete =="
echo "Launch from your application menu (Spike Power Meter), or directly with:"
echo "    $REPO_DIR/venv/bin/python3 $SRC_DIR/dpm_ui.py"
echo
echo "If the app doesn't appear in your menu immediately, log out and back in."