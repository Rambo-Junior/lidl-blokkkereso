# Lidl blokk- és termékkereső – Linux

> Jelenleg kizárólag a Lidl Magyarországot támogatja.

Nem hivatalos, közösségi Linux TUI a saját Lidl digitális nyugták helyi indexeléséhez, kereséséhez és költési elemzéséhez. A projekt nem áll kapcsolatban a Lidl-lel.

## v3.1.0 architektúra

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
SQLite index + TUI + analitika + helyi HTML riport
```

Nincs Playwright, nincs Lidl-jelszó tárolás, nincs Firefox-cookie másolás, nincs localhost webszerver, nincs telemetria.

A Linux CLI verziója **3.1.0**. A Firefox-kiegészítő továbbra is a Mozilla által aláírt **3.0.0**, mert a 3.1.0 új funkciói kizárólag a helyi Linux alkalmazást és az SQLite-adatok megjelenítését érintik.

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

```bash
TMP="$(mktemp -d)" && (cd "$TMP" && curl -fLO https://github.com/Rambo-Junior/lidl-blokkkereso/releases/download/v3.1.0/lidl-blokkkereso-v3.1.0-linux.zip && curl -fLO https://github.com/Rambo-Junior/lidl-blokkkereso/releases/download/v3.1.0/SHA256SUMS && grep 'lidl-blokkkereso-v3.1.0-linux.zip' SHA256SUMS | sha256sum -c - && unzip -q lidl-blokkkereso-v3.1.0-linux.zip && cd lidl-blokkkereso-v3.1.0 && ./install-v3.sh && ./promote-to-stable.sh) && rm -rf "$TMP" && hash -r && lidl-blokkkereso --version
```

Első telepítéskor a Firefoxban egyszer jóvá kell hagyni a Mozilla által aláírt kiegészítőt. Meglévő aktív kiegészítő esetén nincs újratelepítési felugró ablak.

## Főképernyő

A v3.1.0 a kereső fölött már pénzügyi összesítést is mutat:

- összes költés;
- aktuális hónap költése;
- előző hónap és százalékos változás;
- utolsó 30 nap költése;
- átlagos blokkérték.

Az összesítés a már helyben indexelt, pozitív végösszegű blokkokból készül.

## Analitika TUI

Nyomd meg az `A` billentyűt. Öt oldal érhető el:

1. utolsó 12 hónap költése Unicode oszlopdiagrammal;
2. utolsó 30 nap napi trendje sparkline-nal;
3. top 10 legdrágább blokk;
4. top 20 leggyakoribb termék;
5. üzletenkénti blokkszám, átlagos blokkérték és összköltés.

Az analitika nézetben `←/→` vagy `1-5` vált oldalt, `H` elkészíti és megnyitja a helyi HTML riportot, `q` visszalép.

## HTML riport

CLI-ből:

```bash
lidl-blokkkereso --report
```

A riport alapértelmezett helye:

```text
~/.local/share/lidl-blokkkereso/lidl-analitika.html
```

A HTML önálló, külső JavaScript/CDN nélkül működik, és tartalmazza az összesítő kártyákat, havi és napi grafikonokat, top blokkokat, top termékeket és üzletstatisztikát. A riport helyben készül; a program nem tölt fel vásárlási adatot sehova.

## TUI billentyűk

- `/` keresés
- `↑` / `↓` navigálás
- `Enter` blokk megnyitása
- `r` inkrementális frissítés
- `R` teljes listaellenőrzés
- `l` blokkok listája
- `L` Lidl belépési oldal
- `o` blokk megnyitása online
- `s` gyors statisztika
- `A` részletes analitika
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
lidl-blokkkereso --report
lidl-blokkkereso --login
lidl-blokkkereso --browser-info
lidl-blokkkereso --clear-index
```

## Firefox bridge retry

A v3.0.2-ben bevezetett automatikus retry megmaradt. Ha az első Firefox-triggerre 30 másodpercig egyetlen extension-válasz sem érkezik, a program egyszer új `runId`-val megismétli az indítást. Diagnosztikai célból kikapcsolható:

```bash
LIDL_V3_STARTUP_RETRIES=0 lidl-blokkkereso --sync
```

Helyi adatkönyvtár: `~/.local/share/lidl-blokkkereso/`

Adatvédelem: [PRIVACY.md](PRIVACY.md)
Biztonság: [SECURITY.md](SECURITY.md)
Licenc: MIT
