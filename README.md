# Lidl blokk- és termékkereső – Linux

> 🇭🇺 Jelenleg kizárólag a Lidl Magyarországot támogatja.

Nem hivatalos, közösségi Linux TUI a saját Lidl digitális nyugták helyi indexeléséhez és kereséséhez. A projekt nem áll kapcsolatban a Lidl-lel.

## v3.0.0 architektúra

```text
normál Firefox
      ↓
Mozilla által aláírt WebExtension
      ↓
Lidl API a valódi bejelentkezett munkamenettel
      ↓
Firefox Native Messaging
      ↓
helyi Linux alkalmazás
      ↓
SQLite index + TUI
```

Nincs Playwright, nincs Lidl-jelszó tárolás, nincs Firefox-cookie másolás, nincs localhost webszerver, nincs telemetria.

## Követelmények

- Linux
- Firefox 140+
- Python 3
- `curl` és `unzip`
- Lidl Magyarország fiók digitális nyugtákkal

Debian / Ubuntu / Linux Mint:

```bash
sudo apt install python3 curl unzip
```

## Telepítés GitHub Release-ből

```bash
TMP="$(mktemp -d)" && cd "$TMP" && curl -fL https://github.com/Rambo-Junior/lidl-blokkkereso/releases/download/v3.0.0/lidl-blokkkereso-v3.0.0-linux.zip -o lidl.zip && unzip -q lidl.zip && cd lidl-blokkkereso-v3.0.0 && ./install-v3.sh && ./promote-to-stable.sh
```

A telepítő megnyitja a Mozilla által aláírt Firefox-kiegészítőt; a Firefoxban egyszer jóvá kell hagyni a telepítést.

Ezután:

```bash
lidl-blokkkereso --session-status
lidl-blokkkereso --sync
lidl-blokkkereso
```

## TUI billentyűk

- `/` keresés
- `↑` / `↓` navigálás
- `Enter` blokk megnyitása
- `r` inkrementális frissítés
- `R` teljes listaellenőrzés
- `l` blokkok listája
- `L` Lidl belépési oldal
- `o` blokk megnyitása online
- `s` statisztika
- `D` helyi index törlése
- `q` kilépés / vissza

## CLI

```bash
lidl-blokkkereso --version
lidl-blokkkereso --session-status
lidl-blokkkereso --sync
lidl-blokkkereso --full-sync
lidl-blokkkereso --search "camembert"
lidl-blokkkereso --stats
lidl-blokkkereso --login
lidl-blokkkereso --browser-info
lidl-blokkkereso --clear-index
```

Ha a Lidl-munkamenet lejár, jelentkezz be a normál Firefoxban, majd futtasd újra a `lidl-blokkkereso --sync` parancsot.

Helyi adatkönyvtár: `~/.local/share/lidl-blokkkereso/`

Adatvédelem: [PRIVACY.md](PRIVACY.md)
Biztonság: [SECURITY.md](SECURITY.md)
Licenc: MIT
