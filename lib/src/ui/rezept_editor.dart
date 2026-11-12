import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/recipe.dart';
import '../services/fotos.dart';
import '../services/rezept_import.dart' show vorschaubild;
import 'foto_auswahl.dart';
import 'rezept_fotos.dart';

/// Foto im Editor: schon gespeichert oder gerade aufgenommen.
class _Foto {
  _Foto.gespeichert(RecipePhoto this.photo) : neu = null;
  _Foto.neu(FotoDaten this.neu) : photo = null;
  final RecipePhoto? photo;
  final FotoDaten? neu;
}

/// Eigenes Rezept anlegen oder ein gespeichertes bearbeiten.
class RezeptEditor extends StatefulWidget {
  const RezeptEditor({super.key, required this.state, this.recipe, this.mitFoto = false});
  final AppState state;
  final Recipe? recipe;

  /// Gleich die Kamera/Galerie öffnen (z. B. „Kochbuchseite fotografieren“).
  final bool mitFoto;

  @override
  State<RezeptEditor> createState() => _RezeptEditorState();
}

class _RezeptEditorState extends State<RezeptEditor> {
  late final _titel = TextEditingController(text: widget.recipe?.title ?? '');
  late final _portionen = TextEditingController(text: widget.recipe?.servings?.toString() ?? '');
  late final _minuten = TextEditingController(text: widget.recipe?.totalMinutes?.toString() ?? '');
  late final _zutaten = TextEditingController(text: widget.recipe?.ingredients.join('\n') ?? '');
  late final _schritte = TextEditingController(text: widget.recipe?.steps.join('\n\n') ?? '');
  late final _notizen = TextEditingController(text: widget.recipe?.notes ?? '');
  late final _quelle = TextEditingController(text: widget.recipe?.sourceUrl ?? '');

  late final List<_Foto> _fotos = [for (final p in widget.recipe?.photos ?? <RecipePhoto>[]) _Foto.gespeichert(p)];

  /// In dieser Bearbeitung als Titelbild gewählt.
  _Foto? _titelFoto;
  bool _speichert = false;

  @override
  void initState() {
    super.initState();
    if (widget.mitFoto) WidgetsBinding.instance.addPostFrameCallback((_) => _fotoHinzufuegen());
  }

  /// Welches Foto wird das Titelbild? Gewählt, bisheriges, sonst das erste –
  /// außer das Rezept hat schon ein Bild aus dem Originalrezept.
  bool _istTitel(_Foto f) {
    if (_titelFoto != null) return identical(f, _titelFoto);
    final cover = widget.recipe?.coverPhoto ?? '';
    if (cover.isNotEmpty && _fotos.any((g) => g.photo?.id == cover)) return f.photo?.id == cover;
    final bildVomOriginal = cover.isEmpty && (widget.recipe?.imageJpeg ?? '').isNotEmpty;
    return !bildVomOriginal && _fotos.isNotEmpty && identical(f, _fotos.first);
  }

  Future<void> _fotoHinzufuegen() async {
    final neu = await fotosWaehlen(context);
    if (!mounted || neu.isEmpty) return;
    setState(() => _fotos.addAll(neu.map(_Foto.neu)));
  }

  Future<String> _vorschauVon(RecipePhoto p) async {
    final bytes = await widget.state.repo.loadPhoto(p.id);
    return bytes == null ? '' : compute(vorschaubild, bytes);
  }

  @override
  void dispose() {
    for (final c in [_titel, _portionen, _minuten, _zutaten, _schritte, _notizen, _quelle]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _speichern() async {
    final titel = _titel.text.trim();
    if (titel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte einen Namen eingeben.')));
      return;
    }
    if (_speichert) return;
    setState(() => _speichert = true);
    try {
      await _uebernehmen(titel);
    } finally {
      if (mounted) setState(() => _speichert = false);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _uebernehmen(String titel) async {
    List<String> zeilen(String t) =>
        t.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final r = widget.recipe ?? Recipe(title: titel);
    // Fotos: neue verschlüsselt ablegen (werden beim nächsten Abgleich hochgeladen)
    final store = widget.state.repo.photos;
    final photos = <RecipePhoto>[];
    String? titelId, titelBild;
    for (final f in _fotos) {
      final RecipePhoto p;
      if (f.neu != null) {
        if (store == null) continue;
        p = RecipePhoto(id: await store.add(f.neu!.jpeg), width: f.neu!.breite, height: f.neu!.hoehe);
        if (_istTitel(f)) (titelId, titelBild) = (p.id, f.neu!.vorschau);
      } else {
        p = f.photo!;
        if (_istTitel(f) && p.id != r.coverPhoto) (titelId, titelBild) = (p.id, await _vorschauVon(p));
      }
      photos.add(p);
    }
    final ids = photos.map((p) => p.id).toSet();
    // Titelbild-Foto entfernt: Titelbild weg (oder das nächste Foto nehmen)
    if (r.coverPhoto.isNotEmpty && !ids.contains(r.coverPhoto) && titelId == null) {
      r.imageJpeg = '';
      r.coverPhoto = '';
    }
    if (titelId != null && titelBild != null && titelBild.isNotEmpty) {
      r.imageJpeg = titelBild;
      r.coverPhoto = titelId;
    }
    r.photos = photos;
    r
      ..title = titel
      ..servings = int.tryParse(_portionen.text.trim())
      ..totalMinutes = int.tryParse(_minuten.text.trim())
      ..ingredients = zeilen(_zutaten.text)
      // Schritte durch Leerzeilen getrennt; ohne Leerzeilen ist jede Zeile ein Schritt
      ..steps = _schritte.text.contains(RegExp(r'\n\s*\n'))
          ? _schritte.text.split(RegExp(r'\n\s*\n')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : zeilen(_schritte.text)
      ..notes = _notizen.text.trim()
      ..sourceUrl = _quelle.text.trim();
    await widget.state.saveRecipe(r);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    InputDecoration deko(String label, {String? hint, String? helper}) =>
        InputDecoration(labelText: label, hintText: hint, helperText: helper, border: const OutlineInputBorder());
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'Eigenes Rezept' : 'Rezept bearbeiten'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _speichert ? null : _speichern,
              child: _speichert
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Speichern'),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        TextField(
          controller: _titel,
          autofocus: widget.recipe == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: deko('Name', hint: 'z. B. Omas Kartoffelsalat'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _portionen,
              keyboardType: TextInputType.number,
              decoration: deko('Portionen'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _minuten,
              keyboardType: TextInputType.number,
              decoration: deko('Zeit (Minuten)'),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        _fotoBereich(theme),
        const SizedBox(height: 18),
        TextField(
          controller: _zutaten,
          minLines: 5,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          decoration: deko('Zutaten',
              hint: '500 g Kartoffeln\n1 Zwiebel\n2 EL Essig\nSalz und Pfeffer',
              helper: 'Eine Zutat pro Zeile, Menge vorn. „Für die Soße:“ wird zur Zwischenüberschrift.'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _schritte,
          minLines: 5,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          decoration: deko('Zubereitung', helper: 'Schritte durch Leerzeilen trennen'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _notizen,
          minLines: 2,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          decoration: deko('Notizen', hint: 'z. B. „mit weniger Zucker“, „schmeckt aufgewärmt besser“'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _quelle,
          keyboardType: TextInputType.url,
          decoration: deko('Quelle (optional)', hint: 'Link oder z. B. „Kochbuch S. 42“'),
        ),
      ]),
    );
  }

  Widget _fotoBereich(ThemeData theme) {
    const hoehe = 128.0;
    final repo = widget.state.repo;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Fotos', style: theme.textTheme.titleSmall),
      const SizedBox(height: 2),
      Text(
        _fotos.isEmpty
            ? 'Kochbuchseite oder Rezeptkarte fotografieren – dann musst du nichts abtippen.'
            : 'Antippen zum Ansehen, ⋮ für Titelbild oder Entfernen.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: hoehe,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final (i, f) in _fotos.indexed)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: hoehe * 0.75,
                  height: hoehe,
                  child: Stack(fit: StackFit.expand, children: [
                    GestureDetector(
                      onTap: f.photo == null
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FotoAnsicht(
                                    repo: repo,
                                    photos: [for (final g in _fotos) ?g.photo],
                                    start: _fotos.take(i).where((g) => g.photo != null).length,
                                  ),
                                ),
                              ),
                      child: FotoBild(repo: repo, id: f.photo?.id ?? '', bytes: f.neu?.jpeg, decodeHeight: hoehe),
                    ),
                    if (_istTitel(f))
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Titelbild',
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimary)),
                        ),
                      ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: PopupMenuButton<String>(
                        tooltip: 'Foto-Optionen',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (v) => setState(() {
                          if (v == 'titel') _titelFoto = f;
                          if (v == 'weg') {
                            _fotos.remove(f);
                            if (identical(_titelFoto, f)) _titelFoto = null;
                          }
                        }),
                        itemBuilder: (c) => [
                          if (!_istTitel(f)) const PopupMenuItem(value: 'titel', child: Text('Als Titelbild')),
                          const PopupMenuItem(value: 'weg', child: Text('Entfernen')),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          SizedBox(
            width: hoehe * 0.75,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _fotoHinzufuegen,
              child: const Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_a_photo_outlined),
                SizedBox(height: 6),
                Text('Foto', textAlign: TextAlign.center),
              ]),
            ),
          ),
        ]),
      ),
    ]);
  }
}
