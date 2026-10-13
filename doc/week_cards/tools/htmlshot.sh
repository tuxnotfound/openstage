#!/bin/bash
# Screenshot a local HTML page (an app-rendered card wrapped with its fonts) with headless Chrome.
# Usage: htmlshot.sh <page.html> <out.png> [width] [height]
set -euo pipefail
width="${3:-1200}"; height="${4:-630}"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=1 --virtual-time-budget=4000 --allow-file-access-from-files \
  --window-size="$width,$height" --screenshot="$2" "file://$1" >/dev/null 2>&1
echo "$2"
