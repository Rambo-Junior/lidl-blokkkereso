# Security

## Érzékeny helyi adatok

Soha ne töltsd fel hibajegyhez, fórumra vagy GitHubra az alábbiakat:

- teljes Firefox-profilt;
- `cookies.sqlite`, `cookies.sqlite-wal`, `cookies.sqlite-shm` fájlokat;
- Lidl-cookie értékeket vagy teljes `Cookie:` fejlécet;
- böngészőből kimásolt `Copy as cURL` parancsot, ha hitelesítő cookie-kat vagy tokeneket tartalmaz;
- `~/.local/share/lidl-blokkkereso/lidl_receipts.sqlite3` fájlt, ha személyes vásárlási adatot tartalmaz;
- Lidl-felhasználónevet vagy jelszót.

## Firefox session-hozzáférés

A 2.8.1 a normál Firefoxban meglévő Lidl-munkamenetet használja. Ehhez a programnak olvasási hozzáférése van a saját Linux-felhasználód Firefox cookie-adatbázisához.

A Lidl session cookie hitelesítő adatnak számít: aki hozzáfér, a munkamenet érvényességi ideje alatt a fiókhoz kapcsolódó webes API-kat is elérheti. Emiatt csak megbízható forrásból származó programot futtass ugyanazon Linux-felhasználó alatt.

A program a cookie-adatbázist ideiglenes könyvtárba másolja, és nem tartja meg a másolatot tartós alkalmazásadatként.

## Korábbi 2.7.x adatok

A 2.8.1 már nem használja a korábbi:

- `browser-profile-firefox/` könyvtárat;
- `credentials.enc` fájlt;
- `auth-state.json` fájlt;
- alkalmazás saját `venv/` könyvtárát.

Frissítés után ezek a fájlok helyben megmaradhatnak. Csak akkor töröld őket, ha már ellenőrizted, hogy a 2.8.1 megfelelően működik, és nincs szükséged visszaállásra.

## Hibajelentés

Biztonsági hibánál csak a reprodukcióhoz szükséges minimális naplót oszd meg. Session cookie-t, tokent, nyugtatartalmat és személyes adatot mindig távolíts el.
