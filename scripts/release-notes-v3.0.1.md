# Lidl blokkkereső 3.0.1

Linux oldali javítókiadás. A Mozilla által aláírt Firefox-kiegészítő **változatlanul 3.0.0-s**, és benne van a Linux ZIP-ben. Új Firefox-aláírásra nincs szükség.

- Szabályos `Ctrl+C`-kezelés a TUI külső frissítéseinél.
- 30 másodperces válaszhiány- és 90 másodperces előrehaladás-ellenőrzés, használható diagnosztikai üzenetek.
- A telepítő az aláírt XPI-t tartós helyre menti **még azelőtt**, hogy az ideiglenes letöltési könyvtár eltávolítható lenne.
- Már telepített kiegészítő esetén nincs újratelepítési felugró ablak.
- Meglévő helyi SQLite blokkindex kompatibilis; nincs adatbázismigráció.

A release ZIP és a külön XPI fájl SHA-256 összege a `SHA256SUMS` fájlban található.

**Telepítéshez lásd a README.md fájlt.** A Firefoxban az első telepítést egyszer jóvá kell hagyni; a Lidl-fiókba a normál böngészőben kell belépni.
