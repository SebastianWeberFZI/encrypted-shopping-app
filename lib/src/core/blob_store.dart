import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto_service.dart';
import 'github_api.dart';

/// Unveränderliche, verschlüsselte Binärdateien (z. B. Fotos) unter
/// `<remoteDir>/<id>.enc` – gleiches Format wie die Dokumente.
///
/// Anders als Dokumente werden sie nicht beim Start geladen, sondern erst,
/// wenn sie angezeigt werden; danach liegen sie verschlüsselt auf dem Gerät.
/// Neue Dateien werden vor dem Dokument-Abgleich hochgeladen, damit das
/// Rezept, das auf sie verweist, nicht vor ihnen ankommt. Dateien, auf die
/// nichts mehr verweist, räumt [collectGarbage] nach einer Schonfrist weg.
///
/// Lokal: `<baseDir>/<id>.enc` (verschlüsselt) und `<id>.upload` (Marker:
/// noch hochzuladen).
class BlobStore {
  BlobStore({
    required this.baseDir,
    required this.remoteDir,
    required this.crypto,
    required this.key,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String baseDir;
  final String remoteDir;
  final CryptoService crypto;
  final SecretKey key;
  final DateTime Function() _clock;

  /// Entschlüsselte Dateien der letzten Zeit (wenige, Fotos sind groß).
  final Map<String, Uint8List> _cache = {};
  final Map<String, Future<Uint8List?>> _loading = {};
  static const _cacheSize = 6;
  static final _random = Random.secure();

  /// IDs beginnen mit dem Zeitpunkt (Millisekunden, Basis 36) – so lässt sich
  /// die Schonfrist ohne zusätzliche Anfragen prüfen.
  String newId() {
    final t = _clock().toUtc().millisecondsSinceEpoch.toRadixString(36);
    final r = List.generate(10, (_) => _random.nextInt(36).toRadixString(36)).join();
    return '$t-$r';
  }

  static DateTime? createdAt(String id) {
    final ms = int.tryParse(id.split('-').first, radix: 36);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  String remotePath(String id) => '$remoteDir/$id.enc';
  File _file(String id) => File('$baseDir/$id.enc');
  File _marker(String id) => File('$baseDir/$id.upload');

  void _remember(String id, Uint8List data) {
    _cache.remove(id);
    _cache[id] = data;
    while (_cache.length > _cacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Speichert eine neue Datei (verschlüsselt) und merkt sie zum Hochladen vor.
  Future<String> add(Uint8List data) async {
    final id = newId();
    await Directory(baseDir).create(recursive: true);
    await _file(id).writeAsBytes(await crypto.encryptBytes(data, key), flush: true);
    await _marker(id).writeAsString('');
    _remember(id, data);
    return id;
  }

  /// Schon im Speicher? (für sofortige Anzeige ohne Ladeanimation)
  Uint8List? cached(String id) => _cache[id];

  /// Liefert die Datei – aus dem Speicher, vom Gerät oder (mit [api]) aus dem
  /// Repo. null, wenn es sie (noch) nicht gibt. Netzwerkfehler werden
  /// weitergereicht.
  Future<Uint8List?> load(String id, {GithubApi? api}) {
    final c = _cache[id];
    if (c != null) return Future.value(c);
    // Block statt Pfeil: remove() liefert das Future selbst – whenComplete
    // würde sonst auf sich selbst warten.
    return _loading[id] ??= _load(id, api).whenComplete(() {
      _loading.remove(id);
    });
  }

  Future<Uint8List?> _load(String id, GithubApi? api) async {
    final f = _file(id);
    if (await f.exists()) {
      try {
        final d = await crypto.decryptBytes(await f.readAsBytes(), key);
        _remember(id, d);
        return d;
      } on UnsupportedFormatException {
        rethrow;
      } on DecryptionFailedException {
        if (!await _marker(id).exists()) await f.delete(); // beschädigt: neu laden
      }
    }
    if (api == null) return null;
    final remote = await api.getFile(remotePath(id));
    if (remote == null || remote.content == null) return null;
    final d = await crypto.decryptBytes(remote.content!, key);
    await Directory(baseDir).create(recursive: true);
    await f.writeAsBytes(remote.content!, flush: true);
    _remember(id, d);
    return d;
  }

  /// Noch nicht übertragene Dateien.
  Future<List<String>> pendingUploads() async {
    final dir = Directory(baseDir);
    if (!await dir.exists()) return [];
    return [
      await for (final e in dir.list())
        if (e is File && e.path.endsWith('.upload'))
          e.uri.pathSegments.last.replaceFirst(RegExp(r'\.upload$'), ''),
    ];
  }

  /// Lädt noch nicht übertragene Dateien hoch; liefert die Anzahl.
  Future<int> upload(GithubApi api, {String message = 'sync'}) async {
    var n = 0;
    for (final id in await pendingUploads()) {
      final f = _file(id);
      if (await f.exists()) {
        try {
          await api.putFile(remotePath(id), await f.readAsBytes(), message);
          n++;
        } on GithubApiException catch (e) {
          // Existiert schon (z. B. abgebrochener Lauf oder zweiter Prozess):
          // Dateien sind unveränderlich, also ist das Ziel erreicht.
          if (!e.isConflict) rethrow;
        }
      }
      final m = _marker(id);
      if (await m.exists()) await m.delete();
    }
    return n;
  }

  /// Entfernt Dateien, auf die nichts mehr verweist ([used]): remote erst,
  /// wenn sie älter als [grace] sind (ein Rezept, das gerade auf einem
  /// anderen Handy entsteht, könnte sie sonst verlieren), lokal sofort.
  Future<int> collectGarbage(GithubApi api, RepoTree tree, Set<String> used,
      {Duration grace = const Duration(days: 7), String message = 'sync'}) async {
    var n = 0;
    final now = _clock().toUtc();
    final pending = (await pendingUploads()).toSet();
    for (final e in tree.files.entries) {
      if (!e.key.startsWith('$remoteDir/') || !e.key.endsWith('.enc')) continue;
      final id = e.key.substring(remoteDir.length + 1, e.key.length - 4);
      if (used.contains(id) || pending.contains(id)) continue;
      final created = createdAt(id);
      if (created == null || now.difference(created) < grace) continue;
      await api.deleteFile(e.key, e.value, message);
      n++;
    }
    final dir = Directory(baseDir);
    if (await dir.exists()) {
      await for (final e in dir.list()) {
        if (e is! File || !e.path.endsWith('.enc')) continue;
        final id = e.uri.pathSegments.last.replaceFirst(RegExp(r'\.enc$'), '');
        if (used.contains(id) || pending.contains(id)) continue;
        await e.delete();
        _cache.remove(id);
      }
    }
    return n;
  }
}
