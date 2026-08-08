import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../models/category.dart';
import '../services/template_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/top_nav_tiles.dart';
import 'edit_ingredient_screen.dart';

// ============================================================================
// IngredientsScreen
// ----------------------------------------------------------------------------
// Shows a scrollable list of ingredients (e.g. everything in one category,
// or literally every ingredient in the app) with a text search and a tag
// filter. Also exposes a "+" button to create a brand-new ingredient.
//
// This screen doesn't load data itself - it is handed an already-prepared
// `ingredients` list by whoever navigated to it (see CategoryBrowserScreen).
// That keeps this widget simple: its only job is to filter/display what
// it was given.
// ============================================================================
class IngredientsScreen extends StatefulWidget {
  // Source ingredients for this view (can be category-specific).
  final List<Ingredient> ingredients;

  // Screen title shown in AppBar.
  final String title;

  // Full category tree; used to collect all possible tags for the filter
  // dialog (tags can exist on ingredients outside of `ingredients` above).
  final List<Category> allCategories;

  // Where a newly added ingredient should be inserted by default.
  final String? sourceCategoryName;

  // Which template allCategories came from - passed straight through to
  // EditIngredientScreen so a new/edited ingredient gets saved back to the
  // right template.
  final TemplateFile activeTemplate;

  const IngredientsScreen({
    super.key,
    required this.ingredients,
    required this.title,
    required this.allCategories,
    required this.activeTemplate,
    this.sourceCategoryName,
  });

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
  // Current visible list after applying filters. We keep a *separate*
  // filtered copy instead of filtering widget.ingredients directly inside
  // build(), so the filtering work only happens when search/tag actually
  // change - not on every rebuild for unrelated reasons.
  List<Ingredient> _filteredIngredients = [];

  // Text query for name/producer/description matching. Stored in lowercase
  // isn't necessary here since we lowercase at compare-time (see below).
  String _searchQuery = '';

  // Active tag filter (empty string means "no tag filter applied").
  String _selectedTag = '';

  @override
  void initState() {
    super.initState();

    // Start by showing all provided ingredients, unfiltered.
    _filteredIngredients = widget.ingredients;
  }

  // Recomputes the visible list based on the current search text and
  // selected tag. Called any time either filter changes.
  void _filterIngredients() {
    // Lowercase the query once, up front, instead of inside the loop below.
    // Calling toLowerCase() per-ingredient-per-field would repeat the same
    // conversion of `_searchQuery` over and over for no benefit, since the
    // query itself doesn't change while we're filtering this one list.
    final query = _searchQuery.toLowerCase();

    setState(() {
      _filteredIngredients = widget.ingredients.where((ingredient) {
        // Match if the query is empty (nothing to filter on) OR it appears
        // in any of the ingredient's user-facing text fields.
        final matchesSearch = query.isEmpty ||
            ingredient.name.toLowerCase().contains(query) ||
            ingredient.producer.toLowerCase().contains(query) ||
            ingredient.description.toLowerCase().contains(query);

        // Match tag when one is selected; otherwise every item passes.
        final matchesTag = _selectedTag.isEmpty ||
            ingredient.tags.contains(_selectedTag);

        // An item stays visible only if *all* active filters pass - this is
        // how search text and tag filter combine (logical AND).
        return matchesSearch && matchesTag;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            // Opens text input dialog for live search.
            onPressed: () => _showSearchDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            // Opens tag picker dialog.
            onPressed: () => _showTagFilterDialog(context),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          const TopNavTiles(),
          // Expanded makes the list take up all remaining vertical space
          // in the Column, so it can scroll within the fixed-size screen.
          Expanded(
            child: ListView.builder(
              // ListView.builder only builds the list tiles that are
              // actually visible on screen (plus a small buffer), which
              // keeps scrolling smooth even for long ingredient lists.
              itemCount: _filteredIngredients.length,
              itemBuilder: (context, index) {
                final ingredient = _filteredIngredients[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text(ingredient.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ingredient.producer),
                        Text(ingredient.description),
                        // Render tags as small chips for quick scanning.
                        if (ingredient.tags.isNotEmpty)
                          Wrap(
                            spacing: 4.0,
                            children: ingredient.tags
                                .map((tag) => Chip(
                                      label: Text(tag),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ))
                                .toList(),
                          ),
                      ],
                    ),
                    trailing: Text('${ingredient.bottlesCount} bottles'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        // Passing ingredient: null tells EditIngredientScreen "create new"
        // mode instead of "edit existing" mode. The result it pops back
        // with (the created Ingredient) isn't consumed here yet, but the
        // screen already persists it via TemplateService internally.
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditIngredientScreen(
              ingredient: null,
              allCategories: widget.allCategories,
              targetCategoryName: widget.sourceCategoryName,
              activeTemplate: widget.activeTemplate,
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  // Dialog for entering search text. Uses a plain (non-Form) TextField
  // since there's nothing to validate - any text, including empty, is OK.
  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          decoration: const InputDecoration(hintText: 'Search by name, producer, or description'),
          onChanged: (value) {
            // Update query immediately while user types, so the list
            // behind the dialog updates live as they type each letter.
            _searchQuery = value;
            _filterIngredients();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Reset search and refresh list.
              _searchQuery = '';
              _filterIngredients();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTagFilterDialog(BuildContext context) {
    // Build a unique set of tags from the *full* dataset (all categories),
    // not just the ingredients currently shown on screen - so the filter
    // list is complete even when viewing a single category.
    // Using a Set<String> automatically de-duplicates repeated tags.
    final allTags = <String>{};
    for (final category in widget.allCategories) {
      for (final ingredient in category.allIngredients) {
        allTags.addAll(ingredient.tags);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Tag'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            // shrinkWrap lets this ListView size itself to its content
            // instead of trying to fill infinite height, which is required
            // when a ListView is placed inside a dialog.
            shrinkWrap: true,
            itemCount: allTags.length,
            itemBuilder: (context, index) {
              // Sets don't support index access directly, so elementAt()
              // walks to the Nth element - fine for the small tag counts
              // expected here.
              final tag = allTags.elementAt(index);
              return ListTile(
                title: Text(tag),
                onTap: () {
                  // Apply selected tag and close picker.
                  _selectedTag = tag;
                  _filterIngredients();
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Remove tag filter and show all matching search results.
              _selectedTag = '';
              _filterIngredients();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
