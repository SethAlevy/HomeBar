import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../models/category.dart';
import 'edit_ingredient_screen.dart';

// Displays a list of ingredients with search/tag filtering.
class IngredientsScreen extends StatefulWidget {
  // Source ingredients for this view (can be category-specific).
  final List<Ingredient> ingredients;

  // Screen title shown in AppBar.
  final String title;

  // Full category tree; used to collect all possible tags.
  final List<Category> allCategories;

  // Where a newly added ingredient should be inserted by default.
  final String? sourceCategoryName;

  const IngredientsScreen({
    super.key,
    required this.ingredients,
    required this.title,
    required this.allCategories,
    this.sourceCategoryName,
  });

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
  // Current visible list after applying filters.
  List<Ingredient> _filteredIngredients = [];

  // Text query for name/producer/description matching.
  String _searchQuery = '';

  // Active tag filter (empty means no tag filter).
  String _selectedTag = '';

  @override
  void initState() {
    super.initState();

    // Start by showing all provided ingredients.
    _filteredIngredients = widget.ingredients;
  }

  // Recomputes visible list based on current search and selected tag.
  void _filterIngredients() {
    setState(() {
      _filteredIngredients = widget.ingredients.where((ingredient) {
        // Match if query appears in any user-facing text field.
        final matchesSearch = _searchQuery.isEmpty ||
            ingredient.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            ingredient.producer.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            ingredient.description.toLowerCase().contains(_searchQuery.toLowerCase());

        // Match tag when one is selected.
        final matchesTag = _selectedTag.isEmpty ||
            ingredient.tags.contains(_selectedTag);

        // Item stays visible only if all active filters pass.
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
      body: ListView.builder(
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
      floatingActionButton: FloatingActionButton(
        // Create ingredient; result is saved in edit screen.
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditIngredientScreen(
              ingredient: null,
              allCategories: widget.allCategories,
              targetCategoryName: widget.sourceCategoryName,
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  // Dialog for entering search text.
  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          decoration: const InputDecoration(hintText: 'Search by name, producer, or description'),
          onChanged: (value) {
            // Update query immediately while user types.
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
    // Build a unique set of tags from the full dataset.
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
            shrinkWrap: true,
            itemCount: allTags.length,
            itemBuilder: (context, index) {
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
