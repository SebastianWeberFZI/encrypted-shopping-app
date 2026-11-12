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
- Katalog mit rund 190 Artikeln in 15 Ladenbereichen, Sortierung nach Ladenbereich
- Einheitliche **Piktogramme** auf allen Handys und im Widget: [Fluent Emoji](https://github.com/microsoft/fluentui-emoji) (Microsoft, MIT) im Stil *Flat*, ergänzt um eigene Symbole im selben Stil (`piktogramme/`); Symbol je Artikel änderbar (lange drücken)
- Suche mit Synonymen, Details per Zahl („Milch 2 l“), eigene Artikel
- **Rezepte übernehmen** über *Teilen*: Rezeptlink aus Chefkoch, Lecker, Kitchen Stories, EAT SMARTER u. a. (alle Seiten mit schema.org-Rezeptdaten) oder eine Zutatenliste als Text → Zutaten prüfen, Portionen anpassen, auf eine Liste setzen
- **Rezepte-Reiter**: Rezepte samt Zutaten, Zubereitung, Bild (verkleinert), Portionen, Zeiten, Kategorie, Kalorien und Quelle speichern – beim Teilen, per eingefügtem Link oder als eigenes Rezept (Kochbuch, Familienrezept). **Fotos** anhängen – z. B. die Kochbuchseite statt abzutippen, oder das fertige Gericht als Titelbild; im Vollbild lesbar (zoomen, doppelt tippen). Portionen umrechnen, Zutaten mit einem Tipp wieder auf die Liste, bearbeiten, löschen; beide sehen dieselben Rezepte
- Vorschläge aus dem Kaufverlauf (übliches Intervall abgelaufen)
- Benachrichtigungen, wenn die andere Person etwas hinzufügt, einkauft oder „Ich gehe einkaufen“ meldet
- Startbildschirm-**Widget**: zeigt die offenen Artikel einer Liste (je Widget wählbar), antippen hakt ab – ohne die App zu öffnen; auf Geräten, die Sperrbildschirm-Widgets können, auch dort
- **Liste auf dem Sperrbildschirm** (Einstellungen → Benachrichtigungen): angeheftete, lautlose Benachrichtigung mit den offenen Artikeln der aktuellen Liste – antippen hakt ab, ohne zu entsperren
- Offline-First; deterministische Artikel-IDs (HMAC) verhindern Dubletten bei gleichzeitigem Hinzufügen

## Daten-Repo
```
meta.json · keycheck.enc
lists/<id>.enc      Listen
items/<hmac>.enc    Artikel je Liste (Status, Details, Verlauf)
catalog/<id>.enc    eigene Artikel
activity/<id>.enc   „Ich gehe einkaufen“-Signale (7 Tage)
recipes/<id>.enc    gespeicherte Rezepte (inkl. Vorschaubild als JPEG, ≤ 640 px)
photos/<id>.enc     Rezeptfotos (JPEG ≤ 1800 px, ohne Metadaten; erst beim Anzeigen geladen)
```

## Kompatibilität zwischen App-Versionen
Beide Handys müssen nicht gleichzeitig aktualisiert werden:
- Ältere und neuere Dokumente werden tolerant gelesen – fehlende Felder bekommen Standardwerte, falsche Typen oder unbekannte Werte bringen die App nicht zum Absturz.
- Felder, die eine App-Version nicht kennt, bleiben beim Speichern unverändert erhalten (eine ältere App beschneidet die Daten einer neueren nicht).
- Dokumente in einem neueren Verschlüsselungsformat werden weder gelesen noch überschrieben; die App bittet dann um ein Update.
- Erhöht eine neuere App die Datenformat-Generation (`schema` in `meta.json`), pausieren ältere Apps den Abgleich, behalten ihre lokalen Änderungen und bitten um ein Update.
- Unlesbare oder beschädigte Dateien werden übersprungen und nicht bei jedem Abgleich neu geladen.
