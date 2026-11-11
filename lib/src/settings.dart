import 'package:shared_preferences/shared_preferences.dart';

/// Geräte-lokale Einstellungen der Einkaufsliste (keine Geheimnisse).
class LocalSettings {
  LocalSettings._(this._p);
  final SharedPreferences _p;

  static Future<LocalSettings> load() async =>
      LocalSettings._(await SharedPreferences.getInstance());

  Future<void> reload() => _p.reload();

  String get userName => _p.getString('user_name') ?? '';
  set userName(String v) => _p.setString('user_name', v);

  String get currentListId => _p.getString('current_list') ?? '';
  set currentListId(String v) => _p.setString('current_list', v);

  /// Benachrichtigen, wenn die andere Person Artikel hinzufügt/abhakt.
  bool get notifyChanges => _p.getBool('notify_changes') ?? true;
  set notifyChanges(bool v) => _p.setBool('notify_changes', v);

  /// Benachrichtigen bei "Ich gehe einkaufen".
  bool get notifyShopping => _p.getBool('notify_shopping') ?? true;
  set notifyShopping(bool v) => _p.setBool('notify_shopping', v);

  bool get showSuggestions => _p.getBool('show_suggestions') ?? true;
  set showSuggestions(bool v) => _p.setBool('show_suggestions', v);

  bool get showCatalog => _p.getBool('show_catalog') ?? true;
  set showCatalog(bool v) => _p.setBool('show_catalog', v);

  /// Kachelgröße: 3 oder 4 Spalten.
  int get columns => _p.getInt('columns') ?? 4;
  set columns(int v) => _p.setInt('columns', v);

  DateTime? get foregroundBeat =>
      DateTime.tryParse(_p.getString('foreground_beat') ?? '');
  set foregroundBeat(DateTime? v) => v == null
      ? _p.remove('foreground_beat')
      : _p.setString('foreground_beat', v.toIso8601String());
}
