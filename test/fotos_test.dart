import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypted_shopping_app/src/core/blob_store.dart';
import 'package:encrypted_shopping_app/src/core/crypto_service.dart';
import 'package:encrypted_shopping_app/src/core/github_api.dart';
import 'package:encrypted_shopping_app/src/core/source_config.dart';
import 'package:encrypted_shopping_app/src/models/recipe.dart';
import 'package:encrypted_shopping_app/src/services/fotos.dart';
import 'package:encrypted_shopping_app/src/shopping_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'fake_github.dart';
import 'shopping_test.dart' show MemoryConfigStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  late Directory tmp;
  late FakeGithub gh;
  final crypto = CryptoService();
  const params = CryptoParams(salt: 'AAAAAAAAAAAAAAAAAAAAAA==', memoryKiB: 1024, iterations: 1, parallelism: 1);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fotos');
    gh = FakeGithub();
  });
  tearDown(() => tmp.delete(recursive: true));

  Future<SourceConfig> cfg() async {
    final key = await crypto.deriveKey('passphrase', params);
    return SourceConfig(
        id: 'src', label: 'Einkauf', owner: 'o', repo: 'r', token: 't',
        masterKeyB64: base64.encode(await key.extractBytes()), cryptoParams: params);
  }

  Future<ShoppingRepository> device(String user) async {
    final c = await cfg();
    final r = ShoppingRepository(
        baseDir: '${tmp.path}/$user', configStore: MemoryConfigStore()..saved = [c], userName: () => user);
    await r.openWith(GithubApi(c.github, client: gh.client()));
    return r;
  }

  test('Foto wird vor dem Rezept hochgeladen, verschlüsselt und erst beim Anzeigen geladen', () async {
    final a = await device('Anna');
    final b = await device('Ben');
    final bytes = Uint8List.fromList(List.generate(5000, (i) => i % 251));
    final id = await a.photos!.add(bytes);
    await a.saveRecipe(Recipe(title: 'Omas Apfelkuchen', photos: [RecipePhoto(id: id, width: 1200, height: 1600)]));
    await a.sync();

    final remote = gh.files['photos/$id.enc']!;
    expect(remote.first, 1, reason: 'Formatbyte wie bei Dokumenten');
    expect(remote.length, greaterThan(bytes.length));
    expect(await a.photos!.pendingUploads(), isEmpty);

    await b.sync();
    final r = b.recipes.single;
    expect(r.photos.single.id, id);
    expect(r.photos.single.aspect, 0.75);
    final reads = gh.blobReads;
    expect(await b.loadPhoto(id), bytes);
    expect(gh.blobReads, reads + 1, reason: 'erst beim Anzeigen geladen');
    expect(await b.loadPhoto(id), bytes);
    expect(gh.blobReads, reads + 1, reason: 'danach vom Gerät');

    // Nach einem Neustart (neuer Speicher) kommt es verschlüsselt vom Gerät.
    final b2 = await device('Ben');
    expect(await b2.loadPhoto(id), bytes);
    expect(gh.blobReads, reads + 1);
    expect(await b.loadPhoto('gibtsnicht-123'), isNull);
  });

  test('Nicht mehr verwendete Fotos verschwinden erst nach der Schonfrist', () async {
    final c = await cfg();
    final key = await crypto.deriveKey('passphrase', params);
    final api = GithubApi(c.github, client: gh.client());
    var now = DateTime.utc(2026, 11, 1);
    final store = BlobStore(baseDir: '${tmp.path}/blobs', remoteDir: 'photos', crypto: crypto, key: key, clock: () => now);
    final alt = await store.add(Uint8List.fromList([1, 2, 3]));
    final behalten = await store.add(Uint8List.fromList([4, 5, 6]));
    await store.upload(api);
    expect(await store.upload(api), 0, reason: 'nichts doppelt');
    expect(BlobStore.createdAt(alt), now);

    now = DateTime.utc(2026, 11, 5);
    final neu = await store.add(Uint8List.fromList([7]));
    await store.upload(api);
    Future<int> gc() async => store.collectGarbage(api, await api.getTree(), {behalten});
    expect(await gc(), 0, reason: 'innerhalb der Schonfrist');
    now = DateTime.utc(2026, 11, 9);
    expect(await gc(), 1);
    expect(gh.files.keys, containsAll(['photos/$behalten.enc', 'photos/$neu.enc']));
    expect(gh.files.containsKey('photos/$alt.enc'), isFalse);
    expect(File('${tmp.path}/blobs/$alt.enc').existsSync(), isFalse, reason: 'lokale Kopie weg');
    expect(File('${tmp.path}/blobs/$behalten.enc').existsSync(), isTrue);
  });

  test('Rezept löschen: Fotos werden später aufgeräumt, unbekannte Rezeptformate schützen sie', () async {
    final a = await device('Anna');
    final id = await a.photos!.add(Uint8List.fromList([9, 9, 9]));
    final r = Recipe(title: 'X', photos: [RecipePhoto(id: id)]);
    await a.saveRecipe(r);
    await a.sync();
    await a.deleteRecipe(r);
    await a.sync();
    expect(gh.files.containsKey('photos/$id.enc'), isTrue, reason: 'Schonfrist');
  });

  test('Fotoverweise: hin und zurück, tolerant', () {
    final r = Recipe(title: 'A', photos: [RecipePhoto(id: 'k1', width: 3, height: 4)]);
    final j = jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>;
    (j['photos'] as List).add({'id': 'k2', 'w': '10', 'h': 5, 'beschriftung': 'S. 42'});
    j['photos'].add(7);
    j['photos'].add({'w': 1});
    j['photos'].add({'id': '../böse'});
    final back = Recipe.fromJson(j);
    expect(back.photos.map((p) => p.id), ['k1', 'k2']);
    expect(back.photos[1].width, 10);
    expect(back.photos[1].toJson()['beschriftung'], 'S. 42');
    expect(Recipe.fromJson({'id': 'x', 'title': 'B', 'photos': 'kaputt'}).photos, isEmpty);
    expect(Recipe(title: 'C').toJson().containsKey('photos'), isFalse);
  });

  test('Aufbereiten: Drehung aus EXIF, verkleinert, ohne Metadaten, Vorschaubild', () {
    final hoch = img.Image(width: 3000, height: 2000);
    img.fill(hoch, color: img.ColorRgb8(240, 230, 200));
    hoch.exif.imageIfd.orientation = 6; // Kamera hochkant gehalten
    hoch.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
    final f = fotoAufbereiten(Uint8List.fromList(img.encodeJpg(hoch)))!;
    expect((f.breite, f.hoehe), (1200, 1800));
    final wieder = img.decodeJpg(f.jpeg)!;
    expect((wieder.width, wieder.height), (1200, 1800));
    expect(wieder.exif.isEmpty, isTrue, reason: 'keine Ortsdaten im Repo');
    final v = img.decodeJpg(base64Decode(f.vorschau))!;
    expect(v.width, 640);
    expect(fotoAufbereiten(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
