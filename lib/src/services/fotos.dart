import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'rezept_import.dart' show vorschauAus;

/// Ein aufbereitetes Foto: richtig gedreht, höchstens [kFotoKante] px an der
/// langen Seite, ohne Metadaten (keine Ortsdaten im Repo), dazu ein
/// Vorschaubild für die Rezeptliste.
class FotoDaten {
  const FotoDaten({required this.jpeg, required this.breite, required this.hoehe, required this.vorschau});
  final Uint8List jpeg;
  final int breite;
  final int hoehe;

  /// Vorschaubild (JPEG, Base64, ≤ 640 px breit) – für das Titelbild.
  final String vorschau;
}

/// Lange Bildkante: reicht, um eine Kochbuchseite gut zu lesen.
const kFotoKante = 1800;

/// Läuft per `compute` in einem eigenen Isolate. null, wenn kein Bild.
FotoDaten? fotoAufbereiten(Uint8List roh) {
  final dekodiert = img.decodeImage(roh);
  if (dekodiert == null) return null;
  var bild = img.bakeOrientation(dekodiert);
  if (max(bild.width, bild.height) > kFotoKante) {
    bild = bild.width >= bild.height
        ? img.copyResize(bild, width: kFotoKante, interpolation: img.Interpolation.average)
        : img.copyResize(bild, height: kFotoKante, interpolation: img.Interpolation.average);
  }
  bild.exif = img.ExifData();
  return FotoDaten(
    jpeg: img.encodeJpg(bild, quality: 80),
    breite: bild.width,
    hoehe: bild.height,
    vorschau: vorschauAus(bild),
  );
}
