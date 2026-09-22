# Firefox extension aláírás – v3.0.0

A normál Firefox tartósan csak Mozilla által aláírt kiegészítőt telepít.

Az aláíráshoz az `lidl-blokkkereso-v3-extension-source.zip` fájlt kell az addons.mozilla.org fejlesztői felületén új kiegészítőként, **Unlisted / On your own** terjesztési móddal feltölteni.

Az extension azonosítója:

`lidl-blokkkereso-v3@rambo-junior`

Kért jogosultságok:

- `nativeMessaging`
- `https://www.lidl.hu/*`

A visszakapott aláírt `.xpi` fájlt tedd a release könyvtárba `lidl-blokkkereso-v3-signed.xpi` néven. Ezután `./install-v3.sh` megnyitja Firefoxban telepítésre.
