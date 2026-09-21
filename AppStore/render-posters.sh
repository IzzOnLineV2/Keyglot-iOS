#!/bin/bash
#
# Render the App Store poster HTML into PNGs at the sizes App Store Connect accepts.
#
#   AppStore/posters/poster_{it,en}_NN.html  ->  AppStore/screenshots/<size>/<lang>/poster_..png
#
# Sizes produced:
#   6.9inch  1320 x 2868  (iPhone 6.9", primary slot)
#   6.5inch  1242 x 2688  (iPhone 6.5", downscaled from the 6.9" render)
#
# The HTML pulls Instrument Serif/Sans + Noto Sans Arabic from Google Fonts, so keep a network
# connection when rendering. Requires Google Chrome and macOS `sips`.
#
# Usage:  bash AppStore/render-posters.sh
#
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
POSTERS="$DIR/posters"
OUT="$DIR/screenshots"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

[ -x "$CHROME" ] || { echo "Google Chrome not found at: $CHROME"; exit 1; }

for lang in it en; do
  mkdir -p "$OUT/6.9inch/$lang" "$OUT/6.5inch/$lang"
done

for html in "$POSTERS"/poster_*.html; do
  name="$(basename "$html" .html)"        # poster_it_01
  lang="${name#poster_}"; lang="${lang%%_*}"   # it | en
  big="$OUT/6.9inch/$lang/$name.png"
  small="$OUT/6.5inch/$lang/$name.png"

  "$CHROME" --headless=new --disable-gpu --force-device-scale-factor=1 \
    --hide-scrollbars --window-size=1320,2868 --virtual-time-budget=6000 \
    --screenshot="$big" "file://$html" >/dev/null 2>&1

  sips -z 2688 1242 "$big" --out "$small" >/dev/null   # 6.5" = 1242 x 2688
  echo "rendered $name  (6.9 + 6.5)"
done

echo "Done. PNGs in $OUT/{6.9inch,6.5inch}/{it,en}/"
