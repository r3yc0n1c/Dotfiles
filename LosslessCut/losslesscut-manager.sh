#!/usr/bin/env bash
# ==============================================================================
# LosslessCut Manager
# ------------------------------------------------------------------------------
# Install, update, and uninstall LosslessCut using its official Linux AppImage.
#
# Features:
#   - Download the latest official x86_64 AppImage
#   - Accept a local AppImage as an installation source
#   - Update with rollback support
#   - Install the official SVG application icon
#   - Create a desktop launcher
#   - Provide a global CLI command
#   - Uninstall while preserving user data
#   - Optionally purge application settings and caches
#
# Usage:
#   losslesscut-manager install [AppImage]
#   losslesscut-manager update  [AppImage]
#   losslesscut-manager remove
#   losslesscut-manager remove --purge
#
# Requirements:
#   Ubuntu/Linux x86_64, Bash, curl, sudo
#
# Copyright (c) 2026 r3yc0n1c
# License: MIT
#
# Independent community utility. Not affiliated with LosslessCut.
# ==============================================================================

set -Eeuo pipefail

APP_NAME="LosslessCut"

INSTALL_DIR="/opt/losslesscut"
APPIMAGE="${INSTALL_DIR}/LosslessCut.AppImage"
BIN_LINK="/usr/local/bin/losslesscut"

DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/losslesscut.desktop"

ICON_ROOT="${HOME}/.local/share/icons/hicolor"
ICON_DIR="${ICON_ROOT}/scalable/apps"
ICON_FILE="${ICON_DIR}/losslesscut.svg"
LEGACY_ICON="${HOME}/.local/share/icons/hicolor/512x512/apps/losslesscut.png"

DOWNLOAD_URL="https://github.com/mifi/lossless-cut/releases/latest/download/LosslessCut-linux-x86_64.AppImage"
ICON_URL="https://raw.githubusercontent.com/mifi/lossless-cut/master/src/renderer/src/icon.svg"
DOWNLOAD_DIR="${HOME}/Downloads"

STAGING_DIR="${INSTALL_DIR}.new"
BACKUP_DIR="${INSTALL_DIR}.backup"

# Global state used by the EXIT trap.
LC_TMPDIR=""
LC_SWAP_DONE=0
LC_HAD_INSTALL=0
LC_COMMITTED=0

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

info() {
    echo "[LosslessCut] $*" >&2
}

die() {
    info "Error: $*"
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

cleanup() {
    local status=$?

    trap - EXIT

    if [[ "$status" -ne 0 && "$LC_SWAP_DONE" -eq 1 && "$LC_COMMITTED" -eq 0 ]]; then
        info "Installation failed. Attempting rollback..."

        sudo rm -rf "$INSTALL_DIR" 2>/dev/null || true

        if [[ "$LC_HAD_INSTALL" -eq 1 && -d "$BACKUP_DIR" ]]; then
            sudo mv "$BACKUP_DIR" "$INSTALL_DIR" || true

            # Restore the previous CLI target if possible.
            local old_exec
            old_exec="$(find "$INSTALL_DIR" -type f \
                \( -name 'LosslessCut' -o -name 'losslesscut' \) \
                -executable -print -quit 2>/dev/null || true)"

            if [[ -n "$old_exec" ]]; then
                sudo ln -sfn "$old_exec" "$BIN_LINK" || true
            fi
        fi
    fi

    if [[ -n "$STAGING_DIR" ]]; then
        sudo rm -rf "$STAGING_DIR" 2>/dev/null || true
    fi

    if [[ -n "$LC_TMPDIR" ]]; then
        rm -rf "$LC_TMPDIR" 2>/dev/null || true
    fi

    return "$status"
}

refresh_desktop() {
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$DESKTOP_DIR" || true
    fi

    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -t "$ICON_ROOT" || true
    fi
}

# ------------------------------------------------------------------------------
# AppImage handling
# ------------------------------------------------------------------------------

resolve_appimage() {
    local source="${1:-}"

    if [[ -n "$source" ]]; then
        [[ -f "$source" ]] || die "AppImage not found: $source"
        printf '%s\n' "$source"
        return
    fi

    # Use an existing AppImage in Downloads if available.
    if [[ -d "$DOWNLOAD_DIR" ]]; then
        source="$(find "$DOWNLOAD_DIR" -maxdepth 1 -type f \
            -iname 'LosslessCut*.AppImage' \
            -printf '%T@ %p\n' 2>/dev/null |
            sort -nr |
            head -n1 |
            cut -d' ' -f2- || true)"
    fi

    if [[ -n "$source" && -f "$source" ]]; then
        printf '%s\n' "$source"
        return
    fi

    # Otherwise download the latest official release.
    info "No local AppImage found."
    info "Downloading the latest official release..."

    local destination="${LC_TMPDIR}/LosslessCut.AppImage"

    curl --fail --location --silent --show-error \
        "$DOWNLOAD_URL" \
        --output "$destination" ||
        die "Failed to download LosslessCut."

    [[ -s "$destination" ]] || die "Downloaded AppImage is empty."

    printf '%s\n' "$destination"
}

validate_appimage() {
    local appimage="$1"
    local magic

    [[ -f "$appimage" ]] || die "AppImage does not exist."
    [[ -s "$appimage" ]] || die "AppImage is empty."

    # An AppImage must be an ELF executable.
    magic="$(od -An -tx1 -N4 "$appimage" | tr -d ' \n')"

    [[ "$magic" == "7f454c46" ]] ||
        die "Invalid AppImage: ELF header not found."

    chmod +x "$appimage"

    info "AppImage validation passed."
}

# ------------------------------------------------------------------------------
# Icon and desktop integration
# ------------------------------------------------------------------------------

install_icon() {
    local downloaded_icon="${LC_TMPDIR}/losslesscut.svg"

    info "Downloading official LosslessCut icon..."

    if curl --fail --location --silent --show-error \
        "$ICON_URL" --output "$downloaded_icon" &&
        grep -q '<svg' "$downloaded_icon"; then

        mkdir -p "$ICON_DIR"
        install -m 644 "$downloaded_icon" "$ICON_FILE"
        rm -f "$LEGACY_ICON"

        info "Application icon installed."
    else
        info "Could not download the official SVG icon."
        info "Keeping an existing icon, if available."
    fi
}

create_launcher() {
    mkdir -p "$DESKTOP_DIR"

    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=LosslessCut
Comment=Lossless video and audio editor
Exec=${APPIMAGE} %U
Terminal=false
Type=Application
Icon=losslesscut
Categories=AudioVideo;
StartupNotify=true
EOF

    chmod 644 "$DESKTOP_FILE"

    if command -v desktop-file-validate >/dev/null 2>&1; then
        desktop-file-validate "$DESKTOP_FILE" ||
            die "Desktop launcher validation failed."
    fi

    refresh_desktop
}

# ------------------------------------------------------------------------------
# Install / Update
# ------------------------------------------------------------------------------

install_or_update() {
    local mode="$1"
    local source="${2:-}"
    local resolved_source
    local staged_appimage

    require_command curl
    require_command sudo
    require_command od

    LC_TMPDIR="$(mktemp -d)"
    trap cleanup EXIT

    info "Preparing ${mode}..."

    resolved_source="$(resolve_appimage "$source")"

    info "Source: $resolved_source"

    # Copy the source into a temporary location before modifying installation.
    staged_appimage="${LC_TMPDIR}/LosslessCut.AppImage"

    if [[ "$resolved_source" != "$staged_appimage" ]]; then
        cp "$resolved_source" "$staged_appimage"
    fi

    validate_appimage "$staged_appimage"

    info "Preparing staged installation..."

    sudo mkdir -p "$(dirname "$INSTALL_DIR")"
    sudo rm -rf "$STAGING_DIR"
    sudo mkdir -p "$STAGING_DIR"

    sudo install -m 755 "$staged_appimage" \
        "${STAGING_DIR}/LosslessCut.AppImage"

    [[ -x "${STAGING_DIR}/LosslessCut.AppImage" ]] ||
        die "Staged AppImage is not executable."

    # Prepare the icon before replacing the existing installation.
    install_icon

    # Back up the previous installation.
    sudo rm -rf "$BACKUP_DIR"

    if [[ -d "$INSTALL_DIR" ]]; then
        LC_HAD_INSTALL=1
        sudo mv "$INSTALL_DIR" "$BACKUP_DIR"
    fi

    LC_SWAP_DONE=1

    # Activate the new installation.
    sudo mv "$STAGING_DIR" "$INSTALL_DIR"

    # Set up CLI and desktop integration.
    sudo ln -sfn "$APPIMAGE" "$BIN_LINK"

    create_launcher

    # Commit only after all required installation steps succeed.
    LC_COMMITTED=1
    LC_SWAP_DONE=0

    sudo rm -rf "$BACKUP_DIR"

    echo
    info "LosslessCut ${mode} completed successfully."
    info "Launch from the application menu or run:"
    echo "    losslesscut"
}

# ------------------------------------------------------------------------------
# Remove
# ------------------------------------------------------------------------------

remove_app() {
    local purge="${1:-}"

    if [[ "$purge" != "" && "$purge" != "--purge" ]]; then
        die "Unknown remove option: $purge"
    fi

    if [[ ! -d "$INSTALL_DIR" ]] &&
       [[ ! -L "$BIN_LINK" ]] &&
       [[ ! -f "$DESKTOP_FILE" ]]; then

        info "LosslessCut is not installed."

        if [[ "$purge" == "--purge" ]]; then
            read -rp "Remove leftover user data too? [y/N] " answer

            if [[ "$answer" =~ ^[Yy]$ ]]; then
                purge_user_data
                info "User data removed."
            fi
        fi

        return 0
    fi

    echo
    echo "LosslessCut Uninstaller"
    echo "----------------------"

    echo "This will remove:"
    echo "  - Application: ${INSTALL_DIR}"
    echo "  - CLI command: ${BIN_LINK}"
    echo "  - Desktop launcher: ${DESKTOP_FILE}"
    echo "  - Application icon"

    if [[ "$purge" == "--purge" ]]; then
        echo "  - User settings and caches"
    else
        echo
        echo "User settings and caches will be preserved."
    fi

    echo
    read -rp "Continue? [y/N] " answer

    [[ "$answer" =~ ^[Yy]$ ]] || {
        info "Uninstall cancelled."
        return 0
    }

    info "Removing application..."

    sudo rm -rf "$INSTALL_DIR" "$STAGING_DIR" "$BACKUP_DIR"
    sudo rm -f "$BIN_LINK"

    rm -f "$DESKTOP_FILE" "$ICON_FILE" "$LEGACY_ICON"

    if [[ "$purge" == "--purge" ]]; then
        purge_user_data
    fi

    refresh_desktop

    echo
    info "LosslessCut has been uninstalled."
}

purge_user_data() {
    rm -rf \
        "${HOME}/.config/LosslessCut" \
        "${HOME}/.config/losslesscut" \
        "${HOME}/.config/losslesscut-updater" \
        "${HOME}/.cache/LosslessCut" \
        "${HOME}/.cache/losslesscut"
}

# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------

usage() {
    cat <<EOF
LosslessCut Manager

Usage:
  losslesscut-manager install [AppImage]
  losslesscut-manager update  [AppImage]
  losslesscut-manager remove
  losslesscut-manager remove --purge

Examples:
  losslesscut-manager install
  losslesscut-manager install ~/Downloads/LosslessCut-linux-x86_64.AppImage
  losslesscut-manager update
  losslesscut-manager update ~/Downloads/LosslessCut-linux-x86_64.AppImage
  losslesscut-manager remove
  losslesscut-manager remove --purge

If no AppImage is supplied:
  1. The newest matching AppImage in ~/Downloads is used.
  2. Otherwise, the latest official GitHub release is downloaded.
EOF
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

case "${1:-}" in
    install)
        install_or_update install "${2:-}"
        ;;
    update)
        install_or_update update "${2:-}"
        ;;
    remove)
        remove_app "${2:-}"
        ;;
    -h|--help|help|"")
        usage
        ;;
    *)
        die "Unknown command: $1. Use --help."
        ;;
esac
