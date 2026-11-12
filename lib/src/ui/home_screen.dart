import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../app_state.dart';
import '../models/catalog.dart';
import '../models/shopping_models.dart';
import '../services/share_service.dart';
import 'item_sheet.dart';
import 'item_tile.dart';
import 'lists_screen.dart';
import 'pikto.dart';
import 'rezept_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});
  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<String> _openCategories = {};
  StreamSubscription<Uri?>? _widgetClicks;
  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    state.toast.addListener(_toast);
    if (Platform.isAndroid) {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri).catchError((_) {});
      _widgetClicks = HomeWidget.widgetClicked.listen(_handleWidgetUri, onError: (_) {});
      ShareService.initial().then((t) {
        if (t != null) _handleShare(t);
      });
      ShareService.listen(_handleShare);
    }
  }

  @override
  void dispose() {
    state.toast.removeListener(_toast);
    _widgetClicks?.cancel();
    super.dispose();
  }

  /// Aus dem Widget: einkauf://list?list=… (Liste zeigen), einkauf://add?list=… (Artikel suchen).
  /// Aus einer anderen App geteilt (Rezeptlink oder Zutatenliste).
  void _handleShare(String text) {
    if (!mounted || text.trim().isEmpty) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (state.currentList == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => RezeptScreen(state: state, text: text)));
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null || !mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    final id = uri.queryParameters['list'];
    final l = id == null ? null : state.repo.list(id);
    if (l != null) state.selectList(l);
    if (uri.host == 'add') _openSearch(context);
  }

  void _toast() {
    final m = state.toast.value;
    if (m == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 3)));
    state.toast.value = null;
  }

  String? _badge(ShopItem i) {
    if (i.addedBy.isEmpty || i.addedBy == state.me) return null;
    if (DateTime.now().difference(i.addedAt).inHours > 48) return null;
    return i.addedBy.characters.first.toUpperCase();
  }

  Future<void> _bought(ShopItem i) async {
    await state.bought(i);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${i.name} eingekauft'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(label: 'Rückgängig', onPressed: () => state.needed(i)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final l = state.currentList;
        if (l == null) return _noLists(context);
        final color = Color(l.color);
        final theme = Theme.of(context);
        final cols = state.settings.columns;
        final needed = state.repo.needed(l.id);
        final recent = state.repo.recent(l.id);
        final suggestions = state.settings.showSuggestions ? state.repo.suggestions(l.id) : <ShopItem>[];
        final activity = state.repo.activities
            .where((a) =>
                a.listId == l.id &&
                a.by != state.me &&
                a.type == Activity.goingShopping &&
                DateTime.now().difference(a.at).inMinutes < 90)
            .firstOrNull;

        Widget header(String title, {String? trailing, Widget? action}) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 8, 10),
                child: Row(children: [
                  Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  if (trailing != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(trailing, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
                    ),
                  const Spacer(),
                  ?action,
                ]),
              ),
            );

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            title: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _pickList(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Pikto(emoji: l.emoji, size: 28),
                  const SizedBox(width: 8),
                  Flexible(child: Text(l.name, overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.arrow_drop_down),
                ]),
              ),
            ),
            actions: [
              _SyncIcon(state: state),
              IconButton(
                tooltip: 'Ich gehe einkaufen',
                icon: const Icon(Icons.directions_walk),
                onPressed: () async {
                  await state.goingShopping();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Die anderen wissen jetzt, dass du einkaufen gehst.')));
                  }
                },
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'all') state.boughtAll();
                  if (v == 'lists') _openLists(context);
                  if (v == 'settings') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(state: state)));
                  }
                },
                itemBuilder: (_) => [
                  if (needed.isNotEmpty) const PopupMenuItem(value: 'all', child: Text('Alles eingekauft')),
                  const PopupMenuItem(value: 'lists', child: Text('Listen verwalten')),
                  const PopupMenuItem(value: 'settings', child: Text('Einstellungen')),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => state.syncNow(),
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _SearchBar(color: color, onTap: () => _openSearch(context))),
              if (activity != null)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      const Text('🛒', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text('${activity.by} ist gerade einkaufen – was noch fehlt, schnell eintragen.')),
                    ]),
                  ),
                ),
              header('Einkaufsliste', trailing: needed.isEmpty ? null : '${needed.length}'),
              if (needed.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(children: [
                      const Text('🎉', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 8),
                      Text('Alles erledigt', style: theme.textTheme.titleMedium),
                      Text('Tippe unten auf einen Artikel, um ihn hinzuzufügen.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
                    ]),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: tileGrid(
                    columns: cols,
                    count: needed.length,
                    builder: (c, i) => ItemTile(
                      key: ValueKey('n${needed[i].id}'),
                      emoji: needed[i].emoji,
                      icon: needed[i].icon,
                      name: needed[i].name,
                      spec: needed[i].spec,
                      style: TileStyle.needed,
                      color: color,
                      badge: _badge(needed[i]),
                      onTap: () => _bought(needed[i]),
                      onLongPress: () => showItemSheet(context, state, needed[i]),
                    ),
                  ),
                ),
              if (suggestions.isNotEmpty) ...[
                header('Vorschläge', trailing: 'wird bald wieder gebraucht'),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 104,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: suggestions.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (c, i) => SizedBox(
                        width: 96,
                        child: ItemTile(
                          emoji: suggestions[i].emoji,
                          icon: suggestions[i].icon,
                          name: suggestions[i].name,
                          style: TileStyle.suggestion,
                          color: color,
                          onTap: () => state.needed(suggestions[i]),
                          onLongPress: () => showItemSheet(context, state, suggestions[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (recent.isNotEmpty) ...[
                header('Zuletzt verwendet'),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: tileGrid(
                    columns: cols,
                    count: recent.length.clamp(0, cols * 3),
                    builder: (c, i) => ItemTile(
                      key: ValueKey('r${recent[i].id}'),
                      emoji: recent[i].emoji,
                      icon: recent[i].icon,
                      name: recent[i].name,
                      spec: recent[i].spec,
                      style: TileStyle.recent,
                      color: color,
                      onTap: () => state.needed(recent[i]),
                      onLongPress: () => showItemSheet(context, state, recent[i]),
                    ),
                  ),
                ),
              ],
              if (state.settings.showCatalog) ...[
                header('Alle Artikel'),
                for (final cat in kCategories) ..._catalogSection(context, cat, l, cols, color),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ]),
          ),
        );
      },
    );
  }

  List<Widget> _catalogSection(BuildContext context, Category cat, ShoppingList l, int cols, Color color) {
    final theme = Theme.of(context);
    final custom = state.repo.customArticles.where((a) => a.category == cat.key);
    final entries = <(String, String, String?)>[
      for (final c in kCatalog.where((c) => c.category == cat.key)) (c.name, c.emoji, null),
      for (final a in custom) (a.name, a.emoji, a.icon),
    ];
    if (entries.isEmpty) return [];
    final open = _openCategories.contains(cat.key);
    return [
      SliverToBoxAdapter(
        child: InkWell(
          onTap: () => setState(() => open ? _openCategories.remove(cat.key) : _openCategories.add(cat.key)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Pikto(emoji: cat.emoji, size: 26),
              const SizedBox(width: 12),
              Expanded(child: Text(cat.name, style: theme.textTheme.bodyLarge)),
              Text('${entries.length}', style: TextStyle(color: theme.colorScheme.outline)),
              Icon(open ? Icons.expand_less : Icons.expand_more, color: theme.colorScheme.outline),
            ]),
          ),
        ),
      ),
      if (open)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          sliver: tileGrid(
            columns: cols,
            count: entries.length,
            builder: (c, i) {
              final (name, emoji, icon) = entries[i];
              final existing = state.repo.itemByName(l.id, name);
              final onList = existing?.needed ?? false;
              return ItemTile(
                emoji: emoji,
                icon: existing?.icon ?? icon,
                name: name,
                style: TileStyle.catalog,
                selected: onList,
                color: color,
                onTap: () => onList
                    ? state.removeFromList(existing!)
                    : state.add(name, emoji: emoji, icon: icon, category: cat.key),
                onLongPress: existing == null ? null : () => showItemSheet(context, state, existing),
              );
            },
          ),
        ),
    ];
  }

  Widget _noLists(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Einkaufsliste')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Noch keine Liste'),
            const SizedBox(height: 12),
            FilledButton(onPressed: state.createDefaultLists, child: const Text('Standardlisten anlegen')),
          ]),
        ),
      );

  Future<void> _openSearch(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(state: state)));

  Future<void> _openLists(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ListsScreen(state: state)));

  Future<void> _pickList(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final l in state.lists)
            ListTile(
              leading: CircleAvatar(
                  backgroundColor: Color(l.color).withValues(alpha: 0.15), child: Pikto(emoji: l.emoji, size: 24)),
              title: Text(l.name),
              trailing: Text('${state.repo.needed(l.id).length}',
                  style: TextStyle(color: Color(l.color), fontWeight: FontWeight.w700)),
              selected: l.id == state.currentList?.id,
              onTap: () {
                state.selectList(l);
                Navigator.pop(c);
              },
            ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Listen verwalten'),
            onTap: () {
              Navigator.pop(c);
              _openLists(context);
            },
          ),
        ]),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.color, required this.onTap});
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              Icon(Icons.search, color: color),
              const SizedBox(width: 12),
              Text('Was brauchst du?', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SyncIcon extends StatelessWidget {
  const _SyncIcon({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.syncing) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final pending = state.repo.pendingCount;
    final err = state.repo.error;
    final notice = state.repo.notice;
    final needsUpdate = (err ?? notice ?? '').contains('neueren App-Version');
    return IconButton(
      tooltip: err ?? notice ?? (pending > 0 ? '$pending Änderung(en) ausstehend' : 'Synchronisiert'),
      onPressed: () => state.syncNow(),
      icon: Badge(
        isLabelVisible: pending > 0,
        label: Text('$pending'),
        child: Icon(needsUpdate
            ? Icons.system_update_alt
            : err != null
            ? Icons.cloud_off_outlined
            : pending > 0
                ? Icons.cloud_upload_outlined
                : Icons.cloud_done_outlined),
      ),
    );
  }
}
