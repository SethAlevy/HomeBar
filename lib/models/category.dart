import 'ingredient.dart';

class Category {
  final String name;
  final List<Category> subcategories;
  final List<Ingredient> ingredients;

  Category({
    required this.name,
    this.subcategories = const [],
    this.ingredients = const [],
  });

  // Convert to YAML-compatible map
  Map<String, dynamic> toYaml() => {
        'name': name,
        if (subcategories.isNotEmpty)
          'subcategories': subcategories.map((e) => e.toYaml()).toList(),
        if (ingredients.isNotEmpty)
          'ingredients': ingredients.map((e) => e.toYaml()).toList(),
      };

  // Create from YAML map
  factory Category.fromYaml(Map<String, dynamic> yaml) => Category(
        name: yaml['name'] ?? '',
        subcategories: (yaml['subcategories'] as List<dynamic>?)
            ?.map((e) => Category.fromYaml(e as Map<String, dynamic>))
            .toList() ??
            [],
        ingredients: (yaml['ingredients'] as List<dynamic>?)
            ?.map((e) => Ingredient.fromYaml(e as Map<String, dynamic>))
            .toList() ??
            [],
      );

  // Get all ingredients recursively (including subcategories)
  List<Ingredient> get allIngredients {
    final List<Ingredient> result = [];
    result.addAll(ingredients);
    for (final subcategory in subcategories) {
      result.addAll(subcategory.allIngredients);
    }
    return result;
  }

  // Copy with updated fields
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
