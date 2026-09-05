# Lidl blokk- és termékkereső – Linux

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

## Követelmények

- Linux
- Python 3
- `python3-venv`
- internetkapcsolat az első telepítéshez és a frissítéshez

Ubuntu / Linux Mint / Debian:

```bash
sudo apt install python3 python3-venv
```

A program első indításkor saját virtuális környezetet készít, és telepíti a szükséges Python-csomagokat (`playwright`, `keyring`, `cryptography`), majd a Playwright Firefoxot.

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

A `--uninstall` az indítót távolítja el; a helyi adatbázist és profilt nem törli.

## Első használat

1. Indítsd el: `lidl-blokkkereso`
2. A TUI-ban `c` billentyűvel mentsd a Lidl-fiókot.
3. `r` vagy `F5` indítja az inkrementális frissítést.
4. Ha nincs érvényes munkamenet, a program megpróbál automatikusan bejelentkezni.

## TUI billentyűk

A fő nézetben a képernyő alján mindig látszanak az aktuális billentyűk. Fontosabbak:

- `/` – keresés
- `r` / `F5` – inkrementális frissítés
- `R` – teljes listaellenőrzés
- `l` – letöltött blokkok listája
- `L` – Lidl belépés
- `c` – fiók mentése/módosítása
- `C` – mentett fiók törlése
- `q` – vissza / kilépés

## Parancssori használat

```bash
lidl-blokkkereso --version
lidl-blokkkereso --about
lidl-blokkkereso --browser-info
lidl-blokkkereso --credential-status
lidl-blokkkereso --sync
lidl-blokkkereso --full-sync
lidl-blokkkereso --search "camembert"
lidl-blokkkereso --stats
lidl-blokkkereso --login
lidl-blokkkereso --logout
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
- szükség esetén a fallback hitelesítőadat-fájl.

## Hitelesítőadatok

A program először a Linux rendszerkulcstartóját próbálja használni. Ha ez nem elérhető, helyi titkosított fallback fájlt használ.

Fontos: ugyanazon Linux-felhasználói fiók teljes kompromittálása esetén semmilyen lokálisan tárolt hitelesítőadat nem tekinthető biztonságosnak. A program saját működéséhez vissza tudja fejteni a fallback fájlt.

Ne tölts fel GitHubra semmilyen saját adatkönyvtárat, Firefox-profilt, SQLite-adatbázist vagy credential fájlt.

## Adatvédelem

A program a nyugtákat a saját gépeden indexeli. Nem tartalmaz saját köztes szervert vagy telemetriát.

A hálózati kommunikáció a Lidl webes felületeihez, illetve az első telepítéskor a Python/Playwright függőségek letöltési forrásaihoz történik.

## Jogi megjegyzés

Ez a projekt független, nem hivatalos eszköz. A `Lidl` név és az esetleges kapcsolódó védjegyek jogosultjaik tulajdonai. A név kizárólag annak leírására szolgál, hogy a program milyen szolgáltatással interoperál.

A felhasználó felelőssége, hogy a program használata megfeleljen a rá vonatkozó szolgáltatási feltételeknek és jogszabályoknak.

## Licenc

MIT. Lásd: [`LICENSE`](LICENSE).
