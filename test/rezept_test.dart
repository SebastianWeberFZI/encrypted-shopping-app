import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypted_shopping_app/src/models/recipe.dart';
import 'package:encrypted_shopping_app/src/models/rezept.dart';
import 'package:encrypted_shopping_app/src/services/rezept_import.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';

Zutat eins(String zeile) {
  final z = parseZutat(zeile);
  expect(z, hasLength(1), reason: zeile);
  return z.single;
}

void main() {
  group('Zutatenzeilen (Chefkoch-Schreibweise)', () {
    test('Menge, Einheit, Anmerkung', () {
      final z = eins('400 g Mehl (wer mag, kann Vollkornmehl verwenden)');
      expect(z.name, 'Mehl');
      expect(z.spec(), '400 g');
      expect(z.vorrat, isFalse);
    });

    test('Pluralmarker und Größe', () {
      final z = eins('3 große Ei(er), Größe L');
      expect(z.name, 'Eier');
      expect(z.spec(), '3 große');
      expect(eins('2 Zwiebel(n) (mittelgroß)').name, 'Zwiebeln');
      expect(eins('2 Zwiebel(n) (mittelgroß)').spec(), '2 Stück');
      expect(eins('1 Karotte(n) (gewürfelt)').name, 'Karotten');
    });

    test('Zehe/n, Paprikaschote, Knoblauchzehe', () {
      final k = eins('3 Zehe/n Knoblauch');
      expect(k.name, 'Knoblauch');
      expect(k.spec(), '3 Zehen');
      expect(eins('2 Knoblauchzehe(n)').name, 'Knoblauch');
      expect(eins('2 Knoblauchzehe(n)').spec(), '2 Zehen');
      expect(eins('1 Paprikaschote(n), orange').name, 'Paprika');
    });

    test('Kleinmengen und Grundvorrat sind abgewählt', () {
      expect(eins('1 Prise(n) Salz').vorrat, isTrue);
      expect(eins('1 Msp. Muskatnuss, frisch geriebene').vorrat, isTrue);
      expect(eins('evtl. Saucenbinder').vorrat, isTrue);
      expect(eins('etwas Rotwein (und Brühe oder Balsamico, ca. 50 - 100 ml)').katalog?.name, 'Wein');
      expect(eins('1 Becher Schmand (nach Bedarf)').vorrat, isTrue);
      expect(eins('750 ml Milch (fettarme)').vorrat, isFalse);
    });

    test('Salz und Pfeffer werden zwei Artikel', () {
      final z = parseZutat('Salz und Pfeffer');
      expect(z.map((e) => e.name), ['Salz', 'Pfeffer']);
      expect(z.every((e) => e.vorrat), isTrue);
    });

    test('Zusammensetzungen und Synonyme', () {
      expect(eins('800 g Rinderhackfleisch (oder halb Rinder-, halb Schweinehack)').name, 'Hackfleisch');
      expect(eins('500 g Hackfleisch, gemischtes').name, 'Hackfleisch');
      expect(eins('300 ml Rinderbrühe').name, 'Rinderbrühe');
      expect(eins('300 ml Rinderbrühe').katalog?.name, 'Gemüsebrühe');
      expect(eins('0.7 Liter Rotwein').spec(), '0,7 l');
      expect(eins('0.7 Liter Rotwein').name, 'Rotwein');
      expect(eins('1 TL, gehäuft Paprikapulver, edelsüßes').name, 'Paprikapulver');
      expect(eins('1 TL, gehäuft Paprikapulver, edelsüßes').katalog?.name, 'Gewürze');
      expect(eins('2 EL Öl zum Braten').katalog?.name, 'Speiseöl');
      expect(eins('2 EL Olivenöl').name, 'Olivenöl');
      expect(eins('30 ml Mineralwasser mit Kohlensäure').katalog?.name, 'Wasser');
      expect(eins('20 g Butterflöckchen').name, 'Butter');
      expect(eins('2 EL Butterschmalz').name, 'Butterschmalz');
      expect(eins('300 g Lasagneplatte(n)').name, 'Lasagneplatten');
      expect(eins('300 g Lasagneplatte(n)').katalog?.name, 'Nudeln');
      expect(eins('2 TL Zitronensaft').name, 'Zitronensaft');
      expect(eins('200 g Käse, geriebener (z. B. Gouda, Emmentaler oder Mozzarella)').name, 'Käse');
      expect(eins('2 Lorbeerblätter').name, 'Lorbeerblätter');
      expect(eins('2 Lorbeerblätter').katalog?.name, 'Gewürze');
      expect(eins('1 kl. Dose/n Kidneybohnen (480 g)').name, 'Kidneybohnen');
      expect(eins('1 Bund Petersilie (oder TK)').name, 'Petersilie');
    });

    test('Dosentomaten', () {
      final z = eins('1 gr. Dose/n Tomaten, stückige (ca. 800 g)');
      expect(z.name, 'Dosentomaten');
      expect(z.spec(), '1 Dose');
      expect(eins('2 Dosen Tomaten, geschälte').spec(), '2 Dosen');
    });

    test('Unbekanntes bleibt als eigener Artikel', () {
      final z = eins('6 Spritzer Tabasco (oder andere Würzsauce)');
      expect(z.name, 'Tabasco');
      expect(z.katalog, isNull);
      expect(z.vorrat, isTrue);
    });

    test('Brüche, Bereiche, Skalierung', () {
      expect(eins('½ TL Salz').menge, 0.5);
      expect(eins('1 ½ Tassen Mehl').menge, 1.5);
      expect(eins('1/2 Bund Petersilie').menge, 0.5);
      expect(eins('2-3 Äpfel').menge, 3);
      final z = eins('400 g Mehl');
      expect(z.spec(1.5), '600 g');
      expect(z.spec(0.25), '100 g');
      expect(eins('3 Eier').spec(1.5), '5 Stück');
      expect(eins('3 Zehe/n Knoblauch').spec(1.5), '5 Zehen');
      expect(eins('1 gr. Dose/n Tomaten').spec(1.5), '2 Dosen');
      expect(eins('800 g Rinderhackfleisch').spec(1.5), '1,2 kg');
      expect(eins('750 ml Milch').spec(2), '1,5 l');
      expect(eins('2 EL Öl').spec(1.5), '3 EL');
      expect(eins('1 TL Zimt').spec(1.5), '1,5 TL');
      expect(eins('125 g Butter').spec(1.5), '190 g');
    });
  });

  group('Webseiten', () {
    test('JSON-LD mit @graph (Chefkoch)', () {
      const html = '''<html><head>
<script type="application/ld+json">{"@context":"https://schema.org","@graph":[
 {"@type":"WebPage","name":"x"},
 {"@type":"Recipe","name":"Lasagne Rezept - wie beim Italiener von koch123",
  "recipeYield":["4","4 Portionen"],
  "recipeIngredient":["1 Zwiebel(n)","500 g Hackfleisch, gemischtes","Salz und Pfeffer","1 Dose Tomaten, geschälte (800 g)"]}]}
</script></head><body></body></html>''';
      final r = rezeptAusHtml(html, quelle: Uri.parse('https://www.chefkoch.de/rezepte/1/Lasagne.html'))!;
      expect(r.titel, 'Lasagne Rezept - wie beim Italiener');
      expect(r.portionen, 4);
      expect(r.zutaten.map((z) => z.name), ['Zwiebeln', 'Hackfleisch', 'Salz', 'Pfeffer', 'Dosentomaten']);
    });

    test('Rezept als Liste, Typ als Liste, Entitäten', () {
      const html = '''<script type="application/ld+json">[{"@type":"Organization"},
 {"@type":["Recipe","Thing"],"name":"Apfel &amp; Zimt","recipeYield":"6 Stück",
  "recipeIngredient":["2 &frac12; Äpfel","1 TL Zimt"]}]</script>''';
      final r = rezeptAusHtml(html)!;
      expect(r.titel, 'Apfel & Zimt');
      expect(r.portionen, 6);
      expect(r.zutaten.last.name, 'Zimt');
      expect(r.zutaten.last.katalog?.name, 'Gewürze');
    });

    test('Seite ohne Rezept', () {
      expect(rezeptAusHtml('<script type="application/ld+json">{"@type":"WebPage"}</script>'), isNull);
      expect(rezeptAusHtml('<html>kaputt <script type="application/ld+json">{nicht json</script>'), isNull);
    });

    test('Adresse im geteilten Text', () {
      expect(ersteAdresse('Schau mal: Lasagne https://www.chefkoch.de/rezepte/745721177147257/Lasagne.html.')!.path,
          '/rezepte/745721177147257/Lasagne.html');
      expect(ersteAdresse('Milch, Eier'), isNull);
    });

    test('Geteilter Text als Zutatenliste', () {
      expect(zutatenAusText('Milch, 6 Eier, Butter').map((z) => z.name), ['Milch', 'Eier', 'Butter']);
      expect(zutatenAusText('Einkauf fürs Wochenende: Zucchini, 2 Paprika, Feta').map((z) => z.name),
          ['Zucchini', 'Paprika', 'Feta']);
      expect(zutatenAusText('Für den Teig:\n200 g Mehl\nFür die Füllung:\nQuark').map((z) => z.name), ['Mehl', 'Quark']);
      expect(zutatenAusText('- 1 kg Kartoffeln\n• Quark\n\n* 2 Zwiebeln').map((z) => z.name),
          ['Kartoffeln', 'Quark', 'Zwiebeln']);
    });
  });

  group('Alles vom Rezept', () {
    const html = '''<html><head>
<script type="application/ld+json">{"@context":"https://schema.org","@graph":[
 {"@type":"ImageObject","@id":"#bild","url":"/img/lasagne.jpg","width":800},
 {"@type":"Person","@id":"#koch","name":"koch123"},
 {"@type":"Recipe","name":"Lasagne","image":{"@id":"#bild"},"author":{"@id":"#koch"},
  "description":"Klassisch &amp; einfach.<br>Gelingt immer.",
  "recipeYield":"4","prepTime":"PT30M","cookTime":"PT1H","totalTime":"P0DT1H30M",
  "recipeCategory":["Hauptspeise","Pasta"],"nutrition":{"@type":"NutritionInformation","calories":"650 kcal"},
  "recipeIngredient":["500 g Hackfleisch","Für die Soße:","1 Dose Tomaten"],
  "recipeInstructions":[
   {"@type":"HowToSection","name":"Soße","itemListElement":[
     {"@type":"HowToStep","text":"Hack anbraten."},{"@type":"HowToStep","text":"Tomaten dazu."}]},
   {"@type":"HowToStep","text":"Schichten &amp; backen."}]}]}
</script></head></html>''';

    test('Schritte, Bild, Autor, Zeiten, Kategorie, Kalorien', () {
      final r = rezeptAusHtml(html, quelle: Uri.parse('https://www.chefkoch.de/rezepte/1/Lasagne.html'))!;
      expect(r.schritte, ['Soße:', 'Hack anbraten.', 'Tomaten dazu.', 'Schichten & backen.']);
      expect(r.bildUrl.toString(), 'https://www.chefkoch.de/img/lasagne.jpg');
      expect(r.autor, 'koch123');
      expect(r.vorbereitung, 30);
      expect(r.kochzeit, 60);
      expect(r.gesamtzeit, 90);
      expect(r.kategorie, 'Hauptspeise · Pasta');
      expect(r.kalorien, '650 kcal');
      expect(r.beschreibung, 'Klassisch & einfach.\nGelingt immer.');
      expect(r.zeilen, ['500 g Hackfleisch', 'Für die Soße:', '1 Dose Tomaten']);
    });

    test('Anleitung als Text oder Liste von Texten', () {
      final a = rezeptAusHtml('''<script type="application/ld+json">{"@type":"Recipe","name":"A",
        "recipeIngredient":["Mehl"],"recipeInstructions":"Alles verrühren.\\nBacken."}</script>''')!;
      expect(a.schritte, ['Alles verrühren.', 'Backen.']);
      final b = rezeptAusHtml('''<script type="application/ld+json">{"@type":"Recipe","name":"B",
        "recipeIngredient":["Mehl"],"recipeInstructions":["Rühren.","Backen."],"image":["https://x.de/1.jpg"]}</script>''')!;
      expect(b.schritte, ['Rühren.', 'Backen.']);
      expect(b.bildUrl.toString(), 'https://x.de/1.jpg');
    });

    test('ISO-Dauern', () {
      expect(isoMinuten('PT45M'), 45);
      expect(isoMinuten('PT1H15M'), 75);
      expect(isoMinuten('P1D'), 1440);
      expect(isoMinuten('PT0S'), isNull);
      expect(isoMinuten('irgendwas'), isNull);
      expect(isoMinuten(20), 20);
    });

    test('Zeilen skalieren', () {
      expect(skaliereZeile('500 g Hackfleisch', 0.5), '250 g Hackfleisch');
      expect(skaliereZeile('2-3 Zwiebeln', 2), '4–6 Zwiebeln');
      expect(skaliereZeile('Salz und Pfeffer', 2), 'Salz und Pfeffer');
      expect(skaliereZeile('½ TL Zimt', 2), '1 TL Zimt');
    });

    test('Gespeichertes Rezept: hin und zurück, unbekannte Felder bleiben', () {
      final r = rezeptAusHtml(html, quelle: Uri.parse('https://www.chefkoch.de/rezepte/1/Lasagne.html'))!;
      final rec = recipeAusRezept(r, bild: 'QUJD', von: 'Sebastian');
      final json = rec.toJson()..['bewertung'] = 5;
      final back = Recipe.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(back.title, 'Lasagne');
      expect(back.servings, 4);
      expect(back.ingredients, r.zeilen);
      expect(back.steps, r.schritte);
      expect(back.prepMinutes, 30);
      expect(back.totalMinutes, 90);
      expect(back.author, 'koch123');
      expect(back.addedBy, 'Sebastian');
      expect(back.sourceHost, 'chefkoch.de');
      expect(back.imageBytes, utf8.encode('ABC'));
      expect(back.toJson()['bewertung'], 5);
      final wieder = rezeptAusRecipe(back);
      expect(wieder.zutaten.map((z) => z.name), ['Hackfleisch', 'Dosentomaten']);
      expect(wieder.portionen, 4);
    });

    test('Kaputte oder fremde Felder werden toleriert', () {
      final r = Recipe.fromJson({'id': 'x', 'title': 7, 'servings': '3', 'ingredients': 'Mehl', 'steps': null});
      expect(r.title, 'Rezept');
      expect(r.servings, 3);
      expect(r.ingredients, isEmpty);
      expect(r.steps, isEmpty);
      expect(r.imageBytes, isNull);
    });

    test('Vorschaubild wird verkleinert und als JPEG gespeichert', () {
      final gross = img.Image(width: 1600, height: 900);
      img.fill(gross, color: img.ColorRgb8(200, 80, 40));
      final b64 = vorschaubild(Uint8List.fromList(img.encodePng(gross)));
      final klein = img.decodeJpg(base64Decode(b64))!;
      expect(klein.width, 640);
      expect(klein.height, 360);
      expect(vorschaubild(Uint8List.fromList([1, 2, 3])), '');
    });
  });
}
