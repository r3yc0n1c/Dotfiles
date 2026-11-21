#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# Antigravity Manager
# ------------------------------------------------------------------------------
# A lightweight installer, updater, and uninstaller for Google Antigravity
# on Ubuntu/Linux (x86_64).
#
# Features:
#   - Install Antigravity from the official portable tarball
#   - Update existing installations with rollback support
#   - Configure Electron's Chrome SUID sandbox
#   - Extract and install the application icon
#   - Create and refresh the desktop application launcher
#   - Uninstall while optionally preserving user data
#   - Purge application settings, caches, and updater data
#
# Usage:
#   antigravity-manager install [tarball]
#   antigravity-manager update [tarball]
#   antigravity-manager remove
#   antigravity-manager remove --purge
#
# Requirements:
#   Ubuntu/Linux x86_64, Bash, tar, sudo
#
# Copyright (c) 2026 r3yc0n1c
# License: MIT
#
# This is an independent community-maintained utility and is not
# affiliated with, endorsed by, or officially supported by Google.
# ==============================================================================

APP_NAME="Antigravity"
INSTALL_DIR="/opt/antigravity"
DESKTOP_FILE="${HOME}/.local/share/applications/antigravity.desktop"
ICON_DIR="${HOME}/.local/share/icons/hicolor/512x512/apps"
ICON_FILE="${ICON_DIR}/antigravity.png"
DOWNLOAD_DIR="${HOME}/Downloads"

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────

die() {
    echo "Error: $*" >&2
    exit 1
}

info() {
    echo "[Antigravity] $*" >&2
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

find_tarball() {
    find "$DOWNLOAD_DIR" -maxdepth 1 -type f \
        \( -iname 'Antigravity*.tar.gz' -o -iname 'Antigravity*.tgz' \) \
        -printf '%T@ %p\n' 2>/dev/null |
        sort -nr |
        head -n1 |
        cut -d' ' -f2-
}

resolve_tarball() {
    local archive="${1:-}"

    if [[ -z "$archive" ]]; then
        archive="$(find_tarball)"
    fi

    [[ -n "$archive" ]] || die "No Antigravity tarball found in ${DOWNLOAD_DIR}"
    [[ -f "$archive" ]] || die "File not found: $archive"

    printf '%s\n' "$archive"
}

extract_app() {
    local archive="$1"
    local tmpdir="$2"

    info "Extracting archive..."
    tar -xzf "$archive" -C "$tmpdir"

    local appdir
    appdir="$(find "$tmpdir" -type f -name antigravity -printf '%h\n' | head -n1)"

    [[ -n "$appdir" ]] || die "Could not find Antigravity executable"

    printf '%s\n' "$appdir"
}

extract_icon() {
    local appdir="$1"
    local tmpdir="$2"
    local icon_out="$tmpdir/antigravity-icon.png"

    # Prefer the icon inside app.asar.
    local asar_file="$appdir/resources/app.asar"

    if [[ -f "$asar_file" ]] && command -v npx >/dev/null 2>&1; then
        info "Extracting icon from app.asar using asar..."
        if (cd "$tmpdir" && npx --yes asar extract-file "$asar_file" icon.png) \
            >/dev/null 2>&1; then
            if [[ -f "$tmpdir/icon.png" ]]; then
                cp "$tmpdir/icon.png" "$icon_out"
                printf '%s\n' "$icon_out"
                return 0
            fi
        fi
    fi

    # Fallback: search for a bundled PNG icon.
    local fallback
    fallback="$(find "$appdir" -type f \
        \( -iname 'icon.png' -o -iname 'product_icon.png' \) \
        | head -n1)"

    if [[ -n "$fallback" ]]; then
        cp "$fallback" "$icon_out"
        printf '%s\n' "$icon_out"
        return 0
    fi

    return 1
}

refresh_desktop() {
    command -v update-desktop-database >/dev/null 2>&1 &&
        update-desktop-database "${HOME}/.local/share/applications" || true

    command -v gtk-update-icon-cache >/dev/null 2>&1 &&
        gtk-update-icon-cache -t "${HOME}/.local/share/icons/hicolor" || true
}

create_launcher() {
    mkdir -p "$(dirname "$DESKTOP_FILE")" "$ICON_DIR"

    cat > "$DESKTOP_FILE" <<'EOF'
[Desktop Entry]
Name=Antigravity
Comment=Google Antigravity IDE
Exec=/opt/antigravity/antigravity %U
Terminal=false
Type=Application
Icon=antigravity
Categories=Development;IDE;
StartupNotify=true
StartupWMClass=Antigravity
MimeType=x-scheme-handler/antigravity;
EOF

    chmod +x "$DESKTOP_FILE"

    command -v desktop-file-validate >/dev/null 2>&1 &&
        desktop-file-validate "$DESKTOP_FILE" || true

    refresh_desktop
}

# ─────────────────────────────────────────────────────────────
# Install / Update
# ─────────────────────────────────────────────────────────────

install_or_update() {
    local mode="$1"
    local archive
    archive="$(resolve_tarball "${2:-}")"

    require_command tar
    require_command sudo

    info "Archive: $archive"

    local tmpdir
    tmpdir="$(mktemp -d)"
    local staging="${INSTALL_DIR}.new"
    local backup="${INSTALL_DIR}.backup"
    local extracted_app=""
    local extracted_icon=""

    local had_install=0

    cleanup() {
        trap - EXIT

        if [[ -n "${staging:-}" ]]; then
            sudo rm -rf "$staging" 2>/dev/null || true
        fi

        if [[ -n "${tmpdir:-}" ]]; then
            rm -rf "$tmpdir"
        fi
    }

    # Validate/extract before touching the existing installation.
    local extracted_app
    extracted_app="$(extract_app "$archive" "$tmpdir")"

    # Extract icon before installation, if possible.
    local extracted_icon=""
    extracted_icon="$(extract_icon "$extracted_app" "$tmpdir" || true)"

    info "Preparing installation..."

    sudo rm -rf "$staging"
    sudo mkdir -p "$staging"
    sudo cp -a "$extracted_app/." "$staging/"

    # Set sandbox helper permissions on the staged version.
    if [[ -f "$staging/chrome-sandbox" ]]; then
        sudo chown root:root "$staging/chrome-sandbox"
        sudo chmod 4755 "$staging/chrome-sandbox"
    else
        info "Warning: chrome-sandbox not found in extracted build."
    fi

    # Ensure the main executable exists.
    [[ -x "$staging/antigravity" ]] ||
        sudo chmod +x "$staging/antigravity"

    # Swap installation with rollback support.
    sudo rm -rf "$backup"

    if [[ -d "$INSTALL_DIR" ]]; then
        had_install=1
        sudo mv "$INSTALL_DIR" "$backup"
    fi

    if sudo mv "$staging" "$INSTALL_DIR"; then
        info "Application installed successfully."
        sudo rm -rf "$backup"
    else
        info "Installation failed; restoring previous version..."
        if [[ "$had_install" -eq 1 && -d "$backup" ]]; then
            sudo mv "$backup" "$INSTALL_DIR"
        fi
        die "Could not replace installation."
    fi

    # Install/update desktop icon.
    if [[ -n "$extracted_icon" && -f "$extracted_icon" ]]; then
        mkdir -p "$ICON_DIR"
        cp "$extracted_icon" "$ICON_FILE"
    else
        info "Could not extract icon; existing icon will be retained if present."
    fi

    create_launcher

    echo
    info "Done!"
    info "Launch Antigravity from your application menu or with:"
    echo "    /opt/antigravity/antigravity"

    trap cleanup EXIT
}

# ─────────────────────────────────────────────────────────────
# Remove
# ─────────────────────────────────────────────────────────────


remove_app() {
    local purge="${1:-}"

    if [[ ! -d "$INSTALL_DIR" ]]; then
        info "Antigravity is not installed."
        exit 0
    fi

    echo
    echo "Antigravity Uninstaller"
    echo "----------------------"

    if [[ "$purge" == "--purge" ]]; then
        echo "This will remove:"
        echo "  - Application: ${INSTALL_DIR}"
        echo "  - Desktop launcher: ${DESKTOP_FILE}"
        echo "  - Application icon: ${ICON_FILE}"
        echo "  - User configuration: ~/.config/Antigravity"
        echo "  - User cache: ~/.cache/Antigravity"
        echo "  - Updater data: ~/.config/antigravity-updater"
    else
        echo "This will remove:"
        echo "  - Application: ${INSTALL_DIR}"
        echo "  - Desktop launcher: ${DESKTOP_FILE}"
        echo "  - Application icon: ${ICON_FILE}"
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

    sudo rm -rf "$INSTALL_DIR"
    sudo rm -rf "${INSTALL_DIR}.new" "${INSTALL_DIR}.backup"

    rm -f "$DESKTOP_FILE" "$ICON_FILE"

    if [[ "$purge" == "--purge" ]]; then
        info "Removing user data..."

        rm -rf \
            "${HOME}/.config/Antigravity" \
            "${HOME}/.cache/Antigravity" \
            "${HOME}/.config/antigravity-updater"
    fi

    refresh_desktop

    echo
    info "Antigravity has been completely uninstalled."
}

# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Antigravity Manager

Usage:
  antigravity-manager install [tarball]
  antigravity-manager update  [tarball]
  antigravity-manager remove
  antigravity-manager remove --purge

Examples:
  antigravity-manager install ~/Downloads/Antigravity.tar.gz
  antigravity-manager update ~/Downloads/Antigravity.tar.gz
  antigravity-manager update
  antigravity-manager remove
  antigravity-manager remove --purge

If no tarball is provided, the newest matching archive in ~/Downloads
will be selected automatically.
EOF
}

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
        die "Unknown command: $1. Run antigravity-manager --help"
        ;;
esac
