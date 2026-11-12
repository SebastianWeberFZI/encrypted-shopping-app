import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import '../core/source_config.dart';
import '../core/werkstatt.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../settings.dart';
import '../shopping_repository.dart';

const kPeriodicTask = 'einkauf-sync';

/// Einstiegspunkt des Hintergrund-Workers (eigener Dart-Isolate, ca. alle
/// 15 Minuten): holt Änderungen und benachrichtigt über fremde Änderungen.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
      await runBackgroundCycle(force: input?['force'] == true);
    } catch (e) {
      debugPrint('Hintergrund-Sync fehlgeschlagen: $e');
    }
    return true;
  });
}

Future<void> runBackgroundCycle({bool force = false}) async {
  final settings = await LocalSettings.load();
  final beat = settings.foregroundBeat;
  if (!force && beat != null && DateTime.now().difference(beat).inMinutes < 3) {
    _log('übersprungen: App im Vordergrund (Herzschlag $beat)');
    return;
  }
  final dir = await getApplicationSupportDirectory();
  final repo = ShoppingRepository(
      baseDir: dir.path, configStore: SourceConfigStore(), userName: () => settings.userName);
  await repo.open();
  if (!repo.isOpen) {
    _log('kein Repo verbunden');
    return;
  }
  final r = await repo.sync();
  if (r != null && r.pulled > 0) await ShoppingWidget.update(repo, settings);
  if (r == null) {
    _log('Sync ohne Ergebnis (gesperrt oder Fehler: ${repo.error})');
    return;
  }
  final summaries = repo.summarize(r, settings.userName);
  _log('force=$force geholt=${r.pulled} Änderungen=${r.changes.length} Hinweise=${summaries.length}');
  if (summaries.isEmpty) return;
  final n = NotificationService();
  await n.init(requestPermissions: false);
  await n.showChanges(summaries, repo, settings);
}

Future<void> registerBackgroundWork() async {
  if (!Platform.isAndroid) return;
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    kPeriodicTask,
    kPeriodicTask,
    frequency: const Duration(minutes: 15),
    // Energie sparen: nur mit Netz (ohne Netz gibt es nichts abzugleichen).
    // „update“ übernimmt geänderte Bedingungen auch für bereits registrierte Aufgaben.
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}

/// Werkstatt-Test: denselben Hintergrund-Durchlauf einmalig nach [delay]
/// auslösen (periodische Arbeit lässt Android nicht vorzeitig laufen).
Future<void> triggerBackgroundOnce({Duration delay = const Duration(seconds: 15)}) async {
  if (!Platform.isAndroid) return;
  await Workmanager().registerOneOffTask(
    '$kPeriodicTask-test-${DateTime.now().millisecondsSinceEpoch}',
    '$kPeriodicTask-test',
    initialDelay: delay,
    inputData: {'force': true},
  );
}

void _log(String m) {
  if (kWerkstatt) debugPrint('[Hintergrund] $m');
}
