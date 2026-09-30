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

  // Whether this category (or any descendant subcategory) has at least one
  // ingredient in stock - used by collectAvailableMatchKeys() below to
  // decide whether the category's own name counts as "available".
  bool get hasStock =>
      ingredients.any((i) => i.bottlesCount > 0) || subcategories.any((c) => c.hasStock);
}

// Every tag used anywhere in a category tree, alphabetically sorted with
// duplicates removed - the source list for tag autocomplete/suggestions
// wherever an ingredient's tags are edited.
List<String> collectAllTags(List<Category> categories) {
  final tags = <String>{};
  for (final category in categories) {
    for (final ingredient in category.allIngredients) {
      tags.addAll(ingredient.tags);
    }
  }
  return tags.toList()..sort();
}

// Tags likely to fit a brand-new ingredient being added to `destination`,
// inferred from tags its existing ingredients already carry (including ones
// in subcategories underneath it) - e.g. if most bottles under
// "Alkohole/Mocne" are tagged "baza", a new bottle added there will suggest
// "baza" too. A tag needs to already be used by at least 2 ingredients
// before it's suggested, so a single bottle's one-off tags don't get
// parroted back immediately for the very next addition.
//
// Returns the suggestions most-common-first, capped at 6 so the UI never has
// to show an overwhelming wall of suggested chips.
List<String> suggestTagsForNewIngredient(Category destination) {
  final tagCounts = <String, int>{};
  for (final ingredient in destination.allIngredients) {
    // toSet() first so one ingredient can only ever contribute 1 to a tag's
    // count, even if (through some data error) it listed the same tag twice.
    for (final tag in ingredient.tags.toSet()) {
      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }
  }

  final suggested = tagCounts.entries.where((entry) => entry.value >= 2).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return suggested.take(6).map((entry) => entry.key).toList();
}

// Builds the set of "match keys" that currently have stock behind them, from
// a whole category tree: every ingredient name backed by at least one
// bottle, plus every category/subcategory name that has such an ingredient
// anywhere underneath it. Names are normalized (trimmed, lowercased) so
// lookups can compare case-insensitively.
//
// This is what lets Recipe.isAvailable() treat a recipe ingredient line
// loosely - RecipeIngredient.matchKey might name a specific bottle
// ("Aperol") or a whole category ("Whisky"), and either way it only needs
// one matching bottle in stock to count.
Set<String> collectAvailableMatchKeys(List<Category> categories) {
  final keys = <String>{};

  void visit(Category category) {
    for (final subcategory in category.subcategories) {
      visit(subcategory);
    }
    for (final ingredient in category.ingredients) {
      if (ingredient.bottlesCount > 0) {
        keys.add(ingredient.name.trim().toLowerCase());
      }
    }
    if (category.hasStock) {
      keys.add(category.name.trim().toLowerCase());
    }
  }

  for (final category in categories) {
    visit(category);
  }

  return keys;
}
