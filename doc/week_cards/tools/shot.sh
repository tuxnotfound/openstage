#!/bin/bash
# Screenshots a design-canvas mock at its real size with headless Chrome.
# Usage: shot.sh <mock.dc.html> '<props json>' <out.png> [width] [height]
# Example: doc/week_cards/tools/shot.sh doc/week_cards/mocks/changelog.dc.html '{"week":"w41","theme":"light"}' /tmp/changelog-w41.png
set -euo pipefail
. "$HOME/.nvm/nvm.sh" >/dev/null 2>&1 || true
here="$(cd "$(dirname "$0")" && pwd)"
html="${3%.png}.html"
node "$here/render.mjs" "$1" "$html" "$2"
"$here/htmlshot.sh" "$html" "$3" "${4:-1200}" "${5:-630}"
