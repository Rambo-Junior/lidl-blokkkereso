# Privacy

A program nem tartalmaz telemetriát, nem gyűjt használati statisztikát és nem üzemeltet saját köztes szervert.

## Helyileg tárolt adatok

A program tartósan tárolhatja:

- a felhasználó saját digitális Lidl-nyugtáit és azok keresési indexét a helyi SQLite adatbázisban;
- technikai cache fájlként a beágyazott Python alkalmazás kibontott példányát.

Alapértelmezett adatkönyvtár:

```text
~/.local/share/lidl-blokkkereso/
```

## Firefox munkamenet

A 2.8.1 nem kér és nem tárol Lidl-felhasználónevet vagy jelszót.

A program a felhasználó normál Firefox-profiljának `cookies.sqlite` adatbázisából használja a már meglévő Lidl-munkamenetet. A futó Firefox miatt az adatbázist és a hozzá tartozó `-wal` / `-shm` fájlokat egy rendszer által kezelt ideiglenes könyvtárba másolja, majd a másolatból olvas.

- a Lidl-cookie-k értékei nem kerülnek az alkalmazás saját tartós adatkönyvtárába;
- a cookie-értékeket a program nem írja ki normál naplóba;
- az ideiglenes másolat a művelet végén törlődik a `TemporaryDirectory` működésének megfelelően.

## Hálózati kommunikáció

A program a saját nyugták lekéréséhez közvetlenül a Lidl Magyarország webes szolgáltatásaihoz kapcsolódik (`www.lidl.hu`).

A program nem továbbítja a nyugtákat vagy a Lidl-munkamenetet saját vagy harmadik fél által üzemeltetett köztes szerverre.

## Korábbi verziók

A 2.7.x verziók használhattak külön Playwright-profilt és mentett hitelesítőadatot. A 2.8.1 ezeket már nem használja. Régi fájlok frissítés után a helyi adatkönyvtárban maradhatnak, amíg a felhasználó külön el nem távolítja őket.
