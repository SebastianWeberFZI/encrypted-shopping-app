import 'package:flutter/material.dart';

import '../models/pikto.dart';

/// Piktogramm eines Artikels, einer Liste oder eines Ladenbereichs –
/// mitgeliefertes Bild, sonst das Emoji als Text.
class Pikto extends StatelessWidget {
  const Pikto({super.key, this.icon, this.name, required this.emoji, this.size = 32});

  final String? icon;
  final String? name;
  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final key = resolvePikto(icon: icon, name: name, emoji: emoji);
    final fallback = SizedBox(
      width: size,
      height: size,
      child: Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.8, height: 1))),
    );
    if (key == null) return fallback;
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.asset(
      piktoAsset(key),
      width: size,
      height: size,
      cacheWidth: px,
      cacheHeight: px,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
