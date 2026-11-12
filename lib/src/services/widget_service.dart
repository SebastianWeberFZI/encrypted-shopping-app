import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

import '../core/source_config.dart';
import '../models/pikto.dart';
import '../settings.dart';
import '../shopping_repository.dart';

/// Startbildschirm-Widget der Einkaufsliste: zeigt die offenen Artikel einer
/// Liste (je Widget wählbar, sonst die aktuelle Liste der App); Antippen hakt
/// einen Artikel ab – ohne die App zu öffnen ([shoppingWidgetCallback]).
class ShoppingWidget {
  static const provider = 'de.sweber.encrypted_shopping_app.ShoppingWidgetProvider';
  static const _key = 'shopping_data';

  static Future<void> register() async {
    if (!Platform.isAndroid) return;
    try {
      await HomeWidget.registerInteractivityCallback(shoppingWidgetCallback);
    } catch (_) {}
  }

  /// Schreibt die Widget-Daten – aber nur, wenn sie sich geändert haben
  /// (Energie: sonst würde jeder Abgleich das Widget neu zeichnen).
  static Future<void> update(ShoppingRepository repo, LocalSettings settings) async {
    if (!Platform.isAndroid || !repo.isOpen) return;
    final lists = repo.lists;
    final current = lists.where((l) => l.id == settings.currentListId).firstOrNull ??
        (lists.isEmpty ? null : lists.first);
    final data = {
      'default_list': current?.id ?? '',
      'lists': [
        for (final l in lists)
          {'id': l.id, 'n': l.name, 'e': l.emoji, 'i': ?resolvePikto(emoji: l.emoji), 'c': l.color}
      ],
      'items': {
        for (final l in lists)
          l.id: [
            for (final i in repo.needed(l.id))
              {
                'id': i.id,
                'n': i.name,
                'e': i.emoji,
                'i': ?resolvePikto(icon: i.icon, name: i.name, emoji: i.emoji),
                's': i.spec,
              }
          ]
      },
    };
    try {
      final encoded = jsonEncode(data);
      final previous = await HomeWidget.getWidgetData<String>(_key);
      if (encoded == previous) return;
      await HomeWidget.saveWidgetData<String>(_key, encoded);
      await HomeWidget.updateWidget(qualifiedAndroidName: provider);
    } catch (_) {
      // Kein Widget-Support (z. B. Tests) – nicht kritisch.
    }
  }

  /// Sperrbildschirm-Liste ein/aus: Kotlin (LockList) liest den Schalter aus
  /// den Widget-Daten und zeichnet die Benachrichtigung beim nächsten Update.
  static Future<void> setLockList(bool on) async {
    if (!Platform.isAndroid) return;
    try {
      await HomeWidget.saveWidgetData<bool>('lock_list', on);
      await HomeWidget.updateWidget(qualifiedAndroidName: provider);
    } catch (_) {}
  }

  static Future<bool> canPin() async {
    if (!Platform.isAndroid) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> pin() => HomeWidget.requestPinWidget(qualifiedAndroidName: provider);
}

/// Läuft in einem Hintergrund-Isolate, wenn im Widget ein Artikel angetippt
/// wird (einkauf://check?item=…): als gekauft markieren, Widget aktualisieren,
/// abgleichen – Sarah sieht es dann sofort.
@pragma('vm:entry-point')
Future<void> shoppingWidgetCallback(Uri? uri) async {
  if (uri == null || uri.host != 'check') return;
  final id = uri.queryParameters['item'];
  if (id == null || id.isEmpty) return;
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final settings = await LocalSettings.load();
  final dir = await getApplicationSupportDirectory();
  final repo = ShoppingRepository(
      baseDir: dir.path, configStore: SourceConfigStore(), userName: () => settings.userName);
  await repo.open();
  if (!repo.isOpen) return;
  final item = repo.items.where((i) => i.id == id).firstOrNull;
  if (item != null && item.needed) await repo.markBought(item);
  await ShoppingWidget.update(repo, settings);
  try {
    await repo.sync();
  } catch (e) {
    debugPrint('Widget-Abgleich fehlgeschlagen: $e');
  }
  await ShoppingWidget.update(repo, settings);
}
