import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/template_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/top_nav_tiles.dart';
import 'ingredients_screen.dart';

// ============================================================================
// CategoryBrowserScreen
// ----------------------------------------------------------------------------
// Entry point for browsing ingredients organized by category. It loads the
// full category tree once - from whichever ingredient template is
// currently "active" (see TemplateService.resolveActiveIngredientTemplate,
// which is driven by the selection made in "Zarządzaj zestawami") - then
// renders it as a list of expandable CategoryTreeItem rows.
// ============================================================================
class CategoryBrowserScreen extends StatefulWidget {
  const CategoryBrowserScreen({super.key});

  @override
  State<CategoryBrowserScreen> createState() => _CategoryBrowserScreenState();
}

class _CategoryBrowserScreenState extends State<CategoryBrowserScreen> {
  List<Category> _categories = [];

  // Which template _categories was loaded from - threaded down into
  // IngredientsScreen/EditIngredientScreen so that adding or editing an
  // ingredient saves back to this same template, not some other one.
  TemplateFile? _activeTemplate;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final template = await TemplateService.resolveActiveIngredientTemplate();
    final categories = await TemplateService.loadTemplateCategories(template);

    if (!mounted) return;

    setState(() {
      _activeTemplate = template;
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
          // Only reachable once loading has finished (see build() below),
          // so _activeTemplate is always set by this point.
          activeTemplate: _activeTemplate!,
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
              children: [
                const TopNavTiles(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openAllIngredients(context),
                      icon: const Icon(Icons.liquor_outlined, size: 18),
                      label: const Text('Wyświetl wszystkie'),
                    ),
                  ),
                ),
                // Spread operator (...) inlines each mapped widget directly
                // into this children list, as if we had written them out
                // one by one - one top-level tree row per top-level category.
                ..._categories.map(
                  (category) => CategoryTreeItem(
                    category: category,
                    allCategories: _categories,
                    activeTemplate: _activeTemplate!,
                  ),
                ),
              ],
            ),
    );
  }
}

// ============================================================================
// CategoryTreeItem
// ----------------------------------------------------------------------------
// Renders a single category as a tappable card, plus (if it has
// subcategories) an expand/collapse arrow that reveals nested
// CategoryTreeItem rows for each subcategory - i.e. this widget recursively
// builds itself to represent an arbitrarily deep category tree.
//
// It's a StatefulWidget purely to remember whether *this* row is expanded;
// that state is local to each row and doesn't need to live in a parent.
// ============================================================================
class CategoryTreeItem extends StatefulWidget {
  final Category category;

  // The complete category tree (not just this branch) - passed through
  // unchanged so that deeper screens (like the tag filter) can see tags
  // used anywhere in the app, not just under this category.
  final List<Category> allCategories;

  // Which template allCategories came from - passed through unchanged so
  // that adding/editing an ingredient from anywhere in this tree saves
  // back to the right template.
  final TemplateFile activeTemplate;

  const CategoryTreeItem({
    super.key,
    required this.category,
    required this.allCategories,
    required this.activeTemplate,
  });

  @override
  State<CategoryTreeItem> createState() => _CategoryTreeItemState();
}

class _CategoryTreeItemState extends State<CategoryTreeItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final hasSubcategories = widget.category.subcategories.isNotEmpty;

    // `allIngredients` recursively walks this category's whole subtree, so
    // it's computed once here and reused below (for both the "N produktów"
    // subtitle and the tap handler) instead of calling it twice and doing
    // that walk redundantly on every build.
    final ingredients = widget.category.allIngredients;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            color: Theme.of(context).colorScheme.secondaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              leading: Icon(
                // Folder icon for a category that groups other categories,
                // bottle icon for one that directly holds ingredients.
                hasSubcategories
                    ? Icons.folder_outlined
                    : Icons.liquor_outlined,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              title: Text(
                widget.category.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              subtitle: Text(
                '${ingredients.length} produktów',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              onTap: () {
                // Tapping the row (not the expand arrow) drills into a
                // dedicated screen listing every ingredient in this branch.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IngredientsScreen(
                      ingredients: ingredients,
                      title: widget.category.name,
                      allCategories: widget.allCategories,
                      sourceCategoryName: widget.category.name,
                      activeTemplate: widget.activeTemplate,
                    ),
                  ),
                );
              },
              trailing: hasSubcategories
                  // Only show the expand/collapse arrow when there's
                  // actually something to expand into.
                  ? IconButton(
                      icon: Icon(
                        _isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      onPressed: () {
                        // setState() here only rebuilds this row (and its
                        // children), not the whole screen.
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                    )
                  : null,
            ),
          ),
        ),

        if (_isExpanded)
          Padding(
            // Indent nested rows so the tree hierarchy is visible at a
            // glance - each depth level shifts 24px further right.
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              children: widget.category.subcategories
                  .map(
                    // Recursive step: each subcategory becomes its own
                    // CategoryTreeItem, which can itself expand further.
                    (subcategory) => CategoryTreeItem(
                      category: subcategory,
                      allCategories: widget.allCategories,
                      activeTemplate: widget.activeTemplate,
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
