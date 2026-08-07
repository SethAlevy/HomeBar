// ============================================================================
// Ingredient
// ----------------------------------------------------------------------------
// A "model" class: a plain Dart object that just holds data, with no
// Flutter/UI code in it at all. Models describe the *shape* of the app's
// data so the rest of the code (screens, services) can pass it around in a
// type-safe way instead of juggling raw Maps everywhere.
//
// This one represents a single item in the home bar inventory, e.g. one
// bottle of rum or one carton of orange juice.
// ============================================================================
class Ingredient {
  // Display name (e.g., "Bacardi", "Orange Juice").
  final String name;

  // Brand or producer of the ingredient.
  final String producer;

  // Free-form notes shown in the UI.
  final String description;

  // How many bottles/units we currently have. Not `final` (unlike the
  // fields above) because the app is expected to update this number in
  // place as stock changes, without needing to build a whole new object.
  int bottlesCount;

  // Labels used for searching/filtering (e.g., "fresh", "bourbon").
  final List<String> tags;

  // The main constructor. `required this.xxx` is Dart shorthand that both
  // declares the constructor parameter and assigns it straight to the
  // matching field - equivalent to writing `this.name = name` by hand.
  Ingredient({
    required this.name,
    required this.producer,
    required this.description,
    required this.bottlesCount,
    required this.tags,
  });

  // Converts this object into a plain Map<String, dynamic>, using the exact
  // key names our YAML file format expects (snake_case, matching the YAML
  // files under assets/data/). This is the mirror image of fromYaml() below
  // - together they're how an Ingredient survives being saved to disk and
  // loaded back later.
  Map<String, dynamic> toYaml() => {
        'name': name,
        'producer': producer,
        'description': description,
        'bottles_count': bottlesCount,
        'tags': tags,
      };

  // A "factory constructor": instead of always building a new instance the
  // normal way, this one runs some logic first (reading values out of a
  // parsed YAML map) and *then* returns an Ingredient built from them.
  //
  // The `?? ''` / `?? 0` / `?? []` fallbacks mean: if a field is missing
  // from the YAML (e.g. an older file that predates the "tags" field),
  // use a sensible empty default instead of crashing.
  factory Ingredient.fromYaml(Map<String, dynamic> yaml) => Ingredient(
        name: yaml['name'] ?? '',
        producer: yaml['producer'] ?? '',
        description: yaml['description'] ?? '',
        bottlesCount: yaml['bottles_count'] ?? 0,
        // The yaml package returns lists as YamlList, not a plain
        // List<String> - List<String>.from(...) copies it into a normal,
        // strongly-typed Dart list we can use everywhere else in the app.
        tags: List<String>.from(yaml['tags'] ?? []),
      );
}
