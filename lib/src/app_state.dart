import 'dart:async';

import 'package:flutter/widgets.dart';

import 'core/github_api.dart';
import 'core/werkstatt.dart';
import 'models/shopping_models.dart';
import 'services/notification_service.dart';
import 'services/widget_service.dart';
import 'settings.dart';
import 'shopping_repository.dart';

/// Zentraler UI-Zustand der Einkaufsliste.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState({required this.repo, required this.settings, required this.notifications});

  final ShoppingRepository repo;
  final LocalSettings settings;
  final NotificationService notifications;

  bool initialized = false;
  bool syncing = false;
  Timer? _syncDebounce;
  Timer? _poll;
  Timer? _widgetDebounce;

  /// Hinweise für die UI (Snackbar), z. B. fremde Änderungen im Vordergrund.
  final ValueNotifier<String?> toast = ValueNotifier(null);

  bool get isConfigured => repo.isOpen && settings.userName.isNotEmpty;
  String get me => settings.userName;

  List<ShoppingList> get lists => repo.lists;

  ShoppingList? get currentList {
    final l = repo.lists;
    if (l.isEmpty) return null;
    return l.where((x) => x.id == settings.currentListId).firstOrNull ?? l.first;
  }

  void selectList(ShoppingList l) {
    settings.currentListId = l.id;
    notifyListeners();
    _scheduleWidget();
  }

  /// Startbildschirm-Widget gesammelt aktualisieren (nicht bei jedem Tippen).
  void _scheduleWidget() {
    _widgetDebounce?.cancel();
    _widgetDebounce = Timer(const Duration(milliseconds: 700),
        () => ShoppingWidget.update(repo, settings));
  }

  // ------------------------------------------------------------ Start

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    await repo.open();
    await notifications.init();
    await ShoppingWidget.register();
    initialized = true;
    _scheduleWidget();
    notifyListeners();
    _startPolling();
    if (repo.isOpen) unawaited(syncNow(silent: true));
  }

  /// Im Vordergrund alle 30 s abgleichen – beim gemeinsamen Einkaufen zählt Tempo.
  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      settings.foregroundBeat = DateTime.now();
      syncNow(silent: true);
    });
    settings.foregroundBeat = DateTime.now();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kWerkstatt) debugPrint('[Vordergrund] Lebenszyklus: $state');
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      unawaited(() async {
        if (await repo.reloadIfChangedOnDisk()) notifyListeners();
        await syncNow(silent: true);
      }());
    } else if (state == AppLifecycleState.paused) {
      _poll?.cancel();
      settings.foregroundBeat = null;
    }
  }

  // ------------------------------------------------------------ Artikel

  Future<ShopItem?> add(String name, {String? emoji, String? category, String spec = ''}) async {
    final l = currentList;
    if (l == null || name.trim().isEmpty) return null;
    final i = await repo.addItem(l.id, name, emoji: emoji, category: category, spec: spec);
    _changed();
    return i;
  }

  Future<void> bought(ShopItem i) async {
    await repo.markBought(i);
    _changed();
  }

  Future<void> needed(ShopItem i) async {
    await repo.markNeeded(i);
    _changed();
  }

  Future<void> removeFromList(ShopItem i) async {
    await repo.markNotNeeded(i);
    _changed();
  }

  Future<void> updateItem(ShopItem i) async {
    await repo.updateItem(i);
    _changed();
  }

  Future<void> removeItem(ShopItem i) async {
    await repo.removeItem(i);
    _changed();
  }

  /// Alle Artikel der Liste als gekauft markieren.
  Future<void> boughtAll() async {
    final l = currentList;
    if (l == null) return;
    for (final i in repo.needed(l.id)) {
      await repo.markBought(i);
    }
    await repo.postActivity(Activity.doneShopping, l.id);
    _changed();
  }

  Future<void> goingShopping() async {
    final l = currentList;
    if (l == null) return;
    await repo.postActivity(Activity.goingShopping, l.id);
    _changed();
  }

  Future<void> saveCustomArticle(CustomArticle a) async {
    await repo.saveCustomArticle(a);
    _changed();
  }

  // ------------------------------------------------------------ Listen

  Future<void> saveList(ShoppingList l) async {
    await repo.saveList(l);
    _changed();
  }

  Future<void> deleteList(ShoppingList l) async {
    await repo.deleteList(l);
    _changed();
  }

  void _changed() {
    notifyListeners();
    _scheduleWidget();
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 1500), () => syncNow(silent: true));
  }

  // ------------------------------------------------------------ Sync

  Future<void> syncNow({bool silent = false}) async {
    if (syncing || !repo.isOpen) return;
    syncing = true;
    if (!silent) notifyListeners();
    try {
      final r = await repo.sync();
      if (kWerkstatt) debugPrint('[Vordergrund] Sync: $r');
      if (r != null) {
        final summaries = repo.summarize(r, me);
        if (summaries.isNotEmpty) {
          // Im Vordergrund als Hinweis in der App statt System-Benachrichtigung.
          final texts = [
            for (final s in summaries)
              ...NotificationService.texts(s, repo.list(s.listId)?.name ?? 'Liste').map((t) => t.$2)
          ];
          toast.value = texts.join('\n');
        }
        if (r.pulled > 0) await repo.cleanupActivities();
        if (r.pulled > 0) _scheduleWidget();
      }
      if (!silent) toast.value ??= repo.error ?? repo.notice ?? 'Alles aktuell';
    } finally {
      syncing = false;
      notifyListeners();
      if (repo.error == null && repo.pendingCount > 0) {
        _syncDebounce?.cancel();
        _syncDebounce = Timer(const Duration(seconds: 3), () => syncNow(silent: true));
      }
    }
  }

  // ------------------------------------------------------------ Einrichtung

  void settingsChanged() => notifyListeners();

  void setUserName(String name) {
    settings.userName = name.trim();
    notifyListeners();
  }

  Future<bool> connect({required GithubConfig github, required String passphrase}) async {
    final fresh = await repo.connect(github: github, passphrase: passphrase);
    notifyListeners();
    return fresh;
  }

  Future<void> createDefaultLists() async {
    final defaults = [
      ShoppingList(name: 'Supermarkt', emoji: '🛒', color: 0xFF2F7D6B, sortOrder: 0),
      ShoppingList(name: 'Drogerie', emoji: '🧴', color: 0xFF8E5BB5, sortOrder: 1),
      ShoppingList(name: 'Baumarkt', emoji: '🔨', color: 0xFFC9762B, sortOrder: 2),
    ];
    for (final l in defaults) {
      await repo.saveList(l);
    }
    settings.currentListId = defaults.first.id;
    _changed();
  }

  Future<void> disconnect() async {
    await repo.disconnect();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }
}
