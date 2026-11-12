import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Vom Android-Teilen-Menü an die App übergebener Text (Rezeptlink oder Zutaten).
class ShareService {
  static const _channel = MethodChannel('einkauf/share');

  /// Text, mit dem die App gestartet wurde (einmalig).
  static Future<String?> initial() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('initial');
    } catch (_) {
      return null;
    }
  }

  /// Weitere geteilte Texte, während die App läuft.
  static void listen(void Function(String text) onText) {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared' && call.arguments is String) onText(call.arguments as String);
    });
  }
}
