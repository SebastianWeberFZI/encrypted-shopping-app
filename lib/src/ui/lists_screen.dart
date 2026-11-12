import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/shopping_models.dart';
import 'pikto.dart';

const kListColors = [
  0xFF2F7D6B, 0xFF3D6FB6, 0xFF8E5BB5, 0xFFC94F7C, 0xFFD2553F, 0xFFC9762B, 0xFF9A8A2E, 0xFF5D6D7E,
];
const kListEmojis = ['🛒', '🧴', '🔨', '🥕', '🍷', '🐾', '🎁', '💊', '🏠', '👶', '🌱', '📦'];

/// Listen anlegen, umbenennen, einfärben, löschen.
class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Listen')),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Neue Liste'),
          onPressed: () => _edit(context, null),
        ),
        body: ListView(children: [
          for (final l in state.lists)
            ListTile(
              leading: CircleAvatar(
                  backgroundColor: Color(l.color).withValues(alpha: 0.18), child: Pikto(emoji: l.emoji, size: 26)),
              title: Text(l.name),
              subtitle: Text('${state.repo.needed(l.id).length} zu kaufen · '
                  '${state.repo.recent(l.id).length} im Verlauf'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _edit(context, l),
            ),
        ]),
      ),
    );
  }

  Future<void> _edit(BuildContext context, ShoppingList? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    var color = existing?.color ?? kListColors[state.lists.length % kListColors.length];
    var emoji = existing?.emoji ?? '🛒';
    final result = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(existing == null ? 'Neue Liste' : 'Liste bearbeiten'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: name, autofocus: existing == null, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 16),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in kListEmojis)
                  ChoiceChip(label: Pikto(emoji: e, size: 24), selected: emoji == e,
                      showCheckmark: false, onSelected: (_) => set(() => emoji = e)),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final col in kListColors)
                  GestureDetector(
                    onTap: () => set(() => color = col),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(col),
                      child: color == col ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  ),
              ]),
            ]),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () => Navigator.pop(c, 'delete'),
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Löschen'),
              ),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Abbrechen')),
            FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('Speichern')),
          ],
        ),
      ),
    );
    if (result == 'save' && name.text.trim().isNotEmpty) {
      final l = existing ?? ShoppingList(name: '', sortOrder: state.lists.length);
      l
        ..name = name.text.trim()
        ..color = color
        ..emoji = emoji;
      await state.saveList(l);
      if (existing == null) state.selectList(l);
    } else if (result == 'delete' && existing != null && context.mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('„${existing.name}“ löschen?'),
          content: const Text('Die Liste und ihr Verlauf werden für alle gelöscht.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Löschen')),
          ],
        ),
      );
      if (ok == true) await state.deleteList(existing);
    }
  }
}
