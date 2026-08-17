import 'inventory_entry.dart';
import 'paint_list.dart';

/// Painting techniques a recipe section can use.
enum PaintTechnique {
  basecoat,
  layering,
  wash,
  drybrush,
  highlight,
  glaze,
  stipple,
  blending,
  freehand;

  static PaintTechnique? tryParse(String? value) {
    if (value == null) return null;
    for (final technique in PaintTechnique.values) {
      if (technique.name == value) return technique;
    }
    return null;
  }
}

/// A web page or video the recipe drew inspiration from.
class RecipeLink {
  const RecipeLink({required this.title, required this.url});

  final String title;
  final String url;

  bool get isYouTube {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.contains('youtube.') || host == 'youtu.be';
  }

  Map<String, dynamic> toMap() => {'title': title, 'url': url};

  static RecipeLink? fromMap(Map<String, dynamic> map) {
    final title = map['title'] as String?;
    final url = map['url'] as String?;
    if (title == null || url == null) return null;
    return RecipeLink(title: title, url: url);
  }
}

/// One ordered step of a section: a role ("Basecoat", "First highlight"…),
/// optionally the paint used and a short note ("heavy drybrush").
///
/// The ORDER of the steps is the recipe — that is what makes it repeatable.
class RecipeStep {
  const RecipeStep({required this.title, this.paintId, this.note = ''});

  final String title;
  final String? paintId;
  final String note;

  RecipeStep copyWith({String? title, String? paintId, String? note}) {
    return RecipeStep(
      title: title ?? this.title,
      paintId: paintId ?? this.paintId,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        if (paintId != null) 'paintId': paintId,
        'note': note,
      };

  static RecipeStep? fromMap(Map<String, dynamic> map) {
    final title = map['title'] as String?;
    if (title == null) return null;
    return RecipeStep(
      title: title,
      paintId: map['paintId'] as String?,
      note: map['note'] as String? ?? '',
    );
  }
}

/// One part of the miniature — armour, cloak, base… — with the ordered steps
/// that painted it.
class RecipeSection {
  const RecipeSection({
    required this.name,
    this.steps = const [],
    this.techniques = const {},
    this.notes = '',
  });

  final String name;
  final List<RecipeStep> steps;
  final Set<PaintTechnique> techniques;

  /// Extra remarks that do not belong to any single step.
  final String notes;

  /// Paints used across the steps, in step order, deduplicated.
  List<String> get paintIds {
    final seen = <String>{};
    return [
      for (final step in steps)
        if (step.paintId != null && seen.add(step.paintId!)) step.paintId!,
    ];
  }

  RecipeSection copyWith({
    String? name,
    List<RecipeStep>? steps,
    Set<PaintTechnique>? techniques,
    String? notes,
  }) {
    return RecipeSection(
      name: name ?? this.name,
      steps: steps ?? this.steps,
      techniques: techniques ?? this.techniques,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'steps': steps.map((s) => s.toMap()).toList(),
        'techniques': techniques.map((t) => t.name).toList(),
        'notes': notes,
      };

  static RecipeSection? fromMap(Map<String, dynamic> map) {
    final name = map['name'] as String?;
    if (name == null) return null;
    var steps = (map['steps'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RecipeStep.fromMap)
        .whereType<RecipeStep>()
        .toList();
    if (steps.isEmpty) {
      // Legacy documents stored a flat paint list; surface it as untitled
      // steps so nothing is lost.
      steps = (map['paintIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((id) => RecipeStep(title: '', paintId: id))
          .toList();
    }
    return RecipeSection(
      name: name,
      steps: steps,
      techniques: (map['techniques'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map(PaintTechnique.tryParse)
          .whereType<PaintTechnique>()
          .toSet(),
      notes: map['notes'] as String? ?? '',
    );
  }
}

/// A painting recipe: how a miniature (or part of one) was painted, section
/// by section, with the paints used and links to the sources of inspiration.
class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    this.description = '',
    this.sections = const [],
    this.links = const [],
    this.photo,
    this.photoUrl,
    this.publishedId,
    this.published = false,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final List<RecipeSection> sections;
  final List<RecipeLink> links;

  /// LEGACY cover photo, base64 inside the document.
  ///
  /// Written before Cloud Storage was available on this project. Still read
  /// so existing recipes keep their picture, but never written again — new
  /// photos go to [photoUrl].
  final String? photo;

  /// Cover photo in Cloud Storage, as a download URL.
  final String? photoUrl;

  /// Whether this recipe has a picture at all, from either source.
  bool get hasPhoto =>
      (photoUrl != null && photoUrl!.isNotEmpty) ||
      (photo != null && photo!.isNotEmpty);

  /// Id of the public copy in `publishedRecipes`, assigned the first time
  /// this recipe is shared and then kept forever — including through an
  /// unshare/reshare cycle — so a share link and a follower's link both
  /// keep pointing at the same place instead of going stale when the recipe
  /// comes back.
  final String? publishedId;

  final DateTime updatedAt;

  /// Whether the recipe is shared RIGHT NOW, as opposed to merely having a
  /// [publishedId] from a past share. Deliberately separate from
  /// [publishedId] not being null: unsharing must not forget the id, or
  /// resharing would hand out a new one and orphan every existing link.
  final bool published;

  bool get isPublished => published;

  /// Every paint used across all sections, deduplicated.
  Set<String> get allPaintIds =>
      {for (final section in sections) ...section.paintIds};

  /// Whether the shelf is ready to paint this recipe right now.
  PaintListReadiness readiness(Map<String, InventoryEntry> inventory) =>
      readinessOf(allPaintIds, inventory);

  Recipe copyWith({
    String? name,
    String? description,
    List<RecipeSection>? sections,
    List<RecipeLink>? links,
    String? photo,
    String? photoUrl,
    bool clearPhoto = false,
    String? publishedId,
    bool? published,
  }) {
    return Recipe(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      sections: sections ?? this.sections,
      links: links ?? this.links,
      photo: clearPhoto ? null : (photo ?? this.photo),
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      publishedId: publishedId ?? this.publishedId,
      published: published ?? this.published,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'sections': sections.map((s) => s.toMap()).toList(),
        'links': links.map((l) => l.toMap()).toList(),
        if (photo != null) 'photo': photo,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (publishedId != null) 'publishedId': publishedId,
        'published': published,
      };
}
