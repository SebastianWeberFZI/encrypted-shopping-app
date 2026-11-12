import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/recipe.dart';

/// Eigenes Rezept anlegen oder ein gespeichertes bearbeiten.
class RezeptEditor extends StatefulWidget {
  const RezeptEditor({super.key, required this.state, this.recipe});
  final AppState state;
  final Recipe? recipe;

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
    List<String> zeilen(String t) =>
        t.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final r = widget.recipe ?? Recipe(title: titel);
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
    if (mounted) Navigator.pop(context);
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
            child: FilledButton(onPressed: _speichern, child: const Text('Speichern')),
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
        const SizedBox(height: 14),
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
}
