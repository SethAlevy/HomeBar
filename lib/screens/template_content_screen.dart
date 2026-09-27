import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../services/template_service.dart';
import '../widgets/add_template_node_dialog.dart';
import '../widgets/edit_template_ingredient_dialog.dart';

// ============================================================================
// TemplateContentScreen
// ----------------------------------------------------------------------------
// Full-screen viewer AND editor for one template file (picked in
// ManageHomebarsScreen) - branches on widget.template.type into two
// completely different views:
//   - Ingredient templates load a Category tree and render it as a fully
//     expanded tree: categories as collapsible, color-coded group tiles
//     (color darkens with nesting depth - see _categoryPalette), and
//     ingredients as detail cards in a single fixed color (see
//     _ingredientPalette) showing every field.
//   - Recipe templates load a flat List<Recipe> and render it as a list of
//     RecipeCard tiles with edit/delete buttons. Editing isn't built yet
//     (see _editRecipe) - only deleting is, for now.
//
// Every edit only changes the in-memory data and marks it dirty - nothing
// is written to disk until the bottom bar's "Zapisz" button is tapped (see
// _save). That button is disabled whenever there's nothing unsaved.
// ============================================================================
class TemplateContentScreen extends StatefulWidget {
  final TemplateFile template;

  const TemplateContentScreen({required this.template, super.key});

  @override
  State<TemplateContentScreen> createState() => _TemplateContentScreenState();
}

class _TemplateContentScreenState extends State<TemplateContentScreen> {
  // Only one of _categories/_recipes is ever populated, depending on
  // widget.template.type - see _isRecipeTemplate.
  List<Category> _categories = [];
  List<Recipe> _recipes = [];
  bool _isLoading = true;

  // True whenever the in-memory data has changes that haven't been written
  // to disk yet - drives whether the bottom bar's Save button is enabled.
  bool _isDirty = false;

  bool get _isRecipeTemplate => widget.template.type == TemplateType.recipe;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isRecipeTemplate) {
      final recipes = await TemplateService.loadRecipes(widget.template);
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
      return;
    }

    final categories = await TemplateService.loadTemplateCategories(widget.template);

    if (!mounted) return;

    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  // Writes the current in-memory data out to the template's writable copy
  // and clears the dirty flag. Only ever called explicitly from the "Zapisz"
  // button - every edit method below only touches _categories/_recipes in
  // memory.
  Future<void> _save() async {
    if (_isRecipeTemplate) {
      await TemplateService.saveTemplateRecipes(widget.template, _recipes);
    } else {
      await TemplateService.saveTemplateCategories(widget.template, _categories);
    }

    if (!mounted) return;
    setState(() => _isDirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zapisano zmiany.')),
    );
  }

  // ---- Recipe actions --------------------------------------------------

  Future<void> _deleteRecipe(Recipe target) async {
    final confirmed = await _confirmDelete(context, 'Usunąć przepis "${target.name}"?');
    if (!confirmed || !mounted) return;

    setState(() {
      _recipes = _recipes.where((r) => !identical(r, target)).toList();
      _isDirty = true;
    });
  }

  // Recipe editing isn't built yet - same "coming soon" convention used
  // elsewhere in the app (see HomeScreen/AppDrawer) for destinations that
  // don't exist yet.
  void _editRecipe(Recipe target) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edycja przepisów — wkrótce!')),
    );
  }

  // ---- Category actions ----------------------------------------------

  Future<void> _renameCategory(Category target) async {
    final newName = await _showRenameDialog(context, target.name);
    if (newName == null || newName == target.name) return;

    setState(() {
      _categories = _renameCategoryInTree(_categories, target, newName);
      _isDirty = true;
    });
  }

  Future<void> _deleteCategory(Category target) async {
    final confirmed = await _confirmDelete(
      context,
      'Usunąć kategorię "${target.name}" wraz z całą jej zawartością?',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _categories = _removeCategoryFromTree(_categories, target);
      _isDirty = true;
    });
  }

  // ---- Ingredient actions ---------------------------------------------

  Future<void> _deleteIngredient(Ingredient target) async {
    final confirmed = await _confirmDelete(context, 'Usunąć składnik "${target.name}"?');
    if (!confirmed || !mounted) return;

    setState(() {
      _categories = _removeIngredientFromTree(_categories, target);
      _isDirty = true;
    });
  }

  Future<void> _editIngredient(Ingredient target) async {
    final currentParent = _findParentOf(_categories, target);
    // Shouldn't happen (every rendered ingredient came from this tree),
    // but bail out rather than open a dialog with nowhere to save to.
    if (currentParent == null) return;

    final result = await showDialog<EditIngredientDialogResult>(
      context: context,
      builder: (context) => EditTemplateIngredientDialog(
        ingredient: target,
        allCategories: _categories,
        currentCategory: currentParent,
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _categories = _moveIngredientInTree(
        _categories,
        original: target,
        updated: result.ingredient,
        destination: result.destinationCategory,
      );
      _isDirty = true;
    });
  }

  // ---- Add flow ---------------------------------------------------------

  Future<void> _addNode() async {
    final result = await showDialog<AddTemplateNodeResult>(
      context: context,
      builder: (context) => AddTemplateNodeDialog(categories: _categories),
    );

    if (result == null || !mounted) return;

    setState(() {
      if (result.kind == TemplateNodeKind.category) {
        final newCategory = Category(name: result.name);
        _categories = result.destination == null
            ? [..._categories, newCategory]
            : _insertCategoryInTree(_categories, result.destination!, newCategory);
      } else {
        final newIngredient = Ingredient(
          name: result.name,
          producer: result.producer,
          description: result.description,
          bottlesCount: result.bottlesCount,
          tags: result.tags,
        );
        // AddTemplateNodeDialog only allows saving an ingredient once a
        // destination has been chosen (see its _canSave getter), so this
        // is never null in practice here.
        _categories = _insertIngredientInTree(_categories, result.destination!, newIngredient);
      }
      _isDirty = true;
    });
  }

  Widget _buildRecipeList() {
    if (_recipes.isEmpty) {
      return const Center(child: Text('Brak zawartości szablonu.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _recipes.length,
      itemBuilder: (context, index) {
        final recipe = _recipes[index];
        return _RecipeEditorTile(
          recipe: recipe,
          onEdit: () => _editRecipe(recipe),
          onDelete: () => _deleteRecipe(recipe),
        );
      },
    );
  }

  Widget _buildCategoryTree() {
    if (_categories.isEmpty) {
      return const Center(child: Text('Brak zawartości szablonu.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      // depth: 0 because these are the top-level categories; each nested
      // level below increases depth by one (see _CategoryTile below),
      // which drives both indentation and how dark the tile's color is.
      children: _categories
          .map(
            (category) => _CategoryTile(
              category: category,
              depth: 0,
              onRenameCategory: _renameCategory,
              onDeleteCategory: _deleteCategory,
              onEditIngredient: _editIngredient,
              onDeleteIngredient: _deleteIngredient,
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isRecipeTemplate
              ? _buildRecipeList()
              : _buildCategoryTree(),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Adding new recipes isn't built yet (see _editRecipe), so
            // there's nothing for this button to do for a recipe template
            // - only "Zapisz" (for recipe deletions) is offered there.
            if (!_isRecipeTemplate)
              _BottomBarAction(
                icon: Icons.add,
                label: 'Dodaj',
                onPressed: _isLoading ? null : _addNode,
              ),
            _BottomBarAction(
              icon: Icons.save_outlined,
              label: 'Zapisz',
              // Disabled whenever there's nothing unsaved, so it's never
              // possible to write an unchanged (or not-yet-loaded) tree.
              onPressed: _isDirty ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}

// One bottom-bar entry: an icon over a small label, matching the rest of
// the app's bottom/side navigation styling (see AppDrawer's menu items).
class _BottomBarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _BottomBarAction({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    // A disabled TextButton already dims itself and ignores taps, so
    // "Zapisz" being unavailable when there's nothing to save just falls
    // out of passing onPressed: null - no extra state needed here.
    //
    // Explicit dark foreground colors instead of the theme's default
    // TextButton color: the default read as too faint against the
    // BottomAppBar's light background to tell it's there at all, let alone
    // whether it's enabled.
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: Colors.black87,
        disabledForegroundColor: Colors.black38,
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

// ============================================================================
// Pure tree-editing helpers
// ----------------------------------------------------------------------------
// Category/Ingredient are immutable (see lib/models/), so every "edit" here
// walks the tree and returns a brand-new one rather than mutating anything
// in place. Every helper below locates its target with identical() -
// reference equality - rather than matching by name, since names aren't
// guaranteed unique (two categories, or two ingredients in different
// categories, could share a name) but the exact object always is.
// ============================================================================

List<Category> _renameCategoryInTree(List<Category> categories, Category target, String newName) {
  return categories.map((category) {
    final renamed = identical(category, target) ? category.copyWith(name: newName) : category;
    return renamed.copyWith(
      subcategories: _renameCategoryInTree(renamed.subcategories, target, newName),
    );
  }).toList();
}

List<Category> _removeCategoryFromTree(List<Category> categories, Category target) {
  return categories
      .where((category) => !identical(category, target))
      .map(
        (category) => category.copyWith(
          subcategories: _removeCategoryFromTree(category.subcategories, target),
        ),
      )
      .toList();
}

List<Category> _removeIngredientFromTree(List<Category> categories, Ingredient target) {
  return categories.map((category) {
    return category.copyWith(
      ingredients: category.ingredients.where((i) => !identical(i, target)).toList(),
      subcategories: _removeIngredientFromTree(category.subcategories, target),
    );
  }).toList();
}

// Removes `original` and inserts `updated` under `destination`, in a
// single tree walk. This has to happen in one pass rather than as a
// separate remove-then-add: since Category is immutable, a "remove" pass
// would rebuild every category from the removed ingredient's location up
// to the root, which would leave `destination` (captured from the tree
// *before* that rebuild) pointing at a now-stale, no-longer-in-the-tree
// object if it happened to be one of the rebuilt ancestors - identical()
// would then never match it on a second pass.
List<Category> _moveIngredientInTree(
  List<Category> categories, {
  required Ingredient original,
  required Ingredient updated,
  required Category destination,
}) {
  return categories.map((category) {
    final ingredients = category.ingredients.where((i) => !identical(i, original)).toList();
    if (identical(category, destination)) {
      ingredients.add(updated);
    }

    return category.copyWith(
      ingredients: ingredients,
      subcategories: _moveIngredientInTree(
        category.subcategories,
        original: original,
        updated: updated,
        destination: destination,
      ),
    );
  }).toList();
}

// Inserts `newCategory` as a subcategory of `destination`, wherever it is
// in the tree.
List<Category> _insertCategoryInTree(
  List<Category> categories,
  Category destination,
  Category newCategory,
) {
  return categories.map((category) {
    final subcategories = _insertCategoryInTree(category.subcategories, destination, newCategory);
    return category.copyWith(
      subcategories: identical(category, destination)
          ? [...subcategories, newCategory]
          : subcategories,
    );
  }).toList();
}

// Inserts `newIngredient` directly into `destination`, wherever it is in
// the tree.
List<Category> _insertIngredientInTree(
  List<Category> categories,
  Category destination,
  Ingredient newIngredient,
) {
  return categories.map((category) {
    final ingredients = identical(category, destination)
        ? [...category.ingredients, newIngredient]
        : category.ingredients;

    return category.copyWith(
      ingredients: ingredients,
      subcategories: _insertIngredientInTree(category.subcategories, destination, newIngredient),
    );
  }).toList();
}

// Finds the Category that directly holds `target` (searching subcategories
// recursively). Used to pre-select the ingredient's current location when
// opening the edit dialog.
Category? _findParentOf(List<Category> categories, Ingredient target) {
  for (final category in categories) {
    if (category.ingredients.any((i) => identical(i, target))) {
      return category;
    }
    final found = _findParentOf(category.subcategories, target);
    if (found != null) return found;
  }
  return null;
}

// ============================================================================
// Shared dialogs
// ============================================================================

// Yes/no confirmation used before any destructive action.
Future<bool> _confirmDelete(BuildContext context, String message) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Potwierdź usunięcie'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Nie'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Tak'),
        ),
      ],
    ),
  );
  // showDialog returns null if dismissed (e.g. tapping outside it) -
  // treat that the same as an explicit "No".
  return confirmed ?? false;
}

// Simple single-field rename prompt, used for both top-level categories
// and subcategories - they're both just Category, so one dialog covers
// both.
Future<String?> _showRenameDialog(BuildContext context, String currentName) async {
  final controller = TextEditingController(text: currentName);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Zmień nazwę kategorii'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nazwa'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Zapisz'),
        ),
      ],
    ),
  );
  controller.dispose();

  if (result == null || result.isEmpty) return null;
  return result;
}

// ============================================================================
// Color palettes
// ============================================================================

// A background/foreground color pair for one tile. `foreground` is always
// picked to contrast with `background` (see _foregroundFor below), so text
// and icons stay readable no matter how dark a nested category gets.
class _DepthPalette {
  final Color background;
  final Color foreground;

  const _DepthPalette(this.background, this.foreground);
}

// Hue/saturation for every category tile, regardless of depth - an orange,
// matching the app's own theme color. Kept far enough from the ingredient
// hue below (8, closer to red) that the two tile kinds still read as
// distinct even though both are warm tones.
const double _categoryHue = 32;
const double _categorySaturation = 0.80;

// Hue/saturation/lightness for every ingredient tile. Ingredients always
// use this same fixed color no matter how deep they sit in the tree - only
// *categories* darken with depth, so an ingredient's color instead signals
// "this is a leaf, not a group".
const double _ingredientHue = 8;
const double _ingredientSaturation = 0.45;
const double _ingredientLightness = 0.40;

// Picks a category tile's color for a given nesting depth: the top level
// starts bright, and each level deeper is a bit darker than its parent -
// same hue throughout, so the whole branch still reads as "one category
// and its subcategories" while the darkening makes the nesting visible at
// a glance.
_DepthPalette _categoryPalette(int depth) {
  final lightness = (0.62 - depth * 0.09).clamp(0.22, 0.62);
  final background =
      HSLColor.fromAHSL(1.0, _categoryHue, _categorySaturation, lightness).toColor();
  return _DepthPalette(background, _foregroundFor(background));
}

// The single fixed palette used by every ingredient tile - see the
// constants above for why it doesn't vary with depth.
_DepthPalette _ingredientPalette() {
  const background =
      HSLColor.fromAHSL(1.0, _ingredientHue, _ingredientSaturation, _ingredientLightness);
  return _DepthPalette(background.toColor(), _foregroundFor(background.toColor()));
}

// Chooses black or white text/icons depending on how light or dark
// `background` is, so a tile stays readable whether it landed near the
// bright or dark end of the depth gradient above.
Color _foregroundFor(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black87;
}

// Builds the "N podkategorii • M składników" summary line shown under a
// category's title, so its tile communicates how much content is grouped
// inside it without requiring it to be expanded first.
String _summaryFor(Category category) {
  final subcategoryCount = category.subcategories.length;
  final ingredientCount = category.allIngredients.length;

  if (subcategoryCount > 0) {
    return '$subcategoryCount podkategorii • $ingredientCount składników';
  }
  return '$ingredientCount składników';
}

// ============================================================================
// _CategoryTile
// ----------------------------------------------------------------------------
// Renders one Category - recursively. Draws itself as an expandable, color
// coded tile containing its action buttons, one _CategoryTile per
// subcategory, and one _IngredientCard per direct ingredient. The four
// callbacks are handed down unchanged to every nested _CategoryTile, each
// of which applies them to its *own* `category`, so only this top-level
// widget needs to know how the actions are actually implemented.
// ============================================================================
class _CategoryTile extends StatelessWidget {
  final Category category;

  // How many levels deep in the tree this node is - 0 for a top-level
  // category, 1 for its direct children, and so on. Drives both left
  // indentation and how dark the tile's color is.
  final int depth;

  final ValueChanged<Category> onRenameCategory;
  final ValueChanged<Category> onDeleteCategory;
  final ValueChanged<Ingredient> onEditIngredient;
  final ValueChanged<Ingredient> onDeleteIngredient;

  const _CategoryTile({
    required this.category,
    required this.depth,
    required this.onRenameCategory,
    required this.onDeleteCategory,
    required this.onEditIngredient,
    required this.onDeleteIngredient,
  });

  @override
  Widget build(BuildContext context) {
    final indent = EdgeInsets.only(left: depth * 16.0);
    // Same hue at every depth, just progressively darker - a category and
    // its subcategories render as visually distinct, "cards within cards"
    // tiles that still read as one connected branch.
    final palette = _categoryPalette(depth);

    return Padding(
      padding: indent,
      // ExpansionTile lays its expanded `children` out in a Column that
      // centers them and sizes itself to the widest child (see the
      // ExpansionTile.expandedCrossAxisAlignment docs) - without this,
      // every nested category/ingredient card would shrink-wrap to its own
      // content width instead of filling the row, and end up a different
      // width from its siblings. Forcing width: double.infinity makes this
      // card claim the full width the Column actually has available.
      child: SizedBox(
        width: double.infinity,
        child: Card(
          clipBehavior: Clip.antiAlias,
          color: palette.background,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Theme(
            // Wrapping in a local Theme override removes the faint divider
            // line ExpansionTile normally draws above/below itself when
            // expanded - purely cosmetic, so nested tiles look cleaner.
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              // Always start expanded, per the "show the full expanded tree
              // up front" requirement - the user can still tap to collapse
              // individual branches afterwards.
              initiallyExpanded: true,
              iconColor: palette.foreground,
              collapsedIconColor: palette.foreground,
              title: Text(
                category.name,
                style: TextStyle(fontWeight: FontWeight.w600, color: palette.foreground),
              ),
              subtitle: Text(
                _summaryFor(category),
                style: TextStyle(color: palette.foreground.withValues(alpha: 0.75)),
              ),
              children: [
                _CategoryActionsRow(
                  iconColor: palette.foreground,
                  onEdit: () => onRenameCategory(category),
                  onDelete: () => onDeleteCategory(category),
                ),
                ...category.subcategories.map(
                  (sub) => _CategoryTile(
                    category: sub,
                    depth: depth + 1,
                    onRenameCategory: onRenameCategory,
                    onDeleteCategory: onDeleteCategory,
                    onEditIngredient: onEditIngredient,
                    onDeleteIngredient: onDeleteIngredient,
                  ),
                ),
                ...category.ingredients.map(
                  (ingredient) => Padding(
                    padding: EdgeInsets.only(left: (depth + 1) * 16.0),
                    child: _IngredientCard(
                      ingredient: ingredient,
                      onEdit: () => onEditIngredient(ingredient),
                      onDelete: () => onDeleteIngredient(ingredient),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// The row of action buttons shown at the top of every expanded category:
// edit (rename) this category, or delete it. Adding new categories and
// ingredients now happens through the bottom bar's single "Dodaj" flow
// instead (see AddTemplateNodeDialog), which lets the user pick any
// destination rather than only "directly under this exact category".
class _CategoryActionsRow extends StatelessWidget {
  // Tint for the edit button, matching the category tile's palette so the
  // icon stays legible against whatever container color that depth landed
  // on. Delete deliberately ignores this and always uses the theme's
  // error color instead - see below.
  final Color iconColor;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryActionsRow({
    required this.iconColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Wrap(
        spacing: 4,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edytuj kategorię',
            color: iconColor,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Usuń kategorię',
            // Using the theme's error color signals "destructive action"
            // the same way delete buttons do elsewhere in Material Design -
            // kept distinct from the tile's own palette on purpose.
            color: Theme.of(context).colorScheme.error,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// A detail card for one ingredient leaf: name, producer, action buttons,
// description, bottle count, and its tags - every field the Ingredient
// model carries, not just its name. Every ingredient tile uses the same
// fixed color (see _ingredientPalette) regardless of how deep it sits in
// the tree, so its color alone tells you "this is a leaf", while a
// category's color tells you "this is a group" (and how deep).
class _IngredientCard extends StatelessWidget {
  final Ingredient ingredient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _IngredientCard({
    required this.ingredient,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _ingredientPalette();

    // ExpansionTile lays its expanded `children` out in a Column that
    // centers them and sizes itself to the widest child - without this,
    // every ingredient card would shrink-wrap to its own content width
    // instead of filling the row, so cards would end up different widths
    // depending on how long their name/description happens to be. Forcing
    // width: double.infinity makes every card claim the full width the
    // Column actually has available.
    return SizedBox(
      width: double.infinity,
      child: Card(
        color: palette.background,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          // A single vertical stack - no leading icon and no side-by-side
          // buttons column, so name/producer sit directly above the
          // action buttons instead of squeezed next to them.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ingredient.name,
                style: TextStyle(fontWeight: FontWeight.w600, color: palette.foreground),
              ),
              // Only renders when there's actually a producer, so blank
              // values don't leave an empty gap in the card.
              if (ingredient.producer.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    ingredient.producer,
                    style: TextStyle(color: palette.foreground.withValues(alpha: 0.85)),
                  ),
                ),

              // Action buttons live right under the name/producer header,
              // above the rest of the details.
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edytuj składnik',
                      color: palette.foreground,
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Usuń składnik',
                      // Delete always stays the theme's error color, the
                      // same "destructive action" convention used for
                      // category deletion above.
                      color: Theme.of(context).colorScheme.error,
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),

              if (ingredient.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    ingredient.description,
                    style: TextStyle(color: palette.foreground),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_bar_outlined, size: 16, color: palette.foreground),
                  const SizedBox(width: 4),
                  Text(
                    '${ingredient.bottlesCount} but.',
                    style: TextStyle(color: palette.foreground),
                  ),
                ],
              ),
              if (ingredient.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  // Wrap lays chips out horizontally and only breaks onto
                  // a new line once it runs out of room - so tags flow
                  // sideways like a sentence, but can never spill past
                  // the tile's own width.
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ingredient.tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            // Fixed light-grey/dark-text styling,
                            // independent of the tile's own palette -
                            // keeps the chip readable no matter how dark
                            // the card behind it is.
                            backgroundColor: Colors.grey.shade200,
                            labelStyle: const TextStyle(color: Colors.black87),
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _RecipeEditorTile
// ----------------------------------------------------------------------------
// A deliberately more "raw"/developer-facing rendering of a Recipe than the
// polished RecipeCard used by RecipesScreen/RecipePickerScreen: every
// section is labeled with its literal YAML key (ingredients/instructions/
// comments/tags), every ingredient line shows its resolved matchKey (see
// RecipeIngredient.matchKey and Recipe.isAvailable) so it's obvious at a
// glance whether one was set explicitly or is just defaulting to the
// ingredient's own name, and the comments section always renders - even
// empty - instead of disappearing. That's useful here specifically because
// this screen IS the tool for authoring/correcting that raw YAML data.
// ============================================================================
class _RecipeEditorTile extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecipeEditorTile({
    required this.recipe,
    required this.onEdit,
    required this.onDelete,
  });

  // A small, bold, monospace label naming the literal YAML key a section
  // below it corresponds to - e.g. "ingredients:" - so it's unambiguous
  // which raw field is being edited.
  Widget _keyLabel(BuildContext context, String key) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          '$key:',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(height: 1),
      );

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    recipe.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edytuj przepis',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Usuń przepis',
                  color: Theme.of(context).colorScheme.error,
                  onPressed: onDelete,
                ),
              ],
            ),
            if (recipe.ingredients.isNotEmpty) ...[
              _divider(),
              _keyLabel(context, 'ingredients'),
              for (final ingredient in recipe.ingredients)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(ingredient.name)),
                          Text(ingredient.amount, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                      Row(
                        children: [
                          // A custom matchKey (one that doesn't just equal
                          // the ingredient's own name) is the exception,
                          // not the rule, so it gets its own icon to make
                          // it stand out from the common "defaulted to
                          // name" case.
                          Icon(
                            ingredient.matchKey.trim().toLowerCase() ==
                                    ingredient.name.trim().toLowerCase()
                                ? Icons.vpn_key_off_outlined
                                : Icons.vpn_key_outlined,
                            size: 13,
                            color: mutedColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'matchKey: ${ingredient.matchKey}',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: mutedColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
            if (recipe.instructionSteps.isNotEmpty) ...[
              _divider(),
              _keyLabel(context, 'instructions'),
              for (var i = 0; i < recipe.instructionSteps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${i + 1}. ${recipe.instructionSteps[i]}'),
                ),
            ],
            // Unlike RecipeCard, this section always renders - an empty
            // `comments:` is itself something worth seeing while editing,
            // rather than being indistinguishable from the field not
            // existing at all.
            _divider(),
            _keyLabel(context, 'comments'),
            Text(
              recipe.comments.isEmpty ? '(puste)' : recipe.comments,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: recipe.comments.isEmpty ? mutedColor : null,
                  ),
            ),
            if (recipe.tags.isNotEmpty) ...[
              _divider(),
              _keyLabel(context, 'tags'),
              Wrap(
                spacing: 4.0,
                children: recipe.tags
                    .map((tag) => Chip(
                          label: Text(tag),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
