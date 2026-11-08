# ForeverSuite bijwerken op GitHub

Werk steeds in je bestaande ForeverSuite-projectmap op het bureaublad.
Deze map is gekoppeld aan Bovahkiin/ForeverSuite in GitHub Desktop.

## Bestanden bijwerken

1. Laat de nieuwe addonversie in deze projectmap plaatsen.
2. Open GitHub Desktop en kies ForeverSuite.
3. Bekijk de lijst met wijzigingen.
4. Vul onder Summary bijvoorbeeld **Update naar 0.8.10** in.
5. Klik **Commit to main** en daarna **Push origin**.

Dit werkt de bronbestanden bij. Het publiceert nog geen downloadbare release.
ZIP-bestanden, lokale werkbestanden en testlogs worden niet meegestuurd.
Previews blijven in `.previews`; de `.toc` staat in de hoofdmap.

## Een downloadbare release maken

1. Open https://github.com/Bovahkiin/ForeverSuite/actions.
2. Kies links **Nieuwe release maken**.
3. Klik **Run workflow**, laat **main** geselecteerd en bevestig.
4. Wacht tot de controle groen is. Bij een fout wordt geen release gemaakt.
5. Ga naar **Releases** en open de nieuwe **Draft** (conceptrelease).
6. Controleer de patchnotes en het bestand `ForeverSuite-VERSIE-forever.zip`.
7. Klik **Publish release** wanneer je de update wilt uitbrengen.

Wil je de release meteen na de controles publiceren? Vink bij **Run workflow**
de optie **Direct publiceren na geslaagde controles** aan. Dan maakt GitHub
direct een gepubliceerde release en zijn stappen 5–7 niet nodig.

De knop controleert de addon, maakt de ZIP met de juiste mapstructuur en voegt
de patchnotes en controlecode toe. Een bestaand versienummer wordt niet overschreven.
Voor een volgende update moeten het versienummer in `ForeverSuite.toc` en
`Core/Init.lua` overeenkomen en moeten de nieuwste patchnotes bovenaan
`CHANGELOG.md` staan. Dit verzorgen we tijdens het maken van de update.

Je hoeft geen toegangssleutel of wachtwoord in de repository te zetten.
