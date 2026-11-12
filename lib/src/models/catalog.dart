/// Standard-Artikelkatalog (eigenes Design mit Emoji-Symbolen).
library;

class Category {
  const Category(this.key, this.name, this.emoji);
  final String key;
  final String name;
  final String emoji;
}

class CatalogItem {
  const CatalogItem(this.name, this.emoji, this.category, {this.aliases = const [], this.icon});
  final String name;

  /// Emoji für ältere App-Versionen, Benachrichtigungen und als Rückfall.
  final String emoji;
  final String category;
  final List<String> aliases;

  /// Eigenes Piktogramm (piktogramme/eigene); null = Fluent-Emoji zu [emoji].
  final String? icon;

  /// Schlüssel des Piktogramms in assets/piktos.
  String get pikto => icon ?? emojiKey(emoji);
}

/// Schlüssel eines Fluent-Emoji-Piktogramms: Codepoints ohne FE0F (🍎 → u1f34e).
String emojiKey(String emoji) =>
    'u${emoji.runes.where((r) => r != 0xFE0F).map((r) => r.toRadixString(16)).join('-')}';

/// Emoji zu einem Fluent-Schlüssel (null bei eigenen Symbolen).
String? emojiOfKey(String key) {
  if (!RegExp(r'^u[0-9a-f]+(-[0-9a-f]+)*$').hasMatch(key)) return null;
  return String.fromCharCodes(key.substring(1).split('-').map((h) => int.parse(h, radix: 16)));
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

final Map<String, CatalogItem> _byName = {for (final c in kCatalog) normalizeName(c.name): c};

CatalogItem? catalogLookup(String name) => _byName[normalizeName(name)];

final Map<String, CatalogItem> _byAlias = {
  for (final c in kCatalog.reversed)
    for (final a in c.aliases) normalizeName(a): c,
};

/// Katalogartikel zu einem Namen oder Synonym („Petersilie“ → Kräuter),
/// z. B. für das passende Symbol.
CatalogItem? catalogLookupOrAlias(String name) => catalogLookup(name) ?? _byAlias[normalizeName(name)];

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
  CatalogItem('Äpfel', '🍎', 'obst', aliases: ['apfel']),
  CatalogItem('Bananen', '🍌', 'obst', aliases: ['banane']),
  CatalogItem('Birnen', '🍐', 'obst', aliases: ['birne']),
  CatalogItem('Orangen', '🍊', 'obst', aliases: ['apfelsinen', 'orange']),
  CatalogItem('Mandarinen', '🍊', 'obst', aliases: ['clementinen'], icon: 'mandarinen'),
  CatalogItem('Zitronen', '🍋', 'obst', aliases: ['zitrone', 'zitronensaft']),
  CatalogItem('Limetten', '🍋', 'obst', aliases: ['limette'], icon: 'limetten'),
  CatalogItem('Trauben', '🍇', 'obst', aliases: ['weintrauben']),
  CatalogItem('Erdbeeren', '🍓', 'obst'),
  CatalogItem('Himbeeren', '🍓', 'obst', icon: 'himbeeren'),
  CatalogItem('Heidelbeeren', '🫐', 'obst', aliases: ['blaubeeren', 'beeren']),
  CatalogItem('Kirschen', '🍒', 'obst'),
  CatalogItem('Pfirsiche', '🍑', 'obst', aliases: ['nektarinen', 'pfirsich']),
  CatalogItem('Kiwis', '🥝', 'obst', aliases: ['kiwi']),
  CatalogItem('Mango', '🥭', 'obst'),
  CatalogItem('Ananas', '🍍', 'obst'),
  CatalogItem('Wassermelone', '🍉', 'obst', aliases: ['melone']),
  CatalogItem('Honigmelone', '🍈', 'obst', aliases: ['zuckermelone', 'galiamelone']),
  CatalogItem('Avocado', '🥑', 'obst', aliases: ['avocados']),
  CatalogItem('Tomaten', '🍅', 'obst', aliases: ['tomate']),
  CatalogItem('Cherrytomaten', '🍅', 'obst', aliases: ['kirschtomaten', 'rispentomaten', 'cocktailtomaten'], icon: 'cherrytomaten'),
  CatalogItem('Gurke', '🥒', 'obst', aliases: ['gurken', 'salatgurke']),
  CatalogItem('Zucchini', '🥒', 'obst', icon: 'zucchini'),
  CatalogItem('Paprika', '🫑', 'obst'),
  CatalogItem('Karotten', '🥕', 'obst', aliases: ['möhren', 'karotte']),
  CatalogItem('Kartoffeln', '🥔', 'obst', aliases: ['kartoffel']),
  CatalogItem('Süßkartoffeln', '🍠', 'obst', aliases: ['süßkartoffel']),
  CatalogItem('Zwiebeln', '🧅', 'obst', aliases: ['zwiebel']),
  CatalogItem('Rote Zwiebeln', '🧅', 'obst', aliases: ['rote zwiebel'], icon: 'rote-zwiebeln'),
  CatalogItem('Frühlingszwiebeln', '🌱', 'obst', aliases: ['lauchzwiebeln'], icon: 'fruehlingszwiebeln'),
  CatalogItem('Knoblauch', '🧄', 'obst'),
  CatalogItem('Ingwer', '🫚', 'obst', icon: 'ingwer'),
  CatalogItem('Brokkoli', '🥦', 'obst'),
  CatalogItem('Blumenkohl', '🥦', 'obst', icon: 'blumenkohl'),
  CatalogItem('Aubergine', '🍆', 'obst', aliases: ['auberginen']),
  CatalogItem('Salat', '🥬', 'obst', aliases: ['kopfsalat', 'eisberg', 'eisbergsalat']),
  CatalogItem('Rucola', '🥬', 'obst', aliases: ['rauke'], icon: 'rucola'),
  CatalogItem('Spinat', '🥬', 'obst', aliases: ['blattspinat'], icon: 'spinat'),
  CatalogItem('Lauch', '🥬', 'obst', aliases: ['porree'], icon: 'lauch'),
  CatalogItem('Champignons', '🍄', 'obst', aliases: ['pilze'], icon: 'champignons'),
  CatalogItem('Mais', '🌽', 'obst'),
  CatalogItem('Erbsen', '🫛', 'obst', aliases: ['zuckerschoten', 'grüne bohnen'], icon: 'erbsen'),
  CatalogItem('Kürbis', '🎃', 'obst', aliases: ['hokkaido'], icon: 'kuerbis'),
  CatalogItem('Spargel', '🌱', 'obst', icon: 'spargel'),
  CatalogItem('Radieschen', '🌱', 'obst', icon: 'radieschen'),
  CatalogItem('Chili', '🌶️', 'obst', aliases: ['peperoni']),
  CatalogItem('Basilikum', '🌿', 'obst', icon: 'basilikum'),
  CatalogItem('Kräuter', '🌿', 'obst', aliases: ['petersilie', 'schnittlauch', 'dill', 'koriander', 'thymian', 'rosmarin', 'salbei', 'minze']),
  CatalogItem('Oliven', '🫒', 'obst'),
  // Brot & Gebäck
  CatalogItem('Brot', '🍞', 'brot', aliases: ['bauernbrot', 'mischbrot', 'vollkornbrot'], icon: 'brot'),
  CatalogItem('Brötchen', '🥯', 'brot', aliases: ['semmeln', 'wecken', 'schrippen'], icon: 'broetchen'),
  CatalogItem('Toastbrot', '🍞', 'brot', aliases: ['toast']),
  CatalogItem('Baguette', '🥖', 'brot'),
  CatalogItem('Croissants', '🥐', 'brot', aliases: ['croissant']),
  CatalogItem('Brezeln', '🥨', 'brot', aliases: ['laugenbrezel', 'brezel']),
  CatalogItem('Knäckebrot', '🍘', 'brot', icon: 'knaeckebrot'),
  CatalogItem('Wraps', '🫓', 'brot', aliases: ['tortillas', 'fladenbrot']),
  CatalogItem('Kuchen', '🍰', 'brot', aliases: ['torte']),
  CatalogItem('Muffins', '🧁', 'brot', aliases: ['cupcakes']),
  CatalogItem('Donuts', '🍩', 'brot', aliases: ['berliner', 'krapfen']),
  // Milch, Käse & Eier
  CatalogItem('Milch', '🥛', 'milch', aliases: ['vollmilch', 'h-milch'], icon: 'milch'),
  CatalogItem('Hafermilch', '🥛', 'milch', aliases: ['haferdrink', 'pflanzenmilch', 'sojamilch', 'mandelmilch'], icon: 'hafermilch'),
  CatalogItem('Butter', '🧈', 'milch', aliases: ['margarine']),
  CatalogItem('Joghurt', '🥣', 'milch', aliases: ['jogurt'], icon: 'joghurt'),
  CatalogItem('Quark', '🥣', 'milch', aliases: ['skyr'], icon: 'quark'),
  CatalogItem('Sahne', '🥛', 'milch', aliases: ['schlagsahne'], icon: 'sahne'),
  CatalogItem('Schmand', '🥣', 'milch', aliases: ['saure sahne', 'crème fraîche', 'creme fraiche', 'sauerrahm'], icon: 'schmand'),
  CatalogItem('Frischkäse', '🧀', 'milch', icon: 'frischkaese'),
  CatalogItem('Käse', '🧀', 'milch', aliases: ['gouda', 'emmentaler', 'bergkäse']),
  CatalogItem('Mozzarella', '🧀', 'milch', icon: 'mozzarella'),
  CatalogItem('Parmesan', '🧀', 'milch', aliases: ['hartkäse', 'grana padano'], icon: 'parmesan'),
  CatalogItem('Feta', '🧀', 'milch', aliases: ['schafskäse', 'hirtenkäse'], icon: 'feta'),
  CatalogItem('Eier', '🥚', 'milch', aliases: ['ei', 'eigelb', 'eiweiß']),
  CatalogItem('Pudding', '🍮', 'milch', aliases: ['dessert']),
  // Fleisch, Fisch & Tofu
  CatalogItem('Hähnchen', '🍗', 'fleisch', aliases: ['hühnchen', 'geflügel', 'hähnchenbrust']),
  CatalogItem('Hackfleisch', '🥩', 'fleisch', aliases: ['hack', 'gehacktes'], icon: 'hackfleisch'),
  CatalogItem('Steak', '🥩', 'fleisch', aliases: ['rindfleisch', 'schnitzel']),
  CatalogItem('Würstchen', '🌭', 'fleisch', aliases: ['wiener', 'bratwurst', 'wurst'], icon: 'wuerstchen'),
  CatalogItem('Aufschnitt', '🥓', 'fleisch', aliases: ['salami', 'wurstaufschnitt'], icon: 'aufschnitt'),
  CatalogItem('Schinken', '🥓', 'fleisch', aliases: ['kochschinken'], icon: 'schinken'),
  CatalogItem('Speck', '🥓', 'fleisch', aliases: ['bacon', 'schinkenwürfel']),
  CatalogItem('Lachs', '🐟', 'fleisch', aliases: ['räucherlachs'], icon: 'lachs'),
  CatalogItem('Fisch', '🐟', 'fleisch', aliases: ['fischfilet', 'seelachs', 'kabeljau'], icon: 'fisch'),
  CatalogItem('Thunfisch', '🥫', 'fleisch', icon: 'thunfisch'),
  CatalogItem('Garnelen', '🦐', 'fleisch', aliases: ['shrimps', 'krabben']),
  CatalogItem('Tofu', '🍱', 'fleisch', aliases: ['veggie'], icon: 'tofu'),
  // Nudeln, Reis & Vorrat
  CatalogItem('Nudeln', '🍝', 'vorrat', aliases: ['pasta', 'penne', 'fusilli', 'lasagneplatten', 'bandnudeln', 'spätzle'], icon: 'nudeln'),
  CatalogItem('Spaghetti', '🍝', 'vorrat'),
  CatalogItem('Reis', '🍚', 'vorrat', aliases: ['basmati']),
  CatalogItem('Couscous', '🍚', 'vorrat', aliases: ['bulgur', 'quinoa'], icon: 'couscous'),
  CatalogItem('Linsen', '🫘', 'vorrat', icon: 'linsen'),
  CatalogItem('Kichererbsen', '🫘', 'vorrat', icon: 'kichererbsen'),
  CatalogItem('Bohnen', '🫘', 'vorrat', aliases: ['kidneybohnen']),
  CatalogItem('Dosentomaten', '🥫', 'vorrat', aliases: ['passierte tomaten', 'tomatendose']),
  CatalogItem('Kokosmilch', '🥥', 'vorrat'),
  CatalogItem('Haferflocken', '🥣', 'vorrat', icon: 'haferflocken'),
  CatalogItem('Müsli', '🥣', 'vorrat', aliases: ['cornflakes', 'granola']),
  CatalogItem('Nüsse', '🥜', 'vorrat', aliases: ['walnüsse', 'cashews', 'mandeln', 'erdnüsse']),
  // Zutaten & Gewürze
  CatalogItem('Mehl', '🌾', 'zutaten', icon: 'mehl'),
  CatalogItem('Zucker', '🍬', 'zutaten', aliases: ['puderzucker'], icon: 'zucker'),
  CatalogItem('Salz', '🧂', 'zutaten'),
  CatalogItem('Pfeffer', '🧂', 'zutaten', icon: 'pfeffer'),
  CatalogItem('Olivenöl', '🫒', 'zutaten', icon: 'olivenoel'),
  CatalogItem('Speiseöl', '🫒', 'zutaten', aliases: ['öl', 'sonnenblumenöl', 'rapsöl', 'pflanzenöl', 'bratöl'], icon: 'speiseoel'),
  CatalogItem('Essig', '🍶', 'zutaten', aliases: ['balsamico'], icon: 'essig'),
  CatalogItem('Hefe', '🍞', 'zutaten', aliases: ['trockenhefe'], icon: 'hefe'),
  CatalogItem('Backpulver', '🧁', 'zutaten', aliases: ['natron', 'vanillezucker'], icon: 'backpulver'),
  CatalogItem('Senf', '🌭', 'zutaten', icon: 'senf'),
  CatalogItem('Ketchup', '🍅', 'zutaten', icon: 'ketchup'),
  CatalogItem('Mayonnaise', '🥚', 'zutaten', aliases: ['mayo'], icon: 'mayonnaise'),
  CatalogItem('Tomatenmark', '🍅', 'zutaten', icon: 'tomatenmark'),
  CatalogItem('Gemüsebrühe', '🍲', 'zutaten', aliases: ['brühe']),
  CatalogItem('Sojasauce', '🍶', 'zutaten', aliases: ['sojasoße'], icon: 'sojasauce'),
  CatalogItem('Gewürze', '🌶️', 'zutaten', aliases: ['paprikapulver', 'curry', 'zimt', 'oregano', 'chilipulver', 'cayennepfeffer', 'muskat', 'muskatnuss', 'lorbeer', 'lorbeerblätter', 'lorbeerblatt', 'kreuzkümmel', 'kurkuma', 'gewürz'], icon: 'gewuerze'),
  // Frühstück & Aufstriche
  CatalogItem('Marmelade', '🍓', 'fruehstueck', aliases: ['konfitüre'], icon: 'marmelade'),
  CatalogItem('Honig', '🍯', 'fruehstueck'),
  CatalogItem('Nussnougatcreme', '🍫', 'fruehstueck', aliases: ['nutella', 'schokocreme'], icon: 'nussnougatcreme'),
  CatalogItem('Erdnussbutter', '🥜', 'fruehstueck', icon: 'erdnussbutter'),
  CatalogItem('Kaffee', '☕', 'fruehstueck', aliases: ['kaffeebohnen', 'espresso']),
  CatalogItem('Tee', '🍵', 'fruehstueck', aliases: ['teebeutel']),
  // Tiefkühl & Fertiggerichte
  CatalogItem('Pizza', '🍕', 'tk', aliases: ['tiefkühlpizza']),
  CatalogItem('Pommes', '🍟', 'tk', aliases: ['pommes frites']),
  CatalogItem('Eis', '🍨', 'tk', aliases: ['eiscreme']),
  CatalogItem('TK-Gemüse', '🥦', 'tk', aliases: ['rahmspinat', 'tiefkühlgemüse'], icon: 'tk-gemuese'),
  CatalogItem('Fischstäbchen', '🐟', 'tk', icon: 'fischstaebchen'),
  CatalogItem('Maultaschen', '🥟', 'tk', aliases: ['tortellini', 'ravioli']),
  // Snacks & Süßes
  CatalogItem('Chips', '🥔', 'snacks', aliases: ['kartoffelchips'], icon: 'chips'),
  CatalogItem('Schokolade', '🍫', 'snacks', aliases: ['schoki']),
  CatalogItem('Kekse', '🍪', 'snacks', aliases: ['plätzchen']),
  CatalogItem('Gummibärchen', '🐻', 'snacks', aliases: ['fruchtgummi'], icon: 'gummibaerchen'),
  CatalogItem('Bonbons', '🍬', 'snacks', aliases: ['süßigkeiten']),
  CatalogItem('Popcorn', '🍿', 'snacks'),
  CatalogItem('Salzstangen', '🥨', 'snacks', aliases: ['salzbrezeln'], icon: 'salzstangen'),
  // Getränke
  CatalogItem('Wasser', '💧', 'getraenke', aliases: ['mineralwasser', 'sprudel'], icon: 'wasser'),
  CatalogItem('Saft', '🧃', 'getraenke', aliases: ['orangensaft', 'apfelsaft', 'schorle']),
  CatalogItem('Cola', '🥤', 'getraenke', aliases: ['cola zero', 'cola light', 'spezi'], icon: 'cola'),
  CatalogItem('Limonade', '🥤', 'getraenke', aliases: ['limo']),
  CatalogItem('Sirup', '🍹', 'getraenke', aliases: ['getränkesirup', 'holundersirup'], icon: 'sirup'),
  CatalogItem('Bier', '🍺', 'getraenke', aliases: ['alkoholfreies bier']),
  CatalogItem('Wein', '🍷', 'getraenke', aliases: ['rotwein', 'weißwein', 'rosé']),
  CatalogItem('Sekt', '🍾', 'getraenke', aliases: ['prosecco', 'champagner']),
  CatalogItem('Spirituosen', '🥃', 'getraenke', aliases: ['schnaps', 'gin', 'rum', 'whisky', 'wodka', 'likör'], icon: 'spirituosen'),
  // Haushalt
  CatalogItem('Spülmittel', '🧽', 'haushalt', icon: 'spuelmittel'),
  CatalogItem('Spülmaschinentabs', '🫧', 'haushalt', aliases: ['tabs', 'geschirrspültabs'], icon: 'spuelmaschinentabs'),
  CatalogItem('Waschmittel', '🧺', 'haushalt', icon: 'waschmittel'),
  CatalogItem('Weichspüler', '🧺', 'haushalt', icon: 'weichspueler'),
  CatalogItem('Müllbeutel', '🗑️', 'haushalt', aliases: ['mülltüten'], icon: 'muellbeutel'),
  CatalogItem('Küchenrolle', '🧻', 'haushalt', aliases: ['küchentücher'], icon: 'kuechenrolle'),
  CatalogItem('Toilettenpapier', '🧻', 'haushalt', aliases: ['klopapier']),
  CatalogItem('Taschentücher', '🤧', 'haushalt', icon: 'taschentuecher'),
  CatalogItem('Alufolie', '📜', 'haushalt', icon: 'alufolie'),
  CatalogItem('Frischhaltefolie', '📜', 'haushalt', icon: 'frischhaltefolie'),
  CatalogItem('Backpapier', '📜', 'haushalt', icon: 'backpapier'),
  CatalogItem('Schwämme', '🧽', 'haushalt', aliases: ['spülschwamm']),
  CatalogItem('Allzweckreiniger', '🧴', 'haushalt', aliases: ['putzmittel', 'glasreiniger', 'badreiniger'], icon: 'reiniger'),
  CatalogItem('Besen', '🧹', 'haushalt', aliases: ['handfeger']),
  CatalogItem('Batterien', '🔋', 'haushalt', aliases: ['akkus']),
  CatalogItem('Glühbirne', '💡', 'haushalt', aliases: ['leuchtmittel', 'lampe']),
  CatalogItem('Kerzen', '🕯️', 'haushalt', aliases: ['teelichter']),
  CatalogItem('Wasserkocher', '🫖', 'haushalt', aliases: ['kocher'], icon: 'wasserkocher'),
  // Pflege & Drogerie
  CatalogItem('Shampoo', '🧴', 'drogerie', aliases: ['spülung'], icon: 'shampoo'),
  CatalogItem('Duschgel', '🧴', 'drogerie', icon: 'duschgel'),
  CatalogItem('Seife', '🧼', 'drogerie', aliases: ['handseife', 'flüssigseife']),
  CatalogItem('Zahnpasta', '🪥', 'drogerie', aliases: ['zahncreme'], icon: 'zahnpasta'),
  CatalogItem('Zahnbürste', '🪥', 'drogerie'),
  CatalogItem('Deo', '🧴', 'drogerie', aliases: ['deodorant'], icon: 'deo'),
  CatalogItem('Creme', '🧴', 'drogerie', aliases: ['handcreme', 'bodylotion', 'gesichtscreme']),
  CatalogItem('Sonnencreme', '🧴', 'drogerie', aliases: ['sonnenschutz'], icon: 'sonnencreme'),
  CatalogItem('Rasierer', '🪒', 'drogerie', aliases: ['rasierklingen']),
  CatalogItem('Wattepads', '☁️', 'drogerie', aliases: ['abschminkpads'], icon: 'wattepads'),
  CatalogItem('Pflaster', '🩹', 'drogerie'),
  CatalogItem('Schmerztabletten', '💊', 'drogerie', aliases: ['ibuprofen', 'paracetamol', 'medikamente']),
  CatalogItem('Hygieneartikel', '🌸', 'drogerie', aliases: ['tampons', 'binden'], icon: 'hygieneartikel'),
  // Tierbedarf
  CatalogItem('Katzenfutter', '🐱', 'tier', icon: 'katzenfutter'),
  CatalogItem('Hundefutter', '🐶', 'tier', icon: 'hundefutter'),
  CatalogItem('Katzenstreu', '🐈', 'tier', icon: 'katzenstreu'),
  CatalogItem('Leckerli', '🦴', 'tier', aliases: ['kauknochen']),
  // Baumarkt & Garten
  CatalogItem('Pflanzen', '🪴', 'baumarkt', aliases: ['zimmerpflanze']),
  CatalogItem('Blumen', '💐', 'baumarkt', aliases: ['blumenstrauß']),
  CatalogItem('Blumenerde', '🪴', 'baumarkt', aliases: ['erde'], icon: 'blumenerde'),
  CatalogItem('Schrauben', '🔩', 'baumarkt', aliases: ['dübel', 'nägel']),
  CatalogItem('Klebeband', '🩹', 'baumarkt', aliases: ['paketband'], icon: 'klebeband'),
  CatalogItem('Werkzeug', '🧰', 'baumarkt'),
  CatalogItem('Kabel', '🔌', 'baumarkt', aliases: ['verlängerungskabel', 'ladekabel', 'steckdosenleiste']),
  CatalogItem('Farbe', '🎨', 'baumarkt', aliases: ['wandfarbe', 'lack'], icon: 'farbe'),
  CatalogItem('Pinsel', '🖌️', 'baumarkt', aliases: ['farbrolle']),
  CatalogItem('Grillkohle', '🔥', 'baumarkt', aliases: ['holzkohle', 'briketts', 'anzünder'], icon: 'grillkohle'),
];
