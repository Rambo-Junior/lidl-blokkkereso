# Lidl blokkkereső 3.1.0

Nagyobb Linux/TUI funkciókiadás. A Mozilla által aláírt Firefox-kiegészítő változatlanul **3.0.0-s**; a 3.1.0 kizárólag a helyi alkalmazást bővíti, ezért új AMO-aláírásra nincs szükség.

- Pénzügyi összesítő közvetlenül a főképernyőn.
- `A` analitika: 12 havi költés, 30 napos trend, top 10 blokk, top 20 termék, üzletstatisztika.
- Terminálos Unicode grafikonok és sparkline.
- `lidl-blokkkereso --report`: önálló helyi HTML riport grafikonokkal és táblázatokkal.
- Bővített `--stats` JSON pénzügyi aggregátumokkal.
- Nincs adatbázismigráció; a meglévő SQLite index kompatibilis.
- A 3.0.2 egyszeri Firefox startup retry megmaradt.
- A release ZIP az eredeti Mozilla-aláírt XPI-t byte-pontosan változatlanul csomagolja.

A `SHA256SUMS` a Linux ZIP és a külön XPI ellenőrzőösszegét tartalmazza.
