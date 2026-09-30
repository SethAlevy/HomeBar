import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/template_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/category_row_color.dart';
import '../widgets/ingredient_tile.dart';
import '../widgets/top_nav_tiles.dart';
import 'ingredients_screen.dart';

// ============================================================================
// CategoryBrowserScreen
// ----------------------------------------------------------------------------
// Entry point for browsing ingredients organized by category. It loads the
// full category tree once - from whichever ingredient template is
// currently "active" (see TemplateService.resolveActiveIngredientTemplate,
// which is driven by the selection made in "Zarządzaj zestawami") - then
// renders it as one continuous, collapsible table (see _BrowseCategoryTile),
// the same visual structure TemplateContentScreen's editor uses for the
// same tree, just without any of its edit/add/delete actions - this screen
// is read-only, so there's nothing for a button to do here. Ingredients sit
// inline as IngredientTile cards wherever their category is expanded, the
// same tile IngredientsScreen's flat, searchable list uses (reachable here
// via "Wyświetl wszystkie" below).
// ============================================================================
class CategoryBrowserScreen extends StatefulWidget {
  const CategoryBrowserScreen({super.key});

  @override
  State<CategoryBrowserScreen> createState() => _CategoryBrowserScreenState();
}

class _CategoryBrowserScreenState extends State<CategoryBrowserScreen> {
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    // Which ingredient template is "active" only matters for figuring out
    // *what* to load here - IngredientsScreen further down is read-only
    // (see its docs), so there's no need to keep the template itself
    // around afterwards.
    final template = await TemplateService.resolveActiveIngredientTemplate();
    final categories = await TemplateService.loadTemplateCategories(template);

    if (!mounted) return;

    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  // Opens a flat view of every ingredient across every category, using
  // `expand` to flatten the per-category ingredient lists into one list
  // (like a "SelectMany" in other languages).
  void _openAllIngredients(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IngredientsScreen(
          ingredients: _categories.expand((c) => c.allIngredients).toList(),
          title: 'Wszystkie składniki',
          allCategories: _categories,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Składniki',
          style: TextStyle(fontWeight: FontWeight.bold,),
        ),
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const TopNavTiles(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openAllIngredients(context),
                      icon: const Icon(Icons.liquor_outlined, size: 18),
                      label: const Text('Wyświetl wszystkie'),
                    ),
                  ),
                ),
                if (_categories.isNotEmpty)
                  // One continuous, rounded "table" - every category row
                  // (and, once expanded, its ingredients) lives inside this
                  // single Card, separated by thin Dividers - see
                  // TemplateContentScreen's _buildCategoryTree, which builds
                  // the editable counterpart of exactly this same table.
                  Card(
                    clipBehavior: Clip.antiAlias,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: _categories
                          .map((category) => _BrowseCategoryTile(category: category, depth: 0))
                          .toList(),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ============================================================================
// _BrowseCategoryTile
// ----------------------------------------------------------------------------
// One row of the read-only table built by CategoryBrowserScreen: a header
// (name + "N podkategorii • M składników" summary) that expands/collapses
// its children on tap - no edit/add/delete actions, since this screen is
// read-only. When expanded, shows one _BrowseCategoryTile per subcategory
// and one IngredientTile per direct ingredient, inline. Mirrors
// TemplateContentScreen's _CategoryTile - same row tinting (categoryRowColor)
// and "one continuous table" structure - just without its action buttons.
// ============================================================================
class _BrowseCategoryTile extends StatefulWidget {
  final Category category;

  // How many levels deep in the tree this node is - 0 for a top-level
  // category, 1 for its direct children, and so on. Drives how dark the
  // row's tint is (see categoryRowColor) and how large/bold its name reads
  // (see _categoryNameStyle) - deliberately *not* left indentation, so
  // every row - and every ingredient tile nested under it - keeps the
  // table's full width regardless of how deep it sits.
  final int depth;

  const _BrowseCategoryTile({required this.category, required this.depth});

  @override
  State<_BrowseCategoryTile> createState() => _BrowseCategoryTileState();
}

class _BrowseCategoryTileState extends State<_BrowseCategoryTile> {
  // Starts collapsed - the user drills down into just the branches they
  // care about, rather than the whole tree dumping open at once.
  bool _expanded = false;

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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: _categoryNameStyle(depth),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _summaryFor(category),
                          style: TextStyle(color: mutedColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (hasChildren)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
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
            (sub) => _BrowseCategoryTile(category: sub, depth: depth + 1),
          ),
          ...category.ingredients.map(
            (ingredient) => IngredientTile(ingredient: ingredient),
          ),
        ],
      ],
    );
  }
}

// Picks a category name's text style for a given nesting depth: bold and
// largest at the top level, getting smaller and lighter-weight with each
// level deeper - the nesting cue that used to be left indentation, now that
// rows no longer shift right by depth (see the `depth` field doc above).
TextStyle _categoryNameStyle(int depth) {
  final fontSize = (17 - depth * 1.5).clamp(12.0, 17.0);
  final fontWeight = switch (depth) {
    0 => FontWeight.bold,
    1 => FontWeight.w600,
    _ => FontWeight.w500,
  };
  return TextStyle(fontSize: fontSize, fontWeight: fontWeight);
}

// Builds the "N podkategorii • M składników" summary line shown under a
// category's name - the same summary TemplateContentScreen's editor shows
// for the same data.
String _summaryFor(Category category) {
  final subcategoryCount = category.subcategories.length;
  final ingredientCount = category.allIngredients.length;

  if (subcategoryCount > 0) {
    return '$subcategoryCount podkategorii • $ingredientCount składników';
  }
  return '$ingredientCount składników';
}
