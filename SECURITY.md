# Security

## Érzékeny helyi adatok

Soha ne töltsd fel hibajegyhez vagy GitHubra az alábbiakat:

- `~/.local/share/lidl-blokkkereso/browser-profile-firefox/`
- `~/.local/share/lidl-blokkkereso/credentials.enc`
- `~/.local/share/lidl-blokkkereso/lidl_receipts.sqlite3`
- böngészős cookie-k, storage state vagy teljes profilmentés
- Lidl-felhasználónév/jelszó

## Credential storage

A program lehetőség szerint Linux rendszerkulcstartót használ. Fallbackként helyileg titkosított fájlt hoz létre. Ez a fallback a véletlen fájlolvasás ellen hasznos, de nem véd egy olyan támadótól, aki már a felhasználói fiókod jogosultságaival futtat kódot.

## Hibajelentés

Biztonsági hibánál a reprodukcióhoz szükséges minimális naplót oszd meg, titkok és nyugtaadatok nélkül.
