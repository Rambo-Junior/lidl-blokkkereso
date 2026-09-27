#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOST_NAME="hu.lidl.blokkkereso"
HOST_DIR="$HOME/.mozilla/native-messaging-hosts"
LIB_DIR="$HOME/.local/lib/lidl-blokkkereso-v3"
BASE_EXT_DIR="$HOME/.local/share/lidl-blokkkereso-v3"
EXT_DIR="$BASE_EXT_DIR/extension"
PERSISTENT_XPI="$BASE_EXT_DIR/lidl-blokkkereso-v3-signed.xpi"
BIN="$HOME/.local/bin/lidl-blokkkereso-v3"

mkdir -p "$HOST_DIR" "$LIB_DIR" "$EXT_DIR" "$HOME/.local/bin"
install -m 700 "$HERE/native/lidl-native-host.py" "$LIB_DIR/lidl-native-host.py"
install -m 755 "$HERE/lidl-blokkkereso.sh" "$BIN"
cp -f "$HERE/extension/manifest.json" "$HERE/extension/background.js" "$HERE/extension/content.js" "$EXT_DIR/"

# Régi, ideiglenes fejlesztői kiegészítők frissítése (ha még léteznek).
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
  "allowed_extensions": ["lidl-blokkkereso-v3@rambo-junior"]
}
EOF_JSON
chmod 600 "$HOST_DIR/$HOST_NAME.json"

# A Firefox számára megnyitott XPI-t a telepítés ELŐTT tartós helyre másoljuk.
# Így az ideiglenes letöltési könyvtár akár azonnal törölhető.
SIGNED=""
for candidate in \
  "$HERE/lidl-blokkkereso-v3-signed.xpi" \
  "$HERE/lidl-blokkkereso-v3.xpi"; do
  if [[ -s "$candidate" ]]; then SIGNED="$candidate"; break; fi
done
if [[ -n "$SIGNED" ]]; then
  if [[ "$SIGNED" != "$PERSISTENT_XPI" ]]; then
    install -m 600 "$SIGNED" "$PERSISTENT_XPI"
  fi
  echo "Mozilla-aláírt XPI tartósan elmentve: $PERSISTENT_XPI"
fi

# Az aktív, tartósan telepített kiegészítőt nem szükséges újra telepíteni.
ADDON_INSTALLED="$(python3 - <<'PY'
import json
from pathlib import Path
home = Path.home()
profiles = (home / '.mozilla/firefox').glob('*/extensions.json')
for profile in profiles:
    try:
        addons = json.loads(profile.read_text()).get('addons', [])
        if any(a.get('id') == 'lidl-blokkkereso-v3@rambo-junior' and a.get('active') and not a.get('appDisabled') and not a.get('userDisabled') for a in addons):
            print('yes')
            break
    except (OSError, ValueError):
        pass
PY
)"

if [[ "$ADDON_INSTALLED" == "yes" ]]; then
  echo "A Lidl Firefox-kiegészítő már telepítve és aktív. Nem nyitok új telepítőlapot."
elif [[ -s "$PERSISTENT_XPI" ]]; then
  echo "A Firefox-kiegészítő még nincs telepítve az ellenőrzött profilban."
  if command -v firefox >/dev/null 2>&1; then
    firefox "file://$PERSISTENT_XPI" >/dev/null 2>&1 &
    echo "Firefox: kattints a Hozzáadás gombra. Ezt követően jelentkezz be a Lidlbe."
  else
    echo "HIBA: firefox parancs nem található. Nyisd meg kézzel az XPI-t: $PERSISTENT_XPI" >&2
  fi
else
  echo "Nincs aláírt XPI ebben a csomagban. A CLI és a native host telepítve."
  if [[ "$UPDATED_TEMP" -eq 1 ]]; then
    echo "Ideiglenes fejlesztői kiegészítő frissítve, about:debugging oldalon Reload szükséges."
  else
    echo "Az aláírt XPI-t a GitHub Release-csomagnak tartalmaznia kell;"
    echo "fejlesztői teszt: about:debugging → Load Temporary Add-on → $EXT_DIR/manifest.json"
  fi
fi

printf '\nTelepítve:\n  %s\n  %s\n  %s\n' "$BIN" "$LIB_DIR/lidl-native-host.py" "$HOST_DIR/$HOST_NAME.json"
printf '\nTeszt (Firefox jóváhagyás és Lidl belépés után):\n  lidl-blokkkereso --session-status\n'
