# Changelog

## 3.0.1

- `Ctrl+C`-kezelés és curses terminál helyreállítás a TUI-frissítéseknél.
- Ha nem érkezik első válasz, 30 mp után érthető hiba; 90 mp-es előrehaladás-ellenőrzés.
- Az aláírt XPI-t a telepítő tartósan elmenti még a telepítőcsomag ideiglenes mappájának törlése előtt.
- Az aktív, meglévő böngésző-kiegészítőt a telepítő nem kéri újra telepíteni.
- A Firefox-kiegészítő változatlanul Mozilla által aláírt v3.0.0; a Linux CLI v3.0.1.

## 3.0.0

- Új Firefox WebExtension + Native Messaging architektúra.
- A Lidl API-hívásokat a felhasználó normál, bejelentkezett Firefox-munkamenete végzi.
- Mozilla által aláírt, tartósan telepíthető Firefox-kiegészítő.
- Playwright eltávolítva.
- Firefox `cookies.sqlite` másolás és közvetlen cookie-auth eltávolítva.
- Lidl-jelszó tárolása nem szükséges.
- Inkrementális (`r` / `--sync`) és teljes (`R` / `--full-sync`) szinkron.
- A meglévő SQLite nyugtaindex és TUI megmarad.
- A böngésző és a Linux alkalmazás Native Messaginggel kommunikál; nincs localhost webszerver.

## 2.8.1

- A hitelesítés teljesen átállt a felhasználó normál Firefoxában meglévő Lidl-munkamenetre.
- Playwright és a külön automatizált Firefox-profil eltávolítva.
- Automatikus Lidl-bejelentkezés és külön Lidl-jelszó tárolás eltávolítva.
- `keyring` és `cryptography` függőségek eltávolítva.
- Saját Python virtuális környezet már nem szükséges; a program a Python standard libraryt használja.
- A futó Firefox `cookies.sqlite`, `-wal` és `-shm` fájljait ideiglenes könyvtárba másolja, és csak a másolatból olvas.
- A Lidl-cookie-k értékei nem kerülnek tartósan az alkalmazás adatkönyvtárába.
- Új `--session-status` parancs a Firefox Lidl-munkamenet ellenőrzésére.
- Új `--browser-info` parancs a felismert Firefox-profilok megjelenítésére.
- `LIDL_FIREFOX_PROFILE` környezeti változóval konkrét Firefox-profil választható.
- Normál, Snap és Flatpak Firefox-profilok automatikus keresése.
- Az online blokk és a Lidl belépési oldal a rendszer normál Firefoxában/alapértelmezett böngészőjében nyílik meg.
- Inkrementális és teljes szinkron megmaradt; a korábbi SQLite index kompatibilis.
- TUI súgósor frissítve az aktuális billentyűkhöz.

## 2.7.0

- GitHub-ready kiadás.
- MIT licenc és SPDX fejléc.
- Nem hivatalos / Lidl-lel nem kapcsolt projekt disclaimer.
- README, SECURITY és PRIVACY dokumentáció.
- `--about` és `--license` kapcsolók.
- A 2.6 működése változatlan maradt.

## 2.6.0

- A 0 vagy hiányzó blokkösszeg helyreállítása a mentett nyugta HTML-ből.
- Hiányzó tételszám helyi helyreállítása.
- Jó helyi metaadatot nem ír felül hibás API-metaadat.
