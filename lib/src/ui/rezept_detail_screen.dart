import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models/recipe.dart';
import '../models/rezept.dart';
import 'rezept_editor.dart';
import 'rezept_screen.dart';

/// Ein gespeichertes Rezept: Zutaten (mit Portionen umgerechnet), Zubereitung,
/// Notizen – und die Zutaten mit einem Tipp auf die Einkaufsliste.
class RezeptDetailScreen extends StatefulWidget {
  const RezeptDetailScreen({super.key, required this.state, required this.recipe});
  final AppState state;
  final Recipe recipe;

  @override
  State<RezeptDetailScreen> createState() => _RezeptDetailScreenState();
}

class _RezeptDetailScreenState extends State<RezeptDetailScreen> {
  late int? _portionen = widget.recipe.servings;
  static const _bildHoehe = 240.0;
  final _scroll = ScrollController();

  /// Bild eingeklappt? Dann Titel in der Leiste, sonst nur Symbole über dem Bild.
  bool _zu = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final zu = _scroll.offset > _bildHoehe - kToolbarHeight - 24;
      if (zu != _zu) setState(() => _zu = zu);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Aktuelle Fassung (kann sich durch Bearbeiten oder Abgleich ändern).
  Recipe get r => widget.state.repo.recipes.where((x) => x.id == widget.recipe.id).firstOrNull ?? widget.recipe;

  double get _faktor {
    final s = r.servings;
    return (s == null || _portionen == null) ? 1 : _portionen! / s;
  }

  Future<void> _loeschen() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('„${r.title}“ löschen?'),
        content: const Text('Das Rezept verschwindet für alle, die diese Einkaufsliste nutzen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.state.deleteRecipe(r);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final rezept = r;
        final bild = rezept.imageBytes;
        final meta = [
          if (rezept.prepMinutes != null) ('Vorbereitung', _kurz(rezept.prepMinutes!)),
          if (rezept.cookMinutes != null) ('Garen', _kurz(rezept.cookMinutes!)),
          if (rezept.totalMinutes != null) ('Gesamt', _kurz(rezept.totalMinutes!)),
          if (rezept.calories.isNotEmpty) ('pro Portion', rezept.calories),
        ];
        var schritt = 0;
        return Scaffold(
          body: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: bild != null ? _bildHoehe : null,
                foregroundColor: bild != null && !_zu ? Colors.white : null,
                systemOverlayStyle: bild != null && !_zu ? SystemUiOverlayStyle.light : null,
                title: bild == null || _zu ? Text(rezept.title, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                flexibleSpace: bild == null
                    ? null
                    : FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(bild, fit: BoxFit.cover, gaplessPlayback: true),
                            // Abdunkeln oben, damit Statusleiste und Symbole lesbar bleiben
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment(0, -0.2),
                                  colors: [Color(0x99000000), Color(0x00000000)],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                actions: [
                  IconButton(
                    tooltip: 'Bearbeiten',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RezeptEditor(state: widget.state, recipe: rezept),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'quelle') launchUrl(Uri.parse(rezept.sourceUrl), mode: LaunchMode.externalApplication);
                      if (v == 'loeschen') _loeschen();
                    },
                    itemBuilder: (c) => [
                      if (rezept.sourceUrl.isNotEmpty)
                        PopupMenuItem(value: 'quelle', child: Text('Original auf ${rezept.sourceHost} öffnen')),
                      const PopupMenuItem(value: 'loeschen', child: Text('Rezept löschen')),
                    ],
                  ),
                ],
              ),
              SliverList.list(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rezept.title, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (rezept.category.isNotEmpty) rezept.category,
                            if (rezept.sourceHost.isNotEmpty) rezept.sourceHost else 'eigenes Rezept',
                            if (rezept.author.isNotEmpty) 'von ${rezept.author}',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                for (final (label, wert) in meta)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Column(
                                        children: [
                                          Text(
                                            wert,
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            label,
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: theme.colorScheme.outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (rezept.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(rezept.description, style: theme.textTheme.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                    child: Row(
                      children: [
                        Expanded(child: Text('Zutaten', style: theme.textTheme.titleLarge)),
                        if (_portionen != null) ...[
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _portionen! > 1 ? () => setState(() => _portionen = _portionen! - 1) : null,
                          ),
                          Text('$_portionen Portionen', style: theme.textTheme.titleSmall),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: _portionen! < 40 ? () => setState(() => _portionen = _portionen! + 1) : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                  for (final z in rezept.ingredients)
                    z.trim().endsWith(':')
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
                            child: Text(z, style: theme.textTheme.titleSmall),
                          )
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(20, 3, 20, 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 7, right: 10),
                                  child: Icon(Icons.circle, size: 6, color: theme.colorScheme.primary),
                                ),
                                Expanded(child: Text(skaliereZeile(z, _faktor), style: theme.textTheme.bodyLarge)),
                              ],
                            ),
                          ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Zutaten auf die Einkaufsliste'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RezeptScreen.gespeichert(state: widget.state, recipe: rezept, portionen: _portionen),
                        ),
                      ),
                    ),
                  ),
                  if (rezept.steps.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: Text('Zubereitung', style: theme.textTheme.titleLarge),
                    ),
                    for (final s in rezept.steps)
                      if (s.trim().endsWith(':'))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
                          child: Text(s, style: theme.textTheme.titleSmall),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 20, 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Text(
                                  '${++schritt}',
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimaryContainer),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(s, style: theme.textTheme.bodyLarge?.copyWith(height: 1.4))),
                            ],
                          ),
                        ),
                  ],
                  if (rezept.notes.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: Text('Notizen', style: theme.textTheme.titleLarge),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Text(rezept.notes, style: theme.textTheme.bodyLarge),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Text(
                      [
                        if (rezept.addedBy.isNotEmpty) 'Gespeichert von ${rezept.addedBy}',
                        if (rezept.lastUsed != null)
                          'zuletzt eingekauft am ${rezept.lastUsed!.day}.${rezept.lastUsed!.month}.${rezept.lastUsed!.year}',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Kurze Dauer für die Kopfzeile: „45 Min.“, „1 Std.“, „1:10 Std.“
String _kurz(int min) {
  if (min < 60) return '$min Min.';
  final m = min % 60;
  return m == 0 ? '${min ~/ 60} Std.' : '${min ~/ 60}:${m.toString().padLeft(2, '0')} Std.';
}
