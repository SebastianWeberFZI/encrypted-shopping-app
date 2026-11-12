# Piktogramme

Die Einkaufsliste zeigt Artikel, Listen und Ladenbereiche mit einheitlichen Symbolen
statt mit den Emoji des jeweiligen Handys (die je nach Hersteller anders aussehen).

| Ordner | Inhalt | Lizenz |
|---|---|---|
| `fluent/` | [Fluent Emoji](https://github.com/microsoft/fluentui-emoji) von Microsoft im Stil *Flat*, unverändert. Dateiname = Codepoints ohne FE0F (`u1f34e.svg` = 🍎). | MIT, siehe `LICENSE-fluent-emoji.txt` |
| `eigene/` | Selbst gezeichnete Ergänzungen im selben Stil – für Artikel ohne passendes Emoji (Hafermilch, Himbeeren, Lachs, Zahnpasta …). Dateiname = Schlüssel (`hafermilch.svg`). | wie das Projekt; teils aus Fluent abgeleitet (MIT) |
| `werkzeug/` | `zeichnen.py` erzeugt `eigene/` aus Code, `bauen.py` rendert alles nach `assets/piktos/` und schreibt `lib/src/models/piktos.g.dart`, `vorschau.py` erstellt einen Kontaktbogen. | |

## Ein Symbol ergänzen

1. Gibt es ein passendes Emoji? `python3 piktogramme/werkzeug/bauen.py --hole 🥝` lädt es aus Fluent Emoji Flat.
2. Sonst in `werkzeug/zeichnen.py` eine Funktion mit `@icon("name")` anlegen
   (Bausteine für Flaschen, Gläser, Kartons, Tüten … sind vorhanden; Stilregeln stehen oben in der Datei)
   und `python3 piktogramme/werkzeug/zeichnen.py name` ausführen.
3. `python3 piktogramme/werkzeug/bauen.py` – rendert PNGs (128 px) und aktualisiert die Symbolliste.
4. Im Katalog (`lib/src/models/catalog.dart`) den Artikel mit `icon: 'name'` eintragen.
   Das `emoji` bleibt gesetzt: Es dient älteren App-Versionen und Benachrichtigungen.

Benötigt: `pip install cairosvg pillow`.

## Welches Symbol ein Artikel bekommt

1. ein in der App gewähltes Symbol (Artikel lange drücken → Symbol antippen),
2. das Symbol des gleichnamigen Katalogartikels,
3. das Fluent-Emoji zum gespeicherten Emoji,
4. sonst das Emoji als Text.

Die Daten im Repo ändern sich dadurch nicht; ein gewähltes Symbol steht zusätzlich im Feld `icon`.
