#!/usr/bin/env bash
set -Eeuo pipefail
V3="$HOME/.local/bin/lidl-blokkkereso-v3"
STABLE="$HOME/.local/bin/lidl-blokkkereso"
BACKUP="$STABLE.pre-v3.0.2-backup"
[[ -x "$V3" ]] || { echo "HIBA: nincs telepítve: $V3" >&2; exit 1; }
if [[ -e "$STABLE" ]] && ! cmp -s "$V3" "$STABLE" && [[ ! -e "$BACKUP" ]]; then
  cp -a "$STABLE" "$BACKUP"
  echo "Előző CLI mentve: $BACKUP"
fi
install -m 755 "$V3" "$STABLE"
echo "A v3.0.2 az alapértelmezett parancs: $STABLE"
"$STABLE" --version
