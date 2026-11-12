import 'dart:io';

import 'package:encrypted_shopping_app/src/models/catalog.dart';
import 'package:encrypted_shopping_app/src/models/pikto.dart';
import 'package:encrypted_shopping_app/src/models/piktos.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Jeder Katalogartikel hat ein mitgeliefertes Symbol', () {
    final missing = [
      for (final c in kCatalog)
        if (!kPiktos.contains(c.pikto)) '${c.name} (${c.pikto})',
    ];
    expect(missing, isEmpty);
  });

  test('Jede Kategorie hat ein mitgeliefertes Symbol', () {
    for (final c in kCategories) {
      expect(resolvePikto(emoji: c.emoji), isNotNull, reason: c.name);
    }
  });

  test('Alle Symbole liegen als PNG vor', () {
    final missing = [
      for (final k in kPiktos)
        if (!File('assets/piktos/$k.png').existsSync()) k,
    ];
    expect(missing, isEmpty);
  });

  test('Katalognamen sind eindeutig', () {
    final names = kCatalog.map((c) => normalizeName(c.name)).toList();
    expect(names.toSet().length, names.length);
  });

  test('Auflösung: eigenes Symbol, dann Katalog, dann Emoji, sonst Text', () {
    expect(resolvePikto(icon: 'lachs', name: 'Milch', emoji: '🥛'), 'lachs');
    expect(resolvePikto(name: 'Lachs', emoji: '🐟'), 'lachs');
    expect(resolvePikto(name: 'lachs', emoji: '🐟'), 'lachs');
    expect(resolvePikto(name: 'Petersilie', emoji: '🥦'), 'u1f33f');
    expect(resolvePikto(name: 'Paprikapulver', emoji: '🧂'), 'gewuerze');
    expect(resolvePikto(name: 'Mein Spezialartikel', emoji: '🍎'), 'u1f34e');
    expect(resolvePikto(name: 'Mein Spezialartikel', emoji: '🌶️'), 'u1f336');
    expect(resolvePikto(icon: 'gibt-es-nicht', name: 'X', emoji: '🦄'), isNull);
    expect(resolvePikto(emoji: ''), isNull);
  });

  test('Emoji ↔ Schlüssel', () {
    expect(emojiKey('🍎'), 'u1f34e');
    expect(emojiKey('🗑️'), 'u1f5d1');
    expect(emojiOfKey('u1f34e'), '🍎');
    expect(emojiOfKey('hafermilch'), isNull);
    expect(emojiForPikto('hafermilch'), '🥛');
    expect(emojiForPikto('u1f34e'), '🍎');
  });

  test('Auswahl beginnt mit den Katalogsymbolen und enthält jedes Symbol einmal', () {
    final a = piktoAuswahl();
    expect(a.first, kCatalog.first.pikto);
    expect(a.toSet().length, a.length);
    expect(a.toSet(), kPiktos);
  });
}
