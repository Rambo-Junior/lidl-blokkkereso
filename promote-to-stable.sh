#!/usr/bin/env bash
set -Eeuo pipefail
V3="$HOME/.local/bin/lidl-blokkkereso-v3"
STABLE="$HOME/.local/bin/lidl-blokkkereso"
[[ -x "$V3" ]] || { echo "HIBA: nincs telepítve: $V3" >&2; exit 1; }
if [[ -e "$STABLE" ]]; then
  cp -a "$STABLE" "$STABLE.pre-v3-backup"
fi
cp -f "$V3" "$STABLE"
chmod +x "$STABLE"
echo "A v3.0.0 lett az alapértelmezett parancs: $STABLE"
"$STABLE" --version
