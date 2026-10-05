#!/usr/bin/env bash
# V3.0.2 Linux release készítése. A v3.0.1 hivatalos GitHub release-ből
# ellenőrzött, eredetileg Mozilla által aláírt XPI-t csomagolja változtatás nélkül.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$HOME/lidl/releases/v3.0.2}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
for bin in curl unzip sha256sum python3; do command -v "$bin" >/dev/null || { echo "HIBA: $bin hiányzik" >&2; exit 1; }; done
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
BASE="https://github.com/Rambo-Junior/lidl-blokkkereso/releases/download/v3.0.1"

if [[ -n "${LIDL_V302_TEST_OLD_RELEASE_ZIP:-}" && -n "${LIDL_V302_TEST_OLD_SUMS:-}" ]]; then
  cp -- "$LIDL_V302_TEST_OLD_RELEASE_ZIP" "$TMP/lidl-blokkkereso-v3.0.1-linux.zip"
  cp -- "$LIDL_V302_TEST_OLD_SUMS" "$TMP/SHA256SUMS"
else
  curl -fL --retry 3 "$BASE/lidl-blokkkereso-v3.0.1-linux.zip" -o "$TMP/lidl-blokkkereso-v3.0.1-linux.zip"
  curl -fL --retry 3 "$BASE/SHA256SUMS" -o "$TMP/SHA256SUMS"
fi
(cd "$TMP" && grep 'lidl-blokkkereso-v3.0.1-linux.zip' SHA256SUMS | sha256sum -c -)

python3 - "$TMP/lidl-blokkkereso-v3.0.1-linux.zip" "$HERE" "$OUT" <<'PY2'
from __future__ import annotations
import hashlib, json, os, pathlib, sys, zipfile
old, repo, out = map(pathlib.Path, sys.argv[1:])
with zipfile.ZipFile(old) as bundle:
    members = [n for n in bundle.namelist() if n.endswith('/lidl-blokkkereso-v3-signed.xpi')]
    if len(members) != 1:
        raise SystemExit('HIBA: a v3.0.1 kiadási ZIP-ben nem található pontosan egy aláírt XPI')
    xpi = bundle.read(members[0])
xpi_path = out / 'lidl-blokkkereso-v3-3.0.0-signed.xpi'
xpi_path.write_bytes(xpi)
with zipfile.ZipFile(xpi_path) as ext:
    manifest = json.loads(ext.read('manifest.json'))
    names = ext.namelist()
    if not any(n.lower().startswith('meta-inf/') and n.lower().endswith(('.rsa','.ec','.sf')) for n in names):
        if os.environ.get('LIDL_V302_TEST_ALLOW_UNSIGNED_FIXTURE') != '1':
            raise SystemExit('HIBA: az XPI-ben nem található Mozilla-aláíráshoz tartozó META-INF fájl')
    if manifest.get('version') != '3.0.0' or manifest.get('browser_specific_settings',{}).get('gecko',{}).get('id') != 'lidl-blokkkereso-v3@rambo-junior':
        raise SystemExit('HIBA: a forrás XPI nem a v3.0.0 Lidl Firefox-kiegészítő')
    for rel in ('extension/manifest.json','extension/content.js','extension/background.js'):
        zipped = ext.read(rel.split('/',1)[1])
        source = (repo/rel).read_bytes()
        same = json.loads(zipped) == json.loads(source) if rel.endswith('.json') else zipped == source
        if not same:
            raise SystemExit(f'HIBA: az aláírt XPI és a repó extension-forrása eltér: {rel}. A v3.0.2 nem módosíthatja az aláírt kiegészítőt.')
archive = out / 'lidl-blokkkereso-v3.0.2-linux.zip'
paths = [
    'lidl-blokkkereso.sh','install-v3.sh','promote-to-stable.sh',
    'native/lidl-native-host.py','extension/manifest.json','extension/content.js',
    'extension/background.js','README.md','CHANGELOG.md','LICENSE','PRIVACY.md','SECURITY.md',
]
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as target:
    for rel in paths:
        p = repo/rel
        if not p.is_file(): raise SystemExit(f'HIBA: hiányzó repófájl: {p}')
        info = zipfile.ZipInfo('lidl-blokkkereso-v3.0.2/'+rel, date_time=(2026,10,5,0,0,0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = ((0o755 if rel.endswith('.sh') else 0o644) << 16)
        target.writestr(info,p.read_bytes(),compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
    info=zipfile.ZipInfo('lidl-blokkkereso-v3.0.2/lidl-blokkkereso-v3-signed.xpi', date_time=(2026,10,5,0,0,0))
    info.compress_type=zipfile.ZIP_DEFLATED
    info.external_attr=0o644 << 16
    target.writestr(info,xpi,compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
sums=out/'SHA256SUMS'
sums.write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in (archive,xpi_path)))
print('ELKÉSZÜLT:',archive,'\nALÁÍRT XPI:',xpi_path,'\nELLENŐRZŐ:',sums)
PY2
(cd "$OUT" && sha256sum -c SHA256SUMS && unzip -tq lidl-blokkkereso-v3.0.2-linux.zip | tail -1)
