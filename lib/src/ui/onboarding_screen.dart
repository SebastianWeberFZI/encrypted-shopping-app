import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/github_api.dart';
import '../core/werkstatt.dart';
import '../shopping_repository.dart';
import '../werkstatt/demo_data.dart';

/// Erster Start: Name + gemeinsames Daten-Repo verbinden.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.state});
  final AppState state;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
      text: widget.state.settings.userName.isNotEmpty ? widget.state.settings.userName : (kWerkstatt ? kWerkstattUser : ''));
  final _owner = TextEditingController(text: kWerkstatt ? kWerkstattOwner : '');
  final _repo = TextEditingController(text: kWerkstatt ? 'einkauf-gemeinsam' : '');
  final _token = TextEditingController(text: kWerkstatt ? kWerkstattToken : '');
  final _pass = TextEditingController(text: kWerkstatt ? kWerkstattPassphrase : '');
  final _branch = TextEditingController(text: 'main');
  final _api = TextEditingController(text: kWerkstatt ? kWerkstattApiBase : kGithubApiBase);
  bool _busy = false;
  bool _obscure = true;
  bool _obscureToken = true;
  String? _error;

  AppState get state => widget.state;

  Future<void> _connect({bool demo = false}) async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      state.setUserName(_name.text);
      final fresh = await state.connect(
        github: GithubConfig(
          owner: _owner.text.trim(),
          repo: _repo.text.trim(),
          branch: _branch.text.trim().isEmpty ? 'main' : _branch.text.trim(),
          token: _token.text.trim(),
          apiBase: _api.text.trim().isEmpty ? kGithubApiBase : _api.text.trim(),
        ),
        passphrase: _pass.text,
      );
      if (fresh || state.lists.isEmpty) {
        await state.createDefaultLists();
        if (demo) await addDemoItems(state);
      }
      await state.syncNow(silent: true);
    } on SetupException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Fehler: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget field(TextEditingController c, String label, {String? hint, bool secret = false, String? helper}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: c,
            obscureText: secret,
            decoration: InputDecoration(labelText: label, hintText: hint, helperText: helper),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Pflichtfeld' : null,
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.fromLTRB(28, 40, 28, 28), children: [
            const Text('🧺', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text('Eure Einkaufsliste', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text('Gemeinsame Listen, verschlüsselt in eurem eigenen GitHub-Repository. '
                'Tippt etwas an – es landet sofort auf beiden Handys.',
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: 28),
            field(_name, 'Dein Name', helper: 'Erscheint bei Änderungen („Sarah hat Milch hinzugefügt“)'),
            field(_owner, 'GitHub-Besitzer'),
            field(_repo, 'Daten-Repository', hint: 'z. B. encrypted-shopping-gemeinsam'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: _token,
                obscureText: _obscureToken,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                  labelText: 'Fine-grained Token',
                  helperText: 'Nur „Contents: Read and write“ auf dieses Repo',
                  suffixIcon: IconButton(
                    tooltip: _obscureToken ? 'Token anzeigen' : 'Token verbergen',
                    icon: Icon(_obscureToken ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureToken = !_obscureToken),
                  ),
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Pflichtfeld' : null,
              ),
            ),
            TextFormField(
              controller: _pass,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Gemeinsame Passphrase',
                helperText: 'Auf beiden Handys gleich. Vergessen = Daten verloren.',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v ?? '').length < 8 ? 'Mindestens 8 Zeichen' : null,
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Erweitert'),
              initiallyExpanded: kWerkstatt,
              children: [field(_branch, 'Branch'), field(_api, 'API-Adresse')],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : () => _connect(),
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Verbinden'),
            ),
            if (kWerkstatt) ...[
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.bolt),
                label: const Text('Werkstatt-Schnellstart mit Demo-Artikeln'),
                onPressed: _busy ? null : () => _connect(demo: true),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
