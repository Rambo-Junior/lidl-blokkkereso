# Lidl blokk- és termékkereső – Linux

> 🇭🇺 Jelenleg kizárólag a Lidl Magyarországot támogatja.

Nem hivatalos, közösségi Linux TUI a saját Lidl digitális nyugták helyi indexeléséhez és kereséséhez. A projekt nem áll kapcsolatban a Lidl-lel.

## v3.0.2 architektúra

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

A Linux CLI verziója **3.0.2**. A Firefox-kiegészítő továbbra is a Mozilla által aláírt **3.0.0** verzió, mert a 3.0.1 és 3.0.2 javításai kizárólag a Linux oldali alkalmazást érintik.

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

## Telepítés vagy frissítés GitHub Release-ből

Ajánlott, SHA-256 ellenőrzéssel:

```bash
sudo apt update && sudo apt install -y python3 curl unzip && TMP="$(mktemp -d)" && (cd "$TMP" && curl -fLO https://github.com/Rambo-Junior/lidl-blokkkereso/releases/download/v3.0.2/lidl-blokkkereso-v3.0.2-linux.zip && curl -fLO https://github.com/Rambo-Junior/lidl-blokkkereso/releases/download/v3.0.2/SHA256SUMS && grep 'lidl-blokkkereso-v3.0.2-linux.zip' SHA256SUMS | sha256sum -c - && unzip -q lidl-blokkkereso-v3.0.2-linux.zip && cd lidl-blokkkereso-v3.0.2 && ./install-v3.sh && ./promote-to-stable.sh) && rm -rf "$TMP" && lidl-blokkkereso --version
```

Első telepítéskor a Firefoxban egyszer jóvá kell hagyni a Mozilla által aláírt kiegészítő telepítését. Meglévő, aktív kiegészítő esetén a telepítő nem nyit új telepítőlapot.

Ellenőrzés:

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

Az `r` és a `lidl-blokkkereso --sync` ugyanazt az inkrementális szinkronizáló kódot használja.

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

## v3.0.2: automatikus Firefox bridge újrapróbálás

A Firefox időnként megnyithatja a Lidl triggerlapot úgy, hogy a kiegészítő első content-script indítása nem jelentkezik vissza a Native Messaging hostnak. Ilyenkor a v3.0.1 30 másodperc után hibával leállt, miközben egy következő kézi próbálkozás rendszerint azonnal működött.

A v3.0.2 ezt automatikusan kezeli:

- ha az első Firefox-triggerre **30 másodpercig semmilyen válasz nem érkezik**, a program egyszer új triggerlapot nyit;
- az újrapróbálás külön `runId`-t használ;
- valódi Lidl/API-, Native Messaging- vagy futás közbeni hibákat nem rejt el és nem próbál végtelenül újra;
- a 90 másodperces előrehaladás-ellenőrzés változatlanul megmarad;
- a TUI `r` és a CLI `--sync` ugyanazt a retry-logikát használja.

A startup retry kikapcsolható diagnosztikához:

```bash
LIDL_V3_STARTUP_RETRIES=0 lidl-blokkkereso --sync
```

Egynél több retry is kérhető, bár normál használatra az alapértelmezett egy próbálkozás ajánlott:

```bash
LIDL_V3_STARTUP_RETRIES=2 lidl-blokkkereso --sync
```

Ha `Ctrl+C`-vel megszakítod a TUI-ban az `r` szinkront, a terminál helyreáll. A már megnyitott Firefox-lap ettől még befejezheti a futását.

## v3.0.1 javítások

- szabályos `Ctrl+C`-kezelés és curses terminál-helyreállítás;
- 30 másodperces válaszhiány- és 90 másodperces előrehaladás-ellenőrzés;
- az aláírt XPI tartós helyre mentése még az ideiglenes telepítési könyvtár törlése előtt;
- meglévő aktív Firefox-kiegészítő esetén nincs felesleges újratelepítési ablak.
