import 'catalog.dart';
import 'piktos.g.dart';

/// Welches Piktogramm zeigt ein Artikel?
///
/// 1. ein selbst gewähltes Symbol ([icon]),
/// 2. das Symbol des Katalogartikels gleichen Namens,
/// 3. das Fluent-Emoji zum gespeicherten [emoji],
/// 4. sonst null – dann wird das Emoji als Text gezeigt (z. B. ein Emoji,
///    das nicht mitgeliefert ist, oder Daten einer neueren App-Version).
String? resolvePikto({String? icon, String? name, String? emoji}) {
  if (icon != null && kPiktos.contains(icon)) return icon;
  if (name != null) {
    final c = catalogLookup(name);
    if (c != null && kPiktos.contains(c.pikto)) return c.pikto;
  }
  if (emoji != null && emoji.isNotEmpty) {
    final k = emojiKey(emoji);
    if (kPiktos.contains(k)) return k;
  }
  return null;
}

/// Asset-Pfad eines Piktogramms.
String piktoAsset(String key) => 'assets/piktos/$key.png';

/// Emoji, das zu einem Symbol gespeichert wird (für ältere App-Versionen und
/// Benachrichtigungen): bei Fluent-Symbolen das Emoji selbst, bei eigenen das
/// Emoji des Katalogartikels, der das Symbol verwendet.
String? emojiForPikto(String key) =>
    emojiOfKey(key) ?? kCatalog.where((c) => c.icon == key).firstOrNull?.emoji;

/// Reihenfolge für die Symbolauswahl: erst die Symbole des Katalogs (nach
/// Ladenbereich), dann alle übrigen.
List<String> piktoAuswahl() {
  final seen = <String>{};
  final out = <String>[];
  for (final c in kCatalog) {
    if (kPiktos.contains(c.pikto) && seen.add(c.pikto)) out.add(c.pikto);
  }
  for (final k in [...kEigenePiktos, ...kFluentPiktos]) {
    if (seen.add(k)) out.add(k);
  }
  return out;
}
