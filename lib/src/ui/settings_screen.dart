import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_state.dart';
import '../background/background_worker.dart';
import '../core/werkstatt.dart';
import '../werkstatt/demo_data.dart';
import 'lists_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final s = state.settings;
        final theme = Theme.of(context);
        final cfg = state.repo.config;
        Widget header(String t) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
              child: Text(t,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
            );
        return Scaffold(
          appBar: AppBar(title: const Text('Einstellungen')),
          body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            header('Profil'),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(s.userName),
              subtitle: const Text('So sieht die andere Person deine Änderungen'),
              onTap: () async {
                final c = TextEditingController(text: s.userName);
                final n = await showDialog<String>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('Dein Name'),
                    content: TextField(controller: c, autofocus: true),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
                      FilledButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('OK')),
                    ],
                  ),
                );
                if (n != null && n.trim().isNotEmpty) state.setUserName(n);
              },
            ),
            header('Listen'),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Listen verwalten'),
              subtitle: Text(state.lists.map((l) => l.name).join(', ')),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ListsScreen(state: state))),
            ),
            header('Benachrichtigungen'),
            SwitchListTile(
              secondary: const Icon(Icons.playlist_add_check),
              title: const Text('Wenn jemand Artikel hinzufügt oder einkauft'),
              value: s.notifyChanges,
              onChanged: (v) {
                s.notifyChanges = v;
                state.settingsChanged();
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.directions_walk),
              title: const Text('Wenn jemand „Ich gehe einkaufen“ meldet'),
              value: s.notifyShopping,
              onChanged: (v) {
                s.notifyShopping = v;
                state.settingsChanged();
              },
            ),
            ListTile(
              leading: const SizedBox(),
              title: const Text('Test-Benachrichtigung'),
              subtitle: const Text('Im Hintergrund wird etwa alle 15 Minuten abgeglichen, bei offener App alle 30 Sekunden.'),
              onTap: () => state.notifications.showTest(),
            ),
            header('Ansicht'),
            SwitchListTile(
              secondary: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Vorschläge anzeigen'),
              subtitle: const Text('Regelmäßig gekaufte Artikel, die bald wieder fällig sind'),
              value: s.showSuggestions,
              onChanged: (v) {
                s.showSuggestions = v;
                state.settingsChanged();
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.grid_view),
              title: const Text('Alle Artikel nach Bereichen zeigen'),
              value: s.showCatalog,
              onChanged: (v) {
                s.showCatalog = v;
                state.settingsChanged();
              },
            ),
            ListTile(
              leading: const Icon(Icons.view_module_outlined),
              title: const Text('Kachelgröße'),
              trailing: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 3, label: Text('Groß')),
                  ButtonSegment(value: 4, label: Text('Klein')),
                ],
                selected: {s.columns},
                onSelectionChanged: (v) {
                  s.columns = v.first;
                  state.settingsChanged();
                },
              ),
            ),
            header('Verbindung'),
            if (cfg != null)
              ListTile(
                leading: Icon(cfg.isMock ? Icons.science_outlined : Icons.lock_outline),
                title: Text('${cfg.owner}/${cfg.repo}'),
                subtitle: Text(state.repo.error ??
                    (state.repo.lastSync == null ? 'noch nicht synchronisiert' : 'Letzter Abgleich ${_fmt(state.repo.lastSync!)}')),
                trailing: IconButton(icon: const Icon(Icons.sync), onPressed: () => state.syncNow()),
              ),
            ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text('Verbindung trennen'),
              subtitle: const Text('Entfernt Token, Schlüssel und lokale Daten von diesem Gerät'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('Verbindung trennen?'),
                    content: const Text('Die verschlüsselten Daten im Repository bleiben erhalten.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
                      FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Trennen')),
                    ],
                  ),
                );
                if (ok == true) {
                  await state.disconnect();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
            header('Info'),
            FutureBuilder(
              future: PackageInfo.fromPlatform(),
              builder: (c, snap) => ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text('Version ${snap.data?.version ?? ''}${kWerkstatt ? ' (Werkstatt)' : ''}'),
              ),
            ),
            if (kWerkstatt && defaultTargetPlatform == TargetPlatform.android)
              ListTile(
                leading: const Icon(Icons.schedule_send_outlined),
                title: const Text('Hintergrund-Abruf testen'),
                subtitle: const Text('Läuft in 15 s wie im Hintergrund – App danach mit der Home-Taste verlassen'),
                onTap: () async {
                  await triggerBackgroundOnce();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Hintergrund-Abruf in 15 s – jetzt die App verlassen')));
                  }
                },
              ),
            if (kWerkstatt)
              ListTile(
                leading: const Icon(Icons.science_outlined),
                title: const Text('Demo-Artikel mit Kaufverlauf anlegen'),
                onTap: () async {
                  await addDemoItems(state);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo-Artikel angelegt')));
                  }
                },
              ),
          ]),
        );
      },
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day}.${d.month}. ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
