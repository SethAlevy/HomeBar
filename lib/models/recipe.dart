// ============================================================================
// RecipeIngredient
// ----------------------------------------------------------------------------
// One line of a recipe's ingredient list, e.g. "Tequila - 1 porcja". Kept
// separate from the main Ingredient model (lib/models/ingredient.dart)
// since a recipe line is just a name + a free-form amount, not a full
// inventory item with a producer, description, tags, etc.
// ============================================================================
class RecipeIngredient {
  final String name;
  final String amount;

  // What this line is matched against when checking whether the recipe can
  // currently be prepared (see Recipe.isAvailable) - an inventory
  // ingredient's name, or a category/subcategory name, anywhere in the
  // active ingredient template. Defaults to `name` itself, which is enough
  // whenever the recipe's wording already matches the inventory (e.g.
  // "Aperol"); it only needs to be set explicitly in the YAML when it
  // doesn't (e.g. "Sok z limonki" needs a match key of just "Limonki").
  final String matchKey;

  const RecipeIngredient({required this.name, required this.amount, String? matchKey})
      : matchKey = matchKey ?? name;

  List<String> toYaml() => matchKey == name ? [name, amount] : [name, amount, matchKey];

  // The YAML format stores each ingredient line as a list, e.g.
  // `[Tequila, 1 porcja]` or, with an explicit match key,
  // `[Sok z limonki, 1/2 porcja, Limonki]` - the yaml package hands that
  // back as a YamlList, which behaves like a normal Dart List.
  factory RecipeIngredient.fromYaml(dynamic item) {
    if (item is List && item.length >= 3) {
      return RecipeIngredient(
        name: item[0].toString(),
        amount: item[1].toString(),
        matchKey: item[2].toString(),
      );
    }
    if (item is List && item.length >= 2) {
      return RecipeIngredient(name: item[0].toString(), amount: item[1].toString());
    }
    if (item is List && item.isNotEmpty) {
      return RecipeIngredient(name: item[0].toString(), amount: '');
    }
    return RecipeIngredient(name: item.toString(), amount: '');
  }
}

// ============================================================================
// Recipe
// ----------------------------------------------------------------------------
// A single cocktail recipe: its name, the ingredients it calls for,
// preparation instructions, and tags for filtering. Parsed from the
// `cocktails:` list in a recipe template YAML file (see
// assets/data/recipe/recipe.yaml and TemplateService.loadRecipes).
// ============================================================================
class Recipe {
  final String name;
  final List<RecipeIngredient> ingredients;
  final String instructions;
  final String comments;
  final List<String> tags;

  const Recipe({
    required this.name,
    required this.ingredients,
    required this.instructions,
    this.comments = '',
    required this.tags,
  });

  // Plain (unquoted) multi-line YAML instructions fold into one string
  // like "1. Umieść ... 2. Wstrząśnij ... 3. Przelej ...". Split that back
  // into individual steps (dropping the leading "N. " marker, since the UI
  // re-numbers them itself) so the screen can render one step per line.
  // Falls back to the whole string as a single step when it isn't in that
  // numbered format at all.
  List<String> get instructionSteps => instructions
      .split(RegExp(r'\s*\d+\.\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  // Whether every ingredient this recipe calls for is currently in stock,
  // given the set of "available match keys" produced by
  // Category.collectAvailableMatchKeys() for the active ingredient
  // template - i.e. every ingredient and category/subcategory name backed
  // by at least one bottle. A recipe with no ingredients is trivially
  // available.
  bool isAvailable(Set<String> availableMatchKeys) =>
      ingredients.every((i) => availableMatchKeys.contains(i.matchKey.trim().toLowerCase()));

  Map<String, dynamic> toYaml() => {
        'name': name,
        'ingredients': ingredients.map((e) => e.toYaml()).toList(),
        'instructions': instructions,
        'comments': comments,
        'tags': tags,
      };

  factory Recipe.fromYaml(Map<String, dynamic> yaml) => Recipe(
        name: yaml['name']?.toString() ?? '',
        ingredients: (yaml['ingredients'] as List?)
                ?.map((item) => RecipeIngredient.fromYaml(item))
                .toList() ??
            [],
        // Plain (unquoted) multi-line YAML text folds into a single string
        // with line breaks turned into spaces - that's what the numbered
        // "1. ... 2. ..." instructions in the YAML file already parse into,
        // so this is just read straight through.
        instructions: yaml['instructions']?.toString() ?? '',
        // Optional - many recipes leave this blank in the YAML (a `comments:`
        // key with no value parses as null), so an empty string just means
        // "no comment" rather than a missing field.
        comments: yaml['comments']?.toString() ?? '',
        tags: List<String>.from(yaml['tags'] ?? []),
      );
}
