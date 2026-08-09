import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/template_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/recipe_card.dart';
import '../widgets/search_field.dart';
import '../widgets/tag_filter_panel.dart';
import '../widgets/top_nav_tiles.dart';

// ============================================================================
// RecipesScreen
// ----------------------------------------------------------------------------
// Browsing view for cocktail recipes - the recipe equivalent of
// IngredientsScreen, right down to sharing the same SearchField and
// TagFilterPanel widgets and "start with every tag selected, deselecting
// all of them shows nothing" filtering rule.
//
// Unlike IngredientsScreen, this screen loads its own data (there's no
// "browse by category" step for recipes the way CategoryBrowserScreen
// provides for ingredients - a recipe template is just a flat list), by
// resolving whichever recipe template is currently active (see
// TemplateService.resolveActiveRecipeTemplate) and reading its recipes.
// Also deliberately read-only, same as IngredientsScreen: adding/editing
// recipes isn't implemented yet.
// ============================================================================
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  List<Recipe> _recipes = [];
  bool _isLoading = true;

  // Current visible list after applying filters - see IngredientsScreen
  // for why this is kept separate from _recipes instead of filtering
  // inline inside build().
  List<Recipe> _filteredRecipes = [];

  String _searchQuery = '';

  // Every tag across all loaded recipes, sorted alphabetically.
  List<String> _allTags = [];

  // Same "select all by default, deselecting everything shows nothing"
  // rule as IngredientsScreen - see its field comment for the reasoning.
  final Set<String> _selectedTags = {};

  // Match keys (see RecipeIngredient.matchKey) currently backed by stock -
  // used to decide which recipes actually pass the "available" filter
  // below. See TemplateService.loadAvailableMatchKeys().
  Set<String> _availableMatchKeys = {};

  // Whether the list is restricted to recipes that can currently be
  // prepared. Defaults to on, but stays a toggle (rather than a hard rule)
  // since availability is only as good as the recipe/ingredient YAML's
  // match keys - a switch lets the user fall back to the full list if
  // something looks wrongly hidden.
  bool _availableOnly = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final template = await TemplateService.resolveActiveRecipeTemplate();
    final recipes = await TemplateService.loadRecipes(template);
    final availableMatchKeys = await TemplateService.loadAvailableMatchKeys();

    if (!mounted) return;

    final tags = <String>{};
    for (final recipe in recipes) {
      tags.addAll(recipe.tags);
    }

    setState(() {
      _recipes = recipes;
      _availableMatchKeys = availableMatchKeys;
      _allTags = tags.toList()..sort();
      _selectedTags
        ..clear()
        ..addAll(_allTags);
      _isLoading = false;
      _filteredRecipes = _applyFilters();
    });
  }

  // The actual filtering logic, factored out so both _load() (which can't
  // call setState() while already inside one) and _filterRecipes() below
  // share exactly one implementation.
  List<Recipe> _applyFilters() {
    final query = _searchQuery.toLowerCase();

    return _recipes.where((recipe) {
      // Match if the query is empty (nothing to filter on) OR it appears
      // in the recipe's name, its instructions, or any ingredient it uses.
      final matchesSearch = query.isEmpty ||
          recipe.name.toLowerCase().contains(query) ||
          recipe.instructions.toLowerCase().contains(query) ||
          recipe.comments.toLowerCase().contains(query) ||
          recipe.ingredients.any((i) => i.name.toLowerCase().contains(query));

      // Match only if the recipe carries at least one selected tag - so
      // an empty _selectedTags (everything deselected) means nothing
      // matches, by design (see the field comment above).
      final matchesTags = recipe.tags.any(_selectedTags.contains);

      final matchesAvailability = !_availableOnly || recipe.isAvailable(_availableMatchKeys);

      return matchesSearch && matchesTags && matchesAvailability;
    }).toList();
  }

  void _filterRecipes() {
    setState(() => _filteredRecipes = _applyFilters());
  }

  void _onSearchChanged(String value) {
    _searchQuery = value;
    _filterRecipes();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (!_selectedTags.remove(tag)) {
        _selectedTags.add(tag);
      }
    });
    _filterRecipes();
  }

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
    _filterRecipes();
  }

  void _toggleAvailableOnly(bool value) {
    _availableOnly = value;
    _filterRecipes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Przepisy')),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recipes.isEmpty
              ? const Center(child: Text('Brak przepisów.'))
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const TopNavTiles(),
                          SearchField(
                            hintText: 'Szukaj po nazwie, składnikach lub instrukcji',
                            onChanged: _onSearchChanged,
                          ),
                          TagFilterPanel(
                            title: 'Filtruj po tagach',
                            allTags: _allTags,
                            selectedTags: _selectedTags,
                            onToggleTag: _toggleTag,
                            onToggleSelectAll: _toggleSelectAllTags,
                          ),
                          SwitchListTile(
                            title: const Text('Tylko dostępne przepisy'),
                            subtitle: const Text('Na podstawie stanu składników'),
                            value: _availableOnly,
                            onChanged: _toggleAvailableOnly,
                          ),
                        ],
                      ),
                    ),
                    if (_filteredRecipes.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('Brak przepisów spełniających kryteria.')),
                      )
                    else
                      SliverList.builder(
                        itemCount: _filteredRecipes.length,
                        itemBuilder: (context, index) => RecipeCard(recipe: _filteredRecipes[index]),
                      ),
                  ],
                ),
    );
  }
}
