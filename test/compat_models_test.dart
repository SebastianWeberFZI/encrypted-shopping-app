import 'package:encrypted_shopping_app/src/models/shopping_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dokumente älterer und neuerer App-Versionen: tolerant lesen, verlustfrei
/// zurückschreiben.
void main() {
  test('Minimaler Artikel einer frühen Version wird gelesen', () {
    final i = ShopItem.fromJson({'id': 'a', 'list_id': 'l', 'name': 'Milch'});
    expect(i.needed, isTrue);
    expect(i.purchaseHistory, isEmpty);
    expect(i.emoji, '🛍️');
  });

  test('Unbekannte Felder bleiben beim Abhaken erhalten', () {
    final i = ShopItem.fromJson({
      'id': 'a',
      'list_id': 'l',
      'name': 'Milch',
      'status': 'needed',
      'price': 1.29,
      'photo': {'ref': 'x'},
      'schema_version': 4,
    });
    i.markBought('Sarah', DateTime(2026, 11, 12));
    final out = i.toJson();
    expect(out['price'], 1.29);
    expect(out['photo'], {'ref': 'x'});
    expect(out['status'], 'recent');
    expect(out['schema_version'], kSchemaVersion);
  });

  test('Unbekannter Status: sichtbar als "zu kaufen", Status bleibt erhalten', () {
    final i = ShopItem.fromJson(
        {'id': 'a', 'list_id': 'l', 'name': 'Brot', 'status': 'in_cart'});
    expect(i.needed, isTrue);
    expect(i.toJson()['status'], 'in_cart');
    i.markBought('Sebastian', DateTime(2026, 11, 12));
    expect(i.toJson()['status'], 'recent');
  });

  test('Falsche Typen führen zu Standardwerten statt Absturz', () {
    final i = ShopItem.fromJson({
      'id': 'a',
      'list_id': 3,
      'name': ['x'],
      'purchase_count': '2',
      'purchase_history': ['2026-11-01T10:00:00', 7, null],
      'added_at': false,
      'spec': null,
    });
    expect(i.name, '');
    expect(i.listId, '');
    expect(i.purchaseCount, 2);
    expect(i.purchaseHistory.length, 1);
    expect(i.spec, '');
  });

  test('ID aus dem Dateinamen, Dokument ohne ID wird abgelehnt', () {
    expect(ShopItem.fromJson({'name': 'x'}, path: 'items/abc.enc').id, 'abc');
    expect(() => ShopItem.fromJson({'name': 'x'}), throwsFormatException);
    expect(() => ShoppingList.fromJson({}), throwsFormatException);
  });

  test('Liste: unbekannte Felder und kaputte Bereichsreihenfolge', () {
    final l = ShoppingList.fromJson({
      'id': 'l',
      'name': 'Markt',
      'category_order': ['obst', 3, 'milch'],
      'members': ['Sarah'],
    });
    expect(l.categoryOrder, ['obst', 'milch']);
    l.categoryOrder.add('brot'); // muss veränderbar sein
    expect(l.toJson()['members'], ['Sarah']);
  });

  test('Signal ohne Zeitpunkt gilt als alt', () {
    final a = Activity.fromJson({'id': 'x', 'type': 'going_shopping'});
    expect(a.at.year, 1970);
    final b = Activity.fromJson(
        {'id': 'y', 'type': 'future_type', 'at': '2026-11-12T08:00:00', 'list_id': 'l', 'by': 'S', 'z': 1});
    expect(b.toJson()['z'], 1);
  });
}
