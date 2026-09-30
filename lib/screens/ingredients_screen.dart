import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../models/category.dart';
import '../widgets/app_drawer.dart';
import '../widgets/ingredient_tile.dart';
import '../widgets/search_field.dart';
import '../widgets/tag_filter_panel.dart';
import '../widgets/top_nav_tiles.dart';

// ============================================================================
// IngredientsScreen
// ----------------------------------------------------------------------------
// Shows a scrollable list of ingredients (e.g. everything in one category,
// or literally every ingredient in the app), with an inline search field
// and a collapsible tag filter sitting right below the back/home buttons.
//
// Deliberately read-only: this is the "guest" view of the inventory. The
// only place ingredients can be added or edited is through template
// management (Zarządzaj zestawami -> Edytuj szablony -> TemplateContentScreen)
// - there's no add/edit affordance here at all, by design.
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
  // panel (tags can exist on ingredients outside of `ingredients` above).
  final List<Category> allCategories;

  const IngredientsScreen({
    super.key,
    required this.ingredients,
    required this.title,
    required this.allCategories,
  });

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
  // Current visible list after applying filters. We keep a *separate*
  // filtered copy instead of filtering widget.ingredients directly inside
  // build(), so the filtering work only happens when search/tags actually
  // change - not on every rebuild for unrelated reasons.
  List<Ingredient> _filteredIngredients = [];

  // Text query for name/producer/description matching. Stored in lowercase
  // isn't necessary here since we lowercase at compare-time (see below).
  String _searchQuery = '';

  // Every tag that occurs anywhere in the full category tree (not just in
  // `widget.ingredients`), sorted alphabetically - computed once in
  // initState() since widget.allCategories never changes during this
  // screen's lifetime.
  List<String> _allTags = [];

  // Currently active tag filters. An ingredient matches if it carries *any*
  // of these - so starting with every tag selected (see initState) means
  // "show everything" up front, and the user narrowing it down by
  // deselecting tags one at a time is what actually filters the list.
  // Deselecting *all* of them means nothing can match anymore - the list
  // is meant to go empty, not silently fall back to "no filter".
  final Set<String> _selectedTags = {};

  @override
  void initState() {
    super.initState();

    // Using a Set<String> while collecting automatically de-duplicates
    // repeated tags; sort() afterwards is what gives the filter panel its
    // alphabetical order.
    final tags = <String>{};
    for (final category in widget.allCategories) {
      for (final ingredient in category.allIngredients) {
        tags.addAll(ingredient.tags);
      }
    }
    _allTags = tags.toList()..sort();

    // Start in "select all" mode, so every (tagged) ingredient is shown by
    // default - computed the same way _filterIngredients() would, via
    // _applyFilters(), so the very first frame is already consistent with
    // what toggling a tag off-and-back-on would produce.
    _selectedTags.addAll(_allTags);
    _filteredIngredients = _applyFilters();
  }

  // The actual filtering logic, factored out so both initState() (which
  // can't call setState()) and _filterIngredients() below share exactly
  // one implementation.
  List<Ingredient> _applyFilters() {
    // Lowercase the query once, up front, instead of inside the loop below.
    // Calling toLowerCase() per-ingredient-per-field would repeat the same
    // conversion of `_searchQuery` over and over for no benefit, since the
    // query itself doesn't change while we're filtering this one list.
    final query = _searchQuery.toLowerCase();

    return widget.ingredients.where((ingredient) {
      // Match if the query is empty (nothing to filter on) OR it appears
      // in any of the ingredient's user-facing text fields.
      final matchesSearch = query.isEmpty ||
          ingredient.name.toLowerCase().contains(query) ||
          ingredient.producer.toLowerCase().contains(query) ||
          ingredient.description.toLowerCase().contains(query);

      // Match only if the ingredient carries at least one selected tag -
      // so an empty _selectedTags (everything deselected) means nothing
      // matches, by design (see the field comment above).
      final matchesTags = ingredient.tags.any(_selectedTags.contains);

      // An item stays visible only if *all* active filters pass - this is
      // how search text and tag filter combine (logical AND).
      return matchesSearch && matchesTags;
    }).toList();
  }

  // Recomputes the visible list based on the current search text and
  // selected tags. Called any time either filter changes.
  void _filterIngredients() {
    setState(() => _filteredIngredients = _applyFilters());
  }

  void _onSearchChanged(String value) {
    _searchQuery = value;
    _filterIngredients();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (!_selectedTags.remove(tag)) {
        _selectedTags.add(tag);
      }
    });
    _filterIngredients();
  }

  // "Zaznacz wszystko" is really a toggle: if everything is already
  // selected, tapping it clears the filter instead of being a no-op.
  void _toggleSelectAllTags() {
    setState(() {
      if (_selectedTags.length == _allTags.length) {
        _selectedTags.clear();
      } else {
        _selectedTags
          ..clear()
          ..addAll(_allTags);
      }
    });
    _filterIngredients();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      drawer: const AppDrawer(),
      // CustomScrollView + slivers instead of a Column with an Expanded
      // list: that older layout gave the ingredient list whatever space
      // was left over after the (variable-height, since the tag panel can
      // expand) header, so a tall expanded tag panel could squeeze the
      // list down to nothing and force collapsing it again just to see
      // results. Here, everything - nav tiles, search, tag panel, and the
      // ingredient cards - scrolls together as one page, so expanding the
      // tag panel just pushes the list further down instead of shrinking
      // its viewport.
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const TopNavTiles(),
                SearchField(
                  hintText: 'Szukaj po nazwie, producencie lub opisie',
                  onChanged: _onSearchChanged,
                ),
                TagFilterPanel(
                  title: 'Filtruj po tagach',
                  allTags: _allTags,
                  selectedTags: _selectedTags,
                  onToggleTag: _toggleTag,
                  onToggleSelectAll: _toggleSelectAllTags,
                ),
              ],
            ),
          ),
          // SliverList.builder only builds the list tiles that are
          // actually visible on screen (plus a small buffer), the same
          // laziness ListView.builder gave us before - just contributing
          // to the shared CustomScrollView instead of scrolling on its
          // own.
          SliverList.builder(
            itemCount: _filteredIngredients.length,
            itemBuilder: (context, index) => IngredientTile(ingredient: _filteredIngredients[index]),
          ),
        ],
      ),
    );
  }
}
