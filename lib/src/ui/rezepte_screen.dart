import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models/catalog.dart';
import '../models/recipe.dart';
import 'pikto.dart';
import 'rezept_detail_screen.dart';
import 'rezept_editor.dart';
import 'rezept_screen.dart';

/// Reiter „Rezepte“: alle gespeicherten Rezepte (für alle, die die Liste nutzen).
class RezepteScreen extends StatefulWidget {
  const RezepteScreen({super.key, required this.state});
  final AppState state;

  @override
  State<RezepteScreen> createState() => _RezepteScreenState();
}

class _RezepteScreenState extends State<RezepteScreen> {
  final _suche = TextEditingController();
  AppState get state => widget.state;

  @override
  void dispose() {
    _suche.dispose();
    super.dispose();
  }

  Future<void> _hinzufuegen() async {
    final wahl = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Aus einem Link'),
            subtitle: const Text('Chefkoch, Lecker, Kitchen Stories … – Link einfügen'),
            onTap: () => Navigator.pop(c, 'link'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('Eigenes Rezept eingeben'),
            subtitle: const Text('Aus dem Kochbuch, von Oma, aus dem Kopf'),
            onTap: () => Navigator.pop(c, 'eigen'),
          ),
          const ListTile(
            leading: Icon(Icons.share_outlined),
            title: Text('Tipp: aus anderen Apps teilen'),
            subtitle: Text('In Chefkoch oder im Browser auf „Teilen“ → „Auf die Einkaufsliste“'),
            enabled: false,
          ),
        ]),
      ),
    );
    if (!mounted || wahl == null) return;
    if (wahl == 'eigen') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => RezeptEditor(state: state)));
      return;
    }
    final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (!mounted) return;
    final url = await _linkDialog(clip.contains('http') ? clip.trim() : '');
    if (url == null || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => RezeptScreen.speichern(state: state, text: url)));
  }

  Future<String?> _linkDialog(String vorschlag) {
    final c = TextEditingController(text: vorschlag);
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Rezept aus einem Link'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://www.chefkoch.de/rezepte/…', labelText: 'Link'),
          onSubmitted: (v) => Navigator.pop(d, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Laden')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([state, _suche]),
      builder: (context, _) {
        final q = normalizeName(_suche.text);
        final alle = state.repo.recipes;
        final liste = q.isEmpty
            ? alle
            : alle
                .where((r) =>
                    normalizeName(r.title).contains(q) ||
                    r.ingredients.any((z) => normalizeName(z).contains(q)) ||
                    normalizeName(r.category).contains(q))
                .toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Rezepte')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _hinzufuegen,
            icon: const Icon(Icons.add),
            label: const Text('Rezept'),
          ),
          body: alle.isEmpty
              ? _leer(theme)
              : ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 96), children: [
                  if (alle.length > 4)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: SearchBar(
                        controller: _suche,
                        hintText: 'Rezept oder Zutat suchen',
                        leading: const Icon(Icons.search),
                        elevation: const WidgetStatePropertyAll(0),
                        trailing: [
                          if (_suche.text.isNotEmpty) IconButton(icon: const Icon(Icons.clear), onPressed: _suche.clear),
                        ],
                      ),
                    ),
                  for (final r in liste) _karte(theme, r),
                  if (liste.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Kein Rezept gefunden.', style: TextStyle(color: theme.colorScheme.outline)),
                    ),
                ]),
        );
      },
    );
  }

  Widget _karte(ThemeData theme, Recipe r) {
    final bild = r.imageBytes;
    final meta = [
      if (r.totalMinutes != null) _dauer(r.totalMinutes!),
      if (r.servings != null) '${r.servings} Portionen',
      if (r.sourceHost.isNotEmpty) r.sourceHost else 'eigenes Rezept',
    ].join(' · ');
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => RezeptDetailScreen(state: state, recipe: r))),
        child: Row(children: [
          SizedBox(
            width: 96,
            height: 80,
            child: bild != null
                ? Image.memory(bild, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 300)
                : Container(
                    color: theme.colorScheme.secondaryContainer,
                    alignment: Alignment.center,
                    child: const Pikto(emoji: '🍽️', size: 40),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _leer(ThemeData theme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Pikto(emoji: '🍽️', size: 64),
            const SizedBox(height: 16),
            Text('Noch keine Rezepte', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Teile ein Rezept aus Chefkoch oder dem Browser an „Auf die Einkaufsliste“, '
              'füge einen Link ein oder gib ein eigenes Rezept ein. Gespeicherte Rezepte '
              'sehen alle, die diese Einkaufsliste nutzen.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ]),
        ),
      );
}

String _dauer(int min) => min < 60 ? '$min Min.' : '${min ~/ 60} Std.${min % 60 > 0 ? ' ${min % 60} Min.' : ''}';

/// Dauer lesbar („1 Std. 40 Min.“).
String dauerText(int min) => _dauer(min);
