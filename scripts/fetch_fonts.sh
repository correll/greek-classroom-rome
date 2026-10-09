#!/usr/bin/env bash
# Re-download the vendored open-licence fonts.
# Gentium Book Plus (SIL OFL)  — body text, full polytonic Greek
# GFS Didot (OFL)              — Greek display face
set -euo pipefail
cd "$(dirname "$0")/../assets/fonts"
GF="https://raw.githubusercontent.com/google/fonts/main/ofl"
for f in Regular Bold Italic BoldItalic; do
  curl -sSfL -o "GentiumBookPlus-$f.ttf" "$GF/gentiumbookplus/GentiumBookPlus-$f.ttf"
  echo "  GentiumBookPlus-$f.ttf"
done
curl -sSfL -o GFSDidot-Regular.ttf "$GF/gfsdidot/GFSDidot-Regular.ttf"; echo "  GFSDidot-Regular.ttf"
curl -sSfL -o OFL-GentiumBookPlus.txt "$GF/gentiumbookplus/OFL.txt"
curl -sSfL -o OFL-GFSDidot.txt "$GF/gfsdidot/OFL.txt"
echo "fonts up to date"
