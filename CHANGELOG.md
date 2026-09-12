# Changelog

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
