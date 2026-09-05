#!/usr/bin/env bash
# Rasterizes the readme SVGs to PNGs for the OpenDesktop gallery.
#
#   readme/export_opendesktop.sh
#
# Each PNG keeps its SVG's basename and is rendered at 2x its native size
# (viewBox-driven, via --export-dpi) so adding or resizing an SVG needs no
# change here.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$DIR/opendesktop"

perl "$DIR/generate.pl"
mkdir -p "$OUT"

for svg in "$DIR"/demo_*.svg "$DIR"/panel.svg; do
  name="$(basename "$svg" .svg)"
  inkscape "$svg" --export-type=png --export-filename="$OUT/$name.png" --export-dpi=192
done

ls -la "$OUT"
