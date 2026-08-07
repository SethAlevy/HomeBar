import 'ingredient.dart';

// ============================================================================
// Category
// ----------------------------------------------------------------------------
// A "model" class describing one node in a tree of categories, e.g.
// "Alkohole" -> "Mocne" -> "Rum Jasny". Each node can hold:
//   1) `ingredients`   - items that belong directly to it, and/or
//   2) `subcategories` - nested child categories (which can themselves
//                        have their own ingredients and subcategories).
//
// Because `subcategories` is a `List<Category>`, this class is
// self-referential ("recursive") - a Category tree can be as deep as the
// underlying YAML data describes.
// ============================================================================
class Category {
  // Name shown in the UI.
  final String name;

  // Child categories (recursive structure). Defaults to an empty list so
  // leaf categories (ones with no children) don't need to pass anything.
  final List<Category> subcategories;

  // Ingredients that belong directly to this category (not to a child).
  final List<Ingredient> ingredients;

  Category({
    required this.name,
    this.subcategories = const [],
    this.ingredients = const [],
  });

  // Converts this category - and, recursively, every descendant - into a
  // plain, serializable Map. The `if (...)` entries mean an empty list is
  // omitted from the map entirely instead of writing out `subcategories: []`
  // for every leaf node, keeping the saved YAML file cleaner.
  Map<String, dynamic> toYaml() => {
        'name': name,
        if (subcategories.isNotEmpty)
          'subcategories': subcategories.map((e) => e.toYaml()).toList(),
        if (ingredients.isNotEmpty)
          'ingredients': ingredients.map((e) => e.toYaml()).toList(),
      };

  // Rebuilds a Category (and its whole subtree) from parsed YAML data.
  // Notice the recursive call to Category.fromYaml() inside the
  // subcategories mapping - that's what lets one call at the root parse an
  // entire nested tree in one go.
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

  // Flattens this category and every descendant subcategory into a single,
  // flat list of ingredients - handy whenever some other part of the app
  // wants "everything under here" without caring about the tree shape
  // (e.g. counting products, or searching across a whole branch).
  List<Ingredient> get allIngredients {
    final List<Ingredient> result = [];
    result.addAll(ingredients);
    for (final subcategory in subcategories) {
      // Recursively collect from each child branch - this is what makes
      // `allIngredients` include grandchildren, great-grandchildren, etc.,
      // not just direct children.
      result.addAll(subcategory.allIngredients);
    }
    return result;
  }

  // Returns a new Category with the given fields replaced, and everything
  // else copied as-is. Since Category's fields are all `final` (immutable),
  // this is the standard Dart pattern for "change one thing" without
  // mutating the original object - callers who still hold a reference to
  // the old Category won't see it change out from under them.
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
