import 'package:uuid/uuid.dart';

import 'catalog.dart';
import 'json_util.dart';

/// Version des Dokumentformats, mit der diese App schreibt. Jedes Dokument
/// trägt die Version der App, die es zuletzt gespeichert hat. Unbekannte
/// Felder neuerer Versionen bleiben über `extra` erhalten.
const int kSchemaVersion = 1;
String newId() => const Uuid().v4();

String _id(Map<String, dynamic> j, String? path, String what) {
  final id = idFromPath(path) ?? jStrOrNull(j['id']);
  if (id == null || id.isEmpty) throw FormatException('$what ohne ID');
  return id;
}

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
    Map<String, dynamic>? extra,
  })  : id = id ?? newId(),
        categoryOrder = categoryOrder ?? [],
        updatedAt = updatedAt ?? DateTime.now(),
        extra = extra ?? {};

  final String id;

  /// Unbekannte Felder (neuere App-Version), bleiben beim Speichern erhalten.
  final Map<String, dynamic> extra;
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
        ...extra,
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

  static const _known = {
    'id', 'name', 'emoji', 'color', 'sort_order', 'category_order',
    'updated_at', 'updated_by', 'schema_version',
  };

  factory ShoppingList.fromJson(Map<String, dynamic> j, {String? path}) =>
      ShoppingList(
        id: _id(j, path, 'Liste'),
        name: jStr(j['name'], 'Liste'),
        emoji: jStr(j['emoji'], '🛒'),
        color: jInt(j['color'], 0xFF2F7D6B),
        sortOrder: jInt(j['sort_order'], 0),
        categoryOrder: jStrings(j['category_order']),
        updatedAt: jDate(j['updated_at']),
        updatedBy: jStr(j['updated_by']),
        extra: unknownFields(j, _known),
      );
}

enum ItemStatus {
  needed,
  recent;

  static ItemStatus? tryName(Object? v) =>
      ItemStatus.values.where((s) => s.name == v).firstOrNull;
}

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
    Map<String, dynamic>? extra,
    this.unknownStatus,
  })  : addedAt = addedAt ?? DateTime.now(),
        purchaseHistory = purchaseHistory ?? [],
        updatedAt = updatedAt ?? DateTime.now(),
        extra = extra ?? {};

  final String id;

  /// Unbekannte Felder (neuere App-Version), bleiben beim Speichern erhalten.
  final Map<String, dynamic> extra;

  /// Status einer neueren App-Version. Der Artikel erscheint dann als "zu
  /// kaufen" (lieber sichtbar als verschwunden); der Status bleibt erhalten,
  /// bis jemand den Artikel hier abhakt oder neu hinzufügt.
  String? unknownStatus;
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
    unknownStatus = null;
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
    unknownStatus = null;
    addedBy = by;
    addedAt = now;
  }

  Map<String, dynamic> toJson() => {
        ...extra,
        'id': id,
        'list_id': listId,
        'name': name,
        'emoji': emoji,
        'category': category,
        if (spec.isNotEmpty) 'spec': spec,
        'status': unknownStatus ?? status.name,
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

  static const _known = {
    'id', 'list_id', 'name', 'emoji', 'category', 'spec', 'status',
    'added_by', 'added_at', 'done_by', 'done_at', 'purchase_count',
    'purchase_history', 'updated_at', 'updated_by', 'schema_version',
  };

  factory ShopItem.fromJson(Map<String, dynamic> j, {String? path}) {
    final rawStatus = j['status'];
    final status = ItemStatus.tryName(rawStatus);
    return ShopItem(
      id: _id(j, path, 'Artikel'),
      listId: jStr(j['list_id']),
      name: jStr(j['name']),
      emoji: jStr(j['emoji'], '🛍️'),
      category: jStr(j['category'], 'sonstiges'),
      spec: jStr(j['spec']),
      status: status ?? ItemStatus.needed,
      unknownStatus: status == null && rawStatus is String ? rawStatus : null,
      addedBy: jStr(j['added_by']),
      addedAt: jDate(j['added_at']),
      doneBy: jStr(j['done_by']),
      doneAt: jDate(j['done_at']),
      purchaseCount: jInt(j['purchase_count'], 0),
      purchaseHistory: jDates(j['purchase_history']),
      updatedAt: jDate(j['updated_at']),
      updatedBy: jStr(j['updated_by']),
      extra: unknownFields(j, _known),
    );
  }
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
    Map<String, dynamic>? extra,
  })  : id = id ?? newId(),
        updatedAt = updatedAt ?? DateTime.now(),
        extra = extra ?? {};

  final String id;
  final Map<String, dynamic> extra;
  String name;
  String emoji;
  String category;
  DateTime updatedAt;
  String updatedBy;

  String get path => 'catalog/$id.enc';

  Map<String, dynamic> toJson() => {
        ...extra,
        'id': id,
        'name': name,
        'emoji': emoji,
        'category': category,
        'updated_at': updatedAt.toIso8601String(),
        'updated_by': updatedBy,
        'schema_version': kSchemaVersion,
      };

  static const _known = {
    'id', 'name', 'emoji', 'category', 'updated_at', 'updated_by',
    'schema_version',
  };

  factory CustomArticle.fromJson(Map<String, dynamic> j, {String? path}) =>
      CustomArticle(
        id: _id(j, path, 'Katalogartikel'),
        name: jStr(j['name']),
        emoji: jStr(j['emoji'], '🛍️'),
        category: jStr(j['category'], 'sonstiges'),
        updatedAt: jDate(j['updated_at']),
        updatedBy: jStr(j['updated_by']),
        extra: unknownFields(j, _known),
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
    Map<String, dynamic>? extra,
  })  : id = id ?? newId(),
        at = at ?? DateTime.now(),
        extra = extra ?? {};

  final Map<String, dynamic> extra;

  static const goingShopping = 'going_shopping';
  static const doneShopping = 'done_shopping';

  final String id;
  final String type;
  final String listId;
  final String by;
  final DateTime at;

  String get path => 'activity/$id.enc';

  Map<String, dynamic> toJson() => {
        ...extra,
        'id': id,
        'type': type,
        'list_id': listId,
        'by': by,
        'at': at.toIso8601String(),
        'updated_at': at.toIso8601String(),
        'updated_by': by,
      };

  static const _known = {
    'id', 'type', 'list_id', 'by', 'at', 'updated_at', 'updated_by',
  };

  factory Activity.fromJson(Map<String, dynamic> j, {String? path}) =>
      Activity(
        id: _id(j, path, 'Signal'),
        type: jStr(j['type']),
        listId: jStr(j['list_id']),
        by: jStr(j['by']),
        // Ohne Zeitpunkt gilt das Signal als alt (keine Benachrichtigung).
        at: jDate(j['at']) ??
            jDate(j['updated_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        extra: unknownFields(j, _known),
      );
}
