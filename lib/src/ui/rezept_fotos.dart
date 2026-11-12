import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../models/recipe.dart';
import '../shopping_repository.dart';

/// Ein Rezeptfoto – lädt es bei Bedarf (vom Gerät oder aus dem Repo).
class FotoBild extends StatefulWidget {
  const FotoBild({
    super.key,
    required this.repo,
    required this.id,
    this.bytes,
    this.fit = BoxFit.cover,
    this.decodeHeight,
  });
  final ShoppingRepository repo;
  final String id;

  /// Schon vorhandene Bilddaten (z. B. gerade aufgenommen, noch nicht gespeichert).
  final Uint8List? bytes;
  final BoxFit fit;

  /// Zum Sparen von Speicher kleiner dekodieren (logische Pixel).
  final double? decodeHeight;

  @override
  State<FotoBild> createState() => _FotoBildState();
}

class _FotoBildState extends State<FotoBild> {
  Future<Uint8List?>? _future;
  Uint8List? _daten;
  bool _fehler = false;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  @override
  void didUpdateWidget(FotoBild old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id || old.bytes != widget.bytes) _laden();
  }

  void _laden() {
    _daten = widget.bytes ?? widget.repo.photos?.cached(widget.id);
    _fehler = false;
    if (_daten != null) return;
    final f = _future = widget.repo.loadPhoto(widget.id);
    f.then((d) {
      if (mounted && _future == f) setState(() => _daten = d);
    }, onError: (_) {
      if (mounted && _future == f) setState(() => _fehler = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _daten;
    if (d != null) {
      final h = widget.decodeHeight;
      return Image.memory(
        d,
        fit: widget.fit,
        gaplessPlayback: true,
        cacheHeight: h == null ? null : (h * MediaQuery.devicePixelRatioOf(context)).round(),
      );
    }
    final laedt = !_fehler && _future != null;
    return GestureDetector(
      onTap: laedt ? null : () => setState(_laden),
      child: Container(
        color: theme.colorScheme.surfaceContainerHigh,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: FutureBuilder(
          future: _future,
          builder: (c, s) => s.connectionState == ConnectionState.waiting && !_fehler
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_fehler ? Icons.cloud_off_outlined : Icons.hourglass_empty,
                      color: theme.colorScheme.outline),
                  const SizedBox(height: 4),
                  Text(
                    _fehler ? 'Nicht geladen – antippen' : 'Noch nicht da',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ]),
        ),
      ),
    );
  }
}

/// Fotos eines Rezepts als waagerechte Leiste; Antippen öffnet die Vollbildansicht.
class FotoLeiste extends StatelessWidget {
  const FotoLeiste({super.key, required this.repo, required this.photos, this.hoehe = 180});
  final ShoppingRepository repo;
  final List<RecipePhoto> photos;
  final double hoehe;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hoehe,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (c, i) {
          final p = photos[i];
          final breite = (hoehe * (p.aspect ?? 0.75)).clamp(hoehe * 0.5, hoehe * 1.8);
          return Semantics(
            button: true,
            label: 'Foto ${i + 1} von ${photos.length} öffnen',
            child: GestureDetector(
              onTap: () => Navigator.push(
                  c, MaterialPageRoute(builder: (_) => FotoAnsicht(repo: repo, photos: photos, start: i))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: breite,
                  height: hoehe,
                  child: Hero(tag: 'foto-${p.id}', child: FotoBild(repo: repo, id: p.id, decodeHeight: hoehe)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Vollbild zum Lesen (z. B. der Kochbuchseite): wischen, zoomen,
/// doppelt tippen vergrößert.
class FotoAnsicht extends StatefulWidget {
  const FotoAnsicht({super.key, required this.repo, required this.photos, this.start = 0});
  final ShoppingRepository repo;
  final List<RecipePhoto> photos;
  final int start;

  @override
  State<FotoAnsicht> createState() => _FotoAnsichtState();
}

class _FotoAnsichtState extends State<FotoAnsicht> {
  late final _seiten = PageController(initialPage: widget.start);
  late int _index = widget.start;
  final Map<int, TransformationController> _zoom = {};
  bool _gezoomt = false;

  TransformationController _ctrl(int i) => _zoom.putIfAbsent(i, TransformationController.new);

  @override
  void dispose() {
    _seiten.dispose();
    for (final c in _zoom.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _zoomGeaendert() {
    final z = _ctrl(_index).value.getMaxScaleOnAxis() > 1.01;
    if (z != _gezoomt) setState(() => _gezoomt = z);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.photos.length;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black38,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: n > 1 ? Text('${_index + 1} / $n', style: const TextStyle(color: Colors.white)) : null,
      ),
      body: PageView.builder(
        controller: _seiten,
        // Beim Zoomen verschiebt Wischen den Ausschnitt statt zu blättern.
        physics: _gezoomt ? const NeverScrollableScrollPhysics() : null,
        itemCount: n,
        onPageChanged: (i) => setState(() {
          _ctrl(_index).value = Matrix4.identity();
          _index = i;
          _gezoomt = false;
        }),
        itemBuilder: (c, i) {
          final ctrl = _ctrl(i);
          final p = widget.photos[i];
          TapDownDetails? tipp;
          return GestureDetector(
            onDoubleTapDown: (d) => tipp = d,
            onDoubleTap: () {
              if (ctrl.value.getMaxScaleOnAxis() > 1.01) {
                ctrl.value = Matrix4.identity();
              } else {
                final pos = tipp?.localPosition ?? Offset.zero;
                const s = 2.5;
                ctrl.value = Matrix4.identity()
                  ..translateByDouble(-pos.dx * (s - 1), -pos.dy * (s - 1), 0, 1)
                  ..scaleByDouble(s, s, 1, 1);
              }
              _zoomGeaendert();
            },
            child: InteractiveViewer(
              transformationController: ctrl,
              minScale: 1,
              maxScale: 6,
              onInteractionEnd: (_) => _zoomGeaendert(),
              child: SizedBox.expand(
                child: Hero(
                  tag: 'foto-${p.id}',
                  child: FotoBild(repo: widget.repo, id: p.id, fit: BoxFit.contain),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
