import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/catalog.dart';
import '../models/shopping_models.dart';

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
  late final _emoji = TextEditingController(text: widget.item.emoji);
  late String _category = widget.item.category;

  ShopItem get i => widget.item;

  Future<void> _save() async {
    i.spec = _spec.text.trim();
    i.emoji = _emoji.text.trim().isEmpty ? i.emoji : _emoji.text.trim();
    i.category = _category;
    await widget.state.updateItem(i);
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
            SizedBox(
              width: 64,
              child: TextField(
                controller: _emoji,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 34),
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
            const SizedBox(width: 8),
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
              for (final c in kCategories) DropdownMenuItem(value: c.key, child: Text('${c.emoji}  ${c.name}')),
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
