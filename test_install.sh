#!/usr/bin/env bash
# Install the working copy into the running Plasma session and restart the shell.
#
# Deliberately does not go through Nix: this is the fast edit → see-it loop.
# `nix run .#view` renders the widget standalone; this puts the real thing in
# the real panel, which is the only way to test tray behaviour and status
# transitions.
set -euo pipefail

cd "$(dirname "$0")"

id="$(grep -oE '"Id":[[:space:]]*"[^"]+"' package/metadata.json | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
target="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/$id"

echo "installing $id"
rm -rf "$target"
mkdir -p "$(dirname "$target")"
cp -r package "$target"

# Make the icon resolvable outside the package so the Add Widgets dialog and
# the tray's own icon lookup both find it.
icons="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"
mkdir -p "$icons"
cp "package/contents/icons/$id.svg" "$icons/$id.svg" 2>/dev/null || true

if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

if [ "${NO_RESTART:-0}" != "1" ] && command -v plasmashell >/dev/null 2>&1; then
    echo "restarting plasmashell"
    if command -v kquitapp6 >/dev/null 2>&1; then
        kquitapp6 plasmashell >/dev/null 2>&1 || true
    fi
    sleep 1
    (setsid plasmashell --replace >/dev/null 2>&1 &) || true
fi

echo "done — add the widget from the panel's Add Widgets dialog, or drop it in the System Tray"
