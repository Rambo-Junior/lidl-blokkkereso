# Lidl blokkkereső 3.0.2

Linux oldali stabilitási javítókiadás. A Mozilla által aláírt Firefox-kiegészítő **változatlanul 3.0.0-s**, és benne van a Linux ZIP-ben. Új Firefox/AMO-aláírásra nincs szükség.

- Ha az első Firefox-triggerre 30 másodpercig semmilyen extension-válasz nem érkezik, a program egyszer automatikusan újrapróbálja.
- Az újrapróbálás külön `runId`-t kap, így egy esetleg későn induló első lap nem ugyanabba a futási könyvtárba ír.
- A retry működik a TUI `r` / `R`, a CLI `--sync` / `--full-sync` és a `--session-status` esetén.
- Az API-, Native Messaging- és futás közbeni hibákat nem nyeli el; a retry csak a teljes startup-válaszhiányra vonatkozik.
- `LIDL_V3_STARTUP_RETRIES=0` értékkel a retry diagnosztikai célból kikapcsolható.
- A v3.0.1 `Ctrl+C`, timeout és biztonságos XPI-telepítési javításai megmaradnak.
- A meglévő helyi SQLite blokkindex kompatibilis; nincs adatbázismigráció.

A release ZIP és a külön, eredeti Mozilla-aláírt XPI SHA-256 összege a `SHA256SUMS` fájlban található.
