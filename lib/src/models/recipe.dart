import 'dart:convert';
import 'dart:typed_data';

import 'json_util.dart';
import 'shopping_models.dart' show kSchemaVersion, newId;

/// Ein gespeichertes Rezept (Datei `recipes/<id>.enc`, für beide sichtbar).
///
/// Zutaten und Schritte werden so gespeichert, wie sie im Rezept stehen; das
/// Zerlegen in Artikel und Mengen passiert erst beim Übernehmen auf die Liste.
class Recipe {
  Recipe({
    String? id,
    required this.title,
    this.sourceUrl = '',
    this.servings,
    List<String>? ingredients,
    List<String>? steps,
    this.description = '',
    this.imageJpeg = '',
    this.prepMinutes,
    this.cookMinutes,
    this.totalMinutes,
    this.category = '',
    this.author = '',
    this.calories = '',
    this.notes = '',
    this.addedBy = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.updatedBy = '',
    this.lastUsed,
    Map<String, dynamic>? extra,
  })  : id = id ?? newId(),
        ingredients = ingredients ?? [],
        steps = steps ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        extra = extra ?? {};

  final String id;
  String title;
  String sourceUrl;
  int? servings;

  /// Zutatenzeilen wie im Rezept, z. B. „2 Zehe/n Knoblauch“.
  /// Zeilen mit „:“ am Ende sind Zwischenüberschriften („Für die Soße:“).
  List<String> ingredients;

  /// Arbeitsschritte; Zeilen mit „:“ am Ende sind Abschnittsüberschriften.
  List<String> steps;
  String description;

  /// Vorschaubild (JPEG, Base64, höchstens ~640 px breit).
  String imageJpeg;
  int? prepMinutes;
  int? cookMinutes;
  int? totalMinutes;
  String category;
  String author;
  String calories;

  /// Eigene Notizen.
  String notes;
  String addedBy;
  final DateTime createdAt;
  DateTime updatedAt;
  String updatedBy;

  /// Zuletzt auf die Einkaufsliste übernommen.
  DateTime? lastUsed;
  final Map<String, dynamic> extra;

  String get path => 'recipes/$id.enc';

  String get sourceHost {
    final h = Uri.tryParse(sourceUrl)?.host ?? '';
    return h.startsWith('www.') ? h.substring(4) : h;
  }

  Uint8List? _bytes;

  /// Bilddaten (zwischengespeichert).
  Uint8List? get imageBytes {
    if (imageJpeg.isEmpty) return null;
    try {
      return _bytes ??= base64Decode(imageJpeg);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        ...extra,
        'id': id,
        'title': title,
        if (sourceUrl.isNotEmpty) 'source_url': sourceUrl,
        'servings': ?servings,
        'ingredients': ingredients,
        'steps': steps,
        if (description.isNotEmpty) 'description': description,
        if (imageJpeg.isNotEmpty) 'image_jpeg': imageJpeg,
        'prep_minutes': ?prepMinutes,
        'cook_minutes': ?cookMinutes,
        'total_minutes': ?totalMinutes,
        if (category.isNotEmpty) 'category': category,
        if (author.isNotEmpty) 'author': author,
        if (calories.isNotEmpty) 'calories': calories,
        if (notes.isNotEmpty) 'notes': notes,
        'added_by': addedBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'updated_by': updatedBy,
        if (lastUsed != null) 'last_used': lastUsed!.toIso8601String(),
        'schema_version': kSchemaVersion,
      };

  static const _known = {
    'id', 'title', 'source_url', 'servings', 'ingredients', 'steps', 'description', 'image_jpeg',
    'prep_minutes', 'cook_minutes', 'total_minutes', 'category', 'author', 'calories', 'notes',
    'added_by', 'created_at', 'updated_at', 'updated_by', 'last_used', 'schema_version',
  };

  factory Recipe.fromJson(Map<String, dynamic> j, {String? path}) {
    final id = idFromPath(path) ?? jStrOrNull(j['id']);
    if (id == null || id.isEmpty) throw const FormatException('Rezept ohne ID');
    final servings = jIntOrNull(j['servings']);
    return Recipe(
      id: id,
      title: jStr(j['title'], 'Rezept'),
      sourceUrl: jStr(j['source_url']),
      servings: servings != null && servings > 0 ? servings : null,
      ingredients: jStrings(j['ingredients']),
      steps: jStrings(j['steps']),
      description: jStr(j['description']),
      imageJpeg: jStr(j['image_jpeg']),
      prepMinutes: jIntOrNull(j['prep_minutes']),
      cookMinutes: jIntOrNull(j['cook_minutes']),
      totalMinutes: jIntOrNull(j['total_minutes']),
      category: jStr(j['category']),
      author: jStr(j['author']),
      calories: jStr(j['calories']),
      notes: jStr(j['notes']),
      addedBy: jStr(j['added_by']),
      createdAt: jDate(j['created_at']),
      updatedAt: jDate(j['updated_at']),
      updatedBy: jStr(j['updated_by']),
      lastUsed: jDate(j['last_used']),
      extra: unknownFields(j, _known),
    );
  }
}
