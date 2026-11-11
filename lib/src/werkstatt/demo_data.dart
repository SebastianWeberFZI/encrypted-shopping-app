import '../app_state.dart';
import '../models/shopping_models.dart';

/// Demo-Artikel inkl. Kaufverlauf (für Vorschläge) – nur Werkstatt.
Future<void> addDemoItems(AppState state) async {
  final lists = state.lists;
  if (lists.isEmpty) return;
  final market = lists.first;
  final drug = lists.length > 1 ? lists[1] : market;
  final now = DateTime.now();
  final other = state.me == 'Sarah' ? 'Sebastian' : 'Sarah';

  Future<void> needed(String listId, String name, {String spec = '', String? by}) async {
    final i = await state.repo.addItem(listId, name, spec: spec);
    if (by != null) {
      i.addedBy = by;
      i.addedAt = now.subtract(const Duration(minutes: 25));
      await state.repo.updateItem(i);
    }
  }

  /// Regelmäßig gekauft: alle [everyDays] Tage, zuletzt vor [lastDaysAgo] Tagen.
  Future<void> history(String listId, String name, int everyDays, int lastDaysAgo) async {
    final i = await state.repo.addItem(listId, name);
    i.status = ItemStatus.recent;
    i.purchaseHistory = [
      for (var k = 4; k >= 0; k--) now.subtract(Duration(days: lastDaysAgo + k * everyDays)),
    ];
    i.purchaseCount = 5;
    i.doneBy = other;
    i.doneAt = i.purchaseHistory.last;
    await state.repo.updateItem(i);
  }

  await history(market.id, 'Bananen', 5, 6);
  await history(market.id, 'Eier', 7, 8);
  await history(market.id, 'Toilettenpapier', 14, 15);
  await history(market.id, 'Hafermilch', 4, 2);
  await history(market.id, 'Butter', 9, 3);
  await history(market.id, 'Joghurt', 6, 1);
  await history(market.id, 'Nudeln', 12, 4);
  await history(market.id, 'Zwiebeln', 10, 5);

  await needed(market.id, 'Milch', spec: '2 l');
  await needed(market.id, 'Brot');
  await needed(market.id, 'Äpfel', spec: '1 kg');
  await needed(market.id, 'Tomaten');
  await needed(market.id, 'Käse', spec: 'Gouda, am Stück');
  await needed(market.id, 'Kaffee', by: other);
  await needed(market.id, 'Spülmaschinentabs', by: other);
  await needed(market.id, 'Basilikum');

  await needed(drug.id, 'Zahnpasta');
  await needed(drug.id, 'Shampoo', spec: 'für trockenes Haar', by: other);
  await history(drug.id, 'Duschgel', 21, 10);
}
