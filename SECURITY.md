# Security

## Ne tölts fel nyilvánosan

- `~/.local/share/lidl-blokkkereso/lidl_receipts.sqlite3`
- nyers digitális nyugtákat
- Firefox cookie-kat vagy teljes Firefox-profilt
- Lidl-felhasználónevet vagy jelszót
- személyes vásárlási adatot tartalmazó debug naplót

## Hitelesítés

A v3 nem tárol Lidl-jelszót és nem másolja a Firefox `cookies.sqlite` adatbázisát. A Lidl API-kéréseket a Mozilla által aláírt Firefox WebExtension indítja a felhasználó saját, bejelentkezett Firefox-munkamenetéből.

## Native Messaging

Native host: `hu.lidl.blokkkereso`

Engedélyezett extension ID: `lidl-blokkkereso-v3@rambo-junior`

A kommunikáció Firefox Native Messaginggel történik; a program nem nyit localhost TCP-portot.
