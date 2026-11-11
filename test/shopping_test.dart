import 'dart:convert';
import 'dart:io';

import 'package:encrypted_shopping_app/src/core/crypto_service.dart';
import 'package:encrypted_shopping_app/src/core/github_api.dart';
import 'package:encrypted_shopping_app/src/core/source_config.dart';
import 'package:encrypted_shopping_app/src/models/catalog.dart';
import 'package:encrypted_shopping_app/src/models/shopping_models.dart';
import 'package:encrypted_shopping_app/src/services/notification_service.dart';
import 'package:encrypted_shopping_app/src/shopping_repository.dart';
import 'package:encrypted_shopping_app/src/ui/search_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_github.dart';

/// Keystore-Ersatz für Tests.
class MemoryConfigStore extends SourceConfigStore {
  List<SourceConfig> saved = [];
  @override
  Future<List<SourceConfig>> load() async => saved;
  @override
  Future<void> save(List<SourceConfig> sources) async => saved = sources;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('Katalog & Eingabe', () {
    test('Suche findet Synonyme, Wortanfang zuerst', () {
      expect(catalogSearch('möhr').first.name, 'Karotten');
      expect(catalogSearch('milch').first.name, 'Milch');
      expect(catalogSearch('nutella').single.name, 'Nussnougatcreme');
    });

    test('Details werden von Zahlen an abgetrennt', () {
      expect(splitQuery('Milch 2 l'), ('Milch', '2 l'));
      expect(splitQuery('Rote Zwiebeln 3'), ('Rote Zwiebeln', '3'));
      expect(splitQuery('Brot'), ('Brot', ''));
    });

    test('Kategorie eigener Artikel wird geraten', () {
      expect(guessCategory('Bananen bio'), 'obst');
      expect(guessCategory('Xyz'), 'sonstiges');
    });
  });

  group('Vorschläge', () {
    test('fällig, wenn das übliche Intervall abgelaufen ist', () {
      final now = DateTime(2026, 11, 11);
      final i = ShopItem(id: 'x', listId: 'l', name: 'Eier', status: ItemStatus.recent, purchaseCount: 3,
          purchaseHistory: [now.subtract(const Duration(days: 22)), now.subtract(const Duration(days: 15)),
            now.subtract(const Duration(days: 8))]);
      expect(i.averageInterval!.inDays, 7);
      expect(i.dueRatio(now), greaterThan(1));
      i.markBought('A', now);
      expect(i.dueRatio(now), 0);
      expect(i.purchaseCount, 4);
    });
  });

  group('Zwei Personen, ein Repo', () {
    late Directory tmp;
    late FakeGithub gh;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('shop');
      gh = FakeGithub();
    });
    tearDown(() => tmp.delete(recursive: true));

    ShoppingRepository device(String user, MemoryConfigStore store) =>
        ShoppingRepository(baseDir: '${tmp.path}/$user', configStore: store, userName: () => user);

    test('gleichzeitig "Milch" hinzufügen erzeugt keine Dublette; Änderungen werden zusammengefasst', () async {
      // Schnelle KDF für Tests
      final crypto = CryptoService();
      final params = const CryptoParams(salt: 'AAAAAAAAAAAAAAAAAAAAAA==', memoryKiB: 1024, iterations: 1, parallelism: 1);
      final key = await crypto.deriveKey('passphrase', params);
      final b64 = await key.extractBytes();
      SourceConfig cfg() => SourceConfig(
            id: 'src', label: 'Einkauf', owner: 'o', repo: 'r', token: 't',
            masterKeyB64: base64.encode(b64), cryptoParams: params);
      final sa = MemoryConfigStore()..saved = [cfg()];
      final sb = MemoryConfigStore()..saved = [cfg()];
      final a = device('Anna', sa);
      final b = device('Ben', sb);
      await a.openWith(GithubApi(cfg().github, client: gh.client()));
      await b.openWith(GithubApi(cfg().github, client: gh.client()));

      final list = ShoppingList(name: 'Supermarkt');
      await a.saveList(list);
      await a.sync();
      await b.sync();
      expect(b.lists.single.name, 'Supermarkt');

      await a.addItem(list.id, 'Milch');
      await b.addItem(list.id, 'milch ', spec: '2 l');
      await a.sync();
      final rb = await b.sync();
      expect(rb!.conflicts, 1);
      await a.sync();
      expect(a.items.where((i) => i.listId == list.id).length, 1);
      expect(b.items.single.spec, '2 l');

      await b.addItem(list.id, 'Brot');
      await b.addItem(list.id, 'Äpfel');
      await b.sync();
      final ra = await a.sync();
      final sums = a.summarize(ra!, 'Anna');
      expect(sums.single.by, 'Ben');
      expect(sums.single.added, containsAll(['Brot', 'Äpfel']));
      expect(NotificationService.texts(sums.single, 'Supermarkt').first.$2, contains('Ben hat'));
    });
  });
}
