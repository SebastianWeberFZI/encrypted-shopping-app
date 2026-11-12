import 'dart:convert';

import 'catalog.dart';

/// Eine Zutat aus einem Rezept oder geteilten Text.
class Zutat {
  Zutat({
    required this.original,
    required this.name,
    this.menge,
    this.einheit = '',
    this.zusatz = '',
    this.vorrat = false,
    this.katalog,
  });

  /// Zeile, wie sie im Rezept steht.
  final String original;

  /// Artikelname für die Liste (Katalogname, wenn erkannt).
  final String name;
  final double? menge;

  /// Einheit in Kurzform (g, ml, EL, Dose …), leer bei Stückzahlen.
  final String einheit;

  /// Größenangabe ohne Einheit, z. B. „große“ bei „3 große Eier“.
  final String zusatz;

  /// Kleinmenge oder Grundvorrat (Prise Salz, etwas Öl) – standardmäßig abgewählt.
  final bool vorrat;
  final CatalogItem? katalog;

  /// Mengenangabe für die Liste, skaliert mit [faktor] (Portionen).
  String spec([double faktor = 1]) {
    final m = menge;
    if (m == null) return '';
    var wert = m * faktor;
    var e = einheit;
    // Ganze Dinge kauft man ganz: 1,5 Paprika → 2
    if (_stueckig.contains(e) && wert > 0.5) {
      final unten = wert.floorToDouble();
      wert = (wert - unten) < 0.05 ? unten : wert.ceilToDouble();
    }
    if (e == 'g' && wert >= 1000) {
      wert /= 1000;
      e = 'kg';
    } else if (e == 'ml' && wert >= 1000) {
      wert /= 1000;
      e = 'l';
    }
    final zahl = formatMenge(wert, e);
    if (e.isEmpty) return zusatz.isEmpty ? '$zahl Stück' : '$zahl $zusatz';
    return '$zahl ${_plural(e, wert)}';
  }
}

/// Ein Rezept mit Zutaten.
class Rezept {
  Rezept({required this.titel, required this.zutaten, this.portionen, this.quelle});
  final String titel;
  final List<Zutat> zutaten;
  final int? portionen;
  final Uri? quelle;
}

/// Zahl ohne überflüssige Nachkommastellen, mit Komma; große Gramm-/ml-Werte gerundet.
String formatMenge(double v, [String einheit = '']) {
  if ((einheit == 'g' || einheit == 'ml') && v >= 100) v = (v / 10).round() * 10.0;
  final halbe = (v * 2).round() / 2;
  final r = (einheit.isEmpty && (v - halbe).abs() < 0.13) ? halbe : (v * 10).round() / 10;
  final s = r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  return s.replaceAll('.', ',');
}

// ------------------------------------------------------------- Einheiten

const Map<String, String> _einheiten = {
  'g': 'g', 'gramm': 'g', 'kg': 'kg', 'kilogramm': 'kg', 'kilo': 'kg', 'mg': 'mg',
  'ml': 'ml', 'milliliter': 'ml', 'cl': 'cl', 'dl': 'dl', 'l': 'l', 'liter': 'l', 'ltr': 'l',
  'el': 'EL', 'esslöffel': 'EL', 'tl': 'TL', 'teelöffel': 'TL',
  'msp': 'Msp.', 'messerspitze': 'Msp.', 'prise': 'Prise', 'prisen': 'Prise',
  'pck': 'Pck.', 'päckchen': 'Pck.', 'packung': 'Packung', 'packungen': 'Packung', 'pkg': 'Packung',
  'dose': 'Dose', 'dosen': 'Dose', 'becher': 'Becher', 'bund': 'Bund', 'zehe': 'Zehe', 'zehen': 'Zehe',
  'stück': 'Stück', 'stk': 'Stück', 'stck': 'Stück', 'scheibe': 'Scheibe', 'scheiben': 'Scheibe',
  'tasse': 'Tasse', 'tassen': 'Tasse', 'glas': 'Glas', 'gläser': 'Glas', 'flasche': 'Flasche',
  'flaschen': 'Flasche', 'beutel': 'Beutel', 'tüte': 'Tüte', 'tüten': 'Tüte', 'spritzer': 'Spritzer',
  'schuss': 'Schuss', 'handvoll': 'Handvoll', 'würfel': 'Würfel', 'blatt': 'Blatt', 'blätter': 'Blatt',
  'stange': 'Stange', 'stangen': 'Stange', 'zweig': 'Zweig', 'zweige': 'Zweig', 'kopf': 'Kopf',
  'köpfe': 'Kopf', 'knolle': 'Knolle', 'knollen': 'Knolle', 'tropfen': 'Tropfen', 'rolle': 'Rolle',
  'rollen': 'Rolle', 'netz': 'Netz', 'schale': 'Schale', 'schalen': 'Schale', 'paket': 'Packung',
};

const Map<String, String> _mehrzahl = {
  'Dose': 'Dosen', 'Zehe': 'Zehen', 'Scheibe': 'Scheiben', 'Prise': 'Prisen', 'Tasse': 'Tassen',
  'Flasche': 'Flaschen', 'Stange': 'Stangen', 'Glas': 'Gläser', 'Blatt': 'Blätter', 'Zweig': 'Zweige',
  'Knolle': 'Knollen', 'Kopf': 'Köpfe', 'Tüte': 'Tüten', 'Packung': 'Packungen', 'Rolle': 'Rollen',
  'Schale': 'Schalen',
};

String _plural(String einheit, double wert) => wert > 1 ? (_mehrzahl[einheit] ?? einheit) : einheit;

/// Einheiten, die man nur ganz kaufen kann.
const _stueckig = {
  '', 'Stück', 'Zehe', 'Dose', 'Bund', 'Becher', 'Packung', 'Pck.', 'Glas', 'Flasche', 'Stange',
  'Knolle', 'Kopf', 'Beutel', 'Tüte', 'Rolle', 'Netz', 'Schale',
};

/// Kleinmengen: werden meist nicht extra gekauft.
const _kleinmengen = {'Prise', 'Msp.', 'Spritzer', 'Tropfen', 'Schuss'};

/// Grundvorrat: standardmäßig abgewählt (kann man in der Vorschau wieder anhaken).
const _grundvorrat = {'salz', 'pfeffer', 'wasser'};

const _groessen = {
  'gr', 'groß', 'große', 'großer', 'großes', 'großen', 'kl', 'klein', 'kleine', 'kleiner',
  'kleines', 'kleinen', 'mittelgroß', 'mittelgroße', 'mittelgroßer', 'mittelgroßes', 'mittlere',
  'mittlerer', 'mittleres', 'reife', 'reifer', 'frische', 'frischer', 'frisches', 'ganze',
};

const _vorsatz = {'etwas', 'evtl', 'eventuell', 'ggf', 'einige', 'wenig', 'n.b', 'nb'};

/// Anhängsel, die eine Zutat nur näher beschreiben (Knoblauchzehe → Knoblauch).
const _formen = {
  'zehe', 'zehen', 'schote', 'schoten', 'flöckchen', 'stück', 'stücke', 'stückchen', 'würfel',
  'scheibe', 'scheiben', 'streifen', 'filet', 'filets', 'blätter', 'blatt', 'ringe', 'röschen',
};

// ------------------------------------------------------------- Zerlegen

final _bruch = {'½': 0.5, '¼': 0.25, '¾': 0.75, '⅓': 1 / 3, '⅔': 2 / 3, '⅛': 0.125};
final _mengeRe = RegExp(
    r'^(\d+\s*/\s*\d+|\d+(?:[.,]\d+)?(?:\s*[½¼¾⅓⅔⅛])?|[½¼¾⅓⅔⅛])(?:\s*(?:-|–|bis)\s*(\d+(?:[.,]\d+)?|[½¼¾⅓⅔⅛]))?\s*');

double? _zahl(String s) {
  s = s.trim();
  if (_bruch.containsKey(s)) return _bruch[s];
  final mixed = RegExp(r'^(\d+)\s*([½¼¾⅓⅔⅛])$').firstMatch(s);
  if (mixed != null) return int.parse(mixed.group(1)!) + _bruch[mixed.group(2)]!;
  final frac = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(s);
  if (frac != null) {
    final d = int.parse(frac.group(2)!);
    return d == 0 ? null : int.parse(frac.group(1)!) / d;
  }
  return double.tryParse(s.replaceAll(',', '.'));
}

/// Häufige HTML-Entitäten in Rezeptdaten.
String htmlText(String s) => s
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)))
    .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&frac12;', '½')
    .replaceAll('&frac14;', '¼')
    .replaceAll('&frac34;', '¾')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Zerlegt eine Zutatenzeile („2 Zehe/n Knoblauch“, „Salz und Pfeffer“).
List<Zutat> parseZutat(String zeile) {
  final original = htmlText(zeile).replaceFirst(RegExp(r'^[-•*·☐✓▢\s]+'), '').trim();
  // Zwischenüberschriften wie „Für den Teig:“
  if (original.isEmpty || original.endsWith(':')) return const [];
  var s = original;
  var vorrat = false;
  // Pluralmarker entfernen: Zwiebel(n), Ei(er), Zehe/n → Grundform
  s = s.replaceAllMapped(RegExp(r'(\w)(?:\((?:n|en|er|e|s|nen)\)|/(?:n|en|e|s))(?=\W|$)'), (m) => m.group(1)!);
  // Anmerkungen in Klammern
  final notes = RegExp(r'\(([^)]*)\)').allMatches(s).map((m) => m.group(1)!.toLowerCase()).toList();
  if (notes.any((n) => n.contains('nach bedarf') || n.contains('nach belieben') || n.contains('optional'))) {
    vorrat = true;
  }
  s = s.replaceAll(RegExp(r'\([^)]*\)'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  var words = s.split(' ');
  String low(String w) => w.toLowerCase().replaceAll(RegExp(r'[.,:;]+$'), '');
  // Vorsätze: etwas, evtl., n. B.
  while (words.isNotEmpty) {
    final w = low(words.first);
    if (w == 'n' && words.length > 1 && low(words[1]) == 'b') {
      words = words.sublist(2);
      vorrat = true;
    } else if (_vorsatz.contains(w)) {
      words = words.sublist(1);
      vorrat = true;
    } else if (w == 'ca' || w == 'etwa' || w == 'circa' || w == 'je') {
      words = words.sublist(1);
    } else {
      break;
    }
  }
  s = words.join(' ');

  double? menge;
  final mm = _mengeRe.firstMatch(s);
  if (mm != null) {
    final a = _zahl(mm.group(1)!), b = mm.group(2) == null ? null : _zahl(mm.group(2)!);
    menge = b ?? a; // bei „1–2“ lieber genug kaufen
    s = s.substring(mm.end);
  }
  words = s.split(' ').where((w) => w.isNotEmpty).toList();

  var zusatz = '';
  var einheit = '';
  for (var guard = 0; guard < 4 && words.isNotEmpty; guard++) {
    final w = low(words.first);
    if (_groessen.contains(w)) {
      if (einheit.isEmpty && zusatz.isEmpty && w != 'gr' && w != 'kl') zusatz = words.first.replaceAll(',', '');
      words = words.sublist(1);
      continue;
    }
    if (einheit.isEmpty && _einheiten.containsKey(w) && words.length > 1) {
      einheit = _einheiten[w]!;
      words = words.sublist(1);
      // „1 TL, gehäuft Paprikapulver“
      while (words.isNotEmpty && {'gehäuft', 'gestrichen', 'gehäufter', 'gestrichener'}.contains(low(words.first))) {
        words = words.sublist(1);
      }
      continue;
    }
    break;
  }
  if (_kleinmengen.contains(einheit)) vorrat = true;

  var name = words.join(' ').replaceFirst(RegExp(r'^[,\s]+'), '');
  // „Tomaten, stückige“ / „Öl zum Braten“ / „Mineralwasser mit Kohlensäure“
  name = name.split(',').first;
  name = name.split(RegExp(r'\s+(?:zum|zur|für|fürs|mit|ohne|oder|als|nach|vom|von|aus|in)\s+', caseSensitive: false)).first;
  name = name.replaceAll(RegExp(r'[.:;]+$'), '').trim();
  if (name.isEmpty) return const [];

  // „Salz und Pfeffer“ → zwei Artikel, wenn beide bekannt sind
  final teile = name.split(RegExp(r'\s+(?:und|&)\s+'));
  if (teile.length > 1 && teile.every((t) => matchCatalog(t) != null)) {
    return [
      for (final t in teile)
        Zutat(original: original, name: matchCatalog(t)!.name, vorrat: true, katalog: matchCatalog(t)),
    ];
  }

  final treffer = _match(name, einheit: einheit);
  final kat = treffer?.$1;
  final ziel = kat == null ? _gross(name) : (treffer!.$2 ?? kat.name);
  // „2 Knoblauchzehen“ → 2 Zehen
  if (einheit.isEmpty && menge != null) {
    final n = normalizeName(name);
    for (final e in const {'zehe': 'Zehe', 'scheibe': 'Scheibe', 'stange': 'Stange'}.entries) {
      if (n.endsWith(e.key) || n.endsWith('${e.key}n')) einheit = e.value;
    }
  }
  if (_grundvorrat.contains(normalizeName(ziel))) vorrat = true;
  return [
    Zutat(
      original: original,
      name: ziel,
      menge: menge,
      einheit: einheit,
      zusatz: zusatz,
      vorrat: vorrat,
      katalog: kat,
    ),
  ];
}

String _gross(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Ordnet einen Zutatennamen einem Katalogartikel zu (null = eigener Artikel).
CatalogItem? matchCatalog(String name, {String einheit = ''}) => _match(name, einheit: einheit)?.$1;

/// Treffer und der Name für die Liste: bei Synonymen bleibt der genauere Name
/// („Paprikapulver“ statt „Gewürze“, „Petersilie“ statt „Kräuter“), sonst null
/// für den Katalognamen.
(CatalogItem, String?)? _match(String name, {String einheit = ''}) {
  final n = normalizeName(name);
  if (n.length < 2) return null;
  final formen = {n, '${n}n', '${n}en', '${n}er', '${n}e', '${n}s', if (n.endsWith('n')) n.substring(0, n.length - 1)};
  if (einheit == 'Dose' && n.startsWith('tomate')) return (catalogLookup('Dosentomaten')!, null);
  for (final c in kCatalog) {
    if (formen.contains(normalizeName(c.name))) return (c, null);
  }
  for (final c in kCatalog) {
    for (final a in c.aliases) {
      if (formen.contains(normalizeName(a))) return (c, _gross(a));
    }
  }
  // Zusammensetzungen: das Grundwort steht hinten (Rinderhackfleisch → Hackfleisch) …
  CatalogItem? best;
  var bestLen = 0;
  var bestAlias = false;
  for (final c in kCatalog) {
    final names = [c.name, ...c.aliases].map(normalizeName).toList();
    for (var k = 0; k < names.length; k++) {
      final a = names[k];
      if (a.length >= 4 && a.length > bestLen && !a.contains(' ') && formen.any((f) => f.endsWith(a))) {
        best = c;
        bestLen = a.length;
        bestAlias = k > 0;
      }
    }
  }
  if (best != null) return (best, bestAlias ? _gross(name) : null);
  // … oder eine Form hängt hinten dran (Knoblauchzehe → Knoblauch, Butterflöckchen → Butter)
  for (final c in kCatalog) {
    for (final a in [c.name, ...c.aliases].map(normalizeName)) {
      if (a.length >= 3 && n.startsWith(a) && _formen.contains(n.substring(a.length))) return (c, null);
    }
  }
  return null;
}

/// Zutaten aus frei geteiltem Text (eine pro Zeile oder durch Kommas getrennt).
List<Zutat> zutatenAusText(String text) {
  var zeilen = text.split(RegExp(r'[\r\n]+')).map((z) => z.trim()).where((z) => z.isNotEmpty).toList();
  if (zeilen.length == 1 && zeilen.first.contains(',')) {
    zeilen = zeilen.first.split(',').map((z) => z.trim()).where((z) => z.isNotEmpty).toList();
  }
  return [
    for (var z in zeilen)
      if (!RegExp(r'^https?://').hasMatch(z))
        // „Einkauf fürs Wochenende: Zucchini“ → Zucchini
        ...parseZutat(z.contains(':') && !z.trim().endsWith(':') ? z.substring(z.lastIndexOf(':') + 1) : z),
  ];
}

// ------------------------------------------------------------- JSON-LD

/// Erste http(s)-Adresse in einem geteilten Text.
Uri? ersteAdresse(String text) {
  final m = RegExp(r'https?://[^\s<>"]+').firstMatch(text);
  if (m == null) return null;
  final raw = m.group(0)!.replaceFirst(RegExp(r'[.,;:!?)\]]+$'), '');
  final u = Uri.tryParse(raw);
  return (u != null && u.host.isNotEmpty) ? u : null;
}

/// Liest ein Rezept aus den schema.org-Daten (JSON-LD) einer Webseite –
/// so machen es auch Chefkoch, Lecker, Kitchen Stories, EAT SMARTER u. v. m.
Rezept? rezeptAusHtml(String html, {Uri? quelle}) {
  final scripts = RegExp(r'<script[^>]*application/ld\+json[^>]*>(.*?)</script>', dotAll: true, caseSensitive: false);
  for (final m in scripts.allMatches(html)) {
    final raw = m.group(1)!.trim();
    Object? json;
    try {
      json = jsonDecode(raw);
    } catch (_) {
      try {
        json = jsonDecode(raw.replaceAll(RegExp(r'[\u0000-\u001F]+'), ' '));
      } catch (_) {
        continue;
      }
    }
    final r = _findeRezept(json, 0);
    if (r == null) continue;
    final zutatenRoh = r['recipeIngredient'] ?? r['ingredients'];
    final zeilen = zutatenRoh is List
        ? [for (final z in zutatenRoh) if (z is String) z]
        : zutatenRoh is String
            ? zutatenRoh.split(RegExp(r'\n|,\s(?=\d)'))
            : <String>[];
    if (zeilen.isEmpty) continue;
    var titel = htmlText(r['name'] is String ? r['name'] as String : 'Rezept');
    if (quelle != null && quelle.host.contains('chefkoch')) {
      titel = titel.replaceFirst(RegExp(r'\s+von\s+\S+$'), '');
    }
    return Rezept(
      titel: titel,
      zutaten: [for (final z in zeilen) ...parseZutat(z)],
      portionen: _portionen(r['recipeYield']),
      quelle: quelle,
    );
  }
  return null;
}

Map<String, dynamic>? _findeRezept(Object? j, int tiefe) {
  if (tiefe > 6 || j == null) return null;
  if (j is List) {
    for (final e in j) {
      final r = _findeRezept(e, tiefe + 1);
      if (r != null) return r;
    }
    return null;
  }
  if (j is Map) {
    final t = j['@type'];
    if (t == 'Recipe' || (t is List && t.contains('Recipe'))) return j.cast<String, dynamic>();
    for (final v in j.values) {
      if (v is Map || v is List) {
        final r = _findeRezept(v, tiefe + 1);
        if (r != null) return r;
      }
    }
  }
  return null;
}

int? _portionen(Object? y) {
  if (y is num) return y.toInt() > 0 ? y.toInt() : null;
  if (y is List) {
    for (final e in y) {
      final p = _portionen(e);
      if (p != null) return p;
    }
    return null;
  }
  if (y is String) {
    final m = RegExp(r'\d+').firstMatch(y);
    final v = m == null ? null : int.tryParse(m.group(0)!);
    return (v != null && v > 0 && v < 100) ? v : null;
  }
  return null;
}
