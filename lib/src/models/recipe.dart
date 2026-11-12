import 'dart:convert';
import 'dart:typed_data';

import 'json_util.dart';
import 'shopping_models.dart' show kSchemaVersion, newId;

/// Foto zu einem Rezept (z. B. die Kochbuchseite). Die Bilddaten liegen
/// getrennt unter `photos/<id>.enc` und werden erst beim Anzeigen geladen.
class RecipePhoto {
  RecipePhoto({required this.id, this.width, this.height, Map<String, dynamic>? extra}) : extra = extra ?? {};

  final String id;
  final int? width;
  final int? height;
  final Map<String, dynamic> extra;

  /// Seitenverhältnis (Breite/Höhe), falls bekannt.
  double? get aspect => width != null && height != null && width! > 0 && height! > 0 ? width! / height! : null;

  Map<String, dynamic> toJson() => {...extra, 'id': id, 'w': ?width, 'h': ?height};

  static RecipePhoto? tryParse(Object? v) {
    if (v is String && v.isNotEmpty) return RecipePhoto(id: v);
    if (v is! Map) return null;
    final m = v.cast<String, dynamic>();
    final id = jStrOrNull(m['id']);
    if (id == null || id.isEmpty || id.contains('/')) return null;
    return RecipePhoto(
      id: id,
      width: jIntOrNull(m['w']),
      height: jIntOrNull(m['h']),
      extra: unknownFields(m, const {'id', 'w', 'h'}),
    );
  }
}

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
    List<RecipePhoto>? photos,
    this.description = '',
    this._imageJpeg = '',
    this.coverPhoto = '',
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
        photos = photos ?? [],
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

  /// Eigene Fotos, z. B. die Kochbuchseite oder das fertige Gericht.
  List<RecipePhoto> photos;
  String description;

  /// Vorschaubild (JPEG, Base64, höchstens ~640 px breit).
  String get imageJpeg => _imageJpeg;
  set imageJpeg(String v) {
    _imageJpeg = v;
    _bytes = null;
  }

  String _imageJpeg;

  /// Aus welchem eigenen Foto das Vorschaubild stammt (leer: aus dem
  /// Originalrezept oder keines).
  String coverPhoto;
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
        if (photos.isNotEmpty) 'photos': [for (final p in photos) p.toJson()],
        if (description.isNotEmpty) 'description': description,
        if (imageJpeg.isNotEmpty) 'image_jpeg': imageJpeg,
        if (coverPhoto.isNotEmpty) 'cover_photo': coverPhoto,
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
    'id', 'title', 'source_url', 'servings', 'ingredients', 'steps', 'photos', 'description', 'image_jpeg', 'cover_photo',
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
      photos: photoList(j['photos']),
      description: jStr(j['description']),
      imageJpeg: jStr(j['image_jpeg']),
      coverPhoto: jStr(j['cover_photo']),
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

/// Fotoverweise eines Rezepts (tolerant: fehlende oder kaputte Einträge fallen weg).
List<RecipePhoto> photoList(Object? v) =>
    v is List ? v.map(RecipePhoto.tryParse).whereType<RecipePhoto>().toList() : [];
