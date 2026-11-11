/// Standard-Artikelkatalog (eigenes Design mit Emoji-Symbolen).
library;

class Category {
  const Category(this.key, this.name, this.emoji);
  final String key;
  final String name;
  final String emoji;
}

class CatalogItem {
  const CatalogItem(this.name, this.emoji, this.category, [this.aliases = const []]);
  final String name;
  final String emoji;
  final String category;
  final List<String> aliases;
}

/// Reihenfolge = typischer Weg durch den Supermarkt.
const List<Category> kCategories = [
  Category('obst', 'Obst & Gemüse', '🥦'),
  Category('brot', 'Brot & Gebäck', '🥖'),
  Category('milch', 'Milch, Käse & Eier', '🧀'),
  Category('fleisch', 'Fleisch, Fisch & Tofu', '🥩'),
  Category('vorrat', 'Nudeln, Reis & Vorrat', '🍝'),
  Category('zutaten', 'Zutaten & Gewürze', '🧂'),
  Category('fruehstueck', 'Frühstück & Aufstriche', '🍯'),
  Category('tk', 'Tiefkühl & Fertiggerichte', '🧊'),
  Category('snacks', 'Snacks & Süßes', '🍫'),
  Category('getraenke', 'Getränke', '🥤'),
  Category('haushalt', 'Haushalt', '🧽'),
  Category('drogerie', 'Pflege & Drogerie', '🧴'),
  Category('tier', 'Tierbedarf', '🐾'),
  Category('baumarkt', 'Baumarkt & Garten', '🪴'),
  Category('sonstiges', 'Sonstiges', '🛍️'),
];

Category categoryByKey(String key) =>
    kCategories.firstWhere((c) => c.key == key, orElse: () => kCategories.last);

String normalizeName(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

CatalogItem? catalogLookup(String name) {
  final n = normalizeName(name);
  for (final c in kCatalog) {
    if (normalizeName(c.name) == n) return c;
  }
  return null;
}

/// Suche über Namen und Synonyme; Treffer am Wortanfang zuerst.
List<CatalogItem> catalogSearch(String query) {
  final q = normalizeName(query);
  if (q.isEmpty) return const [];
  final starts = <CatalogItem>[], contains = <CatalogItem>[];
  for (final c in kCatalog) {
    final names = [c.name, ...c.aliases].map(normalizeName);
    if (names.any((n) => n.startsWith(q))) {
      starts.add(c);
    } else if (names.any((n) => n.contains(q))) {
      contains.add(c);
    }
  }
  return [...starts, ...contains];
}

/// Rät die Kategorie eines eigenen Artikels anhand ähnlicher Katalogeinträge.
String guessCategory(String name) {
  final hits = catalogSearch(name.split(' ').first);
  return hits.isEmpty ? 'sonstiges' : hits.first.category;
}

const List<CatalogItem> kCatalog = [
  // Obst & Gemüse
  CatalogItem('Äpfel', '🍎', 'obst', ['apfel']),
  CatalogItem('Bananen', '🍌', 'obst', ['banane']),
  CatalogItem('Birnen', '🍐', 'obst'),
  CatalogItem('Orangen', '🍊', 'obst', ['apfelsinen']),
  CatalogItem('Mandarinen', '🍊', 'obst', ['clementinen']),
  CatalogItem('Zitronen', '🍋', 'obst'),
  CatalogItem('Limetten', '🍋', 'obst'),
  CatalogItem('Trauben', '🍇', 'obst', ['weintrauben']),
  CatalogItem('Erdbeeren', '🍓', 'obst'),
  CatalogItem('Heidelbeeren', '🫐', 'obst', ['blaubeeren']),
  CatalogItem('Himbeeren', '🍓', 'obst'),
  CatalogItem('Kiwis', '🥝', 'obst'),
  CatalogItem('Mango', '🥭', 'obst'),
  CatalogItem('Ananas', '🍍', 'obst'),
  CatalogItem('Wassermelone', '🍉', 'obst', ['melone']),
  CatalogItem('Avocado', '🥑', 'obst'),
  CatalogItem('Tomaten', '🍅', 'obst'),
  CatalogItem('Cherrytomaten', '🍅', 'obst'),
  CatalogItem('Gurke', '🥒', 'obst'),
  CatalogItem('Paprika', '🫑', 'obst'),
  CatalogItem('Karotten', '🥕', 'obst', ['möhren']),
  CatalogItem('Kartoffeln', '🥔', 'obst'),
  CatalogItem('Süßkartoffeln', '🍠', 'obst'),
  CatalogItem('Zwiebeln', '🧅', 'obst'),
  CatalogItem('Rote Zwiebeln', '🧅', 'obst'),
  CatalogItem('Knoblauch', '🧄', 'obst'),
  CatalogItem('Ingwer', '🫚', 'obst'),
  CatalogItem('Brokkoli', '🥦', 'obst'),
  CatalogItem('Blumenkohl', '🥦', 'obst'),
  CatalogItem('Zucchini', '🥒', 'obst'),
  CatalogItem('Aubergine', '🍆', 'obst'),
  CatalogItem('Salat', '🥬', 'obst', ['kopfsalat', 'eisberg']),
  CatalogItem('Rucola', '🥬', 'obst'),
  CatalogItem('Spinat', '🥬', 'obst'),
  CatalogItem('Champignons', '🍄', 'obst', ['pilze']),
  CatalogItem('Mais', '🌽', 'obst'),
  CatalogItem('Frühlingszwiebeln', '🌱', 'obst'),
  CatalogItem('Lauch', '🥬', 'obst', ['porree']),
  CatalogItem('Chili', '🌶️', 'obst'),
  CatalogItem('Basilikum', '🌿', 'obst', ['kräuter']),
  CatalogItem('Petersilie', '🌿', 'obst'),
  CatalogItem('Radieschen', '🌱', 'obst'),
  // Brot & Gebäck
  CatalogItem('Brot', '🍞', 'brot'),
  CatalogItem('Brötchen', '🥯', 'brot', ['semmeln', 'wecken']),
  CatalogItem('Baguette', '🥖', 'brot'),
  CatalogItem('Toastbrot', '🍞', 'brot', ['toast']),
  CatalogItem('Croissants', '🥐', 'brot'),
  CatalogItem('Brezeln', '🥨', 'brot', ['laugenbrezel']),
  CatalogItem('Knäckebrot', '🍘', 'brot'),
  CatalogItem('Wraps', '🫓', 'brot', ['tortillas']),
  CatalogItem('Kuchen', '🍰', 'brot'),
  // Milch, Käse & Eier
  CatalogItem('Milch', '🥛', 'milch'),
  CatalogItem('Hafermilch', '🥛', 'milch', ['haferdrink', 'pflanzenmilch']),
  CatalogItem('Butter', '🧈', 'milch'),
  CatalogItem('Joghurt', '🥣', 'milch'),
  CatalogItem('Quark', '🥣', 'milch'),
  CatalogItem('Sahne', '🥛', 'milch'),
  CatalogItem('Schmand', '🥣', 'milch', ['saure sahne', 'crème fraîche']),
  CatalogItem('Frischkäse', '🧀', 'milch'),
  CatalogItem('Käse', '🧀', 'milch', ['gouda', 'emmentaler']),
  CatalogItem('Mozzarella', '🧀', 'milch'),
  CatalogItem('Parmesan', '🧀', 'milch'),
  CatalogItem('Feta', '🧀', 'milch', ['schafskäse']),
  CatalogItem('Eier', '🥚', 'milch'),
  // Fleisch, Fisch & Tofu
  CatalogItem('Hähnchen', '🍗', 'fleisch', ['hühnchen', 'geflügel']),
  CatalogItem('Hackfleisch', '🥩', 'fleisch', ['hack']),
  CatalogItem('Steak', '🥩', 'fleisch'),
  CatalogItem('Würstchen', '🌭', 'fleisch', ['wurst']),
  CatalogItem('Aufschnitt', '🥓', 'fleisch', ['salami']),
  CatalogItem('Schinken', '🥓', 'fleisch'),
  CatalogItem('Lachs', '🐟', 'fleisch'),
  CatalogItem('Fisch', '🐟', 'fleisch'),
  CatalogItem('Garnelen', '🦐', 'fleisch', ['shrimps']),
  CatalogItem('Tofu', '🍱', 'fleisch'),
  // Vorrat
  CatalogItem('Nudeln', '🍝', 'vorrat', ['pasta']),
  CatalogItem('Spaghetti', '🍝', 'vorrat'),
  CatalogItem('Reis', '🍚', 'vorrat'),
  CatalogItem('Couscous', '🍚', 'vorrat', ['bulgur']),
  CatalogItem('Linsen', '🫘', 'vorrat'),
  CatalogItem('Kichererbsen', '🫘', 'vorrat'),
  CatalogItem('Bohnen', '🫘', 'vorrat', ['kidneybohnen']),
  CatalogItem('Dosentomaten', '🥫', 'vorrat', ['passierte tomaten', 'tomatendose']),
  CatalogItem('Kokosmilch', '🥥', 'vorrat'),
  CatalogItem('Haferflocken', '🥣', 'vorrat'),
  CatalogItem('Müsli', '🥣', 'vorrat'),
  CatalogItem('Nüsse', '🥜', 'vorrat', ['walnüsse', 'cashews']),
  // Zutaten & Gewürze
  CatalogItem('Mehl', '🌾', 'zutaten'),
  CatalogItem('Zucker', '🍬', 'zutaten'),
  CatalogItem('Salz', '🧂', 'zutaten'),
  CatalogItem('Pfeffer', '🧂', 'zutaten'),
  CatalogItem('Olivenöl', '🫒', 'zutaten', ['öl']),
  CatalogItem('Essig', '🍶', 'zutaten', ['balsamico']),
  CatalogItem('Hefe', '🍞', 'zutaten'),
  CatalogItem('Backpulver', '🧁', 'zutaten'),
  CatalogItem('Senf', '🌭', 'zutaten'),
  CatalogItem('Ketchup', '🍅', 'zutaten'),
  CatalogItem('Mayonnaise', '🥚', 'zutaten', ['mayo']),
  CatalogItem('Gemüsebrühe', '🍲', 'zutaten', ['brühe']),
  CatalogItem('Tomatenmark', '🍅', 'zutaten'),
  CatalogItem('Sojasauce', '🍶', 'zutaten'),
  CatalogItem('Gewürze', '🌶️', 'zutaten', ['paprikapulver', 'curry', 'zimt']),
  // Frühstück
  CatalogItem('Marmelade', '🍓', 'fruehstueck', ['konfitüre']),
  CatalogItem('Honig', '🍯', 'fruehstueck'),
  CatalogItem('Nussnougatcreme', '🍫', 'fruehstueck', ['nutella']),
  CatalogItem('Erdnussbutter', '🥜', 'fruehstueck'),
  CatalogItem('Kaffee', '☕', 'fruehstueck', ['kaffeebohnen']),
  CatalogItem('Tee', '🍵', 'fruehstueck'),
  // Tiefkühl
  CatalogItem('Pizza', '🍕', 'tk', ['tiefkühlpizza']),
  CatalogItem('Pommes', '🍟', 'tk'),
  CatalogItem('Eis', '🍨', 'tk', ['eiscreme']),
  CatalogItem('TK-Gemüse', '🥦', 'tk', ['erbsen', 'rahmspinat']),
  CatalogItem('Fischstäbchen', '🐟', 'tk'),
  CatalogItem('Maultaschen', '🥟', 'tk'),
  // Snacks
  CatalogItem('Chips', '🥔', 'snacks'),
  CatalogItem('Schokolade', '🍫', 'snacks'),
  CatalogItem('Kekse', '🍪', 'snacks'),
  CatalogItem('Gummibärchen', '🐻', 'snacks', ['fruchtgummi']),
  CatalogItem('Popcorn', '🍿', 'snacks'),
  CatalogItem('Salzstangen', '🥨', 'snacks'),
  // Getränke
  CatalogItem('Wasser', '💧', 'getraenke', ['mineralwasser', 'sprudel']),
  CatalogItem('Saft', '🧃', 'getraenke', ['orangensaft', 'apfelsaft']),
  CatalogItem('Cola', '🥤', 'getraenke'),
  CatalogItem('Limonade', '🥤', 'getraenke', ['limo']),
  CatalogItem('Bier', '🍺', 'getraenke'),
  CatalogItem('Wein', '🍷', 'getraenke', ['rotwein', 'weißwein']),
  CatalogItem('Sekt', '🍾', 'getraenke', ['prosecco']),
  // Haushalt
  CatalogItem('Spülmittel', '🧽', 'haushalt'),
  CatalogItem('Spülmaschinentabs', '🫧', 'haushalt', ['tabs']),
  CatalogItem('Waschmittel', '🧺', 'haushalt'),
  CatalogItem('Müllbeutel', '🗑️', 'haushalt'),
  CatalogItem('Küchenrolle', '🧻', 'haushalt'),
  CatalogItem('Toilettenpapier', '🧻', 'haushalt', ['klopapier']),
  CatalogItem('Taschentücher', '🤧', 'haushalt'),
  CatalogItem('Alufolie', '📜', 'haushalt'),
  CatalogItem('Backpapier', '📜', 'haushalt'),
  CatalogItem('Schwämme', '🧽', 'haushalt'),
  CatalogItem('Allzweckreiniger', '🧴', 'haushalt', ['putzmittel']),
  CatalogItem('Batterien', '🔋', 'haushalt'),
  CatalogItem('Glühbirne', '💡', 'haushalt', ['leuchtmittel']),
  CatalogItem('Kerzen', '🕯️', 'haushalt', ['teelichter']),
  // Drogerie
  CatalogItem('Shampoo', '🧴', 'drogerie'),
  CatalogItem('Duschgel', '🧴', 'drogerie'),
  CatalogItem('Seife', '🧼', 'drogerie'),
  CatalogItem('Zahnpasta', '🪥', 'drogerie', ['zahncreme']),
  CatalogItem('Zahnbürste', '🪥', 'drogerie'),
  CatalogItem('Deo', '🧴', 'drogerie'),
  CatalogItem('Sonnencreme', '🧴', 'drogerie'),
  CatalogItem('Rasierer', '🪒', 'drogerie'),
  CatalogItem('Wattepads', '☁️', 'drogerie'),
  CatalogItem('Pflaster', '🩹', 'drogerie'),
  CatalogItem('Schmerztabletten', '💊', 'drogerie', ['ibuprofen', 'paracetamol']),
  CatalogItem('Hygieneartikel', '🌸', 'drogerie', ['tampons', 'binden']),
  // Tierbedarf
  CatalogItem('Katzenfutter', '🐱', 'tier'),
  CatalogItem('Hundefutter', '🐶', 'tier'),
  CatalogItem('Katzenstreu', '🐈', 'tier'),
  // Baumarkt & Garten
  CatalogItem('Blumenerde', '🪴', 'baumarkt'),
  CatalogItem('Pflanzen', '🌱', 'baumarkt', ['blumen']),
  CatalogItem('Schrauben', '🔩', 'baumarkt', ['dübel']),
  CatalogItem('Klebeband', '🩹', 'baumarkt'),
  CatalogItem('Werkzeug', '🔧', 'baumarkt'),
];
