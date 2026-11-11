import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../settings.dart';
import '../shopping_repository.dart';

/// Benachrichtigungen über Änderungen der anderen Person.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _changes = NotificationDetails(
    android: AndroidNotificationDetails(
      'list_changes',
      'Änderungen an Listen',
      channelDescription: 'Wenn jemand Artikel hinzufügt oder einkauft',
      importance: Importance.defaultImportance,
    ),
  );
  static const _shopping = NotificationDetails(
    android: AndroidNotificationDetails(
      'going_shopping',
      'Ich gehe einkaufen',
      channelDescription: 'Wenn jemand gerade einkaufen geht',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> init({bool requestPermissions = true}) async {
    if (!Platform.isAndroid) return; // Linux-Vorschau: Hinweise nur in der App
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_notify'),
      ),
    );
    if (requestPermissions) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    _ready = true;
  }

  static String joinNames(List<String> names) {
    if (names.length == 1) return names.first;
    if (names.length <= 3) {
      return '${names.sublist(0, names.length - 1).join(', ')} und ${names.last}';
    }
    return '${names.take(2).join(', ')} und ${names.length - 2} weitere';
  }

  /// Texte für eine Zusammenfassung (Titel, Text, ist "einkaufen gehen").
  static List<(String, String, bool)> texts(ChangeSummary s, String listName) {
    final out = <(String, String, bool)>[];
    if (s.goingShopping) {
      out.add(('${s.by} geht einkaufen 🛒', 'Liste „$listName“ – jetzt noch schnell etwas draufsetzen?', true));
    }
    if (s.added.isNotEmpty) {
      out.add((listName, '${s.by} hat ${joinNames(s.added)} hinzugefügt', false));
    }
    if (s.bought.isNotEmpty) {
      out.add((listName,
          s.bought.length == 1
              ? '${s.by} hat ${s.bought.first} eingekauft ✓'
              : '${s.by} hat ${s.bought.length} Artikel eingekauft ✓',
          false));
    }
    if (s.doneShopping && s.bought.isEmpty) {
      out.add((listName, '${s.by} ist mit dem Einkauf fertig ✓', false));
    }
    return out;
  }

  Future<void> showChanges(List<ChangeSummary> summaries, ShoppingRepository repo, LocalSettings settings) async {
    if (!_ready) return;
    for (final s in summaries) {
      final listName = repo.list(s.listId)?.name ?? 'Einkaufsliste';
      for (final (title, body, shopping) in texts(s, listName)) {
        if (shopping && !settings.notifyShopping) continue;
        if (!shopping && !settings.notifyChanges) continue;
        await _plugin.show(
          id: '${s.listId}|${s.by}|$shopping'.hashCode & 0x7fffffff,
          title: title,
          body: body,
          notificationDetails: shopping ? _shopping : _changes,
        );
      }
    }
  }

  Future<void> showTest() async {
    if (!_ready) return;
    await _plugin.show(
      id: 1,
      title: 'Supermarkt',
      body: 'Sarah hat Milch, Brot und Äpfel hinzugefügt',
      notificationDetails: _changes,
    );
  }
}
