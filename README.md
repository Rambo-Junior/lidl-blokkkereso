# Lidl blokk- és termékkereső – Linux

> 🇭🇺 **Jelenleg kizárólag a Lidl Magyarországot támogatja.**  
> A program a `lidl.hu`, `country=HU` és `languageCode=hu-HU` végpontokra épül.

Nem hivatalos, közösségi Linux TUI a saját Lidl digitális nyugták helyi indexeléséhez és kereséséhez.

> **Nem hivatalos projekt.** Nem áll kapcsolatban a Lidl-lel, és a Lidl nem támogatja vagy hagyta jóvá. A Lidl weboldala és a használt, nem hivatalos webes API bármikor változhat, ezért a működés nem garantálható.

## Mi változott a 2.8.1-ben?

A 2.8-as ág teljesen elhagyta a Playwrightot és a külön automatikus bejelentkezést. A program most a **normál Firefoxban már meglévő Lidl-munkamenetet** használja.

- nincs Playwright;
- nincs külön automatizált Firefox-profil;
- nincs Lidl-jelszó tárolás;
- nincs `keyring` / `cryptography` függőség;
- nincs saját Python virtuális környezet;
- a Firefox `cookies.sqlite` adatbázisa csak ideiglenes másolatból kerül olvasásra;
- a Lidl-cookie-k értékei nem kerülnek az alkalmazás saját adatkönyvtárába.

## Funkciók

- inkrementális nyugtafrissítés;
- teljes listaellenőrzés;
- helyi SQLite-index;
- terméknév, cikkszám, üzlet és dátum szerinti keresés;
- letöltött blokkok listázása;
- blokk megnyitása TUI-ban vagy online;
- blokkösszeg és tételszám helyreállítása a mentett blokk HTML-jéből, ha az API metaadata hiányos;
- egyetlen futtatható `lidl-blokkkereso.sh` fájl;
- normál Firefox-profil automatikus felismerése klasszikus, Snap és Flatpak telepítésnél.

## Követelmények

- Linux
- Python 3
- Mozilla Firefox
- érvényes Lidl-bejelentkezés a normál Firefoxban
- internetkapcsolat a blokkok frissítéséhez

Ubuntu / Linux Mint / Debian:

```bash
sudo apt install python3 firefox
```

A program a Python standard libraryn kívül nem igényel pip csomagot.

## Telepítés

```bash
chmod +x lidl-blokkkereso.sh
./lidl-blokkkereso.sh --install
```

Ezután:

```bash
lidl-blokkkereso
```

Verzió ellenőrzése:

```bash
lidl-blokkkereso --version
```

Eltávolítás:

```bash
lidl-blokkkereso --uninstall
```

A `--uninstall` csak az indítót és a desktop bejegyzést távolítja el. A helyi blokkindexet nem törli.

## Első használat

1. Jelentkezz be a Lidl-fiókodba a normál Firefoxban.
2. Ellenőrizd a munkamenetet:

   ```bash
   lidl-blokkkereso --session-status
   ```

3. Indíts inkrementális frissítést:

   ```bash
   lidl-blokkkereso --sync
   ```

4. Indítsd a TUI-t:

   ```bash
   lidl-blokkkereso
   ```

Ha a munkamenet lejárt, nyisd meg a belépést:

```bash
lidl-blokkkereso --login
```

Jelentkezz be a megnyíló normál Firefoxban, majd futtasd újra a frissítést.

## TUI billentyűk

A fő nézetben:

- `/` – keresés
- `↑` / `↓` vagy `j` / `k` – navigálás
- `ENTER` – blokk megnyitása
- `r` / `F5` – inkrementális frissítés
- `R` – teljes listaellenőrzés
- `l` – letöltött blokkok listája
- `L` – Lidl belépési oldal megnyitása a normál Firefoxban
- `o` – kijelölt blokk online megnyitása
- `s` – statisztika
- `D` – teljes helyi index törlése, megerősítéssel
- `q` – vissza / kilépés

A blokklistában és a megnyitott blokk nézetében:

- `↑` / `↓` vagy `j` / `k` – navigálás / görgetés
- `PgUp` / `PgDn` – lapozás
- `ENTER` – blokk megnyitása a listából
- `o` – online megnyitás
- `q` – vissza

## Parancssori használat

```bash
lidl-blokkkereso --version
lidl-blokkkereso --about
lidl-blokkkereso --login
lidl-blokkkereso --session-status
lidl-blokkkereso --browser-info
lidl-blokkkereso --sync
lidl-blokkkereso --full-sync
lidl-blokkkereso --search "camembert"
lidl-blokkkereso --stats
lidl-blokkkereso --clear-index
```

### Inkrementális és teljes frissítés

Normál használathoz:

```bash
lidl-blokkkereso --sync
```

Ez a legújabb listaoldalaktól indul, és megáll, amikor már nem talál új blokkot.

Teljes listaellenőrzéshez:

```bash
lidl-blokkkereso --full-sync
```

A meglévő helyi index megmarad; a program végigellenőrzi a teljes blokklistát.

## Firefox-profil felismerés

A program ezeket a Linuxon gyakori helyeket vizsgálja:

```text
~/.mozilla/firefox/
~/snap/firefox/common/.mozilla/firefox/
~/.var/app/org.mozilla.firefox/.mozilla/firefox/
```

Ha több Firefox-profilod van, konkrét profilt is megadhatsz:

```bash
LIDL_FIREFOX_PROFILE="$HOME/.mozilla/firefox/xxxxxxxx.default-release" \
  lidl-blokkkereso --session-status
```

A változó közvetlenül `cookies.sqlite` fájlra is mutathat.

> Jelenleg a program az üres Firefox `originAttributes` értékhez tartozó Lidl-cookie-kat használja. Ha a Lidl-bejelentkezést Firefox Multi-Account Containerben vagy más elkülönített konténerben használod, a munkamenet nem feltétlenül lesz felismerhető.

## Adatok helye

Alapértelmezetten:

```text
~/.local/share/lidl-blokkkereso/
```

A fontos tartós adat:

```text
lidl_receipts.sqlite3
```

A beágyazott Python program futáskor ideiglenesen/kódként kicsomagolásra kerülhet:

```text
~/.cache/lidl-blokkkereso/
```

A program **nem másolja tartósan** a Firefox cookie-adatbázisát a saját adatkönyvtárába.

## Frissítés 2.7.x-ről

A 2.8.1 ugyanazt a helyi SQLite blokkindexet használja, ezért a korábbi index megtartható.

A 2.7.x által használt alábbi elemeket a 2.8.1 már nem használja:

- Playwright Firefox-profil;
- Python `venv`;
- `credentials.enc`;
- `auth-state.json`;
- korábban elmentett Lidl hitelesítőadatok.

Ezek megléte nem akadályozza a 2.8.1 működését. Törlésük csak külön, tudatos takarításként javasolt, miután az új verzió működését ellenőrizted.

## Adatvédelem

A program:

- a blokkokat helyben indexeli;
- nem használ saját köztes szervert;
- nem küld telemetriát;
- nem gyűjt használati statisztikát;
- nem kéri és nem tárolja a Lidl-jelszavadat;
- a Firefox Lidl-cookie-jait csak a szükséges API-kérésekhez használja.

Részletek: [`PRIVACY.md`](PRIVACY.md).

## Biztonság

A Firefox munkamenet-cookie hitelesítő adatnak számít. Ne tölts fel GitHubra vagy hibajegyhez:

- Firefox-profilt;
- `cookies.sqlite` / `cookies.sqlite-wal` / `cookies.sqlite-shm` fájlt;
- Cookie fejlécet vagy `Copy as cURL` kimenetet;
- helyi SQLite blokkindexet, ha személyes vásárlási adatot tartalmaz.

Részletek: [`SECURITY.md`](SECURITY.md).

## Korlátozások

- jelenleg csak a Lidl Magyarország támogatott;
- a Firefoxban meglévő érvényes Lidl-munkamenet szükséges;
- a Lidl nyugta API-ja nem hivatalos publikus integrációs felület;
- a Lidl bármikor módosíthatja a végpontokat vagy a hitelesítési viselkedést;
- több Firefox-profil esetén szükség lehet a `LIDL_FIREFOX_PROFILE` beállítására.

## Jogi megjegyzés

Ez a projekt független, nem hivatalos eszköz.

A `Lidl` név és az esetleges kapcsolódó védjegyek jogosultjaik tulajdonai. A név kizárólag annak leírására szolgál, hogy a program milyen szolgáltatással interoperál.

A felhasználó felelőssége, hogy a program használata megfeleljen a rá vonatkozó szolgáltatási feltételeknek és jogszabályoknak.

## Licenc

MIT. Lásd: [`LICENSE`](LICENSE).

---

# English

> 🇭🇺 **Currently supports Lidl Hungary only.**  
> The application is built around `lidl.hu`, `country=HU` and `languageCode=hu-HU`.

Unofficial community Linux TUI for locally indexing and searching your own Lidl digital receipts.

> **Unofficial project.** This project is not affiliated with Lidl, and Lidl does not endorse or support it. Lidl may change its website or the unofficial web API used by this tool at any time, so functionality cannot be guaranteed.

## What changed in 2.8.1?

The 2.8 branch completely removes Playwright and the separate automated login flow. The application now uses the **existing Lidl session from your normal Firefox profile**.

- no Playwright;
- no separate automated Firefox profile;
- no Lidl password storage;
- no `keyring` / `cryptography` dependency;
- no application-specific Python virtual environment;
- Firefox `cookies.sqlite` is read only through a temporary copy;
- Lidl cookie values are not persisted in the application's own data directory.

## Features

- incremental receipt refresh;
- full receipt-list verification;
- local SQLite index;
- search by product name, article number, store and date;
- browse downloaded receipts;
- open receipts inside the TUI or online;
- recover receipt totals and item counts from stored receipt HTML when API metadata is incomplete;
- distributed as a single executable `lidl-blokkkereso.sh` file;
- automatic discovery of regular, Snap and Flatpak Firefox profiles on Linux.

## Requirements

- Linux
- Python 3
- Mozilla Firefox
- an active Lidl login in your normal Firefox profile
- internet connection for receipt refresh

Ubuntu / Linux Mint / Debian:

```bash
sudo apt install python3 firefox
```

No pip packages are required; the application uses the Python standard library only.

## Installation

```bash
chmod +x lidl-blokkkereso.sh
./lidl-blokkkereso.sh --install
```

Then:

```bash
lidl-blokkkereso
```

Check version:

```bash
lidl-blokkkereso --version
```

Uninstall launcher:

```bash
lidl-blokkkereso --uninstall
```

`--uninstall` removes only the launcher and desktop entry. It does not delete the local receipt index.

## First use

1. Log in to Lidl in your normal Firefox browser.
2. Verify the session:

   ```bash
   lidl-blokkkereso --session-status
   ```

3. Run an incremental refresh:

   ```bash
   lidl-blokkkereso --sync
   ```

4. Start the TUI:

   ```bash
   lidl-blokkkereso
   ```

If the session expires, open the login page:

```bash
lidl-blokkkereso --login
```

Log in in the normal Firefox window, then run the refresh again.

## TUI keys

Main view:

- `/` – search
- `↑` / `↓` or `j` / `k` – navigate
- `ENTER` – open receipt
- `r` / `F5` – incremental refresh
- `R` – full receipt-list verification
- `l` – list downloaded receipts
- `L` – open Lidl login in the normal Firefox browser
- `o` – open selected receipt online
- `s` – statistics
- `D` – delete the local index after confirmation
- `q` – back / quit

Receipt list and receipt viewer:

- `↑` / `↓` or `j` / `k` – navigate / scroll
- `PgUp` / `PgDn` – page
- `ENTER` – open selected receipt
- `o` – open online
- `q` – back

## Command-line usage

```bash
lidl-blokkkereso --version
lidl-blokkkereso --about
lidl-blokkkereso --login
lidl-blokkkereso --session-status
lidl-blokkkereso --browser-info
lidl-blokkkereso --sync
lidl-blokkkereso --full-sync
lidl-blokkkereso --search "camembert"
lidl-blokkkereso --stats
lidl-blokkkereso --clear-index
```

## Firefox profile discovery

The application checks these common Linux locations:

```text
~/.mozilla/firefox/
~/snap/firefox/common/.mozilla/firefox/
~/.var/app/org.mozilla.firefox/.mozilla/firefox/
```

You can force a specific profile:

```bash
LIDL_FIREFOX_PROFILE="$HOME/.mozilla/firefox/xxxxxxxx.default-release" \
  lidl-blokkkereso --session-status
```

The variable may also point directly to `cookies.sqlite`.

> The current implementation uses Lidl cookies with empty Firefox `originAttributes`. A Lidl login isolated in Firefox Multi-Account Containers or another container may not be detected.

## Data location

By default:

```text
~/.local/share/lidl-blokkkereso/
```

The important persistent file is:

```text
lidl_receipts.sqlite3
```

The embedded Python application may be extracted at runtime under:

```text
~/.cache/lidl-blokkkereso/
```

The application does **not** persist a copy of your Firefox cookie database in its own data directory.

## Upgrading from 2.7.x

2.8.1 reuses the same local SQLite receipt index, so your existing index can remain in place.

The following 2.7.x components are no longer used:

- Playwright Firefox profile;
- Python `venv`;
- `credentials.enc`;
- `auth-state.json`;
- previously saved Lidl credentials.

Their presence does not prevent 2.8.1 from working. Remove them only as a deliberate cleanup after verifying the new version.

## Privacy

The application:

- indexes receipts locally;
- does not use a relay server;
- sends no telemetry;
- collects no usage analytics;
- does not request or store your Lidl password;
- uses Firefox Lidl cookies only for the required API requests.

See [`PRIVACY.md`](PRIVACY.md).

## Security

Firefox session cookies are authentication material. Never upload these to GitHub or bug reports:

- Firefox profiles;
- `cookies.sqlite`, `cookies.sqlite-wal`, `cookies.sqlite-shm`;
- Cookie headers or `Copy as cURL` output;
- your local SQLite receipt index if it contains personal purchase data.

See [`SECURITY.md`](SECURITY.md).

## Limitations

- Lidl Hungary only;
- an active Lidl session in Firefox is required;
- the Lidl receipt API is not an official public integration API;
- Lidl may change endpoints or authentication behavior at any time;
- multiple Firefox profiles may require `LIDL_FIREFOX_PROFILE`.

## Legal notice

This is an independent, unofficial project.

`Lidl` and related trademarks belong to their respective owners. The name is used only to describe the service this software interoperates with.

Users are responsible for ensuring that their use of the software complies with applicable terms of service and laws.

## License

MIT. See [`LICENSE`](LICENSE).
