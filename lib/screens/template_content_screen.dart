import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../services/template_service.dart';
import '../widgets/add_template_node_dialog.dart';
import '../widgets/category_row_color.dart';
import '../widgets/edit_recipe_dialog.dart';
import '../widgets/edit_template_ingredient_dialog.dart';

// ============================================================================
// TemplateContentScreen
// ----------------------------------------------------------------------------
// Full-screen viewer AND editor for one template file (picked in
// ManageHomebarsScreen) - branches on widget.template.type into two
// completely different views:
//   - Ingredient templates load a Category tree and render it as one
//     continuous table (see _buildCategoryTree): categories as collapsible
//     rows subtly tinted by nesting depth (see categoryRowColor), and
//     ingredients as plain, collapsible leaf rows (see _IngredientRow).
//   - Recipe templates load a flat List<Recipe> and render it as a list of
//     RecipeCard tiles with add/edit/delete buttons (see EditRecipeDialog).
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

  Future<void> _editRecipe(Recipe target) async {
    final result = await showDialog<Recipe>(
      context: context,
      builder: (context) => EditRecipeDialog(recipe: target),
    );
    if (result == null || !mounted) return;

    setState(() {
      _recipes = _recipes.map((r) => identical(r, target) ? result : r).toList();
      _isDirty = true;
    });
  }

  Future<void> _addRecipe() async {
    final result = await showDialog<Recipe>(
      context: context,
      builder: (context) => const EditRecipeDialog(),
    );
    if (result == null || !mounted) return;

    setState(() {
      _recipes = [..._recipes, result];
      _isDirty = true;
    });
  }

  // ---- Category actions ----------------------------------------------

  Future<void> _renameCategory(Category target) async {
    final newName = await _showTextPromptDialog(
      context,
      title: 'Zmień nazwę kategorii',
      label: 'Nazwa',
      initialValue: target.name,
    );
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

  // Bottom bar's "Dodaj grupę" - adds a brand-new top-level category, just
  // by name. Adding subcategories/ingredients under a *specific* existing
  // category instead goes through each category tile's own "+" button (see
  // _quickAddAt below).
  Future<void> _addTopLevelGroup() async {
    final name = await _showTextPromptDialog(context, title: 'Dodaj grupę', label: 'Nazwa grupy');
    if (name == null || !mounted) return;

    setState(() {
      _categories = [..._categories, Category(name: name)];
      _isDirty = true;
    });
  }

  // A category tile's "+" button - adds a new subcategory or ingredient
  // directly under `category`, with no destination picker needed since the
  // destination is exactly the row that was tapped.
  Future<void> _quickAddAt(Category category) async {
    final result = await showDialog<AddTemplateNodeResult>(
      context: context,
      builder: (context) => AddTemplateNodeDialog(destination: category, allCategories: _categories),
    );

    if (result == null || !mounted) return;

    setState(() {
      if (result.kind == TemplateNodeKind.category) {
        _categories = _insertCategoryInTree(_categories, category, Category(name: result.name));
      } else {
        final newIngredient = Ingredient(
          name: result.name,
          producer: result.producer,
          description: result.description,
          bottlesCount: result.bottlesCount,
          tags: result.tags,
        );
        _categories = _insertIngredientInTree(_categories, category, newIngredient);
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
      children: [
        // One continuous, rounded "table" - every category/ingredient row
        // lives inside this single Card (see _CategoryTile/_IngredientRow),
        // separated by thin Dividers, rather than each node floating in
        // its own separate card the way it used to.
        Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Column(
            // depth: 0 because these are the top-level categories; each
            // nested level below increases depth by one (see _CategoryTile
            // below), which drives both indentation and how dark the
            // row's subtle color tint is.
            children: _categories
                .map(
                  (category) => _CategoryTile(
                    category: category,
                    depth: 0,
                    onRenameCategory: _renameCategory,
                    onDeleteCategory: _deleteCategory,
                    onAddChild: _quickAddAt,
                    onEditIngredient: _editIngredient,
                    onDeleteIngredient: _deleteIngredient,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // canPop: false while there are unsaved edits means every attempt to
    // leave this screen (AppBar back arrow, system back gesture, Android
    // predictive back) is intercepted below instead of leaving immediately.
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        // didPop is true when canPop already let the navigation through
        // (i.e. there was nothing unsaved) - nothing left to do here.
        if (didPop) return;

        final shouldLeave = await _confirmLeaveWithoutSaving(context);
        if (shouldLeave && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
              if (!_isRecipeTemplate)
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  tooltip: 'Dodaj grupę',
                  onPressed: _isLoading ? null : _addTopLevelGroup,
                ),
              if (_isRecipeTemplate)
                _BottomBarAction(
                  icon: Icons.add,
                  label: 'Dodaj przepis',
                  onPressed: _isLoading ? null : _addRecipe,
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

// Asked when the user tries to leave this screen (back button/gesture)
// while there are unsaved edits - see the PopScope in build() below. Same
// "Tak/Nie"-style shape as _confirmDelete above, just worded for this case.
Future<bool> _confirmLeaveWithoutSaving(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Niezapisane zmiany'),
      content: const Text(
        'Masz niezapisane zmiany. Czy na pewno chcesz wyjść bez zapisywania?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Wyjdź bez zapisywania'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

// Simple single-text-field prompt - used for renaming a category
// (pre-filled with its current name) and for "Dodaj grupę" (blank), since
// both are really just "ask for one name".
Future<String?> _showTextPromptDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
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

// Builds the "N podkategorii • M składników" summary line shown under a
// category's title, so its row communicates how much content is grouped
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
// Renders one Category - recursively - as one row of the tree's table: a
// header (name, summary, and its add/edit/delete actions all on the same
// line) that can be tapped to expand/collapse its children, followed - when
// expanded - by one _CategoryTile per subcategory and one _IngredientRow
// per direct ingredient. It's a StatefulWidget purely to remember whether
// *this* row is expanded, the same "expansion state is local to each row"
// pattern CategoryTreeItem uses on the read-only browsing screen.
// ============================================================================
class _CategoryTile extends StatefulWidget {
  final Category category;

  // How many levels deep in the tree this node is - 0 for a top-level
  // category, 1 for its direct children, and so on. Drives both left
  // indentation and how dark the row's tint is (see categoryRowColor).
  final int depth;

  final ValueChanged<Category> onRenameCategory;
  final ValueChanged<Category> onDeleteCategory;
  final ValueChanged<Category> onAddChild;
  final ValueChanged<Ingredient> onEditIngredient;
  final ValueChanged<Ingredient> onDeleteIngredient;

  const _CategoryTile({
    required this.category,
    required this.depth,
    required this.onRenameCategory,
    required this.onDeleteCategory,
    required this.onAddChild,
    required this.onEditIngredient,
    required this.onDeleteIngredient,
  });

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  // Starts expanded, so the full tree is visible up front - the user can
  // still collapse individual branches afterwards.
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final depth = widget.depth;
    final hasChildren = category.subcategories.isNotEmpty || category.ingredients.isNotEmpty;
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: categoryRowColor(depth),
          child: InkWell(
            // Only a row with something inside it can be expanded/collapsed
            // - an empty category's header is otherwise inert.
            onTap: hasChildren ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16 + depth * 16.0, 10, 4, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _summaryFor(category),
                          style: TextStyle(color: mutedColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Dodaj do tej grupy',
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => widget.onAddChild(category),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edytuj kategorię',
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => widget.onRenameCategory(category),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Usuń kategorię',
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    // Using the theme's error color signals "destructive
                    // action" the same way delete buttons do elsewhere in
                    // Material Design.
                    color: Theme.of(context).colorScheme.error,
                    onPressed: () => widget.onDeleteCategory(category),
                  ),
                  if (hasChildren)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: mutedColor,
                    ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        if (_expanded) ...[
          ...category.subcategories.map(
            (sub) => _CategoryTile(
              category: sub,
              depth: depth + 1,
              onRenameCategory: widget.onRenameCategory,
              onDeleteCategory: widget.onDeleteCategory,
              onAddChild: widget.onAddChild,
              onEditIngredient: widget.onEditIngredient,
              onDeleteIngredient: widget.onDeleteIngredient,
            ),
          ),
          ...category.ingredients.map(
            (ingredient) => _IngredientRow(
              ingredient: ingredient,
              depth: depth + 1,
              onEdit: () => widget.onEditIngredient(ingredient),
              onDelete: () => widget.onDeleteIngredient(ingredient),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// _IngredientRow
// ----------------------------------------------------------------------------
// One ingredient leaf, rendered as a single table row: icon, name, bottle
// count, and its edit/delete actions, all on one line. A plain surface
// color (no depth tint, unlike _CategoryTile) marks it as a leaf rather
// than a group. Collapsed by default - tapping it (when there's anything to
// show) expands to reveal producer/description/tags, the same
// "table row that expands into a detail view" pattern used for ingredients
// on the read-only browsing screen (see IngredientsScreen's _IngredientTile).
// ============================================================================
class _IngredientRow extends StatefulWidget {
  final Ingredient ingredient;
  final int depth;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _IngredientRow({
    required this.ingredient,
    required this.depth,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<_IngredientRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ingredient = widget.ingredient;
    final hasDetails = ingredient.producer.isNotEmpty ||
        ingredient.description.isNotEmpty ||
        ingredient.tags.isNotEmpty;
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: InkWell(
            onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16 + widget.depth * 16.0, 10, 4, 10),
              child: Row(
                children: [
                  Icon(Icons.liquor_outlined, size: 16, color: mutedColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(ingredient.name, overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    '${ingredient.bottlesCount} but.',
                    style: TextStyle(color: mutedColor, fontSize: 12),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edytuj składnik',
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Usuń składnik',
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    color: Theme.of(context).colorScheme.error,
                    onPressed: widget.onDelete,
                  ),
                  if (hasDetails)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: mutedColor,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded && hasDetails)
          Padding(
            padding: EdgeInsets.fromLTRB(16 + (widget.depth + 1) * 16.0, 0, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ingredient.producer.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(ingredient.producer, style: TextStyle(color: mutedColor)),
                  ),
                if (ingredient.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(ingredient.description),
                  ),
                if (ingredient.tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ingredient.tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            backgroundColor: Colors.grey.shade200,
                            labelStyle: const TextStyle(color: Colors.black87),
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
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
