import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/catalog.dart';
import '../models/pikto.dart';
import '../models/shopping_models.dart';
import 'pikto.dart';

const _quickSpecs = ['2×', '3×', '1 kg', '500 g', '1 l', 'Bio', 'laktosefrei', 'groß', 'klein', 'Angebot'];

Future<void> showItemSheet(BuildContext context, AppState state, ShopItem item) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ItemSheet(state: state, item: item),
    );

String _ago(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 2) return 'gerade eben';
  if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
  if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
  if (diff.inDays == 1) return 'gestern';
  return 'vor ${diff.inDays} Tagen';
}

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.state, required this.item});
  final AppState state;
  final ShopItem item;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final _spec = TextEditingController(text: widget.item.spec);
  late String? _icon = widget.item.icon;
  late String _category = widget.item.category;

  ShopItem get i => widget.item;

  Future<void> _save() async {
    i.spec = _spec.text.trim();
    i.category = _category;
    if (_icon != i.icon) {
      i.icon = _icon;
      if (_icon != null) i.emoji = emojiForPikto(_icon!) ?? i.emoji;
      // Eigener Artikel: das Symbol gilt auch im Katalog und auf anderen Listen.
      final custom = widget.state.repo.customArticles
          .where((a) => normalizeName(a.name) == normalizeName(i.name))
          .firstOrNull;
      if (custom != null) {
        custom
          ..icon = i.icon
          ..emoji = i.emoji;
        await widget.state.saveCustomArticle(custom);
      }
    }
    await widget.state.updateItem(i);
  }

  Future<void> _pickIcon() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => _PiktoPicker(selected: resolvePikto(icon: _icon, name: i.name, emoji: i.emoji)),
    );
    if (picked != null) setState(() => _icon = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avg = i.averageInterval;
    final history = [
      if (i.addedBy.isNotEmpty && i.needed) 'Hinzugefügt von ${i.addedBy} ${_ago(i.addedAt)}',
      if (i.doneBy.isNotEmpty && i.doneAt != null && !i.needed) 'Zuletzt gekauft von ${i.doneBy} ${_ago(i.doneAt!)}',
      if (i.purchaseCount > 0) 'Bisher ${i.purchaseCount}× gekauft${avg != null ? ', etwa alle ${avg.inDays < 1 ? 1 : avg.inDays} Tage' : ''}',
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Tooltip(
              message: 'Symbol ändern',
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickIcon,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Pikto(icon: _icon, name: i.name, emoji: i.emoji, size: 52),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        child: Icon(Icons.edit, size: 12, color: theme.colorScheme.onSecondaryContainer),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(i.name, style: theme.textTheme.headlineSmall)),
          ]),
          for (final h in history)
            Text(h, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 14),
          TextField(
            controller: _spec,
            decoration: const InputDecoration(
              labelText: 'Details',
              hintText: 'z. B. 2 l, laktosefrei, die gute Sorte',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final s in _quickSpecs)
              ActionChip(
                label: Text(s),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() {
                  final t = _spec.text.trim();
                  _spec.text = t.isEmpty ? s : '$t, $s';
                }),
              ),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Ladenbereich', border: OutlineInputBorder()),
            items: [
              for (final c in kCategories)
                DropdownMenuItem(
                  value: c.key,
                  child: Row(children: [Pikto(emoji: c.emoji, size: 22), const SizedBox(width: 10), Text(c.name)]),
                ),
            ],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 16),
          Row(children: [
            if (!i.needed)
              TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Aus Verlauf löschen'),
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                onPressed: () async {
                  await widget.state.removeItem(i);
                  if (context.mounted) Navigator.pop(context);
                },
              )
            else
              TextButton(
                onPressed: () async {
                  await widget.state.removeFromList(i);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Von der Liste nehmen'),
              ),
            const Spacer(),
            FilledButton(
              onPressed: () async {
                await _save();
                if (!i.needed) await widget.state.needed(i);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(i.needed ? 'Speichern' : 'Auf die Liste'),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Auswahl aus allen mitgelieferten Piktogrammen.
class _PiktoPicker extends StatelessWidget {
  const _PiktoPicker({required this.selected});
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final keys = piktoAuswahl();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(children: [
        Text('Symbol wählen', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 60, mainAxisSpacing: 6, crossAxisSpacing: 6),
            itemCount: keys.length,
            itemBuilder: (c, idx) {
              final k = keys[idx];
              final sel = k == selected;
              return Material(
                color: sel ? scheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(context, k),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Pikto(icon: k, emoji: emojiOfKey(k) ?? '', size: 36),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
