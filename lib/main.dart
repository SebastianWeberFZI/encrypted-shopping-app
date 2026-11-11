import 'dart:async';

import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app_state.dart';
import 'src/background/background_worker.dart';
import 'src/core/source_config.dart';
import 'src/services/notification_service.dart';
import 'src/settings.dart';
import 'src/shopping_repository.dart';
import 'src/ui/home_screen.dart';
import 'src/ui/onboarding_screen.dart';

const kSeed = Color(0xFF2F7D6B);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await LocalSettings.load();
  final dir = await getApplicationSupportDirectory();
  final repo = ShoppingRepository(
      baseDir: dir.path, configStore: SourceConfigStore(), userName: () => settings.userName);
  final state = AppState(repo: repo, settings: settings, notifications: NotificationService());
  runApp(ShoppingApp(state: state));
  await state.initialize();
  unawaited(registerBackgroundWork().catchError((Object e) {
    debugPrint('Hintergrund-Sync nicht verfügbar: $e');
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
                ? HomeScreen(state: state)
                : OnboardingScreen(state: state),
      ),
    );
  }
}
