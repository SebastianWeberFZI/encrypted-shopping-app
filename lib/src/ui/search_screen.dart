import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/catalog.dart';
import '../models/shopping_models.dart';
import 'item_tile.dart';

/// Zerlegt "Milch 2 l" in Name "Milch" und Details "2 l".
(String, String) splitQuery(String q) {
  final parts = q.trim().split(RegExp(r'\s+'));
  final idx = parts.indexWhere((p) => RegExp(r'^\d').hasMatch(p));
  if (idx <= 0) return (q.trim(), '');
  return (parts.sublist(0, idx).join(' '), parts.sublist(idx).join(' '));
}

/// "Was brauchst du?" – Suche im Katalog, eigene Artikel anlegen.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.state});
  final AppState state;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([state, _q]),
      builder: (context, _) {
        final l = state.currentList!;
        final color = Color(l.color);
        final (name, spec) = splitQuery(_q.text);
        final results = <(String, String, String)>[]; // name, emoji, category
        final seen = <String>{};
        void addResult(String n, String e, String c) {
          if (seen.add(normalizeName(n))) results.add((n, e, c));
        }

        if (name.isNotEmpty) {
          for (final i in state.repo.items.where((i) => i.listId == l.id && normalizeName(i.name).contains(normalizeName(name)))) {
            addResult(i.name, i.emoji, i.category);
          }
          for (final a in state.repo.customArticles.where((a) => normalizeName(a.name).contains(normalizeName(name)))) {
            addResult(a.name, a.emoji, a.category);
          }
          for (final c in catalogSearch(name)) {
            addResult(c.name, c.emoji, c.category);
          }
        }
        final exact = seen.contains(normalizeName(name));
        final cols = state.settings.columns;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: TextField(
              controller: _q,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Was brauchst du? (z. B. „Milch 2 l“)',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _addTyped(name, spec),
            ),
            actions: [
              if (_q.text.isNotEmpty) IconButton(icon: const Icon(Icons.clear), onPressed: _q.clear),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fertig')),
            ],
          ),
          body: CustomScrollView(slivers: [
            if (name.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Tippe einen Artikel ein. Zahlen dahinter werden zu Details, '
                    'z. B. „Äpfel 1 kg“. Gibt es den Artikel noch nicht, legst du ihn mit Enter an.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            if (name.isNotEmpty && !exact)
              SliverToBoxAdapter(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: color, child: const Icon(Icons.add, color: Colors.white)),
                  title: Text('„$name“ hinzufügen'),
                  subtitle: Text([if (spec.isNotEmpty) spec, categoryByKey(guessCategory(name)).name].join(' · ')),
                  onTap: () => _addTyped(name, spec),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: tileGrid(
                columns: cols,
                count: results.length,
                builder: (c, i) {
                  final (n, e, cat) = results[i];
                  final existing = state.repo.itemByName(l.id, n);
                  final onList = existing?.needed ?? false;
                  return ItemTile(
                    emoji: e,
                    name: n,
                    spec: onList ? existing!.spec : spec,
                    style: TileStyle.catalog,
                    selected: onList,
                    color: color,
                    onTap: () async {
                      if (onList) {
                        await state.removeFromList(existing!);
                      } else {
                        await state.add(n, emoji: e, category: cat, spec: spec);
                        _q.clear();
                      }
                    },
                  );
                },
              ),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _addTyped(String name, String spec) async {
    if (name.isEmpty) return;
    final known = catalogLookup(name) != null ||
        state.repo.customArticles.any((a) => normalizeName(a.name) == normalizeName(name));
    if (!known) {
      await state.saveCustomArticle(CustomArticle(
        name: name,
        category: guessCategory(name),
        emoji: categoryByKey(guessCategory(name)).emoji,
      ));
    }
    await state.add(name, spec: spec);
    _q.clear();
  }
}
