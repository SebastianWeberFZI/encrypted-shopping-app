import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/catalog.dart';
import '../models/recipe.dart';
import '../models/rezept.dart';
import '../services/rezept_import.dart';
import 'pikto.dart';

/// Eine Zeile der Vorschau: gleiche Artikel aus dem Rezept zusammengefasst
/// (z. B. „30 g Butter“ und „20 g Butterflöckchen“).
class _Zeile {
  _Zeile(this.name, this.katalog);
  final String name;
  final CatalogItem? katalog;
  final List<Zutat> teile = [];

  bool get vorrat => teile.every((t) => t.vorrat);
  String get original => teile.map((t) => t.original).toSet().join(' · ');

  String spec(double f) {
    final summen = <String, double>{};
    final reihenfolge = <String>[];
    for (final t in teile) {
      if (t.menge == null) continue;
      final k = '${t.einheit}|${t.zusatz}';
      if (!summen.containsKey(k)) reihenfolge.add(k);
      summen[k] = (summen[k] ?? 0) + t.menge!;
    }
    final out = [
      for (final k in reihenfolge)
        Zutat(original: '', name: name, menge: summen[k], einheit: k.split('|')[0], zusatz: k.split('|')[1]).spec(f),
    ];
    return out.join(' + ');
  }
}

List<_Zeile> _zeilen(List<Zutat> zutaten) {
  final map = <String, _Zeile>{};
  for (final z in zutaten) {
    map.putIfAbsent(normalizeName(z.name), () => _Zeile(z.name, z.katalog)).teile.add(z);
  }
  return map.values.toList();
}

/// Rezept übernehmen: Zutaten eines geteilten Rezeptlinks (oder Textes) bzw.
/// eines gespeicherten Rezepts prüfen, Portionen anpassen und auf eine Liste
/// setzen; geladene Rezepte auf Wunsch unter „Rezepte“ speichern.
class RezeptScreen extends StatefulWidget {
  const RezeptScreen({super.key, required this.state, required this.text})
      : recipe = null,
        portionen = null,
        nurSpeichern = false;

  /// Zutaten eines gespeicherten Rezepts auf die Liste setzen.
  const RezeptScreen.gespeichert({super.key, required this.state, required Recipe this.recipe, this.portionen})
      : text = '',
        nurSpeichern = false;

  /// Link einfügen und als Rezept speichern (ohne gleich einzukaufen).
  const RezeptScreen.speichern({super.key, required this.state, required this.text})
      : recipe = null,
        portionen = null,
        nurSpeichern = true;

  final AppState state;
  final String text;
  final Recipe? recipe;
  final int? portionen;
  final bool nurSpeichern;

  @override
  State<RezeptScreen> createState() => _RezeptScreenState();
}

class _RezeptScreenState extends State<RezeptScreen> {
  AppState get state => widget.state;
  Rezept? _rezept;
  List<_Zeile> _liste = [];
  final Set<int> _an = {};
  String? _fehler;
  List<Zutat> _textZutaten = [];
  int? _portionen;
  late String _listId = state.currentList?.id ?? '';
  bool _speichert = false;

  /// Unter „Rezepte“ speichern (nur bei Rezepten von Webseiten vorausgewählt).
  bool _merken = false;
  Recipe? get _schonGespeichert {
    final q = _rezept?.quelle?.toString();
    if (q == null) return null;
    return state.repo.recipes.where((r) => r.sourceUrl == q).firstOrNull;
  }

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final gespeichert = widget.recipe;
    if (gespeichert != null) {
      _zeigen(rezeptAusRecipe(gespeichert));
      if (widget.portionen != null) _portionen = widget.portionen;
      return;
    }
    final url = ersteAdresse(widget.text);
    _textZutaten = zutatenAusText(widget.text.replaceAll(RegExp(r'https?://\S+'), ''));
    if (url == null) {
      if (_textZutaten.isEmpty) {
        setState(() => _fehler = 'Im geteilten Text wurden keine Zutaten gefunden.');
      } else {
        _zeigen(Rezept(titel: 'Geteilter Text', zutaten: _textZutaten));
      }
      return;
    }
    try {
      _zeigen(await ladeRezept(url));
    } on RezeptFehler catch (e) {
      if (mounted) setState(() => _fehler = e.message);
    }
  }

  void _zeigen(Rezept r) {
    if (!mounted) return;
    setState(() {
      _fehler = null;
      _rezept = r;
      _portionen = r.portionen;
      _merken = widget.recipe == null && (r.quelle != null || widget.nurSpeichern) && _schonGespeichert == null;
      _liste = _zeilen(r.zutaten);
      _an
        ..clear()
        ..addAll([
          if (!widget.nurSpeichern)
            for (var i = 0; i < _liste.length; i++)
              if (!_liste[i].vorrat && !_stehtDrauf(_liste[i])) i,
        ]);
    });
  }

  bool _stehtDrauf(_Zeile z) => state.repo.itemByName(_listId, z.name)?.needed ?? false;

  double get _faktor {
    final p = _rezept?.portionen;
    return (p == null || _portionen == null) ? 1 : _portionen! / p;
  }

  Future<void> _hinzufuegen() async {
    final l = state.repo.list(_listId);
    final r = _rezept;
    if (r == null || _speichert) return;
    setState(() => _speichert = true);
    final meldungen = <String>[];
    if (_merken) {
      final bild = await ladeVorschaubild(r.bildUrl);
      final neu = recipeAusRezept(r, bild: bild, von: state.me);
      if (_an.isNotEmpty) neu.lastUsed = DateTime.now();
      await state.saveRecipe(neu);
      meldungen.add('unter „Rezepte“ gespeichert');
    }
    if (_an.isNotEmpty && l != null) {
      final n = await state.addZutaten(_listId, [
        for (final i in _an.toList()..sort()) (_liste[i].name, _liste[i].spec(_faktor)),
      ]);
      meldungen.insert(0, '$n ${n == 1 ? 'Zutat' : 'Zutaten'} auf „${l.name}“');
      final gespeichert = widget.recipe;
      if (gespeichert != null) {
        gespeichert.lastUsed = DateTime.now();
        await state.saveRecipe(gespeichert);
      }
    }
    if (!mounted) return;
    Navigator.pop(context);
    state.toast.value = '„${r.titel}“: ${meldungen.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = _rezept;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.nurSpeichern
              ? 'Rezept speichern'
              : widget.recipe != null
                  ? 'Zutaten auf die Liste'
                  : 'Rezept übernehmen')),
      body: _fehler != null
          ? _fehlerAnsicht(theme)
          : r == null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Lade Rezept von ${ersteAdresse(widget.text)?.host.replaceFirst('www.', '') ?? ''} …'),
                  ]),
                )
              : ListView(padding: const EdgeInsets.only(bottom: 96), children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.titel, style: theme.textTheme.titleLarge),
                      if (r.quelle != null)
                        Text(r.quelle!.host.replaceFirst('www.', ''),
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                    ]),
                  ),
                  if (_portionen != null)
                    ListTile(
                      leading: const Icon(Icons.people_outline),
                      title: const Text('Portionen'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _portionen! > 1 ? () => setState(() => _portionen = _portionen! - 1) : null,
                        ),
                        Text('$_portionen', style: theme.textTheme.titleMedium),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _portionen! < 40 ? () => setState(() => _portionen = _portionen! + 1) : null,
                        ),
                      ]),
                    ),
                  ListTile(
                    leading: const Icon(Icons.checklist),
                    title: const Text('Auf die Liste'),
                    trailing: DropdownButton<String>(
                      value: state.repo.list(_listId) == null ? null : _listId,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final l in state.lists)
                          DropdownMenuItem(
                            value: l.id,
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Pikto(emoji: l.emoji, size: 22),
                              const SizedBox(width: 8),
                              Text(l.name),
                            ]),
                          ),
                      ],
                      onChanged: (v) => setState(() => _listId = v ?? _listId),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                    child: Text(
                      'Kleinmengen und Grundvorrat (Prise Salz, etwas Öl) sind abgewählt – antippen, um sie doch mitzunehmen.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const Divider(),
                  for (var i = 0; i < _liste.length; i++) _zeile(theme, i),
                  if (widget.recipe == null) ...[
                    const Divider(),
                    if (_schonGespeichert != null)
                      const ListTile(
                        leading: Icon(Icons.bookmark_added_outlined),
                        title: Text('Schon unter „Rezepte“ gespeichert'),
                      )
                    else
                      SwitchListTile(
                        secondary: const Icon(Icons.bookmark_add_outlined),
                        title: const Text('Unter „Rezepte“ speichern'),
                        subtitle: Text(r.schritte.isNotEmpty
                            ? 'Mit Zutaten, Zubereitung und Bild – für alle, die die Liste nutzen'
                            : 'Zutaten und Titel – für alle, die die Liste nutzen'),
                        value: _merken,
                        onChanged: (v) => setState(() => _merken = v),
                      ),
                  ],
                ]),
      bottomNavigationBar: r == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  icon: _speichert
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_an.isEmpty ? Icons.bookmark_add_outlined : Icons.add_shopping_cart),
                  label: Text(_an.isEmpty
                      ? (_merken ? 'Nur Rezept speichern' : 'Nichts ausgewählt')
                      : '${_an.length} ${_an.length == 1 ? 'Zutat' : 'Zutaten'} hinzufügen'),
                  onPressed: (_an.isEmpty && !_merken) || _speichert ? null : _hinzufuegen,
                ),
              ),
            ),
    );
  }

  Widget _zeile(ThemeData theme, int i) {
    final z = _liste[i];
    final spec = z.spec(_faktor);
    final drauf = _stehtDrauf(z);
    final emoji = z.katalog?.emoji ?? categoryByKey(guessCategory(z.name)).emoji;
    return CheckboxListTile(
      value: _an.contains(i),
      onChanged: (v) => setState(() => v == true ? _an.add(i) : _an.remove(i)),
      secondary: Pikto(name: z.name, emoji: emoji, size: 34),
      title: Text(spec.isEmpty ? z.name : '${z.name} · $spec'),
      subtitle: Text(
        [if (drauf) 'steht schon auf der Liste', z.original].join(' – '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: drauf ? theme.colorScheme.primary : theme.colorScheme.outline),
      ),
    );
  }

  Widget _fehlerAnsicht(ThemeData theme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(_fehler!, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Rezepte werden von Seiten mit Rezept-Daten übernommen, z. B. Chefkoch, Lecker, '
              'Kitchen Stories oder EAT SMARTER. Du kannst auch eine Zutatenliste als Text teilen.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (_textZutaten.isNotEmpty)
              FilledButton.tonal(
                onPressed: () => _zeigen(Rezept(titel: 'Geteilter Text', zutaten: _textZutaten)),
                child: const Text('Stattdessen den geteilten Text übernehmen'),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen')),
          ]),
        ),
      );
}
