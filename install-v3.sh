#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOST_NAME="hu.lidl.blokkkereso"
HOST_DIR="$HOME/.mozilla/native-messaging-hosts"
LIB_DIR="$HOME/.local/lib/lidl-blokkkereso-v3"
EXT_DIR="$HOME/.local/share/lidl-blokkkereso-v3/extension"
BIN="$HOME/.local/bin/lidl-blokkkereso-v3"

mkdir -p "$HOST_DIR" "$LIB_DIR" "$EXT_DIR" "$HOME/.local/bin"
install -m 700 "$HERE/native/lidl-native-host.py" "$LIB_DIR/lidl-native-host.py"
install -m 755 "$HERE/lidl-blokkkereso.sh" "$BIN"
cp -f "$HERE/extension/manifest.json" "$HERE/extension/background.js" "$HERE/extension/content.js" "$EXT_DIR/"

# Fejlesztési kényelem: ha egy korábbi ideiglenes v3 extension forrása már
# be van töltve about:debugging alatt, frissítsük azt is, hogy elég legyen Reload.
UPDATED_TEMP=0
for OLD_EXT in \
  "$HOME/lidl/lidl-blokkkereso-v3.0-alpha1-poc/extension" \
  "$HOME/lidl/lidl-blokkkereso-v3.0-alpha2/extension" \
  "$HOME/lidl/lidl-blokkkereso-v3.0-rc1/extension"; do
  if [[ -d "$OLD_EXT" ]]; then
    cp -f "$HERE/extension/manifest.json" "$HERE/extension/background.js" "$HERE/extension/content.js" "$OLD_EXT/"
    UPDATED_TEMP=1
  fi
done

cat > "$HOST_DIR/$HOST_NAME.json" <<EOF_JSON
{
  "name": "$HOST_NAME",
  "description": "Lidl blokkkereső v3 native messaging host",
  "path": "$LIB_DIR/lidl-native-host.py",
  "type": "stdio",
  "allowed_extensions": [
    "lidl-blokkkereso-v3@rambo-junior"
  ]
}
EOF_JSON
chmod 600 "$HOST_DIR/$HOST_NAME.json"

# If a Mozilla-signed XPI is present, open it for normal persistent installation.
SIGNED=""
for candidate in \
  "$HERE/lidl-blokkkereso-v3-signed.xpi" \
  "$HERE/lidl-blokkkereso-v3.xpi"; do
  if [[ -f "$candidate" ]]; then SIGNED="$candidate"; break; fi
done

if [[ -n "$SIGNED" ]]; then
  echo "Mozilla-aláírt Firefox-kiegészítő megtalálva: $SIGNED"
  if command -v firefox >/dev/null 2>&1; then
    firefox "file://$SIGNED" >/dev/null 2>&1 &
    echo "A Firefoxban erősítsd meg a kiegészítő telepítését."
  fi
else
  echo "A CLI és a Native Messaging host telepítve."
  echo "A tartós Firefox-telepítéshez Mozilla által aláírt XPI szükséges."
  if [[ "$UPDATED_TEMP" -eq 1 ]]; then
    echo "A korábban ideiglenesen betöltött v3 extension forrása frissítve lett 3.0.0-ra."
    echo "Firefox about:debugging oldalon kattints a Lidl blokkkereső alatt a Reload gombra."
  else
    echo "Fejlesztési teszthez: about:debugging → Load Temporary Add-on → $EXT_DIR/manifest.json"
  fi
fi

echo
echo "Telepítve:"
echo "  $BIN"
echo "  $LIB_DIR/lidl-native-host.py"
echo "  $HOST_DIR/$HOST_NAME.json"
echo "  $EXT_DIR/manifest.json"
echo
echo "Teszt: lidl-blokkkereso-v3 --session-status"
echo "Sync:  lidl-blokkkereso-v3 --sync"
