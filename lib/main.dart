import 'dart:async';
import 'dart:io';

import 'dart:ui' show PlatformDispatcher, PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app_state.dart';
import 'src/background/background_worker.dart';
import 'src/core/app_log.dart';
import 'src/core/source_config.dart';
import 'src/models/lizenzen.dart';
import 'src/services/notification_service.dart';
import 'src/settings.dart';
import 'src/shopping_repository.dart';
import 'src/ui/main_shell.dart';
import 'src/ui/onboarding_screen.dart';

const kSeed = Color(0xFF2F7D6B);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerLizenzen();
  final settings = await LocalSettings.load();
  final dir = await getApplicationSupportDirectory();
  await AppLog.init(dir.path);
  FlutterError.onError = (details) {
    // Mit dem auslösenden Widget (z. B. bei Layout-Überläufen), gekürzt.
    final text = details.toString();
    AppLog.error('flutter', text.length > 1500 ? '${text.substring(0, 1500)}…' : text, null,
        details.exception is Error ? details.stack : null);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.error('app', 'Unbehandelter Fehler', error, stack);
    return false;
  };
  unawaited(PackageInfo.fromPlatform().then((p) => AppLog.info('app',
      'Start, Version ${p.version} (${p.buildNumber}), ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')).catchError((_) {}));
  final repo = ShoppingRepository(
      baseDir: dir.path, configStore: SourceConfigStore(), userName: () => settings.userName);
  final state = AppState(repo: repo, settings: settings, notifications: NotificationService());
  runApp(ShoppingApp(state: state));
  await state.initialize();
  unawaited(registerBackgroundWork().catchError((Object e) {
    AppLog.warn('app', 'Hintergrund-Sync nicht verfügbar: $e');
  }));
}

ThemeData _theme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: kSeed, brightness: b);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final bg = b == Brightness.light ? const Color(0xFFFBFAF7) : null;
  return base.copyWith(
    scaffoldBackgroundColor: bg,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: bg,
      scrolledUnderElevation: 0,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

class ShoppingApp extends StatelessWidget {
  const ShoppingApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(
        title: 'Einkaufsliste',
        debugShowCheckedModeBanner: false,
        scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        }),
        locale: const Locale('de'),
        supportedLocales: const [Locale('de')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: !state.initialized
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : state.isConfigured
                ? MainShell(state: state)
                : OnboardingScreen(state: state),
      ),
    );
  }
}
