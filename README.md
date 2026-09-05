# Lidl blokk- és termékkereső – Linux

> 🇭🇺 **Jelenleg kizárólag a Lidl Magyarországot támogatja.**  
> A program a `lidl.hu`, `country=HU` és `languageCode=hu-HU` végpontokra épül.

Nem hivatalos, közösségi Linux TUI a saját Lidl digitális nyugták helyi indexeléséhez és kereséséhez.

> **Nem hivatalos projekt.** Nem áll kapcsolatban a Lidl-lel, és a Lidl nem támogatja vagy hagyta jóvá. A Lidl weboldala, belépési folyamata és API-ja bármikor változhat, ezért a működés nem garantálható.

## Funkciók

- tartós Firefox-munkamenet Playwrighttal;
- mentett Lidl-fiók és automatikus belépés;
- inkrementális nyugtafrissítés;
- helyi SQLite-index;
- terméknév, cikkszám, üzlet és dátum szerinti keresés;
- letöltött blokkok listázása;
- blokk megnyitása TUI-ban vagy online;
- blokkösszeg és tételszám helyreállítása a mentett blokk HTML-jéből, ha az API metaadata hiányos;
- egyetlen futtatható `lidl-blokkkereso.sh` fájl.

## Böngésző

A program **kizárólag Firefox böngészőmotorral működik**.

Nem szükséges külön Firefoxot telepíteni: az első indításkor a Playwright automatikusan letölti a saját, kompatibilis Firefox buildjét.

A program jelenlegi verziója **nem támogatja a Chromium, Google Chrome böngészőmotorokat**. Ennek oka, hogy a Lidl bejelentkezési oldala az automatizált Chromium-alapú munkameneteket egyes esetekben korlátozza.

A letöltött Playwright Firefox külön, tartós profilt használ, ezért a meglévő saját Firefox-profilodat nem módosítja.

## Követelmények

- Linux
- Python 3
- `python3-venv`
- internetkapcsolat az első telepítéshez és a nyugták frissítéséhez
- Playwright Firefox – automatikusan települ az első indításkor

Ubuntu / Linux Mint / Debian:

```bash
sudo apt install python3 python3-venv
```

A program első indításkor saját virtuális környezetet készít, és telepíti a szükséges Python-csomagokat:

```text
playwright
keyring
cryptography
```

Ezután letölti a Playwright saját Firefox buildjét.

## Telepítés

```bash
chmod +x lidl-blokkkereso.sh
./lidl-blokkkereso.sh --install
```

Ezután:

```bash
lidl-blokkkereso
```

Eltávolítás:

```bash
lidl-blokkkereso --uninstall
```

A `--uninstall` az indítót távolítja el; a helyi adatbázist és böngészőprofilt nem törli.

## Első használat

1. Indítsd el:

   ```bash
   lidl-blokkkereso
   ```

2. A TUI-ban `c` billentyűvel mentsd a Lidl-fiókot.
3. `r` vagy `F5` indítja az inkrementális frissítést.
4. Ha nincs érvényes munkamenet, a program megpróbál automatikusan bejelentkezni.
5. Az első teljes indexelés után a későbbi frissítések csak az új nyugtákat töltik le.

## TUI billentyűk

A fő nézetben:

- `/` – keresés
- `↑` / `↓` – navigálás
- `ENTER` – blokk megnyitása
- `r` / `F5` – inkrementális frissítés
- `R` – teljes listaellenőrzés
- `l` – letöltött blokkok listája
- `L` – Lidl belépés
- `c` – fiók mentése vagy módosítása
- `C` – mentett fiók törlése
- `o` – blokk online megnyitása
- `s` – statisztika
- `x` – Lidl munkamenet törlése
- `D` – teljes helyi index törlése
- `q` – vissza / kilépés

A blokklistában és a megnyitott blokk nézetében:

- `↑` / `↓` – navigálás / görgetés
- `PgUp` / `PgDn` – lapozás
- `ENTER` – blokk megnyitása a listából
- `o` – online megnyitás
- `q` – vissza

## Parancssori használat

```bash
lidl-blokkkereso --version
lidl-blokkkereso --about
lidl-blokkkereso --browser-info
lidl-blokkkereso --credential-status
lidl-blokkkereso --save-credentials
lidl-blokkkereso --delete-credentials
lidl-blokkkereso --sync
lidl-blokkkereso --full-sync
lidl-blokkkereso --search "camembert"
lidl-blokkkereso --stats
lidl-blokkkereso --login
lidl-blokkkereso --logout
lidl-blokkkereso --clear-index
```

## Adatok helye

Alapértelmezetten:

```text
~/.local/share/lidl-blokkkereso/
```

Itt található többek között:

- SQLite nyugtaindex;
- tartós Firefox-profil;
- virtuális Python-környezet;
- böngészőmotor-jelölő;
- szükség esetén a fallback hitelesítőadat-fájl.

A program futás közben ezen kívül cache fájlokat is létrehozhat:

```text
~/.cache/lidl-blokkkereso/
```

## Hitelesítőadatok

A program először a Linux rendszerkulcstartóját próbálja használni.

Ha ez nem elérhető, helyi titkosított fallback fájlt használ.

A hitelesítőadatok **nem kerülnek bele a `lidl-blokkkereso.sh` fájlba**.

Fontos: ha ugyanaz a Linux-felhasználói fiók teljesen kompromittálódik, semmilyen lokálisan tárolt hitelesítőadat nem tekinthető teljesen biztonságosnak. A program saját működéséhez vissza tudja fejteni a fallback credential fájlt.

## Adatvédelem

A program:

- a nyugtákat helyben indexeli;
- nem használ saját köztes szervert;
- nem küld telemetriát;
- nem gyűjt statisztikát a használatról.

A hálózati kommunikáció a Lidl webes felületeihez, illetve az első telepítéskor a Python/Playwright függőségek letöltési forrásaihoz történik.

Ne tölts fel GitHubra semmilyen saját adatkönyvtárat, Firefox-profilt, SQLite-adatbázist vagy credential fájlt.

## Korlátozások

- jelenleg csak a Lidl Magyarország támogatott;
- kizárólag Firefox böngészőmotor támogatott;
- a Lidl belépési folyamata és API-ja nem hivatalos integrációs felület;
- a Lidl bármikor módosíthatja a végpontokat vagy a hitelesítési folyamatot;
- időszakos belépési korlátozások vagy CAPTCHA előfordulhatnak.

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

> **Unofficial project.** This project is not affiliated with Lidl, and Lidl does not endorse or support it. Lidl may change its website, login flow or API at any time, so functionality cannot be guaranteed.

## Features

- persistent Firefox session via Playwright;
- saved Lidl account credentials and automatic login;
- incremental receipt refresh;
- local SQLite index;
- search by product name, article number, store and date;
- browse already downloaded receipts;
- open receipts inside the TUI or online;
- recover receipt totals and item counts from the stored receipt HTML when API metadata is missing;
- distributed as a single executable `lidl-blokkkereso.sh` file.

## Browser

The application **works exclusively with the Firefox browser engine**.

You do not need to install Firefox separately. On first launch, Playwright automatically downloads its own compatible Firefox build.

The current version **does not support Chromium, Google Chrome or Microsoft Edge browser engines**. The reason is that Lidl's login service may restrict automated Chromium-based sessions in some environments.

The Playwright Firefox build uses its own persistent profile and does not modify your personal Firefox profile.

## Requirements

- Linux
- Python 3
- `python3-venv`
- internet connection for first-time setup and receipt refresh
- Playwright Firefox – installed automatically on first launch

Ubuntu / Linux Mint / Debian:

```bash
sudo apt install python3 python3-venv
```

On first launch, the script creates its own Python virtual environment and installs:

```text
playwright
keyring
cryptography
```

It then downloads Playwright's Firefox build.

## Installation

```bash
chmod +x lidl-blokkkereso.sh
./lidl-blokkkereso.sh --install
```

Then run:

```bash
lidl-blokkkereso
```

Uninstall launcher:

```bash
lidl-blokkkereso --uninstall
```

`--uninstall` removes the launcher only. It does not delete your local receipt database or browser profile.

## First use

1. Start the application:

   ```bash
   lidl-blokkkereso
   ```

2. Press `c` in the TUI to save your Lidl account credentials.
3. Press `r` or `F5` to start an incremental refresh.
4. If there is no valid Lidl session, the application attempts to log in automatically.
5. After the initial full index has been created, later refreshes download only new receipts.

## TUI keys

Main view:

- `/` – search
- `↑` / `↓` – navigate
- `ENTER` – open receipt
- `r` / `F5` – incremental refresh
- `R` – full receipt-list check
- `l` – list downloaded receipts
- `L` – Lidl login
- `c` – save or update account credentials
- `C` – delete saved credentials
- `o` – open receipt online
- `s` – statistics
- `x` – delete Lidl browser session
- `D` – delete local receipt index
- `q` – back / quit

Receipt list and receipt viewer:

- `↑` / `↓` – navigate / scroll
- `PgUp` / `PgDn` – page
- `ENTER` – open selected receipt
- `o` – open online
- `q` – back

## Command-line usage

```bash
lidl-blokkkereso --version
lidl-blokkkereso --about
lidl-blokkkereso --browser-info
lidl-blokkkereso --credential-status
lidl-blokkkereso --save-credentials
lidl-blokkkereso --delete-credentials
lidl-blokkkereso --sync
lidl-blokkkereso --full-sync
lidl-blokkkereso --search "camembert"
lidl-blokkkereso --stats
lidl-blokkkereso --login
lidl-blokkkereso --logout
lidl-blokkkereso --clear-index
```

## Data location

By default:

```text
~/.local/share/lidl-blokkkereso/
```

This may contain:

- SQLite receipt index;
- persistent Firefox profile;
- Python virtual environment;
- browser-engine marker;
- encrypted fallback credentials file when needed.

The application may also create cache files under:

```text
~/.cache/lidl-blokkkereso/
```

## Credentials

The application first tries to store credentials in the Linux system keyring.

If no usable keyring is available, it uses an encrypted local fallback file.

Credentials are **never embedded in `lidl-blokkkereso.sh`**.

Important: if your Linux user account itself is fully compromised, no locally stored credential should be considered completely secure. The application must be able to decrypt its fallback credential file in order to use it.

## Privacy

The application:

- indexes receipts locally;
- does not use its own relay server;
- does not send telemetry;
- does not collect usage analytics.

Network communication is made to Lidl's web services and, during initial setup, to the package/download sources required for Python and Playwright dependencies.

Do not upload your local application data directory, Firefox profile, SQLite database or credential files to GitHub.

## Limitations

- currently supports Lidl Hungary only;
- Firefox browser engine only;
- Lidl's login flow and receipt API are not official public integration interfaces;
- Lidl may change endpoints or authentication behavior at any time;
- temporary login throttling or CAPTCHA may occur.

## Legal notice

This is an independent, unofficial project.

`Lidl` and related trademarks belong to their respective owners. The name is used only to describe the service this software interoperates with.

Users are responsible for ensuring that their use of the software complies with applicable terms of service and laws.

## License

MIT. See [`LICENSE`](LICENSE).
