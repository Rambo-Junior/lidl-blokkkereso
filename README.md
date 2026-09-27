# Lidl blokk- és termékkereső – Linux

> 🇭🇺 Jelenleg kizárólag a Lidl Magyarországot támogatja.

Nem hivatalos, közösségi Linux TUI a saját Lidl digitális nyugták helyi indexeléséhez és kereséséhez. A projekt nem áll kapcsolatban a Lidl-lel.

## v3.0.1 architektúra

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
TMP="$(mktemp -d)" && cd "$TMP" && curl -fL https://github.com/Rambo-Junior/lidl-blokkkereso/releases/download/v3.0.1/lidl-blokkkereso-v3.0.1-linux.zip -o lidl.zip && unzip -q lidl.zip && cd lidl-blokkkereso-v3.0.1 && ./install-v3.sh && ./promote-to-stable.sh
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

## v3.0.1: biztonságos telepítés és hibaelhárítás

A telepítő az eredeti, Mozilla által aláírt **3.0.0-s** XPI-t először
`~/.local/share/lidl-blokkkereso-v3/lidl-blokkkereso-v3-signed.xpi`
útvonalra menti, és csak utána nyitja meg a Firefoxban. Az ideiglenes
letöltési könyvtár ezért a telepítő után biztonságosan törölhető.
Az első telepítésnél a Firefoxban hagyd jóvá a kiegészítőt és jelentkezz be a Lidlbe.

A 3.0.1-es CLI a Firefox első válaszának hiányát 30 másodperc után jelzi,
és 90 másodperces elakadást is felismer. Ellenőrzés:
`lidl-blokkkereso --session-status`.
Ha `Ctrl+C`-vel megszakítod a TUI-ban az `r` szinkront, a terminál helyreáll;
a már megnyitott Firefox-lap a háttérben még dolgozhat. Újabb szinkron
előtt várd meg a Firefox-lapon a művelet végét.

A teljes v3.0.1 telepítés GitHub Release-ből SHA256 ellenőrzéssel:

```bash
sudo apt update && sudo apt install -y python3 curl unzip && TMP="$(mktemp -d)" && (cd "$TMP" && curl -fLO https://github.com/Rambo-Junior/lidl-blokkkereso/releases/download/v3.0.1/lidl-blokkkereso-v3.0.1-linux.zip && curl -fLO https://github.com/Rambo-Junior/lidl-blokkkereso/releases/download/v3.0.1/SHA256SUMS && grep 'lidl-blokkkereso-v3.0.1-linux.zip' SHA256SUMS | sha256sum -c - && unzip -q lidl-blokkkereso-v3.0.1-linux.zip && cd lidl-blokkkereso-v3.0.1 && ./install-v3.sh && ./promote-to-stable.sh) && rm -rf "$TMP" && echo 'KÉSZ. Firefox jóváhagyás után: lidl-blokkkereso --session-status'
```
