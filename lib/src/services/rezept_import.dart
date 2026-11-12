import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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
        'User-Agent': 'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/130.0 Mobile Safari/537.36',
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
