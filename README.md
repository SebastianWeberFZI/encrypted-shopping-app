# Einkaufsliste (verschlüsselt, GitHub-Backend)

Gemeinsame Einkaufsliste für zwei Personen nach dem Vorbild Bring! – eigenes Design, Daten
verschlüsselt in einem privaten GitHub-Repo (AES-256-GCM, Argon2id; Konzept der `encrypted-todo-app`).

## Installieren

<a href="https://sebastianweberfzi.github.io/encrypted-shopping-app/"><img src="https://sebastianweberfzi.github.io/encrypted-shopping-app/qr.svg" alt="QR-Code der F-Droid-Paketquelle (Einkaufsliste)" width="180" align="right"></a>

**F-Droid (empfohlen):** Auf der [Installationsseite](https://sebastianweberfzi.github.io/encrypted-shopping-app/) den QR-Code scannen
(F-Droid → Einstellungen → Paketquellen → **+**) oder dort auf dem Handy auf „hier tippen“ –
die Paketquelle wird dann direkt in F-Droid hinzugefügt. Updates kommen danach automatisch.

**Ohne F-Droid:** APK der [neuesten Version](https://github.com/SebastianWeberFZI/encrypted-shopping-app/releases/latest)
herunterladen und installieren.

Beim ersten Start fragt die App nach dem privaten Daten-Repo, einem Fine-grained Token
(nur „Contents: Read and write“) und der Passphrase.

<br clear="right">

## Funktionen
- Mehrere Listen (Supermarkt, Drogerie, …), Farbe und Symbol je Liste
- Kachel-Ansicht: antippen = eingekauft, Rückgängig; „Zuletzt verwendet“ zum schnellen Wiederhinzufügen
- Katalog mit ~160 Artikeln in 15 Ladenbereichen (Emoji-Symbole), Sortierung nach Ladenbereich
- Suche mit Synonymen, Details per Zahl („Milch 2 l“), eigene Artikel
- Vorschläge aus dem Kaufverlauf (übliches Intervall abgelaufen)
- Benachrichtigungen, wenn die andere Person etwas hinzufügt, einkauft oder „Ich gehe einkaufen“ meldet
- Offline-First; deterministische Artikel-IDs (HMAC) verhindern Dubletten bei gleichzeitigem Hinzufügen

## Daten-Repo
```
meta.json · keycheck.enc
lists/<id>.enc      Listen
items/<hmac>.enc    Artikel je Liste (Status, Details, Verlauf)
catalog/<id>.enc    eigene Artikel
activity/<id>.enc   „Ich gehe einkaufen“-Signale (7 Tage)
```
