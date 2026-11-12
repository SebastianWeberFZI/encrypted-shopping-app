import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import 'core/crypto_service.dart';
import 'core/doc_store.dart';
import 'core/github_api.dart';
import 'core/source_config.dart';
import 'core/sync_engine.dart';
import 'models/catalog.dart';
import 'models/json_util.dart';
import 'models/shopping_models.dart';

const String kAppId = 'encrypted-shopping';

/// Hinweis, wenn Einträge im Format einer neueren App-Version vorliegen.
const String kNewerDataHint = 'Einige Einträge stammen von einer neueren '
    'App-Version und erscheinen erst nach einem Update.';

class SetupException implements Exception {
  const SetupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Zusammenfassung fremder Änderungen einer Liste (für Benachrichtigungen).
class ChangeSummary {
  ChangeSummary(this.listId, this.by);
  final String listId;
  final String by;
  final List<String> added = [];
  final List<String> bought = [];
  bool goingShopping = false;
  bool doneShopping = false;

  bool get isEmpty => added.isEmpty && bought.isEmpty && !goingShopping && !doneShopping;
}

/// Datenzugriff der Einkaufsliste (eine Datenquelle = ein gemeinsames Repo).
/// Ohne UI-Abhängigkeiten, damit auch der Hintergrund-Worker ihn nutzt.
class ShoppingRepository {
  ShoppingRepository({
    required this.baseDir,
    required this.configStore,
    required this.userName,
  });

  final String baseDir;
  final SourceConfigStore configStore;
  String Function() userName;
  final CryptoService crypto = CryptoService();

  SourceConfig? config;
  SecretKey? _key;
  DocStore? store;
  GithubApi? api;
  SyncEngine? engine;
  bool syncing = false;
  String? error;

  /// Hinweis ohne Fehlercharakter (z. B. Daten einer neueren App-Version).
  String? notice;

  int _version = 0;
  int _cacheVersion = -1;
  List<ShoppingList> _lists = [];
  List<ShopItem> _items = [];
  List<CustomArticle> _custom = [];
  List<Activity> _activities = [];

  int get version => _version;
  void touch() => _version++;
  bool get isOpen => store != null;

  // ------------------------------------------------------------ Öffnen

  Future<void> open() async {
    final all = await configStore.load();
    final cfg = all.where((c) => c.masterKeyB64.isNotEmpty).firstOrNull;
    if (cfg == null) return;
    await _open(cfg);
  }

  /// Öffnet die gespeicherte Datenquelle mit einem vorgegebenen API-Client
  /// (für Tests mit einem Fake-GitHub).
  Future<void> openWith(GithubApi testApi) async {
    final cfg = (await configStore.load()).first;
    await _open(cfg, apiOverride: testApi);
  }

  Future<void> _open(SourceConfig cfg, {GithubApi? apiOverride}) async {
    config = cfg;
    _key = SecretKey(base64Decode(cfg.masterKeyB64));
    store = DocStore(baseDir: '$baseDir/data', crypto: crypto, key: _key!);
    await store!.init();
    api = apiOverride ?? GithubApi(cfg.github);
    engine = SyncEngine(
      store: store!,
      api: api!,
      crypto: crypto,
      key: _key!,
      managedDirs: const ['lists', 'items', 'catalog', 'activity'],
      // Keine Konfliktkopien: eine doppelte "Milch" wäre schlimmer als ein
      // verlorener Zwischenstand.
    );
    touch();
  }

  Future<bool> reloadIfChangedOnDisk() async {
    if (store == null || !await store!.changedOnDisk()) return false;
    await store!.init();
    touch();
    return true;
  }

  // ------------------------------------------------------------ Lesen

  void _rebuild() {
    if (_cacheVersion == _version) return;
    final s = store;
    T? safe<T>(T Function() f) {
      try {
        return f();
      } catch (_) {
        return null;
      }
    }

    _lists = s == null
        ? []
        : (s.inDir('lists').map((e) => safe(() => ShoppingList.fromJson(e.value, path: e.key))).whereType<ShoppingList>().toList()
          ..sort((a, b) {
            final c = a.sortOrder.compareTo(b.sortOrder);
            return c != 0 ? c : a.name.compareTo(b.name);
          }));
    _items = s == null
        ? []
        : s.inDir('items').map((e) => safe(() => ShopItem.fromJson(e.value, path: e.key))).whereType<ShopItem>().toList();
    _custom = s == null
        ? []
        : s.inDir('catalog').map((e) => safe(() => CustomArticle.fromJson(e.value, path: e.key))).whereType<CustomArticle>().toList();
    _activities = s == null
        ? []
        : (s.inDir('activity').map((e) => safe(() => Activity.fromJson(e.value, path: e.key))).whereType<Activity>().toList()
          ..sort((a, b) => b.at.compareTo(a.at)));
    _cacheVersion = _version;
  }

  List<ShoppingList> get lists {
    _rebuild();
    return _lists;
  }

  List<ShopItem> get items {
    _rebuild();
    return _items;
  }

  List<CustomArticle> get customArticles {
    _rebuild();
    return _custom;
  }

  List<Activity> get activities {
    _rebuild();
    return _activities;
  }

  ShoppingList? list(String id) => lists.where((l) => l.id == id).firstOrNull;

  /// Zu kaufen, sortiert nach Ladenbereich (Reihenfolge der Liste), dann
  /// nach Zeitpunkt des Hinzufügens.
  List<ShopItem> needed(String listId) {
    final l = list(listId);
    return items.where((i) => i.listId == listId && i.needed).toList()
      ..sort((a, b) {
        final r = (l?.categoryRank(a.category) ?? 0).compareTo(l?.categoryRank(b.category) ?? 0);
        return r != 0 ? r : a.addedAt.compareTo(b.addedAt);
      });
  }

  /// Zuletzt verwendet, jüngste zuerst.
  List<ShopItem> recent(String listId) =>
      items.where((i) => i.listId == listId && !i.needed).toList()
        ..sort((a, b) => (b.doneAt ?? b.updatedAt).compareTo(a.doneAt ?? a.updatedAt));

  /// Vorschläge: regelmäßig gekaufte Artikel, deren übliches Intervall
  /// (fast) abgelaufen ist.
  List<ShopItem> suggestions(String listId, {DateTime? now, int max = 8}) {
    final t = now ?? DateTime.now();
    final list = recent(listId).where((i) => i.purchaseCount >= 2 && i.dueRatio(t) >= 0.85).toList()
      ..sort((a, b) => b.dueRatio(t).compareTo(a.dueRatio(t)));
    return list.take(max).toList();
  }

  ShopItem? itemByName(String listId, String name) {
    final n = normalizeName(name);
    return items.where((i) => i.listId == listId && normalizeName(i.name) == n).firstOrNull;
  }

  // ------------------------------------------------------------ Schreiben

  Future<String> itemId(String listId, String name) =>
      crypto.deterministicId('$listId\n${normalizeName(name)}', _key!);

  Future<void> _putItem(ShopItem i) async {
    i.updatedAt = DateTime.now();
    i.updatedBy = userName();
    await store!.put(i.path, i.toJson());
    touch();
  }

  /// Setzt einen Artikel auf die Liste (legt ihn ggf. an).
  Future<ShopItem> addItem(String listId, String name,
      {String? emoji, String? icon, String? category, String spec = ''}) async {
    final now = DateTime.now();
    final existing = itemByName(listId, name);
    if (existing != null) {
      existing.markNeeded(userName(), now);
      if (spec.isNotEmpty) existing.spec = spec;
      await _putItem(existing);
      return existing;
    }
    final cat = catalogLookup(name);
    final custom = customArticles.where((c) => normalizeName(c.name) == normalizeName(name)).firstOrNull;
    final item = ShopItem(
      id: await itemId(listId, name),
      listId: listId,
      name: cat?.name ?? custom?.name ?? name.trim(),
      emoji: emoji ?? cat?.emoji ?? custom?.emoji ?? categoryByKey(category ?? guessCategory(name)).emoji,
      icon: icon ?? custom?.icon,
      category: category ?? cat?.category ?? custom?.category ?? guessCategory(name),
      spec: spec,
      addedBy: userName(),
      addedAt: now,
    );
    await _putItem(item);
    return item;
  }

  Future<void> markBought(ShopItem i) async {
    i.markBought(userName(), DateTime.now());
    await _putItem(i);
  }

  Future<void> markNeeded(ShopItem i) async {
    i.markNeeded(userName(), DateTime.now());
    await _putItem(i);
  }

  /// Von der Liste nehmen, ohne es als gekauft zu zählen.
  Future<void> markNotNeeded(ShopItem i) async {
    i
      ..status = ItemStatus.recent
      ..unknownStatus = null;
    await _putItem(i);
  }

  Future<void> updateItem(ShopItem i) => _putItem(i);

  Future<void> removeItem(ShopItem i) async {
    await store!.delete(i.path);
    touch();
  }

  Future<void> saveList(ShoppingList l) async {
    l.updatedAt = DateTime.now();
    l.updatedBy = userName();
    await store!.put(l.path, l.toJson());
    touch();
  }

  Future<void> deleteList(ShoppingList l) async {
    for (final i in items.where((i) => i.listId == l.id).toList()) {
      await store!.delete(i.path, persistState: false);
    }
    await store!.delete(l.path);
    touch();
  }

  Future<void> saveCustomArticle(CustomArticle a) async {
    a.updatedAt = DateTime.now();
    a.updatedBy = userName();
    await store!.put(a.path, a.toJson());
    touch();
  }

  Future<void> postActivity(String type, String listId) async {
    final a = Activity(type: type, listId: listId, by: userName());
    await store!.put(a.path, a.toJson());
    touch();
  }

  /// Signale älter als 7 Tage aufräumen.
  Future<void> cleanupActivities() async {
    final limit = DateTime.now().subtract(const Duration(days: 7));
    for (final a in activities.where((a) => a.at.isBefore(limit)).toList()) {
      await store!.delete(a.path, persistState: false);
    }
    await store!.saveState();
    touch();
  }

  // ------------------------------------------------------------ Sync

  Future<SyncResult?> sync() async {
    if (engine == null || syncing) return null;
    syncing = true;
    try {
      final r = await engine!.sync();
      error = null;
      notice = r.newer > 0 ? kNewerDataHint : null;
      if (r.pulled > 0 || r.conflicts > 0 || r.newer > 0) touch();
      return r;
    } on RepoTooNewException catch (e) {
      error = e.message;
    } on GithubApiException catch (e) {
      error = e.isUnauthorized ? 'Token ungültig oder abgelaufen.' : 'Sync fehlgeschlagen: ${e.message}';
    } catch (e) {
      error = 'Keine Verbindung – Änderungen werden später übertragen.';
    } finally {
      syncing = false;
    }
    return null;
  }

  /// Fasst fremde Änderungen je Liste und Person zusammen.
  List<ChangeSummary> summarize(SyncResult r, String me) {
    final out = <String, ChangeSummary>{};
    ChangeSummary sum(String listId, String by) =>
        out.putIfAbsent('$listId|$by', () => ChangeSummary(listId, by));
    for (final c in r.changes) {
      final after = c.after;
      if (after == null) continue;
      final by = jStr(after['updated_by']);
      if (by.isEmpty || by == me) continue;
      if (c.path.startsWith('items/')) {
        final listId = jStr(after['list_id']);
        final now = after['status'];
        final before = c.before?['status'];
        final name = jStr(after['name']);
        if (name.isEmpty) continue;
        if (now == 'needed' && before != 'needed') sum(listId, by).added.add(name);
        if (now == 'recent' && before == 'needed') sum(listId, by).bought.add(name);
      } else if (c.path.startsWith('activity/') && c.before == null) {
        final Activity a;
        try {
          a = Activity.fromJson(after, path: c.path);
        } catch (_) {
          continue;
        }
        if (DateTime.now().difference(a.at).inHours > 3) continue;
        if (a.type == Activity.goingShopping) sum(a.listId, by).goingShopping = true;
        if (a.type == Activity.doneShopping) sum(a.listId, by).doneShopping = true;
      }
    }
    return out.values.where((s) => !s.isEmpty).toList();
  }

  int get pendingCount => store?.pendingCount ?? 0;
  DateTime? get lastSync => store?.lastSync;

  // ------------------------------------------------------------ Einrichtung

  static Future<String?> testConnection(GithubConfig cfg) async {
    try {
      await GithubApi(cfg).testConnection();
      return null;
    } on GithubApiException catch (e) {
      if (e.isNotFound) return 'Repository nicht gefunden – Name und Token-Berechtigung prüfen.';
      if (e.isUnauthorized) return 'Token ungültig oder ohne Berechtigung.';
      return e.toString();
    } catch (e) {
      return 'Verbindung fehlgeschlagen: $e';
    }
  }

  /// Verbindet das Daten-Repo. Liefert true, wenn es neu initialisiert wurde.
  Future<bool> connect({required GithubConfig github, required String passphrase}) async {
    final api = GithubApi(github);
    try {
      await api.testConnection();
    } on GithubApiException catch (e) {
      throw SetupException(e.isNotFound
          ? 'Repository nicht gefunden.'
          : e.isUnauthorized
              ? 'Token ungültig oder ohne Berechtigung.'
              : 'GitHub-Zugriff fehlgeschlagen: ${e.message}');
    } catch (e) {
      throw SetupException('Keine Verbindung zu ${github.apiBase}: $e');
    }
    final CryptoParams? existing;
    try {
      existing = await SyncEngine.fetchMeta(api);
    } on RepoTooNewException catch (e) {
      throw SetupException(e.message);
    } on FormatException {
      throw const SetupException('meta.json im Repository ist beschädigt.');
    }
    final fresh = existing == null;
    final params = existing ?? CryptoParams.generate();
    final key = await crypto.deriveKey(passphrase, params);
    if (fresh) {
      await SyncEngine.initializeRemote(api, crypto, key, params, app: kAppId);
    } else {
      bool ok;
      try {
        ok = await SyncEngine.verifyKey(api, crypto, key);
      } on RepoTooNewException catch (e) {
        throw SetupException(e.message);
      }
      if (!ok) {
        throw const SetupException('Passphrase falsch – sie passt nicht zu den Daten im Repository.');
      }
    }
    final cfg = SourceConfig(
      id: const Uuid().v4().substring(0, 8),
      label: 'Einkauf',
      owner: github.owner,
      repo: github.repo,
      branch: github.branch,
      token: github.token,
      apiBase: github.apiBase,
      masterKeyB64: base64Encode(await key.extractBytes()),
      cryptoParams: params,
    );
    await configStore.save([cfg]);
    await _open(cfg);
    await sync();
    return fresh;
  }

  /// Entfernt die Verbindung und alle lokalen Daten (Repo bleibt erhalten).
  Future<void> disconnect() async {
    await store?.wipe();
    await configStore.save([]);
    config = null;
    store = null;
    api = null;
    engine = null;
    touch();
  }
}
