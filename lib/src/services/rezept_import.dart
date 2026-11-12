import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../models/recipe.dart';
import '../models/rezept.dart';

class RezeptFehler implements Exception {
  const RezeptFehler(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lädt eine Rezeptseite und liest die Zutaten aus den eingebetteten
/// schema.org-Daten. Es wird nur diese eine Seite abgerufen (wie im Browser),
/// ohne Cookies und ohne die Daten weiterzugeben.
const _userAgent = 'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/130.0 Mobile Safari/537.36';

Future<Rezept> ladeRezept(Uri url, {http.Client? client}) async {
  if (url.scheme != 'http' && url.scheme != 'https') {
    throw const RezeptFehler('Nur Links auf Webseiten können übernommen werden.');
  }
  final c = client ?? http.Client();
  try {
    final req = http.Request('GET', url)
      ..followRedirects = true
      ..maxRedirects = 5
      ..headers.addAll({
        'User-Agent': _userAgent,
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'de-DE,de;q=0.9',
      });
    final res = await c.send(req).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw RezeptFehler('Die Seite ist gerade nicht erreichbar (Fehler ${res.statusCode}).');
    }
    final bytes = <int>[];
    await for (final chunk in res.stream.timeout(const Duration(seconds: 20))) {
      bytes.addAll(chunk);
      if (bytes.length > 6 * 1024 * 1024) break; // genügt für jede Rezeptseite
    }
    final html = utf8.decode(bytes, allowMalformed: true);
    final r = rezeptAusHtml(html, quelle: url);
    if (r == null || r.zutaten.isEmpty) {
      throw const RezeptFehler('Auf dieser Seite wurde keine Zutatenliste gefunden.');
    }
    return r;
  } on RezeptFehler {
    rethrow;
  } on TimeoutException {
    throw const RezeptFehler('Die Seite hat zu lange nicht geantwortet.');
  } catch (_) {
    throw const RezeptFehler('Keine Verbindung – das Rezept konnte nicht geladen werden.');
  } finally {
    if (client == null) c.close();
  }
}

/// Lädt das Rezeptbild und verkleinert es zu einem Vorschaubild (JPEG, Base64).
/// Leer, wenn es nicht klappt – das Rezept wird dann ohne Bild gespeichert.
Future<String> ladeVorschaubild(Uri? url, {http.Client? client}) async {
  if (url == null) return '';
  final c = client ?? http.Client();
  try {
    final res = await c.get(url, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200 || res.bodyBytes.length > 8 * 1024 * 1024) return '';
    return await compute(vorschaubild, res.bodyBytes);
  } catch (_) {
    return '';
  } finally {
    if (client == null) c.close();
  }
}

/// Verkleinert ein Bild auf höchstens 640 px Breite (JPEG, Qualität 72).
String vorschaubild(Uint8List bytes) {
  final bild = img.decodeImage(bytes);
  if (bild == null) return '';
  final klein = bild.width > 640 ? img.copyResize(bild, width: 640, interpolation: img.Interpolation.average) : bild;
  return base64Encode(img.encodeJpg(klein, quality: 72));
}

/// Gespeichertes Rezept aus einem geladenen oder geteilten Rezept.
Recipe recipeAusRezept(Rezept r, {String bild = '', String von = ''}) => Recipe(
      title: r.titel,
      sourceUrl: r.quelle?.toString() ?? '',
      servings: r.portionen,
      ingredients: r.zeilen,
      steps: r.schritte,
      description: r.beschreibung,
      imageJpeg: bild,
      prepMinutes: r.vorbereitung,
      cookMinutes: r.kochzeit,
      totalMinutes: r.gesamtzeit,
      category: r.kategorie,
      author: r.autor,
      calories: r.kalorien,
      addedBy: von,
      updatedBy: von,
    );

/// Rezept für die Zutatenauswahl aus einem gespeicherten Rezept.
Rezept rezeptAusRecipe(Recipe r) => Rezept(
      titel: r.title,
      zutaten: [for (final z in r.ingredients) ...parseZutat(z)],
      zeilen: r.ingredients,
      portionen: r.servings,
      quelle: r.sourceUrl.isEmpty ? null : Uri.tryParse(r.sourceUrl),
      schritte: r.steps,
    );
