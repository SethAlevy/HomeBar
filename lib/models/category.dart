import 'ingredient.dart';

// One node in a tree of categories.
//
// Each category can contain:
// 1) direct ingredients
// 2) nested subcategories
class Category {
  // Name shown in the UI.
  final String name;

  // Child categories (recursive structure).
  final List<Category> subcategories;

  // Ingredients that belong directly to this category.
  final List<Ingredient> ingredients;

  Category({
    required this.name,
    this.subcategories = const [],
    this.ingredients = const [],
  });

  // Converts this category (including children) to a serializable map.
  Map<String, dynamic> toYaml() => {
        'name': name,
        if (subcategories.isNotEmpty)
          'subcategories': subcategories.map((e) => e.toYaml()).toList(),
        if (ingredients.isNotEmpty)
          'ingredients': ingredients.map((e) => e.toYaml()).toList(),
      };

  // Parses category data from YAML.
  // Notice recursive parsing for subcategories.
  factory Category.fromYaml(Map<String, dynamic> yaml) => Category(
    name: yaml['name'] ?? '',
    subcategories: (yaml['subcategories'] as List?)
            ?.map(
              (item) => Category.fromYaml(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList() ??
        [],
    ingredients: (yaml['ingredients'] as List?)
            ?.map(
              (item) => Ingredient.fromYaml(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList() ??
        [],
  );

  // Flattens this subtree into a single ingredient list.
  // Useful for counters and global filtering.
  List<Ingredient> get allIngredients {
    final List<Ingredient> result = [];
    result.addAll(ingredients);
    for (final subcategory in subcategories) {
      // Recursively collect from each child branch.
      result.addAll(subcategory.allIngredients);
    }
    return result;
  }

  // Returns a copy with optional field replacements.
  Category copyWith({
    String? name,
    List<Category>? subcategories,
    List<Ingredient>? ingredients,
  }) =>
      Category(
        name: name ?? this.name,
        subcategories: subcategories ?? this.subcategories,
        ingredients: ingredients ?? this.ingredients,
      );
}
