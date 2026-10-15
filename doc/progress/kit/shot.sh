#!/bin/bash
# Screenshot an artboard in a given state.
# Usage: kit/shot.sh <file.dc.html> '<{"props":{},"state":{}}>' <out.png> [width] [height]
set -euo pipefail
. "$HOME/.nvm/nvm.sh" >/dev/null 2>&1 || true
here="$(cd "$(dirname "$0")" && pwd)"
w="${4:-1280}"; h="${5:-1700}"
out="$(cd "$(dirname "$3")" && pwd)/$(basename "$3")"
html="${out%.png}.html"
node "$here/renderdc.mjs" "$1" "$html" "$2" "$w" >/dev/null
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=1 --virtual-time-budget=5000 --allow-file-access-from-files \
  --window-size="$w,$h" --screenshot="$out" "file://$html" >/dev/null 2>&1
echo "$out"
