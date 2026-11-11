# Einkaufsliste (verschlüsselt, GitHub-Backend)

Gemeinsame Einkaufsliste für zwei Personen nach dem Vorbild Bring! – eigenes Design, Daten
verschlüsselt in einem privaten GitHub-Repo (AES-256-GCM, Argon2id; Konzept der `encrypted-todo-app`).

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
