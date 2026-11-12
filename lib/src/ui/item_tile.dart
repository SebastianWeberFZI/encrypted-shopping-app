import 'package:flutter/material.dart';

import 'pikto.dart';

enum TileStyle { needed, recent, catalog, suggestion }

/// Quadratische Artikelkachel (Piktogramm + Name + Details).
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.emoji,
    this.icon,
    required this.name,
    this.spec = '',
    required this.style,
    required this.color,
    this.onTap,
    this.onLongPress,
    this.badge,
    this.selected = false,
  });

  final String emoji;
  final String? icon;
  final String name;
  final String spec;
  final TileStyle style;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Kleines Kürzel oben rechts (z. B. Initiale der Person, die es hinzugefügt hat).
  final String? badge;

  /// Für Katalog/Suche: Artikel steht bereits auf der Liste.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = style == TileStyle.needed || selected;
    final bg = filled
        ? color
        : style == TileStyle.suggestion
            ? color.withValues(alpha: 0.10)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.7);
    final fg = filled ? Colors.white : scheme.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(fit: StackFit.expand, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Opacity(
                opacity: style == TileStyle.recent || style == TileStyle.catalog ? 0.92 : 1,
                child: Pikto(icon: icon, name: name, emoji: emoji, size: 40),
              ),
              const SizedBox(height: 6),
              // Lange Einzelwörter ("Spülmaschinentabs") verkleinern statt mitten im Wort umbrechen
              if (!name.contains(' ') && name.length > 9)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(name,
                      maxLines: 1,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg)),
                )
              else
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5, height: 1.15, fontWeight: FontWeight.w600, color: fg),
                ),
              if (spec.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    spec,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.82)),
                  ),
                ),
            ]),
          ),
          if (badge != null)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: filled ? Colors.white : color,
                  shape: BoxShape.circle,
                ),
                child: Text(badge!,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: filled ? color : Colors.white)),
              ),
            ),
          if (style == TileStyle.suggestion)
            Positioned(
              top: 6,
              left: 6,
              child: Icon(Icons.add_circle, size: 16, color: color),
            ),
        ]),
      ),
    );
  }
}

/// Gitter aus Kacheln mit fester Spaltenzahl.
SliverGrid tileGrid({required int columns, required int count, required IndexedWidgetBuilder builder}) =>
    SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: columns >= 4 ? 0.9 : 1.0,
      ),
      delegate: SliverChildBuilderDelegate(builder, childCount: count),
    );
