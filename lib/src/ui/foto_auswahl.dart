import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

import '../services/fotos.dart';

/// Fragt nach Kamera oder Galerie, lässt Fotos aufnehmen bzw. auswählen und
/// bereitet sie auf (drehen, verkleinern, Metadaten entfernen).
Future<List<FotoDaten>> fotosWaehlen(BuildContext context) async {
  final picker = ImagePicker();
  final kamera = picker.supportsImageSource(ImageSource.camera);
  final quelle = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (kamera)
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Foto aufnehmen'),
            subtitle: const Text('z. B. die Kochbuchseite oder das fertige Gericht'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Aus der Galerie'),
          subtitle: const Text('Auch mehrere auf einmal, z. B. Seite für Seite'),
          onTap: () => Navigator.pop(c, ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (quelle == null) return [];
  // Vorab verkleinern lassen (schnell, nativ); den Rest erledigt fotoAufbereiten.
  const kante = 2400.0;
  List<XFile> dateien;
  try {
    if (quelle == ImageSource.camera) {
      final f = await picker.pickImage(source: ImageSource.camera, maxWidth: kante, maxHeight: kante, imageQuality: 92);
      dateien = [?f];
    } else {
      dateien = await picker.pickMultiImage(maxWidth: kante, maxHeight: kante, imageQuality: 92, limit: 10);
    }
  } on PlatformException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.code == 'no_available_camera' ? 'Keine Kamera gefunden.' : 'Foto konnte nicht geöffnet werden.')));
    }
    return [];
  }
  if (dateien.isEmpty || !context.mounted) return [];

  final fertig = <FotoDaten>[];
  final fortschritt = ValueNotifier(0);
  final navigator = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(width: 20),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: fortschritt,
              builder: (c, n, _) => Text(dateien.length == 1
                  ? 'Foto wird vorbereitet …'
                  : 'Fotos werden vorbereitet … ${n + 1} von ${dateien.length}'),
            ),
          ),
        ]),
      ),
    ),
  );
  try {
    for (final d in dateien) {
      final f = await compute(fotoAufbereiten, await d.readAsBytes());
      if (f != null) fertig.add(f);
      fortschritt.value++;
    }
  } finally {
    navigator.pop();
    fortschritt.dispose();
  }
  if (fertig.length < dateien.length && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ein Foto ließ sich nicht lesen und wurde übersprungen.')));
  }
  return fertig;
}
