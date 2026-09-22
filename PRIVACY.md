# Privacy

A Lidl blokk- és termékkereső nem tartalmaz telemetriát, reklámot vagy fejlesztő által üzemeltetett köztes szervert.

## Helyben tárolt adatok

A Linux alkalmazás helyben tárolhatja a felhasználó saját digitális Lidl-nyugtáit, a nyugták SQLite keresőindexét és a szinkron állapotához szükséges helyi metaadatokat.

Alapértelmezett adatkönyvtár:

```text
~/.local/share/lidl-blokkkereso/
```

## Firefox-kiegészítő

A v3 Firefox WebExtension a `www.lidl.hu` oldalon a felhasználó meglévő, bejelentkezett Lidl-munkamenetét használja a saját digitális nyugták lekéréséhez.

A kiegészítő nem tárol Lidl-felhasználónevet vagy jelszót, nem másolja a Firefox cookie-adatbázisát, és nem küld nyugtaadatot a fejlesztőnek vagy harmadik fél szerverére.

A nyugtaadatok Firefox Native Messagingen keresztül kizárólag a felhasználó saját gépén futó `hu.lidl.blokkkereso` native hosthoz kerülnek.

A Mozilla engedélymodellje miatt a kiegészítő deklarálja a `financialAndPaymentInfo` és `websiteContent` adatkategóriákat, mivel vásárlási/nyugtaadatokat ad át a helyi Linux alkalmazásnak.
