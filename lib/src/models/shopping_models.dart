import 'package:uuid/uuid.dart';

import 'catalog.dart';

const int kSchemaVersion = 1;
String newId() => const Uuid().v4();

DateTime? _dt(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// Eine Einkaufsliste (z. B. Supermarkt, Drogerie).
class ShoppingList {
  ShoppingList({
    String? id,
    required this.name,
    this.emoji = '🛒',
    this.color = 0xFF2F7D6B,
    this.sortOrder = 0,
    List<String>? categoryOrder,
    DateTime? updatedAt,
    this.updatedBy = '',
  })  : id = id ?? newId(),
        categoryOrder = categoryOrder ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String name;
  String emoji;
  int color;
  int sortOrder;

  /// Reihenfolge der Ladenbereiche; leer = Standard.
  List<String> categoryOrder;
  DateTime updatedAt;
  String updatedBy;

  String get path => 'lists/$id.enc';

  int categoryRank(String key) {
    final order = categoryOrder.isEmpty
        ? kCategories.map((c) => c.key).toList()
        : categoryOrder;
    final i = order.indexOf(key);
    return i < 0 ? 999 : i;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color': color,
        'sort_order': sortOrder,
        if (categoryOrder.isNotEmpty) 'category_order': categoryOrder,
        'updated_at': updatedAt.toIso8601String(),
        'updated_by': updatedBy,
        'schema_version': kSchemaVersion,
      };

  factory ShoppingList.fromJson(Map<String, dynamic> j) => ShoppingList(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Liste',
        emoji: j['emoji'] as String? ?? '🛒',
        color: (j['color'] as num?)?.toInt() ?? 0xFF2F7D6B,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
        categoryOrder: (j['category_order'] as List? ?? []).cast<String>(),
        updatedAt: _dt(j['updated_at']),
        updatedBy: j['updated_by'] as String? ?? '',
      );
}

enum ItemStatus { needed, recent }

/// Ein Artikel auf einer Liste. Die ID ist deterministisch
/// (HMAC über Liste + Name), damit gleichzeitiges Hinzufügen desselben
/// Artikels auf zwei Handys keine Dublette erzeugt.
class ShopItem {
  ShopItem({
    required this.id,
    required this.listId,
    required this.name,
    this.emoji = '🛍️',
    this.category = 'sonstiges',
    this.spec = '',
    this.status = ItemStatus.needed,
    this.addedBy = '',
    DateTime? addedAt,
    this.doneBy = '',
    this.doneAt,
    this.purchaseCount = 0,
    List<DateTime>? purchaseHistory,
    DateTime? updatedAt,
    this.updatedBy = '',
  })  : addedAt = addedAt ?? DateTime.now(),
        purchaseHistory = purchaseHistory ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String listId;
  String name;
  String emoji;
  String category;
  String spec;
  ItemStatus status;
  String addedBy;
  DateTime addedAt;
  String doneBy;
  DateTime? doneAt;
  int purchaseCount;

  /// Letzte Kaufzeitpunkte (max. 10) – Grundlage für Vorschläge.
  List<DateTime> purchaseHistory;
  DateTime updatedAt;
  String updatedBy;

  String get path => 'items/$id.enc';
  bool get needed => status == ItemStatus.needed;

  DateTime? get lastPurchased => purchaseHistory.isEmpty
      ? null
      : purchaseHistory.reduce((a, b) => a.isAfter(b) ? a : b);

  /// Durchschnittlicher Abstand zwischen zwei Käufen.
  Duration? get averageInterval {
    if (purchaseHistory.length < 2) return null;
    final sorted = List.of(purchaseHistory)..sort();
    final total = sorted.last.difference(sorted.first);
    return Duration(seconds: total.inSeconds ~/ (sorted.length - 1));
  }

  /// Wie "überfällig" ein erneuter Kauf ist (>= 1 = fällig).
  double dueRatio(DateTime now) {
    final avg = averageInterval;
    final last = lastPurchased;
    if (avg == null || last == null || avg.inHours < 12) return 0;
    return now.difference(last).inSeconds / avg.inSeconds;
  }

  /// Als gekauft markieren (wandert zu "Zuletzt verwendet").
  void markBought(String by, DateTime now) {
    status = ItemStatus.recent;
    doneBy = by;
    doneAt = now;
    purchaseCount++;
    purchaseHistory = [...purchaseHistory, now];
    if (purchaseHistory.length > 10) {
      purchaseHistory = purchaseHistory.sublist(purchaseHistory.length - 10);
    }
  }

  /// Wieder auf die Liste setzen.
  void markNeeded(String by, DateTime now) {
    status = ItemStatus.needed;
    addedBy = by;
    addedAt = now;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'list_id': listId,
        'name': name,
        'emoji': emoji,
        'category': category,
        if (spec.isNotEmpty) 'spec': spec,
        'status': status.name,
        'added_by': addedBy,
        'added_at': addedAt.toIso8601String(),
        if (doneBy.isNotEmpty) 'done_by': doneBy,
        if (doneAt != null) 'done_at': doneAt!.toIso8601String(),
        'purchase_count': purchaseCount,
        'purchase_history':
            purchaseHistory.map((d) => d.toIso8601String()).toList(),
        'updated_at': updatedAt.toIso8601String(),
        'updated_by': updatedBy,
        'schema_version': kSchemaVersion,
      };

  factory ShopItem.fromJson(Map<String, dynamic> j) => ShopItem(
        id: j['id'] as String,
        listId: j['list_id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        emoji: j['emoji'] as String? ?? '🛍️',
        category: j['category'] as String? ?? 'sonstiges',
        spec: j['spec'] as String? ?? '',
        status:
            j['status'] == 'recent' ? ItemStatus.recent : ItemStatus.needed,
        addedBy: j['added_by'] as String? ?? '',
        addedAt: _dt(j['added_at']),
        doneBy: j['done_by'] as String? ?? '',
        doneAt: _dt(j['done_at']),
        purchaseCount: (j['purchase_count'] as num?)?.toInt() ?? 0,
        purchaseHistory: (j['purchase_history'] as List? ?? [])
            .map((e) => DateTime.tryParse(e as String))
            .whereType<DateTime>()
            .toList(),
        updatedAt: _dt(j['updated_at']),
        updatedBy: j['updated_by'] as String? ?? '',
      );
}

/// Eigener Katalogartikel (gilt für alle Listen).
class CustomArticle {
  CustomArticle({
    String? id,
    required this.name,
    this.emoji = '🛍️',
    this.category = 'sonstiges',
    DateTime? updatedAt,
    this.updatedBy = '',
  })  : id = id ?? newId(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String name;
  String emoji;
  String category;
  DateTime updatedAt;
  String updatedBy;

  String get path => 'catalog/$id.enc';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'category': category,
        'updated_at': updatedAt.toIso8601String(),
        'updated_by': updatedBy,
        'schema_version': kSchemaVersion,
      };

  factory CustomArticle.fromJson(Map<String, dynamic> j) => CustomArticle(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        emoji: j['emoji'] as String? ?? '🛍️',
        category: j['category'] as String? ?? 'sonstiges',
        updatedAt: _dt(j['updated_at']),
        updatedBy: j['updated_by'] as String? ?? '',
      );
}

/// Signal an die andere Person, z. B. "Ich gehe einkaufen".
class Activity {
  Activity({
    String? id,
    required this.type,
    required this.listId,
    required this.by,
    DateTime? at,
  })  : id = id ?? newId(),
        at = at ?? DateTime.now();

  static const goingShopping = 'going_shopping';
  static const doneShopping = 'done_shopping';

  final String id;
  final String type;
  final String listId;
  final String by;
  final DateTime at;

  String get path => 'activity/$id.enc';

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'list_id': listId,
        'by': by,
        'at': at.toIso8601String(),
        'updated_at': at.toIso8601String(),
        'updated_by': by,
      };

  factory Activity.fromJson(Map<String, dynamic> j) => Activity(
        id: j['id'] as String,
        type: j['type'] as String? ?? '',
        listId: j['list_id'] as String? ?? '',
        by: j['by'] as String? ?? '',
        at: _dt(j['at']),
      );
}
